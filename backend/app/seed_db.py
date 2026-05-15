import asyncio
import csv
import os
import uuid
from motor.motor_asyncio import AsyncIOMotorClient
from models import Scale, Section, Question

# Connessione locale per lo script standalone
MONGODB_URL = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
client = AsyncIOMotorClient(MONGODB_URL)
database = client.autanalysis
scales_collection = database.get_collection("scales")

async def seed_from_csv():
    csv_path = os.path.join(os.path.dirname(__file__), 'pos_data.csv')
    
    if not os.path.exists(csv_path):
        print(f"File non trovato: {csv_path}")
        print("Assicurati di creare il file 'pos_data.csv' in questa directory prima di lanciare lo script.")
        return

    sezioni_dict = {}
    current_section = "Sezione Generale"

    with open(csv_path, mode='r', encoding='utf-8-sig') as f:
        # Usa Sniffer per rilevare dinamicamente se il file usa ',' o ';'
        dialect = csv.Sniffer().sniff(f.read(1024))
        f.seek(0)
        reader = csv.DictReader(f, dialect=dialect)
        
        # Mappatura chiavi case-insensitive
        for row in reader:
            row_cleaned = {k.strip().lower() if k else '': str(v).strip() if v else '' for k, v in row.items()}
            
            # Cerca le possibili colonne
            testo = row_cleaned.get('testo_domanda', '') or row_cleaned.get('domanda', '')
            tipo = row_cleaned.get('tipo_risposta', '') or row_cleaned.get('tipo', '')
            sezione = row_cleaned.get('sezione', '') or row_cleaned.get('titolo_sezione', '') or row_cleaned.get('categoria', '')
            id_domanda = row_cleaned.get('id_domanda', '') or row_cleaned.get('id', '')

            # Se è una riga che definisce solo la sezione (senza testo della domanda)
            if not testo and sezione:
                current_section = sezione
                continue
                
            # Se la riga ha il testo della domanda ma definisce anche la sezione
            if sezione:
                current_section = sezione
            
            # Se la riga è completamente vuota, salta
            if not testo:
                continue

            # Valori di default
            if not id_domanda:
                id_domanda = f"pos_{uuid.uuid4().hex[:8]}"
            if not tipo:
                tipo = "rating_1_to_5"

            domanda = Question(
                id_domanda=id_domanda,
                testo_domanda=testo,
                tipo_risposta=tipo
            )
            
            if current_section not in sezioni_dict:
                sezioni_dict[current_section] = []
            sezioni_dict[current_section].append(domanda)

    # Costruisci l'albero della Scala
    sezioni_list = []
    for sec_title, domande in sezioni_dict.items():
        sezioni_list.append(Section(titolo_sezione=sec_title, domande=domande))

    scala_pos = Scale(
        id="scala_pos",
        nome="Scala POS Eterovalutativa",
        descrizione="Scala per la valutazione clinica importata da file CSV.",
        sezioni=sezioni_list
    )

    # Aggiorna il database
    await scales_collection.delete_many({"id": "scala_pos"}) # Rimuove vecchie versioni
    result = await scales_collection.insert_one(scala_pos.model_dump())
    
    print(f"Seeding completato con successo! Scala salvata con _id: {result.inserted_id}")
    print(f"Totale sezioni trovate: {len(sezioni_list)}")
    print(f"Totale domande importate: {sum(len(s.domande) for s in sezioni_list)}")

if __name__ == "__main__":
    asyncio.run(seed_from_csv())
