
import os
import codecs

file_path = r'd:\APK\id_diagnostic_app\lib\data\diagnostic_data.dart'

try:
    with codecs.open(file_path, 'r', 'utf-16-le') as f:
        content = f.read()
    
    # Write back as utf-8
    with codecs.open(file_path, 'w', 'utf-8') as f:
        f.write(content)
        
    print(f"Successfully converted {file_path} to UTF-8")
except Exception as e:
    print(f"Error converting file: {e}")
