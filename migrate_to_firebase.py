import sqlite3
import firebase_admin
from firebase_admin import credentials, firestore
import os
import glob
import datetime

# --- CONFIG ---
SQLITE_DB_PATH = r"D:\BOT\ID_DB.sqlite"
BOT_DIR = r"D:\BOT"
# --------------

def find_service_account_key():
    # Find any .json file in BOT_DIR that looks like a key
    files = glob.glob(os.path.join(BOT_DIR, "*.json"))
    for f in files:
        # Simple heuristic: usually contains "firebase" or "service"
        if "firebase" in f.lower() or "service" in f.lower() or "admin" in f.lower():
            return f
    # Fallback: take the first JSON if specific name not found
    if files:
        return files[0]
    return None

def migrate():
    print("Starting Migration: SQLite -> Firestore")
    
    # 1. Setup Firebase
    key_path = find_service_account_key()
    if not key_path:
        print(f"Error: Service Account Key (*.json) not found in {BOT_DIR}")
        print("Please place the JSON file from Firebase Console in that folder.")
        return

    print(f"Found Key: {key_path}")
    
    try:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)
        db = firestore.client()
        print("Firebase Connection established.")
    except Exception as e:
        print(f"Kubernetes Auth Error: {e}")
        # Sometimes user might have it installed but not configured
        print("Make sure you installed: pip install firebase-admin")
        return

    # 2. Connect SQLite
    if not os.path.exists(SQLITE_DB_PATH):
        print(f"Error: SQLite DB not found at {SQLITE_DB_PATH}")
        return

    conn = sqlite3.connect(SQLITE_DB_PATH)
    conn.row_factory = sqlite3.Row # Access by column name
    cursor = conn.cursor()

    # 3. Migrate Users (Partn table)
    print("\nMigrating Users (from 'Partn' table)...")
    cursor.execute("SELECT * FROM Partn")
    users = cursor.fetchall()
    
    batch = db.batch()
    count = 0
    total_users = 0
    
    for user in users:
        user_id = str(user['user_id']) # Doc ID must be string
        
        user_doc = {
            'username': user['username'],
            'first_name': user['user_name'],
            'last_name': user['user_surname'],
            'credits': user['bill'] or 0,
            'pgmd': user['pgmd'] or 0, # Access Level
            'history_access': bool(user['history_access']),
            'phone': user['phone'],
            'invite_code': user['invite'],
            'role': 'user', 
            'migrated_at': firestore.SERVER_TIMESTAMP
        }
        
        # Admin check (you can customize logic)
        # if user_id == "YOUR_TELEGRAM_ID": user_doc['role'] = 'admin'

        ref = db.collection('users').document(user_id)
        batch.set(ref, user_doc, merge=True)
        count += 1
        total_users += 1
        
        if count >= 400: # Firestore batch limit is 500
            batch.commit()
            batch = db.batch()
            count = 0
            print(f"   ... processed {total_users} users")

    if count > 0:
        batch.commit()
    print(f"Users Migrated: {total_users}")

    # 4. Migrate Logs (diagnostic_logs) -> Subcollection 'calculations'
    print("\nMigrating History (from 'diagnostic_logs' joined with 'diagnostic_results')...")
    
    # We fetch logs and for each log we need its results.
    # To be faster, let's fetch all results into a dict? 
    # Or just query per log (easiest for script simplicity).
    
    cursor.execute("SELECT * FROM diagnostic_logs")
    logs = cursor.fetchall()
    
    batch = db.batch()
    count = 0
    total_logs = 0
    
    for log in logs:
        user_id = str(log['user_id'])
        log_id = str(log['id'])
        
        # Determine CreatedAt (Normalize to ISO)
        created_at = log['calculation_date']
        if created_at and ' ' in created_at and 'T' not in created_at:
             try:
                 # Replace space with T to make it ISO-like for sorting
                 # YYYY-MM-DD HH:MM:SS -> YYYY-MM-DDTHH:MM:SS
                 created_at = created_at.replace(' ', 'T')
             except:
                 pass
        if not created_at:
             created_at = datetime.datetime.now().isoformat()

        # Fetch numbers from diagnostic_results
        cursor.execute("SELECT * FROM diagnostic_results WHERE log_id = ?", (log['id'],))
        res = cursor.fetchone()
        
        numbers = []
        if res:
            # num1 to num14
            for i in range(1, 15):
                key = f'num{i}'
                val = res[key]
                numbers.append(val if val is not None else 0)
        
        # If numbers found, great. If not, we store empty (will need calc on fly).
        
        calc_doc = {
            'name': log['name'],
            'birthDate': log['birth_date'],
            'gender': log['gender'],
            'createdAt': created_at,
            'group': log['user_group'] or '',
            'migrated': True,
            'decryption': log['decryption'] or 0
        }
        
        if numbers:
            calc_doc['numbers'] = numbers
            
        ref = db.collection('users').document(user_id).collection('calculations').document(log_id)
        batch.set(ref, calc_doc, merge=True)
        count += 1
        total_logs += 1
        
        if count >= 400:
            batch.commit()
            batch = db.batch()
            count = 0
            print(f"   ... processed {total_logs} logs")
            
    if count > 0:
        batch.commit()
        
    print(f"History Migrated: {total_logs}")
    print("\nMigration Complete!")

if __name__ == "__main__":
    migrate()
