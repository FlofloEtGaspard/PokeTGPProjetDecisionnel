![Pokemon TCG Pocket logo](https://upload.wikimedia.org/wikipedia/commons/c/c2/Pokemon_TCG_Pocket_logo.png)
# Pokemon TCG Pocket metagame analysis

[Pokémon Trading Card Game Pocket](https://en.wikipedia.org/wiki/Pok%C3%A9mon_Trading_Card_Game_Pocket) (often abbreviated as **Pokémon TCG Pocket**) is a free-to-play mobile adaptation of the [Pokémon Trading Card Game](https://en.wikipedia.org/wiki/Pok%C3%A9mon_Trading_Card_Game) (TCG), developed by [Creatures Inc.](https://en.wikipedia.org/wiki/Creatures_Inc.) and [DeNA](https://en.wikipedia.org/wiki/DeNA), and published by [The Pokémon Company](https://en.wikipedia.org/wiki/The_Pok%C3%A9mon_Company).

In this game, players build decks containing sets of cards, and battle each other online.

## Goal

You have been mandated by your client to perform a metagame analysis of this game. Your client wishes to know which cards have the highest winrate, which cards work well in the same deck, which cards to use against popular strategies, if any of those trends have evolved during since the launch of the game, and any other useful patterns you can extract from the data.

## General advice

You will build a complete data ingestion, transformation, and visualization pipeline. It is recommended that you use a machine where you are an administrator, as it will make installing the necessary tooling (development tools and their dependencies, such as Python, Talend, a database, etc) easier. Some ingestion processes will be quite long, so keeping pipelines running overnight may be necessary.

The technologies mentioned in this document are proposed as an example, but feel free to use any other technologies or languages you are familiar with. Your code still must be understandable by the client, so refrain from using proprietary technologies or software protected by a paid licence. Be prepared to defend your technological choices.

Your time is limited. Consider splitting your team when tasks can be parallelized. For example, one person can be in charge of raw data ingestion, another in charge of data transformation, another in charge of reporting and data visualization. Contract interfaces between those steps as soon as possible (ie the people in charge of data visualization and data transformation must agree on what the final datamart will look like as soon as possible)

## Data Collection

The developers of the game do not publish publicly available data for you to consume. However, there are websites organizing tournaments, and publishing data (including decklists, and match results) about those tournaments online. One such organization is [Limitless TCG](https://play.limitlesstcg.com).

Limitless TCG does provide an [API and documentation on how to use it,](https://docs.limitlesstcg.com/developer.html) however this API is locked behind a key that you can request. As the approval process is manual, it is unlikely that you will be able to use this method.

As an alternative, you can use the website to download the data in html format and use an html parser to extract raw data.

The list of completed Pokemon TCG Pocket tournaments on this website can be viewed at [this url](https://play.limitlesstcg.com/tournaments/completed?game=POCKET&format=STANDARD&platform=all&type=online&time=all).

For each tournament, you can view [pairings](https://play.limitlesstcg.com/tournament/6823dbb84c6488b18ed5e5d2/pairings) (including match results), and when available, [player decklists](https://play.limitlesstcg.com/tournament/6823dbb84c6488b18ed5e5d2/player/wiloxomega/decklist). This data can be used for metagame analysis, for example computing winrates for each card

A python script using BeautifulSoup as the html parser is provided. The output of this script is a json file for each tournament, containing decklists and pairings.

A sample of 2 tournament files in included in the sample_output directory in this repository. You will need to run this script yourself to collect all available data on the website using this method, be aware that this is time consuming, and the extraction program will likely have to run overnight (you can also collaborate with other teams to each extract a different page, and share results afterwards). You can of course develop your own data extraction process using another ETL, or modify the provided one if you need additional data from the source.

To run the provided script, use the following commands :
```bash
cd data_collection
pip install beautifulsoup4
pip install aiohttp
pip install aiofile

python3 main.py
```

## Database
You will need a relational database to store and transform your data. Postgres on docker is recommended, but you can use any database at your disposal (keeping in mind that your client will need to be able to reproduce your work)

To run a Postgres database using docker, you can use the following command :
```bash
docker run --name postgres-pokemon -p 5432:5432 -e POSTGRES_PASSWORD='keepThis$ecret' -d postgres
```

## Data transformation
You will need to transform the collected data to make it usable for vizualisation. A simple python script that ingest tournament and decklist data is provided, but feel free to use any ETL you are familiar with for this task. (Talend / Talaxie or Pentaho are examples of tools you can use)

To run the provided script :
```bash
cd data_transformation
pip install psycopg

export POSTGRES_DB=postgres
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD='keepThis$ecret'
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
python3 main.py
```

Some things to keep in mind for data transformation :
 * The sample script provided stores the user id for each deck. This is a bad practice you must fix, the username should be anonymized: nowhere in your database should the user name be visible. Hashing the username, or replacing it with an id are both good solutions.
 * Keep the naming of tables and columns consistent.
 * The client must be able to run your code on his machine.
 * Add logs and error catching to your transformation code.

## Data visualisation
Your final presentation to your client must feature graphs and tables that will showcase what you have learned from the data.

A sample webpage displaying the number of players by tournament date is included. You can reuse this template for your other graphics, or use any other reporting solution, keeping in mind that your client will need to be able to reproduce your work. If you have access to docker, [Metabase](https://www.metabase.com/docs/latest/installation-and-operation/running-metabase-on-docker) is a good choice for a simple "SQL to chart" software.

To run the provided sample web page :
```bash
cd data_transformation
pip install psycopg
pip install "fastapi[standard]"

export POSTGRES_DB=postgres
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD='keepThis$ecret'
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
fastapi dev main.py
```

You will need to familiarize yourself with the data to understand how to present it. One example is the notion of "seasons". All cards in this game were not released at the same time, but rather in "[Expensions](https://en.wikipedia.org/wiki/Pok%C3%A9mon_Trading_Card_Game_Pocket#Expansions)". As such it probably doesn't make sense to aggregate the winrate of a card without taking into account when it was released.

To inform your choice of charts to produce, you can read the 'Goal' paragraph of this document again, but the following suggestions are probably mandatory :
 * A graph showing the most used cards per season
 * A graph showing the cards with the highest winrate per season.
 * For each "interesting" card, a graph showing it's usage and winrate across time.

## Deliverables
You will publish all your data collection, transformation, and visualisation code in a public git repository ([github](https://github.com/) or [gitlab](https://about.gitlab.com/) are popluar choices). Additional requirements :
 * Your repository should mirror the layout of this one, with each step separated.
 * You should provide a README.md file to explain how to run each step.
 * Commit messages should be clear and relevant.
 * DO NOT share secrets (for example API keys, or sensitive passwords) publicly.
 * You code must be portable and runnable easily by the client (so no proprietary or paid software).

You will also need to do a live presentation of your findings. this presentation will also need to be accessible to the client.



