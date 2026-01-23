
import zipfile
import re
import xml.etree.ElementTree as ET

def extract_docx_text(path):
    try:
        with zipfile.ZipFile(path) as docx:
            xml_content = docx.read('word/document.xml')
        
        tree = ET.fromstring(xml_content)
        
        # Namespaces in docx xml
        namespaces = {
            'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
        }
        
        paragraphs = []
        for p in tree.findall('.//w:p', namespaces):
            texts = [node.text for node in p.findall('.//w:t', namespaces) if node.text]
            if texts:
                paragraphs.append(''.join(texts))
        
        return '\n\n'.join(paragraphs)
    except Exception as e:
        return f"Error: {e}"

if __name__ == "__main__":
    text = extract_docx_text("Политика ПД.docx")
    with open("privacy_policy_extracted.txt", "w", encoding="utf-8") as f:
        f.write(text)
    print("Extraction complete.")
