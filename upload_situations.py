import firebase_admin
from firebase_admin import credentials, firestore
import os
import glob
import re

# --- CONFIG ---
BOT_DIR = r"D:\BOT"
SRC_FILE = r"D:\BOT\Ситуации Соло.txt"
PACK_ID = "pack_Solo"
PACK_TITLE = "Ситуации Соло"
# --------------

def find_service_account_key():
    files = glob.glob(os.path.join(BOT_DIR, "*.json"))
    for f in files:
        if "firebase" in f.lower() or "service" in f.lower() or "admin" in f.lower():
            return f
    if files: return files[0]
    return None

def parse_situations(filepath):
    situations = []
    current_category = "General"
    
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            
            # Category detection
            if line.lower().startswith("категория:"):
                current_category = line.split(":", 1)[1].strip()
                continue
                
            # Situation detection (numbered list)
            # Regex to match "1. Text" or "1.Text"
            match = re.match(r'^(\d+)\.\s*(.*)', line)
            if match:
                s_id = match.group(1)
                text = match.group(2)
                
                situations.append({
                    'id': s_id,
                    'text': text,
                    'category': current_category
                })
    return situations

def upload():
    print("Starting Upload...")
    
    # 1. Init Firebase
    key_path = find_service_account_key()
    if not key_path:
        print("Error: No Service Account Key found.")
        return
        
    if not firebase_admin._apps:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)
        
    db = firestore.client()
    
    # 2. Parse
    sits = parse_situations(SRC_FILE)
    print(f"Parsed {len(sits)} situations.")
    if not sits:
        print("No situations found. Check file definition.")
        return

    # 3. Upload
    categories = list(set(s['category'] for s in sits))
    
    doc_data = {
        'id': PACK_ID,
        'title': PACK_TITLE,
        'categories': categories,
        'situations': sits,
        'updatedAt': firestore.SERVER_TIMESTAMP
    }
    
    print(f"Uploading pack '{PACK_ID}' with {len(categories)} categories...")
    
    db.collection('situation_packs').document(PACK_ID).set(doc_data)
    
    print("Upload Complete!")

if __name__ == "__main__":
    upload()
