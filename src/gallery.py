"""
Backend for GalleryManager.qml
"""

import os
import uuid
import shutil
from pathlib import Path
from typing import List

from ImageOrder import ImageOrder
import common

state_imgorder = None

def get_internal_name_for_picture(path:Path):
    return uuid.uuid4().hex + path.suffix

def list_pictures(gallery_id:str) -> List[str]:
    """
    Return a list of picture paths
    Returns ["/app/path/thumbnail/image.png", ...]
    """
    imgorder = get_state_imgorder(gallery_id)
    folder = common.get_local_wallpapers_folder(gallery_id, imgorder=imgorder)

    if not folder.is_dir():
        return

    images = common.explore_wallpapers_folder(folder)
    paths = [str(p) for p in images]
    return paths

def list_thumbs_or_pictures(gallery_id:str):
    """
    Returns a thumbnail if available, otherwise returns the original image
    Returns ["/app/path/thumbnail/image.png", ...]
    """
    imgorder = get_state_imgorder(gallery_id)
    folder = common.get_local_wallpapers_folder(gallery_id)
    thumbs = common.get_thumbnail_folder()

    if not folder.is_dir():
        return []

    res = []
    images = common.explore_wallpapers_folder(folder, imgorder=imgorder)
    for img in images:
        th = thumbs / img.name
        if th.is_file():
            res.append(str(th))
        else:
            res.append(str(img))

    return res

def list_some_pictures(gallery_id:str, maximum:int) -> List[str]:
    """
    List up to `maximum` relevant pictures for the given `gallery_id`
    """
    return list_thumbs_or_pictures(gallery_id)[:maximum]

def count_how_many_wallpapers(gallery_id:str) -> int:
    """
    Count how many wallpaper images are in the collection `gallery_id`
    Returns <0 on error
    Returns the number of images in folder
    """
    folder = common.get_local_wallpapers_folder(gallery_id)

    if not folder.is_dir():
        return 0

    images = common.explore_wallpapers_folder(folder, order="none")
    return len(images)

def append_pictures(gallery_id:str, pictures:List[str]) -> bool:
    """
    Copy the pictures to the internal wallpapers folder.
    Will rename all the files to avoid colisions
    Returns True
    """
    folder = common.get_local_wallpapers_folder(gallery_id)
    folder.mkdir(parents=True, exist_ok=True)

    images = []

    for raw in pictures:
        if raw.startswith('file://'):
            raw = raw.replace('file://', '')
        path = Path(raw)
        if path.is_file() and path.suffix in common.IMAGE_EXTENSIONS:
            target = folder / get_internal_name_for_picture(path)
            shutil.copyfile(path, target)
            images.append(target)
        else:
            print(f"Ignoring invalid path: {path}")

    recreate_imgorder(gallery_id)

    return True

def remove_pictures(gallery_id:str, pictures:List[str]) -> bool:
    """
    pictures: ["file-name.jpg"]
    Removes the pictures from the gallery_id folder
    """
    save_state_imgorder(gallery_id)

    folder = common.get_local_wallpapers_folder(gallery_id)
    thumbfolder = common.get_thumbnail_folder()

    for name in pictures:
        (folder / name).unlink(missing_ok=True)
        (thumbfolder / name).unlink(missing_ok=True)

    recreate_imgorder(gallery_id)

    return True

def swap_order(gallery_id:str, name1:str, name2:str) -> str:
    """
    Swap the order of two given images identified by name like "name.png"

    Returns error message. Returns "" if all ok
    """
    imgorder = get_state_imgorder(gallery_id)

    if name1 not in imgorder or name2 not in imgorder:
        return (
            f"The file {name1} and/or {name2} is not present and can't be sorted"
            f"\nimgorder = {imgorder} ({imgorder.order})"
        )

    imgorder.swap(name1, name2)
    set_state_imgorder(imgorder)
    save_state_imgorder(gallery_id)

    return ""

def recreate_imgorder(gallery_id:str) -> ImageOrder:
    """
    Recreate the ImageOrder for the given gallery.
    We might want to recreate instead of soft appending because if the data
    got corrupted then we can fix it now
    """
    set_state_imgorder(None)
    folder   = common.get_local_wallpapers_folder(gallery_id)
    imgorder = common.read_order_file(gallery_id)
    images   = common.explore_wallpapers_folder(folder, order="default", imgorder=imgorder)
    imgorder = ImageOrder.build_from_list(p.name for p in images)
    common.write_order_to_file(gallery_id, imgorder)
    set_state_imgorder(imgorder)
    return imgorder

def init_imgorder(gallery_id):
    imgorder = get_state_imgorder(gallery_id)
    if len(state_imgorder) == 0:
        recreate_imgorder(gallery_id)
    return

def get_state_imgorder(gallery_id:str) -> ImageOrder:
    global state_imgorder
    if not state_imgorder:
        state_imgorder = common.read_order_file(gallery_id)
    return state_imgorder

def set_state_imgorder(imgorder) -> ImageOrder:
    global state_imgorder
    state_imgorder = imgorder
    return state_imgorder

def save_state_imgorder(gallery_id:str) -> ImageOrder:
    global state_imgorder
    if state_imgorder:
        common.write_order_to_file(gallery_id, state_imgorder)
    return state_imgorder

def delete_all_thumbnails():
    thumbs = common.get_thumbnail_folder()
    if not thumbs.is_dir():
        return True
    for path in thumbs.iterdir():
        if path.is_file():
            path.unlink()

def get_thumbnail_folder():
    path = common.get_thumbnail_folder()
    path.mkdir(parents=True, exist_ok=True)
    return str(path)
