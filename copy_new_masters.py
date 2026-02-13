import shutil
import os

def copy_images():
    # Source paths
    src_ekaterina = r"D:\APK\id_diagnostic_app\fest\Екатерина Курчавина.jpg"
    src_varvara = r"D:\APK\id_diagnostic_app\fest\ВарВара Ардель.jpg"

    # Destination paths
    dest_dir = r"D:\APK\id_diagnostic_app\assets\images"
    dest_ekaterina = os.path.join(dest_dir, "ekaterina_kurchavina.jpg")
    dest_varvara = os.path.join(dest_dir, "varvara_ardel.jpg")

    # Ensure destination directory exists
    os.makedirs(dest_dir, exist_ok=True)

    try:
        if os.path.exists(src_ekaterina):
            shutil.copy2(src_ekaterina, dest_ekaterina)
            print(f"Copied {src_ekaterina} to {dest_ekaterina}")
        else:
            print(f"Source file not found: {src_ekaterina}")

        if os.path.exists(src_varvara):
            shutil.copy2(src_varvara, dest_varvara)
            print(f"Copied {src_varvara} to {dest_varvara}")
        else:
            print(f"Source file not found: {src_varvara}")

    except Exception as e:
        print(f"Error copying images: {e}")

if __name__ == "__main__":
    copy_images()
