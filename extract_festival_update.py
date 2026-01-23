
import zipfile
import re
import sys
import os

docx_path = r"D:\APK\id_diagnostic_app\Территория Игры.docx"
output_path = r"D:\APK\id_diagnostic_app\extracted_festival_update.txt"

if not os.path.exists(docx_path):
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(f"File not found: {docx_path}")
    sys.exit(1)

try:
    with zipfile.ZipFile(docx_path) as z:
        xml_content = z.read('word/document.xml').decode('utf-8')
        xml_content = re.sub(r' xmlns:[^=]+=("[^"]*"|\'[^\']*\')', '', xml_content)
        paragraphs = re.findall(r'<w:p.*?>(.*?)</w:p>', xml_content)
        
        full_text = []
        for p in paragraphs:
            texts = re.findall(r'<w:t.*?>(.*?)</w:t>', p)
            if texts:
                full_text.append(''.join(texts))
        
        with open(output_path, "w", encoding="utf-8") as f:
            f.write('\n'.join(full_text))
            
except Exception as e:
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(f"Error reading docx: {e}")
