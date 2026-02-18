import pandas as pd

try:
    df = pd.read_excel('d:\\APK\\id_diagnostic_app\\telegram\\Login Pasword.xlsx')
    print("Columns:", df.columns.tolist())
    print("First 5 rows:")
    print(df.head())
except Exception as e:
    print(f"Error reading excel: {e}")
