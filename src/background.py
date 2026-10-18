#!/usr/bin/python3

import os
import sys
import json
import shutil
import random
from datetime import datetime
import subprocess
from typing import List
from pathlib import Path

from common import (
    IMAGE_EXTENSIONS,
    ORDER_MAPPING,
    read_config,
    get_last_file_path,
)

WALLPAPER_NAME_PREFIX = "wallpaperninja_"

def set_wallpaper(image_path: str, prefix:str=WALLPAPER_NAME_PREFIX) -> Path:
    """
    Set the Lomiri wallpaper from an image file.
    Returns the destination path of the wallpaper.
    Raises FileNotFoundError, ValueError, or subprocess.CalledProcessError on failure.
    """
    # 1. Verify the image
    src = Path(image_path).resolve(strict=True)

    if not src.is_file() or not os.access(src, os.R_OK):
        raise ValueError(f"image is not a readable file: {src}")

    if src.suffix.lower() not in IMAGE_EXTENSIONS:
        raise ValueError("supported formats are JPG, JPEG and PNG.")

    # 2. Prepare the image in Lomiri's custom wallpaper collection
    
    destdir = _get_lomiri_wallpaper_folder()
    dest    = destdir / f"{WALLPAPER_NAME_PREFIX}{src.name}"

    if src != dest:
        destdir.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dest)
        dest.chmod(0o644)

    # 3. Tell Lomiri to apply the new wallpaper
    user_id = os.getuid()
    subprocess.run(
        [
            "busctl",
            "--system",
            "call",
            "org.freedesktop.Accounts",
            f"/org/freedesktop/Accounts/User{user_id}",
            "org.freedesktop.Accounts.User",
            "SetBackgroundFile",
            "s",
            str(dest),
        ],
        check=True,
    )

    return dest

def _get_lomiri_wallpaper_folder() -> Path:
    user     = os.environ.get("USER", "")
    base_dir = os.environ.get("XDG_GREETER_DATA_DIR") or f"/var/lib/lightdm-data/{user}"
    destdir  = Path(base_dir) / "lomiri-system-settings" / "Pictures"
    return destdir

def remove_previous_wallpapers(current:str=None):
    """
    current must be the file name of the active wallpaper (with or without prefix, both ok)
    """
    if current and not current.startswith(WALLPAPER_NAME_PREFIX):
        current = f"{WALLPAPER_NAME_PREFIX}{current}"
    folder = _get_lomiri_wallpaper_folder()

    for path in folder.iterdir():
        if (path.is_file()
            and path.name.startswith(WALLPAPER_NAME_PREFIX)
            and (not current or path.name != current)):
            print(f"Removing wallpaper file: {path}")
            path.unlink()

def get_and_set_next_wallpaper() -> Path:
    """
    This is the method you probably want to call
    It decides the next wallpaper, it sets it, and leaves everything ready for the next run
    """
    cfg = read_config()
    last = get_last_details()
    imgpath, new_last = get_next_wallpaper(cfg=cfg, last=last)

    if not imgpath:
        return None

    save_last_details(new_last)
    wallpaper = set_wallpaper(imgpath)

    if wallpaper and cfg.get('remove_previous_wallpapers'):
        remove_previous_wallpapers(wallpaper.name)

    return wallpaper

def get_next_wallpaper(cfg:dict=None, last:dict=None) -> Path:
    """
    Returns the (Path(), last) to the wallpaper file
    Returns (None, None) if there are no next wallpapers
    """
    last = dict(last) if last is not None else get_last_details()
    cfg  = cfg if cfg is not None else read_config()
    if not cfg:
        return (None, None)

    order      = cfg['order']
    folder     = get_cfg_folder_by_time(cfg)
    folder_str = str(folder)
    wlist      = explore_wallpapers_folder(folder, cfg['recursive'], order)
    next_path  = None

    if not wlist:
        return (None, None)

    next_path = wlist[0]
    if order in ('abc', 'reversed_abc', 'random_no_repeat'):
        last_paths = last.get(folder_str) or {}
        for path in wlist:
            if str(path) not in last_paths:
                next_path = path
                break
        else:
            next_path = wlist[0]
            last[folder_str] = {}
    else:
        last[folder_str] = {}

    if folder_str not in last:
        last[folder_str] = {}
    last[folder_str][str(next_path)] = _date_now()

    return (next_path, last)

def get_cfg_folder_by_time(cfg, now=None) -> Path:
    """
    Return the wallpaper folder Path to use depending on cfg and daynight switch
    """
    now = now or datetime.now()
    folder = Path(cfg['folder'])
    folder2_raw = cfg.get('folder2')
    if not cfg.get('enable_daynight') or not folder2_raw:
        return folder

    day_parts = cfg.get('day_hour', '').split(':', 2)
    night_parts = cfg.get('night_hour', '').split(':', 2)
    if not day_parts or not day_parts[0] or not night_parts or not night_parts[0]:
        return folder

    day_h = int(day_parts[0])
    day_m = int(day_parts[1])
    night_h = int(night_parts[0])
    night_m = int(night_parts[1])

    if (now.hour > night_h or (now.hour == night_h and now.minute >= night_m)
        or (now.hour < day_h or (now.hour == day_h and now.minute < day_m))):
        return Path(folder2_raw)
        
    return folder

def _date_now() -> str:
    return datetime.now().isoformat().split('.', 1)[0]

def explore_wallpapers_folder(path:Path, recursive:bool=False, order:str=None) -> List[Path]:
    """
    List the folders
    """
    if not path.is_dir():
        raise NotADirectoryError(f"Not a directory: {path}")

    if order is not None and order not in ORDER_MAPPING:
        order = None

    files = [
        p for p in (path.rglob("*") if recursive else path.iterdir())
        if (p.is_file()
            and p.suffix.lower() in IMAGE_EXTENSIONS)
    ]

    # Apply the requested ordering.
    if order == "reversed_abc":
        files.sort(key=lambda p: str(p).lower(), reverse=True)
    elif order in ("random", "random_no_repeat"):
        random.shuffle(files)
    else: # "abc" and default: Path alphabetical order
        files.sort(key=lambda p: str(p).lower())

    return files

def get_last_details() -> dict:
    """
    Returns {"/folder/": {"/folder/path/to/image.png": "2026-10-17T19:20:26"}}
    """
    data = {}
    last_path = get_last_file_path()
    if not last_path.is_file():
        return {}
    with open(last_path, 'r') as fin:
        try:
            data = json.load(fin)
        except json.decoder.JSONDecodeError:
            data = {}
    return data

def save_last_details(details:list):
    with open(get_last_file_path(), 'w') as fout:
        json.dump(details, fout)

def main():
    path = get_and_set_next_wallpaper()
    print(f"Wallpaper changed to: {path}")

if __name__ == '__main__':
    main()
