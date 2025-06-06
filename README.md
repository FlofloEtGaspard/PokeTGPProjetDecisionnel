# Pokémon TCG Pocket Meta Analysis

## Project Overview

This project aims to analyze the meta of the Pokémon Trading Card Game (TCG) Pocket. By collecting and transforming data, we provide insights into the current state of the game's meta, to make sure that helps players and analysts understand trends, popular decks, and strategic shifts.

## Directory Structure

The project is organized into the following directories:

- `data_collection/`: Contains scripts and data related to the tournaments and the cards from the website [limitlesstcg](https://pocket.limitlesstcg.com/). This includes cards informations, deck lists, tournament results, etc...

- `data_transformation/`: Contains scripts and tools for processing and transforming the raw data into a format suitable for analysis. This includes data cleaning, normalization, and aggregation. 

## Getting Started

### Prerequisites

To run this project, you need to have the following software installed:

- Python 3.x
- Git

### Installation

1. **Clone the repository :**

   ```bash
   git clone https://github.com/FlofloEtGaspard/PokeTGPProjetDecisionnel.git

   
2. **Data collection :**

 ```bash
   cd data_collection
   pip install beautifulsoup4
   pip install aiohttp
   pip install aiofile

   python main.py
   python scrapcard.py

```
These scripts should scrap the data from the tournaments as well as the cards informations like the "element_type", the "name" or even the "hp" of the pokemon. 
It should also put all of the tournaments informations in an output directory at the source of your repository, whereas the card informations should be in a cards.json file directly in the "card_collection" folder.

3. **Data transformation :**

The next step require a Postgres database in order to transmit the data to it. You then have to modify the script "main.py" of the "data_transformation" folder to make it work with your database.
At the beginning of the script you'll find these lines : 

```python
postgres_db = ""
postgres_user = ""
postgres_password = ""
postgres_host = ""
postgres_port = ""
```
You'll have to modift these lines to make sur your database can be lnked to the script. 

4. **Data Visualisation:**

The visualisation is contained in a Power BI file linked to the Postgre Database. 

