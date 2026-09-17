#!/usr/bin/env python3
import subprocess
import json
import os
import sys
import re
import threading

CLIPHIST_DB = os.path.expanduser("~/.cache/cliphist/db")

URL_RE = re.compile(r'^\s*https?://\S+\s*$', re.IGNORECASE)
COLOR_RE = re.compile(r'^\s*(#[0-9a-fA-F]{3}|#[0-9a-fA-F]{6}|#[0-9a-fA-F]{8}|rgba?\([^)]+\))\s*$')

def cleanup_cache(all_lines, cache_dir):
    valid_ids = set()
    # Keep top 100 recent IDs to prevent infinite cache bloat
    for line in all_lines[:100]:
        if '\t' in line:
            valid_ids.add(line.split('\t', 1)[0])

    try:
        for f in os.listdir(cache_dir):
            if f.endswith('.png'):
                iid = f.replace('.png', '')
                if iid not in valid_ids:
                    try:
                        os.remove(os.path.join(cache_dir, f))
                    except Exception:
                        pass
    except Exception:
        pass

def get_list_lines(cache_dir):
    """Return all cliphist lines, reusing a disk cache while the cliphist db
    hasn't changed so repeated pagination calls don't re-invoke the binary."""
    list_cache_path = os.path.join(cache_dir, "list.cache")

    try:
        db_mtime = os.path.getmtime(CLIPHIST_DB)
    except OSError:
        db_mtime = None

    if db_mtime is not None:
        try:
            cache_mtime = os.path.getmtime(list_cache_path)
            if cache_mtime >= db_mtime:
                with open(list_cache_path, "r") as f:
                    return f.read().strip().split('\n')
        except OSError:
            pass

    result = subprocess.run(["cliphist", "list"], capture_output=True, text=True)
    text = result.stdout
    try:
        with open(list_cache_path, "w") as f:
            f.write(text)
    except OSError:
        pass

    return text.strip().split('\n')

def detect_subtype(content):
    if URL_RE.match(content):
        return "url"
    if COLOR_RE.match(content):
        return "color"
    return "text"

def get_cliphist():
    # Implement pagination arguments
    offset = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    # Slightly smaller limit to make the initial UI pop open faster
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 12

    # Use dynamically provided cache dir from QML or fallback securely
    cache_dir = sys.argv[3] if len(sys.argv) > 3 else os.environ.get("QS_CACHE_CLIPBOARD", os.path.expanduser("~/.cache/quickshell/clipboard"))
    os.makedirs(cache_dir, exist_ok=True)

    try:
        all_lines = get_list_lines(cache_dir)

        # Slice only the requested chunk
        lines = all_lines[offset:offset+limit]

        # Move cleanup to a background thread so it doesn't block the UI from receiving data
        if offset == 0:
            threading.Thread(target=cleanup_cache, args=(all_lines, cache_dir), daemon=True).start()

    except Exception as e:
        print("[]")
        return

    items = []
    for line in lines:
        if not line: continue
        parts = line.split('\t', 1)
        if len(parts) != 2: continue

        iid, content = parts[0], parts[1]
        item_type = "text"
        subtype = "text"
        display_content = content.strip()

        # Detect images in cliphist output
        if "[[ binary data" in content:
            item_type = "image"
            img_path = os.path.join(cache_dir, f"{iid}.png")

            # CACHING: Only decode the specific item if it doesn't already exist
            if not os.path.exists(img_path):
                with open(img_path, "wb") as f:
                    subprocess.run(["cliphist", "decode", iid], stdout=f)
            display_content = img_path
        else:
            subtype = detect_subtype(display_content)

        items.append({
            "id": iid,
            "content": display_content,
            "type": item_type,
            "subtype": subtype
        })

    print(json.dumps(items))

if __name__ == "__main__":
    get_cliphist()
