import json
import os
from pathlib import Path

INTERVAL_MAPPING = ['boot', 'sec', 'min', 'hour', 'day', 'week', 'month']
ORDER_MAPPING    = ['abc', 'reversed_abc', 'random', 'random_no_repeat']
IMAGE_EXTENSIONS = {'.jpg', '.jpeg', '.png'}

def read_config() -> dict:
    path = get_config_file_path()
    if not path.is_file():
        print(f"[INFO] No config found in {path}")
        return {}
    with open(path, 'r') as fin:
        res = json.load(fin)
    return res

def get_config_folder() -> Path:
    # Click apps have APP_ID like "<package>_<app>_<version>"
    app_id  = os.environ.get("APP_ID", "")
    package = app_id.split("_")[0] if app_id else "wallpaperninja.kitsune.cat"
    base    = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    folder  = base / package
    folder.mkdir(parents=True, exist_ok=True)
    return folder

def get_config_file_path() -> Path:
    # Click apps have APP_ID like "<package>_<app>_<version>"
    return get_config_folder() / "config.json"

def get_last_file_path() -> Path:
    # Click apps have APP_ID like "<package>_<app>_<version>"
    return get_config_folder() / "last.json"
