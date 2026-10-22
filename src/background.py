#!/usr/bin/python3

import os
import json
import shutil
from datetime import datetime
import subprocess
from pathlib import Path

import common

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

    if src.suffix.lower() not in common.IMAGE_EXTENSIONS:
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
    cfg = common.read_config()
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
    cfg  = cfg if cfg is not None else common.read_config()
    if not cfg:
        return (None, None)

    gallery_id = get_gallery_id(cfg)
    order      = cfg.get('order')
    folder     = common.get_local_wallpapers_folder(gallery_id)
    folder_str = str(folder)
    imgorder   = common.read_order_file(gallery_id)

    wlist      = common.explore_wallpapers_folder(folder, order=order, imgorder=imgorder)
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

def get_gallery_id(cfg, now=None):
    """
    Return the gallery_id given the current cfg and time (auto to now)
    """
    now = now or datetime.now()

    if not cfg.get('enable_daynight'):
        return "main"

    day_parts = cfg.get('day_hour', '').split(':', 2)
    night_parts = cfg.get('night_hour', '').split(':', 2)
    if not day_parts or not day_parts[0] or not night_parts or not night_parts[0]:
        return "main"

    day_h = int(day_parts[0])
    day_m = int(day_parts[1])
    night_h = int(night_parts[0])
    night_m = int(night_parts[1])

    if (now.hour > night_h or (now.hour == night_h and now.minute >= night_m)
        or (now.hour < day_h or (now.hour == day_h and now.minute < day_m))):
        return "alternative"

    return "main"

def _date_now() -> str:
    """
    Return the ISO string date
    """
    return datetime.now().isoformat().split('.', 1)[0]

def get_last_details() -> dict:
    """
    Returns {"/folder/": {"/folder/path/to/image.png": "2026-10-17T19:20:26"}}
    """
    data = {}
    last_path = common.get_last_file_path()
    if not last_path.is_file():
        return {}
    with open(last_path, 'r') as fin:
        try:
            data = json.load(fin)
        except json.decoder.JSONDecodeError:
            data = {}
    return data

def save_last_details(details:list):
    with open(common.get_last_file_path(), 'w') as fout:
        json.dump(details, fout)

def main():
    path = get_and_set_next_wallpaper()
    print(f"Wallpaper changed to: {path}")

if __name__ == '__main__':
    main()
