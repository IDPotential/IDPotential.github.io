
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore
import os
import sys

# --- CONFIG ---
# SERVICE_ACCOUNT_KEY_PATH = ... (Will be updated dynamically)
def find_key():
    import glob
    # Prioritize d:\BOT
    search_paths = [r"d:\BOT", r"d:\APK", r"d:\APK\id_diagnostic_app"]
    for p in search_paths:
        files = glob.glob(os.path.join(p, "*firebase-adminsdk*.json"))
        if files: return files[0]
    return r"d:\BOT\id-potential-firebase-adminsdk-fbsvc-5b09ee26e4.json" # Fallback to specific file found

SERVICE_ACCOUNT_KEY_PATH = find_key()
EXCEL_PATH = r"D:\APK\id_diagnostic_app\Таблица названий и имен.xlsx"

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()

def import_activities():
    if not os.path.exists(EXCEL_PATH):
        print(f"Error: {EXCEL_PATH} not found.")
        return

    print(f"Reading {EXCEL_PATH}...")
    try:
        df = pd.read_excel(EXCEL_PATH, header=None)
    except Exception as e:
        print(f"Error reading Excel: {e}")
        return

    # Structure: [MasterName, GameName, Ticket]
    # We want to group by GameName because some games have multiple masters
    
    activities = {} # { "GameName": { "masters": [], "tickets": [] } }

    for index, row in df.iterrows():
        master = str(row[0]).strip() if pd.notnull(row[0]) else ""
        game = str(row[1]).strip() if pd.notnull(row[1]) else ""
        ticket = str(row[2]).strip() if pd.notnull(row[2]) else ""

        if not game: continue

        if game not in activities:
            activities[game] = {
                "title": game,
                "description": "", # Placeholder, can be filled later or from manual map
                "masters": [],
                "tickets": [],
                "type": "game" 
            }
        
        if master and master not in activities[game]["masters"]:
            activities[game]["masters"].append(master)
            
        if ticket and ticket not in activities[game]["tickets"]:
            activities[game]["tickets"].append(ticket)

    # Batch write to Firestore
    batch = db.batch()
    collection_ref = db.collection('festival_activities')
    
    count = 0
    for game_title, data in activities.items():
        # Create a deterministic ID based on title to avoid dupes if re-run
        # Just simple sanitization
        doc_id = game_title.replace("/", "_").replace(".", "").replace(" ", "_").lower()[:50]
        doc_ref = collection_ref.document(doc_id)
        
        batch.set(doc_ref, data, merge=True)
        count += 1

    batch.commit()
    print(f"Successfully imported {count} activities to 'festival_activities'.")
    
    # Print sample
    for title in list(activities.keys())[:3]:
        print(f"Saved: {title} -> Masters: {activities[title]['masters']}, Tickets: {activities[title]['tickets']}")

if __name__ == "__main__":
    import_activities()
