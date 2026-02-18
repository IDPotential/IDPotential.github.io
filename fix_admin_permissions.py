import firebase_admin
from firebase_admin import credentials, firestore
import os
import glob

# Constants
BOT_DIR = r"D:\BOT"
TARGET_EMAIL = "m00001@idpotential.festival"

def find_service_account_key():
    files = glob.glob(os.path.join(BOT_DIR, "*.json"))
    for f in files:
        if "firebase" in f.lower() or "service" in f.lower() or "admin" in f.lower():
            return f
    if files:
        return files[0]
    return None

def fix_admin_permissions():
    print("--- Fixing Admin Permissions for Ticket User ---")
    
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

    # 2. Find User by Email
    print(f"Searching for user with email: {TARGET_EMAIL}...")
    users_ref = db.collection('users')
    docs = users_ref.where('email', '==', TARGET_EMAIL).limit(1).get()
    
    if not docs:
        print(f"User with email {TARGET_EMAIL} NOT FOUND.")
        print("Please ensure you have logged in securely with m00001 and the app created your user doc.")
        return

    target_user = docs[0]
    print(f"User found: {target_user.id} => {target_user.to_dict().get('email')}")

    # 3. Update User Role
    user_updates = {
        'role': 'admin',
        'isTicketUser': True,
        'ticketLogin': 'm00001'
    }
    target_user.reference.update(user_updates)
    print(f"User updated with: {user_updates}")

    print("\nSUCCESS! Permissions fixed.")

if __name__ == "__main__":
    fix_admin_permissions()
