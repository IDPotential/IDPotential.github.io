import pandas as pd
import os

file_path = r"d:\APK\id_diagnostic_app\ATS\Активности АТС.xlsx"

try:
    # Attempt to read all sheets
    xls = pd.ExcelFile(file_path)
    print(f"Sheets found: {xls.sheet_names}")
    
    for sheet_name in xls.sheet_names:
        print(f"\n--- Sheet: {sheet_name} ---")
        df = pd.read_excel(file_path, sheet_name=sheet_name)
        print(df.head(10).to_string())
        print("\nColumns:", df.columns.tolist())
        
except Exception as e:
    print(f"Error reading Excel file: {e}")
