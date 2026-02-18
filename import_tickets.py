import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore, auth
import os

# Initialize Firebase
cred_path = r"D:\BOT\id-potential-firebase-adminsdk-fbsvc-5b09ee26e4.json"
if not os.path.exists(cred_path):
    print(f"Error: Credential file not found at {cred_path}")
    exit(1)

cred = credentials.Certificate(cred_path)
firebase_admin.initialize_app(cred)
db = firestore.client()

excel_path = r"d:\APK\id_diagnostic_app\telegram\Login Pasword.xlsx"

try:
    # Read Excel - Assuming no headers, so we used header=None in inspection? 
    # Wait, inspection showed "Columns: ['m00001', 427163]". 
    # This means the first row WAS treated as header.
    # The file likely has NO headers.
    
    df = pd.read_excel(excel_path, header=None, dtype=str)
    
    print(f"Loaded {len(df)} rows.")
    
    batch = db.batch()
    count = 0
    
    for index, row in df.iterrows():
        login = str(row[0]).strip()
        password = str(row[1]).strip()
        
        if not (login.startswith('m') or login.startswith('g')):
            print(f"Skipping invalid row {index}: {login}")
            continue

        email = f"{login}@idpotential.festival"
        
        # 1. Create/Update Auth User
        try:
            user = auth.get_user_by_email(email)
            print(f"User {email} exists ({user.uid}). Updating password...")
            auth.update_user(user.uid, password=password)
            uid = user.uid
        except auth.UserNotFoundError:
            print(f"Creating user {email}...")
            user = auth.create_user(email=email, password=password)
            uid = user.uid
        except Exception as e:
            print(f"Error auth for {email}: {e}")
            continue
            
        # 2. Add to Firestore 'festival_tickets'
        doc_ref = db.collection('festival_tickets').document(login)
        batch.set(doc_ref, {
            'login': login,
            'password': password,
            'uid': uid,
            'isAssigned': False,
            'assignedToAppId': None,
            'assignedToUserId': None,
            'createdAt': firestore.SERVER_TIMESTAMP
        }, merge=True)
        
        # 3. Create basic user profile in 'users' so they can log in without errors
        user_ref = db.collection('users').document(uid)
        batch.set(user_ref, {
             'email': email,
             'role': 'user',
             'isTicketUser': True,
             'ticketLogin': login
        }, merge=True)

        count += 1
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
            print(f"Committed batch of 400...")

    if count % 400 != 0:
        batch.commit()
        print("Committed final batch.")
        
    print("Import complete.")

except Exception as e:
    print(f"Error: {e}")
