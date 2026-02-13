import shutil
import os

source_path = r"D:\APK\id_diagnostic_app\fest\Ирина Абрамова.jpg"
dest_path = r"D:\APK\id_diagnostic_app\assets\images\irina_abramova.jpg"

try:
    if os.path.exists(source_path):
        shutil.copy2(source_path, dest_path)
        print(f"Successfully copied {source_path} to {dest_path}")
    else:
        print(f"Source file not found: {source_path}")
except Exception as e:
    print(f"Error copying file: {e}")
