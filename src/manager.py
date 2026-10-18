import os
import sys
import json
import subprocess
from pathlib import Path

from common import (
    read_config,
    get_config_file_path,
    INTERVAL_MAPPING,
    ORDER_MAPPING,
    get_last_file_path,
)

SCRIPT_FOLDER     = Path(__file__).parent.resolve()
EXECUTABLE_FOLDER = SCRIPT_FOLDER
EXECUTABLE_PATH   = EXECUTABLE_FOLDER / 'background.py'

SYSTEMD_UNIT_FILE="wallpaperninja.service"
SYSTEMD_UNIT_TEMPLATE = """
[Unit]
Description=Wallpaper Ninja service

[Service]
Type=simple
WorkingDirectory={executable_folder}
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/usr/bin/python3 {executable_path}

[Install]
WantedBy=graphical-session.target
"""

SYSTEMD_TIMER_FILE="wallpaperninja.timer"
SYSTEMD_TIMER_TEMPLATE = """
[Unit]
Description=Wallpaper Ninja timer

[Timer]
OnActiveSec=1sec
OnUnitActiveSec={interval_value}{interval}
AccuracySec={accuracy}
Unit="""+SYSTEMD_UNIT_FILE+"""

[Install]
WantedBy=timers.target
"""

SYSTEMD_DAYNIGHT_FILE="wallpaperninja-daynight.timer"
SYSTEMD_DAYNIGHT_TEMPLATE = """
[Unit]
Description=Wallpaper Ninja day and night switch

[Timer]
OnCalendar=*-*-* {day_hh}:{day_mm}:00
OnCalendar=*-*-* {night_hh}:{night_mm}:00
AccuracySec=1min
Persistent=true
Unit="""+SYSTEMD_UNIT_FILE+"""

[Install]
WantedBy=timers.target
"""


def pull_config() -> dict:
    res = read_config()
    if res.get('interval', "nothing") in INTERVAL_MAPPING:
        res['interval'] = INTERVAL_MAPPING.index(res['interval'])
    else:
        res['interval'] = 0

    if res.get('order', 'nothing') in ORDER_MAPPING:
        res['order'] = ORDER_MAPPING.index(res['order'])
    else:
        res['order'] = 0

    return res

def save_config(cfg:dict) -> bool:
    cfg['interval']       = INTERVAL_MAPPING[cfg.get('interval', 0)]
    cfg['interval_value'] = int(cfg.get('interval_value', 1))
    cfg['order']          = ORDER_MAPPING[cfg.get('order', 0)]
    path = get_config_file_path()
    print("[DEBUG] {path}: {cfg}")
    with open(path, 'w') as fout:
        json.dump(cfg, fout, indent=2)

    # Delete last wallpaper info because setings have changed so we start over
    get_last_file_path().unlink(missing_ok=True)

    return True

def install_background_module() -> bool:
    systemd_folder = _get_systemd_folder()
    cfg = read_config()
    interval = cfg.get('interval', 'min')
    interval_value = int(cfg.get('interval_value', 1))

    # Systemd service unit file
    with open(systemd_folder / SYSTEMD_UNIT_FILE, 'w') as fout:
        fout.write(SYSTEMD_UNIT_TEMPLATE.format(
            executable_folder = str(EXECUTABLE_FOLDER.absolute()),
            executable_path   = str(EXECUTABLE_PATH.absolute()),
        ))

    # Systemd interval timer file
    accuracy = "1min"
    if interval == 'sec':
        accuracy = "1sec"
    elif interval == 'min':
        accuracy = '1min' if interval_value > 10 else '1sec'
    timer_template = SYSTEMD_TIMER_TEMPLATE.format(
        interval       = interval,
        interval_value = interval_value,
        accuracy       = accuracy
    )
    # Comment the reactivation timer if the interval is on boot
    if interval == 'boot':
        timer_template = timer_template.replace('OnUnitActiveSec=', '# OnUnitActiveSec=')
    with open(systemd_folder / SYSTEMD_TIMER_FILE, 'w') as fout:
        fout.write(timer_template)

    # Systemd daynight timer file
    day_parts = cfg.get('day_hour', '07:00').split(':', 2)
    night_parts = cfg.get('night_hour', '20:00').split(':', 2)
    with open(systemd_folder / SYSTEMD_DAYNIGHT_FILE, 'w') as fout:
        fout.write(SYSTEMD_DAYNIGHT_TEMPLATE.format(
            day_hh   = f"{int(day_parts[0]):02d}",
            day_mm   = f"{int(day_parts[1]):02d}",
            night_hh = f"{int(night_parts[0]):02d}",
            night_mm = f"{int(night_parts[1]):02d}",
        ))

    # Update and enable the systemd services
    os.system(f"systemctl --user daemon-reload")
    os.system(f"systemctl --user enable {SYSTEMD_UNIT_FILE}")

    if cfg.get('enable_interval') and cfg.get('interval') != 'boot':
        os.system(f"systemctl --user enable {SYSTEMD_TIMER_FILE}")
        os.system(f"systemctl --user restart {SYSTEMD_TIMER_FILE}")
    else:
        os.system(f"systemctl --user disable {SYSTEMD_TIMER_FILE}")
        os.system(f"systemctl --user stop {SYSTEMD_TIMER_FILE}")

    if cfg.get('enable_daynight'):
        os.system(f"systemctl --user enable --now {SYSTEMD_DAYNIGHT_FILE}")
        os.system(f"systemctl --user restart {SYSTEMD_DAYNIGHT_FILE}")
    else:
        os.system(f"systemctl --user disable {SYSTEMD_DAYNIGHT_FILE}")
        os.system(f"systemctl --user stop {SYSTEMD_DAYNIGHT_FILE}")

    os.system(f"systemctl --user restart {SYSTEMD_UNIT_FILE}")

    return True

def remove_background_module() -> bool:
    systemd_folder = _get_systemd_folder()
    os.system(f"systemctl --user disable {SYSTEMD_TIMER_FILE}")
    os.system(f"systemctl --user disable {SYSTEMD_DAYNIGHT_FILE}")
    os.system(f"systemctl --user disable {SYSTEMD_UNIT_FILE}")
    os.system(f"systemctl --user stop {SYSTEMD_TIMER_FILE}")
    os.system(f"systemctl --user stop {SYSTEMD_DAYNIGHT_FILE}")
    os.system(f"systemctl --user stop {SYSTEMD_UNIT_FILE}")

    path_unit = systemd_folder / SYSTEMD_UNIT_FILE
    path_timer = systemd_folder / SYSTEMD_TIMER_FILE
    path_daynight = systemd_folder / SYSTEMD_DAYNIGHT_FILE
    path_unit.unlink(missing_ok=True)
    path_timer.unlink(missing_ok=True)
    path_daynight.unlink(missing_ok=True)

    os.system(f"systemctl --user daemon-reload")

    get_last_file_path().unlink(missing_ok=True)
    return True

def trigger_next_wallpaper() -> bool:
    config = read_config()
    if not config:
        return False

    from background import (get_and_set_next_wallpaper)
    path = get_and_set_next_wallpaper()

    print(f"[INFO] Set wallpaper to {path}")

    return (path is not None)

def count_how_many_wallpapers(folder:str, recursive:bool=False) -> int:
    """
    Count how many wallpaper images are in the path `folder`.
    Returns <0 on error
    Returns the number of images in folder
    """
    from background import (explore_wallpapers_folder)
    path = Path(folder)
    if not path.is_dir():
        return -1
    wlist = explore_wallpapers_folder(path, recursive=recursive)
    return len(wlist)

def is_background_module_enabled() -> bool:
    systemd_folder = _get_systemd_folder()
    path_unit = systemd_folder / SYSTEMD_UNIT_FILE
    return path_unit.is_file()

def read_logs(max_lines:int=None) -> str:
    return read_journal(SYSTEMD_UNIT_FILE, max_lines=max_lines)

def read_journal(service:str=None, max_lines:int=1024) -> str:
    """
    Returns the last `max_lines` lines of the `service` user journal.
    """
    service = service or SYSTEMD_UNIT_FILE
    max_lines = max(1, max_lines or 1024)

    cmd = [
        "journalctl",
        "--user",
        f"--unit={service}",
        f"--lines={max_lines}",   # journalctl cuts the output itself
        "--no-pager",
        "--output=short-iso",
    ]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=10,
        )
    except FileNotFoundError:
        return "journalctl not found."
    except subprocess.TimeoutExpired:
        return "journalctl timed out."

    if result.returncode != 0:
        error = result.stderr.strip() or f"journalctl exited with code {result.returncode}"
        return f"Could not read logs: {error}"

    return result.stdout

def _get_systemd_folder() -> Path:
    config_home  = Path(os.environ.get("XDG_CONFIG_HOME", "~/.config")).expanduser()
    systemd_user = config_home / "systemd" / "user"
    systemd_user.mkdir(parents=True, exist_ok=True)
    return systemd_user
