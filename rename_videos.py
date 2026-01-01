import os
import re

video_dir = r"d:\APK\id_diagnostic_app\video"
pattern = re.compile(r"AnimРоль (\d+).mp4")

print(f"Scanning {video_dir}...")

for filename in os.listdir(video_dir):
    match = pattern.match(filename)
    if match:
        number = match.group(1)
        # remove leading zero if present to match standard "1", "2" used in code
        # Wait, my code uses `widget.number.toString()` -> "1", "22".
        # But file had "01". 
        # So "01" -> "1". "10" -> "10".
        int_num = int(number)
        new_name = f"role_{int_num}.mp4"
        
        old_path = os.path.join(video_dir, filename)
        new_path = os.path.join(video_dir, new_name)
        
        try:
            os.rename(old_path, new_path)
            print(f"Renamed: {filename} -> {new_name}")
        except Exception as e:
            print(f"Error renaming {filename}: {e}")

print("Done.")
