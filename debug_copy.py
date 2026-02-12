import os
import shutil

src_dir = r'D:\APK\id_diagnostic_app\fest'
dst_dir = r'D:\APK\id_diagnostic_app\assets\images'
dst_file = os.path.join(dst_dir, 'irina_viznyuk.jpg')

print(f"Listing {src_dir}:")
found = False
for f in os.listdir(src_dir):
    print(f"  {f!r}")
    if 'Ирина' in f and f.endswith('.jpg'):
        src_file = os.path.join(src_dir, f)
        print(f"Copying {src_file} to {dst_file}")
        try:
            shutil.copy(src_file, dst_file)
            print("Copy success!")
            found = True
        except Exception as e:
            print(f"Copy failed: {e}")

if not found:
    print("No matching file found.")
