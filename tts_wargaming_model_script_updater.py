#!/usr/bin/env python
""""""
import json
import os
import pathlib
import re
import subprocess
import sys
import time
from time import gmtime, strftime


def read_file(filename):
    infile = open(filename, mode="r", encoding="utf-8")
    intext = infile.read()
    infile.close()
    return intext


THIS_DIR = os.path.dirname(os.path.realpath(__file__))
SCRIPT_PATH = os.path.join(THIS_DIR, "tts_wargaming_model_script.min.lua")
if not os.path.exists(SCRIPT_PATH):
    SCRIPT_PATH = os.path.join(THIS_DIR, "tts_wargaming_model_script.lua")
NEW_SCRIPT_ORIGINAL = read_file(SCRIPT_PATH)
NEW_SCRIPT_HEADER = "--[[ TTS Wargaming Model Script! For more info, see https://github.com/khaaarl/tts-wargaming-model-script ]]--"
NEW_SCRIPT = "\n".join([NEW_SCRIPT_HEADER, NEW_SCRIPT_ORIGINAL.strip()]).strip()


def update_obj(obj):
    found_thing_to_update = False
    if isinstance(obj, dict):
        for k, v in dict(obj.items()).items():
            if k == "LuaScript" and isinstance(v, str):
                if "unitData" in v or v.strip() == NEW_SCRIPT:
                    continue
                if (
                    NEW_SCRIPT_HEADER in v
                    or "changeModelWoundCount" in v
                    or "BASE_SIZES_IN_MM" in v
                ):
                    found_thing_to_update = True
                    obj["LuaScript"] = NEW_SCRIPT
            else:
                found_thing_to_update = update_obj(v) or found_thing_to_update
    elif isinstance(obj, list):
        for item in obj:
            found_thing_to_update = update_obj(item) or found_thing_to_update
    return found_thing_to_update


def retriably_rename(old_path, new_path):
    """Retriably move something from path to path.

    This exists just as a possible workaround for an issue on my
    remote drive.
    """
    for ix in range(5):
        try:
            os.rename(old_path, new_path)
            return
        except PermissionError:
            time.sleep(2.0)
    # last ditch attempt
    os.rename(old_path, new_path)


def file_contains_outdated_scripts(filename):
    if not filename.endswith(".json"):
        return False
    intext = read_file(filename)
    return update_obj(json.loads(intext))


def update_file(filename):
    if not file_contains_outdated_scripts(filename):
        return
    intext = read_file(filename)
    print("Found outdated scripts in", filename)
    now = strftime("%Y-%m-%dT%H-%M-%SZ", gmtime())
    backup_filename = f"{filename}-{now}.backup"
    print("Moving to backup location", backup_filename)
    retriably_rename(filename, backup_filename)
    obj = json.loads(intext)
    update_obj(obj)
    tmp_filename = f"{filename}.tmp"
    outfile = open(tmp_filename, mode="w")
    json.dump(obj, outfile, indent=2)
    outfile.close()
    retriably_rename(tmp_filename, filename)
    print("Updated", filename)
    # sleep so that modified time is in increasing order even when the mtime is only integer granularity.
    time.sleep(1.2)


def expand_thing(path, file_list):
    if os.path.isfile(path):
        file_list.append(path)
    elif os.path.isdir(path):
        for root, dirs, files in os.walk(path):
            for filename in files:
                if filename.endswith(".json"):
                    file_list.append(os.path.join(root, filename))
    else:
        print("File or directory not found; skipping:", path)


if __name__ == "__main__":
    print(strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()), "Starting")
    things = list(sys.argv[1:])
    file_list = []
    for item in things:
        expand_thing(item, file_list)
    file_list.sort(key=lambda path: (os.path.getmtime(path), path))
    for file in file_list:
        update_file(file)
    print(strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()), "Done. Press enter to exit.")
    input()
