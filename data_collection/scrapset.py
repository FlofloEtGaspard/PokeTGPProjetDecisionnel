import requests
import json
from bs4 import BeautifulSoup

# URL du site à scraper
url = "https://pocket.limitlesstcg.com/cards"

# Envoyer une requête HTTP pour obtenir le contenu de la page
response = requests.get(url)

# Liste pour stocker les informations des extensions
extensions = []

if response.status_code == 200:
    # Analyser le contenu HTML avec BeautifulSoup
    soup = BeautifulSoup(response.content, 'html.parser')

    # Trouver toutes les lignes du tableau qui contiennent les informations des extensions
    extension_rows = soup.select('table.data-table.sets-table.striped tr')

    # Parcourir chaque ligne pour extraire les informations
    for row in extension_rows:
        # Extraire les colonnes de chaque ligne
        cols = row.find_all('td')

        # Vérifier si la ligne contient des données d'extension
        if len(cols) >= 3:
            # Extraire le texte complet du nom et du code
            full_name = cols[0].get_text(strip=True)

            # Utiliser rsplit pour séparer le nom et le code
            name_parts = full_name.rsplit('A', 1)

            if len(name_parts) > 1:
                name = name_parts[0].strip()
                code = 'A' + name_parts[1].strip()
            else:
                name = full_name
                code = ""

            # Extraire la date de sortie
            release_date = cols[1].get_text(strip=True)

            # Extraire le nombre de cartes
            num_cards = cols[2].get_text(strip=True)

            # Ajouter les informations extraites à la liste
            extensions.append({
                "Nom": name,
                "Code": code,
                "Date de sortie": release_date,
                "Nombre de cartes": num_cards
            })

    # Enregistrer les informations dans un fichier JSON
    with open('extensions.json', 'w', encoding='utf-8') as json_file:
        json.dump(extensions, json_file, ensure_ascii=False, indent=4)

    print("Les données ont été enregistrées dans extensions.json")
else:
    print("La requête a échoué avec le code d'état:", response.status_code)
