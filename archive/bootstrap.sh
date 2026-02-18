#!/bin/bash
set -e

# --- CONFIGURATION ---
REPO_URL="https://github.com/voust/alignment.git"
# ---------------------

echo "Initializing ALIGNMENT Protocol..."
mkdir -p src/images src/00_introduction src/01_thesis src/99_appendices
mkdir -p theme/css
mkdir -p scripts
mkdir -p .github/workflows

# Write Config
cat > book.toml <<'EOF'
[book]
title = "ALIGNMENT"
authors = ["The Alignment Team"]
language = "en"
multilingual = false
src = "src"

[build]
create-missing = false

[output.html]
theme = "theme"
default-theme = "coal"
preferred-dark-theme = "coal"
git-repository-url = "https://github.com/voust/alignment"
edit-url-template = "https://github.com/voust/alignment/edit/main/{path}"
mathjax-support = true
site-url = "/alignment/"

[output.html.search]
enable = true
limit-results = 30
EOF

# Write CSS
cat > theme/css/custom.css <<'EOF'
@import url('https://fonts.googleapis.com/css2?family=EB+Garamond:wght@400;700&family=Fira+Code:wght@300;500&display=swap');

:root {
    --accent-color: #00ff41;
    --border-style: 1px solid #333;
}

body {
    font-family: 'EB Garamond', serif;
    font-size: 1.25rem;
    line-height: 1.6;
    text-align: justify;
    hyphens: auto;
}

h1, h2, h3, code, pre { font-family: 'Fira Code', monospace; }

h1, h2, h3 {
    text-transform: uppercase;
    letter-spacing: -0.5px;
    border-bottom: var(--border-style);
    margin-top: 2em;
}

a { 
    text-decoration: underline; 
    text-decoration-thickness: 1px; 
    transition: background-color 0.1s ease, color 0.1s ease; 
}
a:hover { background-color: var(--accent-color); color: #000 !important; text-decoration: none; }
.coal a:visited { color: #a0a0a0; }
.rust a:visited { color: #555555; }
a:focus { outline: 2px solid var(--accent-color); outline-offset: 2px; }

.page-wrapper { max-width: 750px; margin: 0 auto; }

blockquote {
    font-family: 'Fira Code', monospace;
    font-size: 0.9rem;
    border-left: 4px solid var(--accent-color);
    background: rgba(0, 255, 65, 0.05);
    padding: 10px 20px;
    margin: 20px 0;
    color: inherit;
}
blockquote strong { color: var(--accent-color); text-transform: uppercase; }
EOF

# Write Gatekeeper
cat > scripts/generate_summary.py <<'EOF'
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
EOF

# Write Workflow
cat > .github/workflows/deploy.yml <<'EOF'
name: Deploy Book
on:
  push:
    branches: [main]
  schedule:
    - cron: '0 0 1 * *'

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
          cache: 'pip'
      - name: Validate & Generate Summary
        run: python scripts/generate_summary.py
      - name: Install mdBook (Hardened)
        run: |
          set -euo pipefail
          mkdir mdbook
          URL="https://github.com/rust-lang/mdBook/releases/download/v0.4.40/mdbook-v0.4.40-x86_64-unknown-linux-gnu.tar.gz"
          EXPECTED_HASH="67c9c0490b40e34771761618a8db20c4c47d79b88307c0886118d04229641e43"
          curl -L -o mdbook.tar.gz "$URL"
          echo "$EXPECTED_HASH mdbook.tar.gz" | sha256sum -c -
          tar -xzf mdbook.tar.gz -C mdbook
          echo "$PWD/mdbook" >> $GITHUB_PATH
      - name: Build Site
        run: mdbook build
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./book
EOF

# Generate Initial Content
echo "# ALIGNMENT" > src/index.md
echo "# Introduction" > src/00_introduction/index.md
echo "# The Alignment Thesis" > src/01_thesis/index.md
echo "# Glossary" > src/99_appendices/index.md
touch requirements.txt

# Run Gatekeeper Verification
python3 scripts/generate_summary.py

# Push to GitHub
git add .
git commit -m "feat: Initialize Alignment Engine (v12 Diamond Spec)"
git branch -M main
git remote add origin "$REPO_URL" 2>/dev/null || git remote set-url origin "$REPO_URL"
git push -u origin main

echo "🚀 DONE. Now go to: https://github.com/voust/alignment/settings/pages"
echo "👉 Action Required: Set 'Source' to 'Deploy from a branch' -> 'gh-pages' / '/ (root)'"
