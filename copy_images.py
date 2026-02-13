import shutil
import os

source_dir = r"D:\APK\id_diagnostic_app\fest"
dest_dir = r"D:\APK\id_diagnostic_app\assets\images"

files_to_copy = {
    "Надежда Ланская.jpg": "nadezhda_lanskaya.jpg",
    "Надя и Тома.jpg": "nadya_toma_game.jpg"
}

for src_name, dest_name in files_to_copy.items():
    src_path = os.path.join(source_dir, src_name)
    dest_path = os.path.join(dest_dir, dest_name)
    
    try:
        shutil.copy2(src_path, dest_path)
        print(f"Successfully copied {src_name} to {dest_name}")
    except Exception as e:
        print(f"Error copying {src_name}: {e}")
