"""
Systemd unit and timers for WallpaperNinja
"""

import os
from pathlib import Path

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
AccuracySec={accuracy}
Persistent=true
Unit="""+SYSTEMD_UNIT_FILE+"""

[Install]
WantedBy=timers.target
"""

def install_service():
    """
    Install the wallpaperninja systemd service
    """
    systemd_folder = _get_systemd_folder()

    # Systemd service unit file
    with open(systemd_folder / SYSTEMD_UNIT_FILE, 'w') as fout:
        fout.write(SYSTEMD_UNIT_TEMPLATE.format(
            executable_folder = str(EXECUTABLE_FOLDER.absolute()),
            executable_path   = str(EXECUTABLE_PATH.absolute()),
        ))

def install_interval_timer(interval:str=None, interval_value:int=None, strict_time:bool=False):
    """
    Install the wallpaperninja systemd interval timer to trigger wallpapers
    every X amount of seconds|minutes|hours...
    """
    if not interval:
        raise ValueError("Missing value for interval")

    accuracy = "1min"
    if strict_time:
        accuracy = "1sec"
    elif interval == 'sec':
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

    systemd_folder = _get_systemd_folder()
    with open(systemd_folder / SYSTEMD_TIMER_FILE, 'w') as fout:
        fout.write(timer_template)

def install_daynight_timer(day_hour:str=None, night_hour:str=None, strict_time:bool=False):
    """
    Install the wallpaperninja systemd daynight timer to trigger wallpapers
    at the given day_hour and night_hour times.
    """
    if not day_hour or not night_hour:
        raise ValueError("Missing value for day_hour and night_hour")

    accuracy    = '1sec' if strict_time else '1min'
    day_parts   = day_hour.split(':', 2)
    night_parts = night_hour.split(':', 2)
    systemd_folder = _get_systemd_folder()
    with open(systemd_folder / SYSTEMD_DAYNIGHT_FILE, 'w') as fout:
        fout.write(SYSTEMD_DAYNIGHT_TEMPLATE.format(
            day_hh   = f"{int(day_parts[0]):02d}",
            day_mm   = f"{int(day_parts[1]):02d}",
            night_hh = f"{int(night_parts[0]):02d}",
            night_mm = f"{int(night_parts[1]):02d}",
            accuracy = accuracy,
        ))

def enable_service():
    os.system(f"systemctl --user enable {SYSTEMD_UNIT_FILE}")

def restart_service():
    os.system(f"systemctl --user restart {SYSTEMD_UNIT_FILE}")

def disable_service():
    os.system(f"systemctl --user disable {SYSTEMD_UNIT_FILE}")

def enable_interval_timer():
    os.system(f"systemctl --user enable {SYSTEMD_TIMER_FILE}")
    os.system(f"systemctl --user restart {SYSTEMD_TIMER_FILE}")

def disable_interval_timer():
    os.system(f"systemctl --user disable {SYSTEMD_TIMER_FILE}")
    os.system(f"systemctl --user stop {SYSTEMD_TIMER_FILE}")

def enable_daynight_timer():
    os.system(f"systemctl --user enable --now {SYSTEMD_DAYNIGHT_FILE}")
    os.system(f"systemctl --user restart {SYSTEMD_DAYNIGHT_FILE}")

def disable_daynight_timer():
    os.system(f"systemctl --user disable {SYSTEMD_DAYNIGHT_FILE}")
    os.system(f"systemctl --user stop {SYSTEMD_DAYNIGHT_FILE}")

def uninstall_all():
    systemd_folder = _get_systemd_folder()

    disable_interval_timer()
    disable_daynight_timer()
    disable_service()

    (systemd_folder / SYSTEMD_UNIT_FILE).unlink(missing_ok=True)
    (systemd_folder / SYSTEMD_TIMER_FILE).unlink(missing_ok=True)
    (systemd_folder / SYSTEMD_DAYNIGHT_FILE).unlink(missing_ok=True)

    daemon_reload()

def daemon_reload():
    return os.system(f"systemctl --user daemon-reload")

def is_installed() -> bool:
    """
    Return if the systemd service is installed or not
    """
    systemd_folder = _get_systemd_folder()
    path_unit = systemd_folder / SYSTEMD_UNIT_FILE
    return path_unit.is_file()

def _get_systemd_folder() -> Path:
    config_home  = Path(os.environ.get("XDG_CONFIG_HOME", "~/.config")).expanduser()
    systemd_user = config_home / "systemd" / "user"
    systemd_user.mkdir(parents=True, exist_ok=True)
    return systemd_user
