
import pandas as pd
import os
import sys

# Set encoding to utf-8 for output
sys.stdout.reconfigure(encoding='utf-8')

file_path = r"D:\APK\id_diagnostic_app\Таблица названий и имен.xlsx"

try:
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
    else:
        # Load without header to see raw data first
        df = pd.read_excel(file_path, header=None)
        
        # We expect columns like: [MasterName, GameName, Ticket]
        # Let's print the first few rows to confirm mapping
        print("Raw Data Sample:")
        print(df.head(10).to_string())
        
        # Iterate and print clean structure
        print("\n--- Extracted Data ---")
        for index, row in df.iterrows():
            # Adjust indices based on visual inspection of the previous output
            # Previous output: [0: ???, 1: ???, 2: m00001]
            # It seems col 0 is Master, Col 1 is Game, Col 2 is Ticket
            
            p1 = str(row[0]).strip() if pd.notnull(row[0]) else ""
            p2 = str(row[1]).strip() if pd.notnull(row[1]) else ""
            p3 = str(row[2]).strip() if pd.notnull(row[2]) else ""
            
            print(f"Row {index}: Master='{p1}', Game='{p2}', Ticket='{p3}'")

except Exception as e:
    print(f"Error reading excel: {e}")
