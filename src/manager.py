"""
Backend for Main.qml
"""

import os
import sys
import json
import subprocess
from pathlib import Path

import common
import systemd

def pull_config() -> dict:
    res = common.read_config()
    if res.get('interval', "nothing") in common.INTERVAL_MAPPING:
        res['interval'] = common.INTERVAL_MAPPING.index(res['interval'])
    else:
        res['interval'] = 0

    if res.get('order', 'nothing') in common.ORDER_MAPPING:
        res['order'] = common.ORDER_MAPPING.index(res['order'])
    else:
        res['order'] = 0

    return res

def save_config(cfg:dict) -> bool:
    cfg['interval']       = common.INTERVAL_MAPPING[cfg.get('interval', 0)]
    cfg['interval_value'] = int(cfg.get('interval_value', 1))
    cfg['order']          = common.ORDER_MAPPING[cfg.get('order', 0)]

    common.write_config(cfg)

    # Delete last wallpaper info because setings have changed so we start over
    common.get_last_file_path().unlink(missing_ok=True)

    return True

def install_background_module() -> bool:
    """
    Install all the necessary systemd modules depending on the configuration
    saved in the config file
    """
    cfg = common.read_config()
    interval = cfg.get('interval', 'min')
    interval_value = int(cfg.get('interval_value', 1))
    strict_time = cfg.get('strict_time', False)

    systemd.install_service()
    systemd.install_interval_timer(
        interval       = interval,
        interval_value = interval_value,
        strict_time    = strict_time,
    )
    systemd.install_daynight_timer(
        day_hour    = cfg.get('day_hour', '07:00'),
        night_hour  = cfg.get('night_hour', '20:00'),
        strict_time = strict_time,
    )

    systemd.daemon_reload()

    systemd.enable_service()

    if cfg.get('enable_interval') and cfg.get('interval') != 'boot':
        systemd.enable_interval_timer()
    else:
        systemd.disable_interval_timer()

    if cfg.get('enable_daynight'):
        systemd.enable_daynight_timer()
    else:
        systemd.disable_daynight_timer()

    systemd.restart_service()

    return True

def remove_background_module() -> bool:
    """
    Fully uninstall the wallpaperninja's systemd modules and leave it clean
    """
    systemd.uninstall_all()
    common.get_last_file_path().unlink(missing_ok=True) # Reset wallpapers cycle
    return True

def trigger_next_wallpaper() -> bool:
    """
    Change the wallpaper to the next wallpaper
    Modifies the next wallpapers list
    Does not alter systemd timers
    """
    config = common.read_config()
    if not config:
        return False

    from background import (get_and_set_next_wallpaper)
    path = get_and_set_next_wallpaper()

    print(f"[INFO] Set wallpaper to {path}")

    return (path is not None)

def is_background_module_enabled() -> bool:
    """
    Return if the systemd modules have been installed or not
    """
    return systemd.is_installed()
