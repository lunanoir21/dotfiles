#!/usr/bin/env python3
"""
Wallpaper Fetcher for Quickshell Wallpaper Hub
Scans ~/Pictures/Wallpapers, seeds defaults if empty, and outputs structured JSON metadata.
"""

import os
import sys
import json
import shutil
from pathlib import Path

def get_wallpaper_dir():
    custom_dir = os.environ.get("WALLPAPER_DIR")
    if custom_dir:
        return Path(custom_dir)
    return Path.home() / "Pictures" / "Wallpapers"

def format_file_size(size_bytes):
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.1f} GB"

def ensure_wallpapers(wall_dir):
    wall_dir.mkdir(parents=True, exist_ok=True)
    
    # Check if directory has any files
    has_files = any(wall_dir.iterdir()) if wall_dir.exists() else False
    if not has_files:
        defaults_dir = Path(__file__).parent / "defaults"
        if defaults_dir.exists() and defaults_dir.is_dir():
            for item in defaults_dir.iterdir():
                if item.is_file() and item.suffix.lower() in {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.mp4', '.mkv', '.mov', '.webm'}:
                    try:
                        shutil.copy2(item, wall_dir / item.name)
                    except Exception:
                        pass

def fetch_wallpapers():
    wall_dir = get_wallpaper_dir()
    ensure_wallpapers(wall_dir)

    valid_extensions = {
        '.jpg': 'image',
        '.jpeg': 'image',
        '.png': 'image',
        '.webp': 'image',
        '.gif': 'image',
        '.mp4': 'video',
        '.mkv': 'video',
        '.mov': 'video',
        '.webm': 'video'
    }

    wallpapers = []

    if not wall_dir.exists() or not wall_dir.is_dir():
        print(json.dumps([]))
        return

    try:
        entries = list(os.scandir(wall_dir))
    except Exception:
        print(json.dumps([]))
        return

    for entry in entries:
        if not entry.is_file():
            continue

        name = entry.name
        ext = os.path.splitext(name)[1].lower()

        if ext in valid_extensions:
            file_type = valid_extensions[ext]
            clean_ext = ext.lstrip('.').upper()

            try:
                stat = entry.stat()
                size_str = format_file_size(stat.st_size)
                mtime = int(stat.st_mtime)
            except Exception:
                size_str = "Unknown"
                mtime = 0

            wallpapers.append({
                "fileName": name,
                "filePath": entry.path,
                "fileType": file_type,
                "extension": clean_ext,
                "size": size_str,
                "mtime": mtime
            })

    # Default sort: newest first
    wallpapers.sort(key=lambda x: x["mtime"], reverse=True)

    print(json.dumps(wallpapers, indent=None))

if __name__ == "__main__":
    fetch_wallpapers()
