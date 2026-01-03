import sqlite3
import os

DB_PATH = r"D:\BOT\ID_DB.sqlite"

if not os.path.exists(DB_PATH):
    print(f"Error: Database not found at {DB_PATH}")
    exit(1)

try:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # List tables
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = cursor.fetchall()
    print("Tables found:", tables)
    
    for table_name in tables:
        table = table_name[0]
        print(f"\nSchema for table '{table}':")
        cursor.execute(f"PRAGMA table_info({table});")
        columns = cursor.fetchall()
        for col in columns:
            print(col)
            
    conn.close()
except Exception as e:
    print(f"Error: {e}")
