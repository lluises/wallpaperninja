import os
import sys
import json
import random
from typing import List
from pathlib import Path

from ImageOrder import ImageOrder

INTERVAL_MAPPING = ['boot', 'sec', 'min', 'hour', 'day', 'week', 'month']
ORDER_MAPPING    = ['abc', 'reversed_abc', 'random', 'random_no_repeat']
IMAGE_EXTENSIONS = {'.jpg', '.jpeg', '.png'}

def read_config() -> dict:
    path = get_config_file_path()
    if not path.is_file():
        return {}
    with open(path, 'r') as fin:
        res = json.load(fin)
    return res

def write_config(cfg):
    path = get_config_file_path()
    with open(path, 'w') as fout:
        json.dump(cfg, fout, indent=2)

def explore_wallpapers_folder(folder:Path, order:str=None, imgorder:ImageOrder=None) -> List[Path]:
    """
    List the image paths
    """
    imgorder = imgorder or ImageOrder()
    def imgorder_sort_key(path):
        return (
            imgorder.get(path.name, 1_000_000),
            str(path).lower()
        )

    if not folder.is_dir():
        raise NotADirectoryError(f"Not a directory: {folder}")

    files = [
        p
        for p in folder.iterdir()
        if (p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS)
    ]

    # Apply the requested ordering.
    if order == "none":
        pass
    elif order == "reversed_abc":
        files.sort(key=imgorder_sort_key, reverse=True)
    elif order in ("random", "random_no_repeat"):
        random.shuffle(files)
    else: # "abc" and default
        files.sort(key=imgorder_sort_key)

    return files

def write_order_to_file(gallery_id, imgorder:ImageOrder) -> bool:
    path = get_order_file(gallery_id)
    if not path.parent.is_dir():
        path.parent.mkdir(parents=True, exist_ok=True)
    data = imgorder.serialize()
    with open(path, 'w') as fout:
        fout.write(data)
    return True

def read_order_file(gallery_id:str) -> ImageOrder:
    path = get_order_file(gallery_id)
    if not path.is_file():
        return ImageOrder()
    ordering = {}
    data = None
    with open(path, 'r') as fin:
        data = fin.read()
    return ImageOrder.parse(data)

def get_order_file(gallery_id:str) -> Path:
    return get_data_folder() / "images" / gallery_id / "order.csv"

def get_config_file_path() -> Path:
    return get_config_folder() / "config.json"

def get_last_file_path() -> Path:
    return get_config_folder() / "last.json"

def get_local_wallpapers_folder(gallery_id:str) -> Path:
    return get_data_folder() / "images" / gallery_id

def get_thumbnail_folder() -> Path:
    return get_cache_folder() / "thumbnail"

def get_config_folder() -> Path:
    folder = _get_xdg_folder("XDG_CONFIG_HOME", Path.home() / ".config")
    folder.mkdir(parents=True, exist_ok=True)
    return folder

def get_data_folder() -> Path:
    folder = _get_xdg_folder("XDG_DATA_HOME", Path.home() / ".local" / "share")
    folder.mkdir(parents=True, exist_ok=True)
    return folder

def get_cache_folder() -> Path:
    folder = _get_xdg_folder("XDG_CACHE_HOME", Path.home() / ".cache")
    folder.mkdir(parents=True, exist_ok=True)
    return folder

def _get_xdg_folder(env_name:str, default:Path):
    """
    Return the app's specific XDG_*_HOME folder path
    """
    # Click apps have APP_ID like "<package>_<app>_<version>"
    app_id  = os.environ.get("APP_ID", "")
    package = app_id.split("_")[0] if app_id else "wallpaperninja.kitsune.cat"
    base    = Path(os.environ.get(env_name, default))
    return base / package
