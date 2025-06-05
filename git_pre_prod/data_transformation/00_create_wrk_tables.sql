-- CREATION TABLES --

DROP TABLE IF EXISTS public.wrk_tournaments;
CREATE TABLE public.wrk_tournaments (
  tournament_id varchar NULL,
  tournament_name varchar NULL,
  tournament_date timestamp NULL,
  tournament_organizer varchar NULL,
  tournament_format varchar NULL,
  tournament_nb_players int NULL
);

DROP TABLE IF EXISTS public.wrk_decklists;
CREATE TABLE public.wrk_decklists (
  tournament_id varchar NULL,
  player_id varchar NULL,
  card_type varchar NULL,
  card_name varchar NULL,
  card_url varchar NULL,
  card_count int NULL
);

DROP TABLE IF EXISTS public.wrk_match_results;
DROP TABLE IF EXISTS public.wrk_matches;
CREATE TABLE public.wrk_matches (
  id SERIAL PRIMARY KEY,
  tournament_id TEXT
);

CREATE TABLE public.wrk_match_results (
    match_id INTEGER REFERENCES wrk_matches(id),
    player_id TEXT,
    score INTEGER,
    PRIMARY KEY (match_id, player_id)
);

DROP TABLE IF EXISTS public.tcg_cards;
CREATE TABLE public.tcg_cards (
    full_url TEXT PRIMARY KEY,
    name TEXT,
    card_type TEXT,
    stage TEXT,
    evolves_from TEXT,
    element_type TEXT,
    hp INTEGER,
    attack TEXT,
    attack_effect TEXT,
    ability TEXT,
    ability_effect TEXT,
    weakness TEXT,
    retreat TEXT,
    illustrator TEXT,
    flavor_text TEXT,
    extension TEXT
);