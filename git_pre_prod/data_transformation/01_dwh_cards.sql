--- TABLE CARDS ---

DROP TABLE IF EXISTS public.dwh_cards;

CREATE TABLE public.dwh_cards AS
  SELECT DISTINCT card_type, card_name, card_url 
  FROM public.wrk_decklists
  WHERE card_type like 'Pok%';

--- IS_LAST_EVOLUTION ---

ALTER TABLE public.tcg_cards
ADD COLUMN is_last_evolution BOOLEAN;

UPDATE public.tcg_cards ca
SET is_last_evolution = CASE
    WHEN EXISTS (
        SELECT 1
        FROM public.tcg_cards
        WHERE evolves_from = ca.name
    ) THEN FALSE
    ELSE TRUE
END
WHERE ca.card_type like 'Pok%';

--- TABLE DECKS ---

DROP TABLE IF EXISTS public.decks;

CREATE TABLE public.decks AS
SELECT
    de.player_id,
    de.tournament_id,
    STRING_AGG(DISTINCT ce.name, ', ' ORDER BY ce.name) AS deck
FROM
    public.wrk_decklists de
LEFT JOIN
    public.tcg_cards ce ON de.card_url = ce.full_url
WHERE
    ce.is_last_evolution IS TRUE
GROUP BY
    de.player_id, de.tournament_id;

--- TOURNAMENT_ID DANS MATCH RES ---

ALTER TABLE public.wrk_match_results
ADD COLUMN tournament_id TEXT;

UPDATE public.wrk_match_results mr
SET tournament_id = t.tournament_id
FROM public.wrk_matches t
WHERE mr.match_id = t.id;

DROP TABLE IF EXISTS public.wrk_matches CASCADE;

--- WINNER/LOOSER IN MATCH RES ---

ALTER TABLE public.wrk_match_results
ADD COLUMN IF NOT EXISTS winner_looser VARCHAR;

WITH match_scores AS (
    SELECT
        match_id,
        player_id,
        score,
        MAX(score) OVER (PARTITION BY match_id) AS max_score,
        MIN(score) OVER (PARTITION BY match_id) AS min_score
    FROM
        public.wrk_match_results
)
UPDATE public.wrk_match_results mr
SET winner_looser = CASE
    WHEN ms.max_score = ms.min_score THEN 'Draw'
    WHEN mr.score = ms.max_score THEN 'Winner'
    ELSE 'Looser'
END
FROM match_scores ms
WHERE mr.match_id = ms.match_id AND mr.player_id = ms.player_id;

--- TABLE WIN RATE PER DECK ---

DROP TABLE IF EXISTS public.win_rate_deck;

CREATE TABLE public.win_rate_deck AS

SELECT
    de.tournament_id,
    de.deck,
    COUNT(*) FILTER (WHERE mr.winner_looser = 'Winner') AS nb_win,
    COUNT(*) AS participation
FROM
    public.decks de
LEFT JOIN
    public.wrk_match_results mr ON de.tournament_id = mr.tournament_id AND de.player_id = mr.player_id
GROUP BY
    de.tournament_id, de.deck;

--- TABLE DECK_LINK ---

DROP TABLE IF EXISTS public.deck_link;

CREATE TABLE public.deck_link AS
WITH deck_list AS (
    SELECT
        STRING_AGG(DISTINCT ce.name, ', ' ORDER BY ce.name) AS deck,
        ARRAY_AGG(DISTINCT ce.full_url) AS card_urls
    FROM
        public.wrk_decklists de
    LEFT JOIN
        public.tcg_cards ce ON de.card_url = ce.full_url
    WHERE
        ce.is_last_evolution IS TRUE
    GROUP BY
    	de.player_id, de.tournament_id
        
)
SELECT
    deck,
    unnest(card_urls) AS card_url
FROM
    deck_list;

--- ADD EXTENSION AT DWH_CARDS ---

ALTER TABLE dwh_cards
ADD COLUMN extension TEXT;

UPDATE dwh_cards
SET extension = CASE
    WHEN card_name LIKE '%(A%' THEN
        SPLIT_PART(SUBSTRING(card_name, STRPOS(card_name, '(') + 1, STRPOS(card_name, ')') - STRPOS(card_name, '(') - 1), '-', 1)
    WHEN card_name LIKE '%(P%' THEN
        'P-A'
    ELSE 'No extension'
END;

--- ADD MAIN_DECK ---

ALTER TABLE decks ADD COLUMN main_deck TEXT;


-- 1. Explosion des cartes avec version brute et version normalisée (sans 'ex')
WITH exploded AS (
  SELECT
    d.player_id,
    d.tournament_id,
    d.deck,
    TRIM(c) AS card,
    -- Version "normalisée" : minuscule, sans ' ex', sans accents éventuels
    LOWER(regexp_replace(TRIM(c), '\s+ex$', '', 'gi')) AS base_card
  FROM decks d,
  unnest(string_to_array(d.deck, ',')) AS c
),

-- 2. Création d’une "signature de famille" pour chaque deck (tri des noms normalisés)
deck_family AS (
  SELECT
    player_id,
    tournament_id,
    deck,
    (SELECT string_agg(base_card, '|' ORDER BY base_card)
     FROM (
       SELECT DISTINCT LOWER(regexp_replace(TRIM(c), '\s+ex$', '', 'gi')) AS base_card
       FROM unnest(string_to_array(deck, ',')) AS c
     ) AS cleaned
    ) AS family_signature
  FROM decks
),

-- 3. Associer les cartes explosées à leur famille
exploded_with_signature AS (
  SELECT
    e.player_id,
    e.tournament_id,
    e.deck,
    e.card,
    e.base_card,
    d.family_signature
  FROM exploded e
  JOIN deck_family d
    ON e.player_id = d.player_id AND e.tournament_id = d.tournament_id
),

-- 4. Compter les cartes les plus fréquentes dans chaque famille
card_counts AS (
  SELECT
    family_signature,
    card,          
    base_card,
    COUNT(*) AS count
  FROM exploded_with_signature
  GROUP BY family_signature, card, base_card
),

-- 5. Ranker les cartes dans chaque famille selon leur base_card
ranked_cards AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY family_signature, base_card
      ORDER BY count DESC, card
    ) AS card_rank
  FROM card_counts
),

-- 6. Sélectionner la version la plus fréquente de chaque base_card
best_card_names AS (
  SELECT
    family_signature,
    base_card,
    card
  FROM ranked_cards
  WHERE card_rank = 1
),

-- 7. Compter la fréquence totale de chaque base_card par famille
base_card_counts AS (
  SELECT
    family_signature,
    base_card,
    SUM(count) AS total_count
  FROM card_counts
  GROUP BY family_signature, base_card
),

-- 8. Récupérer les 2 cartes les plus fréquentes par famille
top2_base_cards AS (
  SELECT
    b.family_signature,
    b.base_card,
    n.card
  FROM base_card_counts b
  JOIN best_card_names n
    ON b.family_signature = n.family_signature AND b.base_card = n.base_card
  ORDER BY b.family_signature, b.total_count DESC, n.card
),

-- 9. Garder les 2 premières par famille
final_main_decks AS (
  SELECT
    family_signature,
    string_agg(card, ', ' ORDER BY card) AS main_deck
  FROM (
    SELECT *,
      ROW_NUMBER() OVER (PARTITION BY family_signature ORDER BY base_card) AS rk
    FROM top2_base_cards
  ) ranked
  WHERE rk <= 2
  GROUP BY family_signature
),

deck_to_update AS (
  SELECT
    df.player_id,
    df.tournament_id,
    m.main_deck
  FROM deck_family df
  JOIN final_main_decks m ON df.family_signature = m.family_signature
)

-- Add main_deck
UPDATE decks d
SET main_deck = u.main_deck
FROM deck_to_update u
WHERE d.player_id = u.player_id AND d.tournament_id = u.tournament_id;

--- TABLE WINRATE MAIN_DECK ---

DROP TABLE IF EXISTS public.win_rate_main_deck;

CREATE TABLE public.win_rate_main_deck AS

SELECT
    de.tournament_id,
    de.main_deck,
    COUNT(*) FILTER (WHERE mr.winner_looser = 'Winner') AS nb_win,
    COUNT(*) AS participation
FROM
    public.decks de
LEFT JOIN
    public.wrk_match_results mr ON de.tournament_id = mr.tournament_id AND de.player_id = mr.player_id
GROUP BY
    de.tournament_id, de.main_deck;