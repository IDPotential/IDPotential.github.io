import os

file_path = r'd:\APK\id_diagnostic_app\lib\data\diagnostic_data.dart'

def recover(encoding):
    try:
        # Read with utf-8-sig to remove BOM if present
        with open(file_path, 'r', encoding='utf-8-sig') as f:
            content = f.read()

        # If BOM was not removed by utf-8-sig (e.g. if it was encoded as part of mojibake), 
        # we might need to manually strip it or just handle exceptions.
        # But 'charmap' error suggests the character exists in the string we are trying to encode.
        
        # We will ignore errors when encoding to cp866 to skip unmappable chars (like BOM)
        # assuming the corruption is consistent.
        fixed_content = content.encode(encoding, errors='ignore').decode('utf-8')
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(fixed_content)
        print(f"Successfully recovered {file_path} using {encoding}")
        return True
    except Exception as e:
        print(f"Error with {encoding}: {e}")
        return False

if not recover('cp866'):
    print("Trying alternate encodings...")
    if not recover('cp437'):
        recover('cp1251')
