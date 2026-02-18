import pandas as pd
import json
import os

file_path = r"D:\APK\id_diagnostic_app\Таблица названий и имен.xlsx"

try:
    if not os.path.exists(file_path):
        print(f"Error: File not found at {file_path}")
        exit(1)

    # Read without header
    df = pd.read_excel(file_path, header=None)
    # Replace NaN with None
    df = df.where(pd.notnull(df), None)
    
    print(f"Columns: {list(df.columns)}")
    print(json.dumps(df.head(5).to_dict(orient='records'), ensure_ascii=False, indent=2))
    
    # Save as Dart-friendly JSON structure (list of lists or list of objects)
    # Mapping: 0 -> MasterName, 1 -> GameTitle, 2 -> TicketLogin
    data = []
    for _, row in df.iterrows():
        if row[0] and row[1]: # valid rows
            data.append({
                "masterName": str(row[0]).strip(),
                "gameTitle": str(row[1]).strip(),
                "ticketLogin": str(row[2]).strip() if row[2] else None
            })
            
    with open("festival_data_parsed.json", "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        
    print(f"\nParsed {len(data)} records to festival_data_parsed.json")

except Exception as e:
    print(f"Error processing file: {e}")
