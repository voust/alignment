import os
import sys
import re

def generate_summary():
    base_dir = "src"
    summary_path = os.path.join(base_dir, "SUMMARY.md")
    landing_page = os.path.join(base_dir, "index.md")
    
    output_lines = ["# Summary", ""]

    if not os.path.exists(base_dir):
        print("❌ Error: 'src' directory not found.")
        sys.exit(1)

    if os.path.exists(landing_page):
        output_lines.append("- [Introduction](index.md)")
        output_lines.append("")

    all_items = os.listdir(base_dir)
    folder_pattern = re.compile(r'^(\d{2})[_-](.+)$')
    folders = []
    seen_numbers = {}

    for item in all_items:
        if item.startswith('.'): continue
        item_path = os.path.join(base_dir, item)
        
        if os.path.isdir(item_path):
            if item[0].isdigit():
                match = folder_pattern.match(item)
                if not match:
                    print(f"❌ BLOCKING ERROR: Folder '{item}' violates naming convention.")
                    sys.exit(1)
                
                num = int(match.group(1))
                if num in seen_numbers:
                    existing = seen_numbers[num]
                    print(f"❌ BLOCKING ERROR: Duplicate section '{num}' (Conflict: '{existing}' vs '{item}')")
                    sys.exit(1)
                seen_numbers[num] = item
                folders.append((item, num, match.group(2)))
            else:
                if item not in ["images"]:
                    print(f"❌ BLOCKING ERROR: Unauthorized folder '{item}' found in src/.")
                    sys.exit(1)

    folders.sort(key=lambda x: (x[1], x[0]))

    for folder_name, num, raw_title in folders:
        folder_path = os.path.join(base_dir, folder_name)
        index_path = os.path.join(folder_path, "index.md")
        clean_title = raw_title.replace('_', ' ').replace('-', ' ').title()

        if not os.path.exists(index_path):
            print(f"❌ BLOCKING ERROR: Folder '{folder_name}' is missing 'index.md'.")
            sys.exit(1)
        
        output_lines.append(f"- [{clean_title}]({folder_name}/index.md)")

        files = sorted([fil for fil in os.listdir(folder_path) if fil.endswith(".md") and fil != "index.md" and not fil.startswith(".")])
        for file in files:
            file_title = file.replace("-", " ").replace("_", " ").replace(".md", "").title()
            rel_path = f"{folder_name}/{file}"
            output_lines.append(f"    - [{file_title}]({rel_path})")

    with open(summary_path, "w") as f:
        f.write("\n".join(output_lines) + "\n")

if __name__ == "__main__":
    generate_summary()
    print("✅ System: Navigation regenerated successfully.")
