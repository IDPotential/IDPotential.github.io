
import os

file_path = r'D:\APK\id_diagnostic_app\lib\screens\festival_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Target line index is around 805 (0-indexed) -> 806 (1-indexed)
# The line is: "                 );"
# We want to change it to: "                 ));"

target_index = 805
found = False

# Search around the target index to be sure
for i in range(target_index - 5, target_index + 5):
    if i < len(lines):
        line = lines[i]
        if line.strip() == ');':
            print(f"Found target at line {i+1}: {line.rstrip()}")
            # Check indentation
            indentation = line[:line.find(')')]
            lines[i] = indentation + '));\n'
            found = True
            break

if found:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print("Successfully patched the file.")
else:
    print("Could not find the target line.");
