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
    DISTINCT deck,
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

--- TABLE WIN/LOOSE PER DECK VS DECK---

DROP TABLE IF EXISTS public.stats_decks;

CREATE TABLE public.stats_decks AS

WITH winner AS (
    SELECT DISTINCT
        mr.tournament_id,
        mr.match_id,
        mr.player_id AS player_winner,
        d.deck AS deck_winner
    FROM public.decks d
    LEFT JOIN public.wrk_match_results mr
        ON mr.tournament_id = d.tournament_id AND mr.player_id = d.player_id
    WHERE mr.winner_looser = 'Winner'
),
looser AS (
    SELECT DISTINCT
        mr.tournament_id,
        mr.match_id,
        mr.player_id AS player_looser,
        d.deck AS deck_looser
    FROM public.decks d
    LEFT JOIN public.wrk_match_results mr
        ON mr.tournament_id = d.tournament_id AND mr.player_id = d.player_id
    WHERE mr.winner_looser = 'Looser'
),
matchups AS (
    SELECT
        w.tournament_id,
        w.match_id,
        w.deck_winner AS deck1,
        l.deck_looser AS deck2,
        1 AS win_deck1,
        0 AS loss_deck1
    FROM winner w
    LEFT JOIN looser l
        ON w.tournament_id = l.tournament_id AND w.match_id = l.match_id

    UNION ALL

    SELECT
        l.tournament_id,
        l.match_id,
        l.deck_looser AS deck1,
        w.deck_winner AS deck2,
        0 AS win_deck1,
        1 AS loss_deck1
    FROM looser l
    LEFT JOIN winner w
        ON l.tournament_id = w.tournament_id AND l.match_id = w.match_id
)

SELECT
    tournament_id,
    deck1,
    deck2,
    COUNT(*) AS total_match,
    SUM(win_deck1) AS match_win,  -- Les match_win et match_loose compare deck1 vs deck2
    SUM(loss_deck1) AS match_loose
FROM matchups
GROUP BY 1,2,3;

--- ADD MAX_EXTENSION IN TOURNAMENT ---

ALTER TABLE public.wrk_tournaments
ADD COLUMN extension_max TEXT;

WITH order_ext AS (
    SELECT
        extension,
        CASE
            WHEN extension LIKE '%(A1)%' THEN 2
            WHEN extension LIKE '%(A1a)%' THEN 3
            WHEN extension LIKE '%(A2)%' THEN 4
            WHEN extension LIKE '%(A2a)%' THEN 5
            WHEN extension LIKE '%(A2b)%' THEN 6	
            WHEN extension LIKE '%(A3)%' THEN 7
            WHEN extension LIKE '%(A3a)%' THEN 8
            ELSE 1
        END AS extension_order
    FROM
        public.tcg_cards
    GROUP BY
        extension
),

extensions_per_tournament AS (
    SELECT DISTINCT
        d.tournament_id,
        c.extension
    FROM
        public.wrk_decklists d
    JOIN
        public.tcg_cards c ON d.card_name = c.name
),

extensions_with_order AS (
    SELECT
        ept.tournament_id,
        ept.extension,
        oe.extension_order
    FROM
        extensions_per_tournament ept
    JOIN
        order_ext oe ON ept.extension = oe.extension
),

max_extension_per_tournament AS (
    SELECT
        tournament_id,
        extension,
        extension_order,
        ROW_NUMBER() OVER (PARTITION BY tournament_id ORDER BY extension_order DESC) AS rn
    FROM
        extensions_with_order
),

final_result AS (
    SELECT
        tournament_id,
        extension AS extension_max
    FROM
        max_extension_per_tournament
    WHERE
        rn = 1
)

UPDATE public.wrk_tournaments t
SET extension_max = f.extension_max
FROM final_result f
WHERE t.tournament_id = f.tournament_id;