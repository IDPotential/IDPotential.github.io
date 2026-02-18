import firebase_admin
from firebase_admin import credentials, firestore
import os
import glob

# Constants
BOT_DIR = r"D:\BOT"
TELEGRAM_ID_INT = 196473271
TELEGRAM_ID_STR = str(TELEGRAM_ID_INT)
TICKET_LOGIN = "m00001"

def find_service_account_key():
    files = glob.glob(os.path.join(BOT_DIR, "*.json"))
    for f in files:
        if "firebase" in f.lower() or "service" in f.lower() or "admin" in f.lower():
            return f
    if files:
        return files[0]
    return None

def assign_ticket():
    print("--- Assigning Admin Ticket ---")
    
    # 1. Init Firebase
    key_path = find_service_account_key()
    if not key_path:
        print(f"Error: Service Account Key not found in {BOT_DIR}")
        return

    try:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)
        db = firestore.client()
        print("Firebase Connection established.")
    except Exception as e:
        print(f"Auth Error: {e}")
        return

    # 2. Find User
    users_ref = db.collection('users')
    target_user = None
    
    # Search by telegram_id (int)
    print(f"Searching for user with telegram_id: {TELEGRAM_ID_INT}...")
    docs = users_ref.where('telegram_id', '==', TELEGRAM_ID_INT).limit(1).get()
    if not docs:
         # Search by telegram_id (str)
         docs = users_ref.where('telegram_id', '==', TELEGRAM_ID_STR).limit(1).get()
    
    if not docs:
        # Search by UID (sometimes UID is the telegram ID)
        doc = users_ref.document(TELEGRAM_ID_STR).get()
        if doc.exists:
            target_user = doc
        else:
             print("User not found by UID either.")
    else:
        target_user = docs[0]

    if not target_user:
        print("User with Telegram ID 196473271 NOT FOUND in Firestore.")
        print("Please ensure the user has logged in via the bot or app at least once.")
        return

    print(f"User found: {target_user.id} => {target_user.to_dict().get('email', 'No Email')}")

    # 3. Update User
    user_updates = {
        'ticketLogin': TICKET_LOGIN,
        'isTicketUser': True,
        'role': 'admin' # Grant admin as requested
    }
    target_user.reference.update(user_updates)
    print(f"User updated with: {user_updates}")

    # 4. Update Ticket
    ticket_ref = db.collection('festival_tickets').document(TICKET_LOGIN)
    ticket_doc = ticket_ref.get()
    
    if ticket_doc.exists:
        ticket_updates = {
            'assignedToUserId': target_user.id,
            'assignedToEmail': target_user.to_dict().get('email', ''),
            'isAssigned': True,
            'assignedAt': firestore.SERVER_TIMESTAMP
        }
        ticket_ref.update(ticket_updates)
        print(f"Ticket {TICKET_LOGIN} updated.")
    else:
        print(f"⚠️ Ticket {TICKET_LOGIN} does not exist in 'festival_tickets' collection.")
        # Create it? Maybe safe to create if missing
        ticket_ref.set({
            'login': TICKET_LOGIN,
            'role': 'master', # m prefix usually master
            'assignedToUserId': target_user.id,
            'isAssigned': True,
            'assignedAt': firestore.SERVER_TIMESTAMP
        })
        print(f"Ticket {TICKET_LOGIN} created and assigned.")

    print("\nSUCCESS! Ticket assigned.")

if __name__ == "__main__":
    assign_ticket()
