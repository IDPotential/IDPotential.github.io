import json
import sqlite3
import datetime

# --- CONFIG ---
DB_PATH = "D:\\BOT\\ID_DB.sqlite"
# --------------

def get_bot_db_connection():
    return sqlite3.connect(DB_PATH)

def export_bot_data_to_json(user_id):
    """
    Exports data for a specific Telegram user to the JSON format compatible with the App.
    """
    conn = get_bot_db_connection()
    cursor = conn.cursor()
    
    try:
        # 1. Get Logged Calculations (from diagnostic_logs) with GROUP
        cursor.execute('''
            SELECT name, birth_date, gender, calculation_date, user_group
            FROM diagnostic_logs 
            WHERE user_id = ?
        ''', (user_id,))
        
        logs = cursor.fetchall()
        
        # 2. Get User Groups (Folders)
        cursor.execute('''
            SELECT DISTINCT user_group 
            FROM diagnostic_logs 
            WHERE user_id = ? AND user_group IS NOT NULL AND user_group != ''
        ''', (user_id,))
        
        folders = [row[0] for row in cursor.fetchall()]
        
        calculations = []
        
        for row in logs:
            name, birth_date, gender, created_at, user_group = row
            
            # Recalculate numbers if they are not stored directly in logs
            # (Assuming the app will recalculate them based on date, which is fine, 
            # OR we can assume you have a utility to calc them. 
            # For simplicity, let's send empty numbers or zeros and let App handle it?
            # actually app expects numbers. Let's look at `diagnostic_results` table linked to logs)
            
            # For this snippet, we will assume we need to calculate them or fetch them.
            # Since I don't have your calculation logic in Python here, I'll fetch if available
            # or fill with zeros. The App creates 'Calculation' object which requires numbers.
            # If the app re-calculates on import, that's better. 
            # But `Calculation.fromMap` takes numbers list.
            
            # Let's try to fetch results if they exist
            # Note: Your schema has diagnostic_results linked by log_id or user_id + date?
            # Let's simplified approach: Just use basic info. 
            # The App Import Logic: it receives numbers. If we send all 0s, the app will show 0s.
            # Ideally the bot should recalculate. 
            # Since I cannot easily replicate the whole logic here, YOU should import your calculation module.
            
            numbers = [0] * 14 # Placeholder
            
            calc_obj = {
                "name": name,
                "birthDate": birth_date,
                "gender": gender if gender else "М", # Default
                "numbers": numbers, 
                "createdAt": created_at,
                "group": user_group, # Correctly mapped now!
                "notes": "Imported from Bot"
            }
            calculations.append(calc_obj)

        export_data = {
            "version": 1,
            "timestamp": datetime.datetime.now().isoformat(),
            "calculations": calculations,
            "folders": folders
        }
        
        return json.dumps(export_data, indent=2, ensure_ascii=False)
        
    finally:
        conn.close()

def import_app_data_to_bot(json_data, user_id):
    """
    Imports data from App JSON to Bot Database.
    Returns status string.
    """
    try:
        data = json.loads(json_data)
        calcs = data.get('calculations', [])
        
        conn = get_bot_db_connection()
        cursor = conn.cursor()
        
        added_count = 0
        
        for item in calcs:
            name = item.get('name')
            birth_date = item.get('birthDate')
            gender = item.get('gender')
            created_at = item.get('createdAt')
            
            # Check duplicate
            cursor.execute('''
                SELECT id FROM diagnostic_logs 
                WHERE user_id = ? AND name = ? AND birth_date = ?
            ''', (user_id, name, birth_date))
            
            if not cursor.fetchone():
                # Insert
                cursor.execute('''
                    INSERT INTO diagnostic_logs (user_id, name, birth_date, gender, calculation_date)
                    VALUES (?, ?, ?, ?, ?)
                ''', (user_id, name, birth_date, gender, created_at))
                added_count += 1
                
        conn.commit()
        return f"✅ Импортировано {added_count} записей."
        
    except Exception as e:
        return f"❌ Ошибка импорта: {e}"
    finally:
        if 'conn' in locals():
            conn.close()

# --- HOW TO USE IN BOT ---
# @bot.message_handler(commands=['export_app'])
# def export_handler(message):
#    json_text = export_bot_data_to_json(message.from_user.id)
#    bot.send_document(message.chat.id, ('data.json', json_text))

# @bot.message_handler(content_types=['document'])
# def handle_docs(message):
#    if message.document.file_name.endswith('.json'):
#       file_info = bot.get_file(message.document.file_id)
#       downloaded_file = bot.download_file(file_info.file_path)
#       result = import_app_data_to_bot(downloaded_file, message.from_user.id)
#       bot.send_message(message.chat.id, result)
