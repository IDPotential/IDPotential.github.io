
import json
import sys
import os
import io

# Force UTF-8 for output
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

sys.path.append(os.path.join(os.path.dirname(__file__), 'telegram'))
from data_libraries import ZONES, ASPECTS_ROLE, ASPECTS

def clean(text):
    if not isinstance(text, str): return str(text)
    return text.replace('"', '\\"').replace('\n', '\\n').replace('$', '\\$')

# Write directly to file to avoid PowerShell encoding issues
output_path = os.path.join(os.path.dirname(__file__), 'lib', 'data', 'diagnostic_data.dart')

with open(output_path, 'w', encoding='utf-8') as f:
    f.write("// ignore_for_file: constant_identifier_names\n")
    f.write("const Map<int, Map<String, String>> zones = {\n")
    for k, v in ZONES.items():
        f.write(f"    {k}: {{\n")
        for field, val in v.items():
            if isinstance(val, str):
                f.write(f"        \"{field}\": \"{clean(val)}\",\n")
        f.write(f"    }},\n")
    f.write("};\n\n")

    f.write("const Map<String, Map<String, String>> aspectsRole = {\n")
    for k, v in ASPECTS_ROLE.items():
        f.write(f"    \"{k}\": {{\n")
        for field, val in v.items():
            if isinstance(val, str):
                f.write(f"        \"{field}\": \"{clean(val)}\",\n")
        f.write(f"    }},\n")

    for k, v in ASPECTS.items():
        if k not in ASPECTS_ROLE:
            f.write(f"    \"{k}\": {{\n")
            f.write(f"        \"aspect_description\": \"{clean(v)}\",\n")
            f.write(f"    }},\n")
    f.write("};\n")

print(f"Successfully wrote to {output_path}")
