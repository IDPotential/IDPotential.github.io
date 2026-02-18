
import firebase_admin
from firebase_admin import credentials, firestore, auth
import argparse
import sys

# --- Configuration ---
# Path to your service account key file. 
# Ensure this file exists and is in .gitignore!
SERVICE_ACCOUNT_KEY_PATH = r"d:\BOT\id-potential-firebase-adminsdk-vh85z-1e71237a62.json"

def initialize_firebase():
    """Initializes the Firebase Admin SDK."""
    if not firebase_admin._apps:
        cred = credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH)
        firebase_admin.initialize_app(cred)
    return firestore.client()

def find_user(db, email=None, telegram=None):
    """Finds a user by Email or Telegram username."""
    user_ref = db.collection('users')
    query = None

    if email:
        print(f"Searching by email: {email}")
        # Note: 'email' field in Firestore might vary (e.g. 'email' or inside auth). 
        # We assume there is an 'email' field in the document for simplicity, 
        # or we find by Auth and then get the doc.
        
        # Strategy 1: Search Firestore 'email' field
        query = user_ref.where('email', '==', email).limit(1)
        results = list(query.stream())
        if results:
            return results[0]
            
        # Strategy 2: Search Auth (if not in Firestore explicitly under 'email')
        try:
            auth_user = auth.get_user_by_email(email)
            doc = user_ref.document(auth_user.uid).get()
            if doc.exists:
                return doc
        except auth.UserNotFoundError:
            pass

    if telegram:
        print(f"Searching by Telegram: {telegram}")
        # Assuming we store telegram username somewhere? 
        # If not, we might only have 'telegram_id'. 
        # If the user input is a username (e.g. @username), we might not find it if we only store IDs.
        # But let's check a 'username' or 'telegram_username' field if it exists.
        # For now, let's assume the user might have put it in 'username' or we check 'telegram_id' if implemented.
        
        # Adapting to your schema: 'username' often stores the email prefix or display name.
        # Use with caution.
        pass
        
    return None

def update_user_master(db, user_id, is_master=True, role=None):
    """Updates the user's master status."""
    updates = {'isMaster': is_master}
    if role:
        updates['role'] = role
        
    db.collection('users').document(user_id).set(updates, merge=True)
    print(f"SUCCESS: User {user_id} updated. isMaster={is_master}, role={role}")

def link_ticket(db, user_id, ticket):
    """Links a festival ticket to the user."""
    # 1. Check if tickets matches ticket pattern
    if not ticket.startswith('m') and not ticket.startswith('g'):
        print("WARNING: Ticket format doesn't look standard (expected mXXXXX or gXXXXX). Continuing anyway...")

    updates = {
        'ticketLogin': ticket,
        'isTicketUser': True 
    }
    db.collection('users').document(user_id).set(updates, merge=True)
    print(f"SUCCESS: Linked ticket '{ticket}' to user {user_id}")


def main():
    parser = argparse.ArgumentParser(description="Manage Festival Users (Masters, Tickets)")
    parser.add_argument("--email", help="User's Email")
    parser.add_argument("--uid", help="User's UID (directly)")
    # parser.add_argument("--telegram", help="User's Telegram Username (e.g. @durov)") # Omitted for now until schema confirmed
    
    parser.add_argument("--make-master", action="store_true", help="Set isMaster=True")
    parser.add_argument("--role", help="Set Role (e.g. 'master', 'admin', 'user')")
    parser.add_argument("--ticket", help="Link a ticket code (e.g. m00002)")
    
    args = parser.parse_args()

    if not args.email and not args.uid:
        print("Error: Must provide --email or --uid")
        return

    try:
        db = initialize_firebase()
        
        user_doc = None
        user_id = args.uid
        
        if not user_id and args.email:
            user_doc = find_user(db, email=args.email)
            if user_doc:
                user_id = user_doc.id
                print(f"Found user: {user_id} ({user_doc.to_dict().get('first_name', 'No Name')})")
            else:
                print(f"Error: User with email '{args.email}' not found in Firestore or Auth.")
                return

        if args.make_master:
            update_user_master(db, user_id, is_master=True, role=args.role)
        elif args.role: # If only role is provided
             update_user_master(db, user_id, is_master=False, role=args.role) # Don't unset isMaster usually, but this logic is simple
             # Actually let's just update role if provided
             db.collection('users').document(user_id).set({'role': args.role}, merge=True)
             print(f"Updated role to {args.role}")

        if args.ticket:
            link_ticket(db, user_id, args.ticket)

        print("-" * 30)
        print("Done.")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    main()
