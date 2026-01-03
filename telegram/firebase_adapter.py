import firebase_admin
from firebase_admin import credentials, firestore, auth
import datetime
import os
import glob

# --- CONFIG ---
BOT_DIR = r"D:\APK\id_diagnostic_app\telegram" if os.name == 'nt' else "."
# --------------

_db = None

def init_firebase():
    global _db
    if _db: return _db

    # Find key
    key_path = None
    # Look in current dir and parent dirs
    search_dirs = [BOT_DIR, ".", "..", r"D:\BOT"]
    
    for d in search_dirs:
        if not os.path.exists(d): continue
        files = glob.glob(os.path.join(d, "*firebase*admin*.json"))
        if files:
            key_path = files[0]
            break
            
    if not key_path:
        print("❌ Error: Firebase Service Account Key not found!")
        return None

    try:
        cred = credentials.Certificate(key_path)
        # Avoid re-init if already initialized
        try:
            firebase_admin.get_app()
        except ValueError:
            firebase_admin.initialize_app(cred)
            
        _db = firestore.client()
        print(f"✅ Firebase initialized with key: {key_path}")
        return _db
    except Exception as e:
        print(f"❌ Firebase Init Error: {e}")
        return None

def get_db():
    if not _db:
        return init_firebase()
    return _db

# --- USER MANAGEMENT ---

def fb_get_user(user_id):
    db = get_db()
    if not db: return None
    doc = db.collection('users').document(str(user_id)).get()
    if doc.exists:
        return doc.to_dict()
    return None

def fb_update_user(user_id, data):
    db = get_db()
    if not db: return
    db.collection('users').document(str(user_id)).set(data, merge=True)

def fb_register_user(user_id, first_name, last_name, username):
    db = get_db()
    if not db: return
    
    user_ref = db.collection('users').document(str(user_id))
    doc = user_ref.get()
    
    if not doc.exists:
        user_ref.set({
            'username': username,
            'first_name': first_name,
            'last_name': last_name,
            'credits': 10, # Welcome bonus
            'pgmd': 1,     # Default Level
            'role': 'user',
            'registered_at': firestore.SERVER_TIMESTAMP
        })
        return True # New User
    else:
        # Update PGMD if needed (legacy logic)
        current = doc.to_dict()
        if current.get('pgmd', 0) == 0:
             user_ref.update({'pgmd': 1})
        return False # Existing

def fb_check_access(user_id, required_level=1):
    user = fb_get_user(user_id)
    if not user: return False
    return user.get('pgmd', 0) >= required_level

def fb_get_credits(user_id):
    user = fb_get_user(user_id)
    if not user: return 0
    return user.get('credits', 0)

def fb_deduct_credits(user_id, amount=5):
    print(f"[DEBUG] Attempting to deduct {amount} credits for user {user_id}")
    db = get_db()
    user_ref = db.collection('users').document(str(user_id))
    
    @firestore.transactional
    def deduct_in_transaction(transaction, ref):
        snapshot = transaction.get(ref)
        if not snapshot.exists: 
            print(f"[DEBUG] User {user_id} document does NOT exist.")
            return False
        
        current_bill = int(snapshot.get('credits') or 0)
        role = snapshot.get('role')
        pgmd = int(snapshot.get('pgmd') or 0)
        
        print(f"[DEBUG] User {user_id}: credits={current_bill}, role={role}, pgmd={pgmd}, required={amount}")
        
        # Admin check (pgmd 100 or role admin) - Free
        if pgmd >= 100 or role == 'admin':
            print(f"[DEBUG] Access Granted (Admin/VIP). No deduction.")
            return True
            
        if current_bill >= amount:
            transaction.update(ref, {'credits': current_bill - amount})
            print(f"[DEBUG] Success. Deducted {amount}. Remaining: {current_bill - amount}")
            return True
            
        print(f"[DEBUG] Insufficient credits. Has {current_bill}, need {amount}.")
        return False

    transaction = db.transaction()
    try:
        return deduct_in_transaction(transaction, user_ref)
    except Exception as e:
        print(f"Transaction failed: {e}")
        return False

# --- LOGS ---

def fb_add_log(user_id, name, birth_date, gender, result_nums):
    db = get_db()
    
    # Store in Subcollection 'calculations'
    calc_ref = db.collection('users').document(str(user_id)).collection('calculations').document()
    
    calc_data = {
        'name': name,
        'birthDate': birth_date,
        'gender': gender,
        'createdAt': datetime.datetime.now().isoformat(),
        'numbers': result_nums, # List of ints
        'type': 'diagnostic'
    }
    
    calc_ref.set(calc_data)
    return calc_ref.id

def fb_check_log_exists(user_id, name, birth_date):
    db = get_db()
    # Query logic might be expensive if many logs. 
    # For now, simple check.
    logs_ref = db.collection('users').document(str(user_id)).collection('calculations')
    query = logs_ref.where('name', '==', name).where('birthDate', '==', birth_date).limit(1)
    results = list(query.stream())
    return results[0].id if results else None

def fb_get_history(user_id, limit=300):
    db = get_db()
    logs_ref = db.collection('users').document(str(user_id)).collection('calculations')
    query = logs_ref.order_by('createdAt', direction=firestore.Query.DESCENDING).limit(limit)
    return [doc.to_dict() | {'id': doc.id} for doc in query.stream()]

# --- AUTH (APP) ---

def fb_create_custom_token(user_id):
    """Generates a Custom Token for the Flutter App login"""
    try:
        # Firebase UIDs must be strings. Telegram IDs are ints.
        uid = str(user_id)
        custom_token = auth.create_custom_token(uid)
        return custom_token.decode('utf-8') # bytes to string
    except Exception as e:
        print(f"Error generating token: {e}")
        return None

def fb_get_log(log_id, user_id=None):
    db = get_db()
    if user_id:
        # Direct access (Fast & Cost-effective)
        doc = db.collection('users').document(str(user_id)).collection('calculations').document(log_id).get()
        if doc.exists:
            data = doc.to_dict()
            data['id'] = doc.id
            data['user_id'] = str(user_id)
            return data
        return None
    
    # Fallback if user_id unknown (Try Collection Group with field 'id' if we had it, but we don't)
    # Since we can't efficiently query by ID without user_id, we return None or try a localized scan if needed.
    # For now, simpler to fail if user_id missing, as the bot should always have it in context.
    print(f"⚠️ fb_get_log call missing user_id for log {log_id}")
    return None

def fb_mark_log_paid(user_id, log_id):
    db = get_db()
    ref = db.collection('users').document(str(user_id)).collection('calculations').document(log_id)
    ref.update({'decryption': 1})

def fb_delete_log(user_id, log_id):
    try:
        db = get_db()
        # Delete from 'users/{uid}/calculations/{logId}'
        print(f"🔥 db delete: users/{user_id}/calculations/{log_id}")
        ref = db.collection('users').document(str(user_id)).collection('calculations').document(log_id)
        ref.delete()
        return True
    except Exception as e:
        print(f"❌ fb_delete_log error: {e}")
        return False

def fb_update_log_group(user_id, log_id, group_name):
    try:
        db = get_db()
        ref = db.collection('users').document(str(user_id)).collection('calculations').document(log_id)
        if group_name:
            ref.update({'group': group_name})
        else:
            ref.update({'group': firestore.DELETE_FIELD})
        return True
    except Exception as e:
        print(f"❌ fb_update_log_group error: {e}")
        return False

