import psycopg
import os
import json
from datetime import datetime
import sys

sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

postgres_db = "pre_prod"
postgres_user = "postgres"
postgres_password = "1234"
postgres_host = "localhost"
postgres_port = "5432"

output_directory = "../data_collection/sample_output"
card_directory = "../data_collection"

def get_connection_string():
  return f"postgresql://{postgres_user}:{postgres_password}@{postgres_host}:{postgres_port}/{postgres_db}"

def execute_sql_script(path: str):
  with psycopg.connect(get_connection_string()) as conn:
    with conn.cursor() as cur:
      with open(path) as f:
        cur.execute(f.read())

def insert_wrk_tournaments():
  tournament_data = []
  for file in os.listdir(output_directory):
    with open(f"{output_directory}/{file}") as f:
      tournament = json.load(f)
      tournament_data.append((
        tournament['id'], 
        tournament['name'].encode('ascii', errors='ignore').decode(), 
        datetime.strptime(tournament['date'], '%Y-%m-%dT%H:%M:%S.000Z'),
        tournament['organizer'], 
        tournament['format'], 
        int(tournament['nb_players'])
        ))
  
  with psycopg.connect(get_connection_string()) as conn:
    with conn.cursor() as cur:
      cur.executemany("INSERT INTO public.wrk_tournaments values (%s, %s, %s, %s, %s, %s)", tournament_data)

def insert_wrk_decklists():
  decklist_data = []
  for file in os.listdir(output_directory):
    with open(f"{output_directory}/{file}") as f:
      tournament = json.load(f)
      tournament_id = tournament['id']
      for player in tournament['players']:
        player_id = player['id']
        for card in player['decklist']:
          decklist_data.append((
            tournament_id,
            player_id,
            card['type'],
            card['name'],
            card['url'],
            int(card['count']),
          ))
  
  with psycopg.connect(get_connection_string()) as conn:
    with conn.cursor() as cur:
      cur.executemany("INSERT INTO public.wrk_decklists values (%s, %s, %s, %s, %s, %s)", decklist_data)

def insert_wrk_matches():
  matches_data = []
  match_results_data = []

  match_id_counter = 1  # Simule l'auto-increment si on veut charger sans RETURNING id

  for file in os.listdir(output_directory):
    with open(f"{output_directory}/{file}") as f:
      tournament = json.load(f)
      tournament_id = tournament['id']
      
      for match in tournament.get("matches", []):
        matches_data.append((tournament_id,))  # une ligne par match
        for result in match["match_results"]:
          match_results_data.append((
            match_id_counter,
            result["player_id"],
            int(result["score"])
          ))
        match_id_counter += 1

  with psycopg.connect(get_connection_string()) as conn:
    with conn.cursor() as cur:
      cur.executemany("INSERT INTO public.wrk_matches (tournament_id) VALUES (%s)",matches_data)
      cur.executemany("INSERT INTO public.wrk_match_results (match_id, player_id, score) VALUES (%s, %s, %s) ON CONFLICT (match_id, player_id) DO NOTHING",match_results_data)


def to_cp1252_safe(text):
    if text is None:
        return None
    return text.encode('cp1252', errors='replace').decode('cp1252')

def insert_tcg_cards():
    cards_data = []

    cards_path = os.path.join(card_directory, "cards.json")
    with open(cards_path, encoding="utf-8") as f:
        cards = json.load(f)

        for card in cards:
            cards_data.append((
                to_cp1252_safe(card.get("full_url")),
                to_cp1252_safe(card.get("name")),
                to_cp1252_safe(card.get("card_type")),
                to_cp1252_safe(card.get("stage")),
                to_cp1252_safe(card.get("evolves_from")),
                to_cp1252_safe(card.get("element_type")),
                int(card.get("hp", 0)) if card.get("hp") else None,
                to_cp1252_safe(card.get("attack")),
                to_cp1252_safe(card.get("attack_effect")),
                to_cp1252_safe(card.get("ability")),
                to_cp1252_safe(card.get("ability_effect")),
                to_cp1252_safe(card.get("weakness")),
                to_cp1252_safe(card.get("retreat")),
                to_cp1252_safe(card.get("illustrator")),
                to_cp1252_safe(card.get("flavor_text")),
                to_cp1252_safe(card.get("extension"))
            ))

    with psycopg.connect(get_connection_string()) as conn:
        with conn.cursor() as cur:
            cur.executemany("""
                INSERT INTO public.tcg_cards (
                    full_url, name, card_type, stage, evolves_from, element_type, hp,
                    attack, attack_effect, ability, ability_effect, weakness, retreat,
                    illustrator, flavor_text, extension
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (full_url) DO NOTHING
            """, cards_data)

print("creating work tables")
execute_sql_script("00_create_wrk_tables.sql")

print("insert raw tournament data")
insert_wrk_tournaments()

print("insert raw decklist data")
insert_wrk_decklists()

print("insert raw matches data")
insert_wrk_matches()

print("insert card data")
insert_tcg_cards()

print("construct card database")
execute_sql_script("01_dwh_cards.sql") 