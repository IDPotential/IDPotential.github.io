
import pandas as pd
import os

file_path = r"D:\APK\id_diagnostic_app\Таблица названий и имен.xlsx"

try:
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
    else:
        df = pd.read_excel(file_path)
        print("Columns:", df.columns.tolist())
        print("-" * 20)
        print(df.head(5).to_string())
except Exception as e:
    print(f"Error reading excel: {e}")
