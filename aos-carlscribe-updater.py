#!/usr/bin/env python
""""""
import json
import multiprocessing
import os
import pathlib
import re
import requests
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
SCRIPT_PATH = os.path.join(THIS_DIR, "aos-carlscribe.lua")
MODEL_SCRIPT_PATH = os.path.join(
    THIS_DIR, "..", "tts-wargaming-model-script", "tts_wargaming_model_script.min.lua"
)
if not os.path.exists(MODEL_SCRIPT_PATH):
    MODEL_SCRIPT_PATH = os.path.join(
        THIS_DIR, "..", "tts-wargaming-model-script", "tts_wargaming_model_script.lua"
    )
MODEL_SCRIPT = read_file(MODEL_SCRIPT_PATH).strip()
MODEL_SCRIPT_HEADER = "--[[ TTS Wargaming Model Script! For more info, see https://github.com/khaaarl/tts-wargaming-model-script ]]--"
MODEL_SCRIPT = "\n".join([MODEL_SCRIPT_HEADER, MODEL_SCRIPT.strip()]).strip()
NEW_SCRIPT = read_file(SCRIPT_PATH).strip()
assert "]=]" not in MODEL_SCRIPT
NEW_SCRIPT += "\n\nMINIFIED_MODEL_SCRIPT = [=[" + MODEL_SCRIPT + "]=]"
NEW_SCRIPT = NEW_SCRIPT.strip()
SCRIPT_HEADER = "--[[ AoS Carlscribe"
assert NEW_SCRIPT.startswith(SCRIPT_HEADER)

BSDATA_FILES = """
Age of Sigmar 4.0.gst
Beasts of Chaos - Library.cat
Beasts of Chaos.cat
Blades of Khorne - Library.cat
Blades of Khorne.cat
Bonesplitterz - Library.cat
Bonesplitterz.cat
Cities of Sigmar - Library.cat
Cities of Sigmar.cat
Daughters of Khaine - Library.cat
Daughters of Khaine - The Croneseer's Pariahs.cat
Daughters of Khaine.cat
Disciples of Tzeentch - Library.cat
Disciples of Tzeentch.cat
Flesh-eater Courts - Library.cat
Flesh-eater Courts.cat
Fyreslayers - Library.cat
Fyreslayers - Lofnir Drothkeepers.cat
Fyreslayers.cat
Gloomspite Gitz - Library.cat
Gloomspite Gitz - Trugg's Troggherd.cat
Gloomspite Gitz.cat
Hedonites of Slaanesh - Library.cat
Hedonites of Slaanesh.cat
Idoneth Deepkin - Library.cat
Idoneth Deepkin.cat
Ironjawz - Krazogg's Grunta Stampede.cat
Ironjawz - Library.cat
Ironjawz.cat
Kharadron Overlords - Grundstok Expeditionary Force.cat
Kharadron Overlords - Library.cat
Kharadron Overlords.cat
Kruleboyz - Library.cat
Kruleboyz.cat
Lumineth Realm-lords - Library.cat
Lumineth Realm-lords.cat
Maggotkin of Nurgle - Library.cat
Maggotkin of Nurgle.cat
Nighthaunt - Library.cat
Nighthaunt.cat
Ogor Mawtribes - Library.cat
Ogor Mawtribes - The Roving Maw.cat
Ogor Mawtribes.cat
Ossiarch Bonereapers - Library.cat
Ossiarch Bonereapers.cat
Regiments of Renown.cat
Seraphon - Library.cat
Seraphon.cat
Skaven - Library.cat
Skaven - Thanquol's Mutated Menagerie.cat
Skaven - The Great-grand Gnawhorde.cat
Skaven.cat
Slaves to Darkness - Library.cat
Slaves to Darkness - The Swords of Chaos.cat
Slaves to Darkness - Tribes of the Snow Peaks.cat
Slaves to Darkness.cat
Sons of Behemat - King Brodd's Stomp.cat
Sons of Behemat - Library.cat
Sons of Behemat.cat
Soulblight Gravelords - Library.cat
Soulblight Gravelords - Scions of Nulahmia.cat
Soulblight Gravelords.cat
Stormcast Eternals - Astral Templars.cat
Stormcast Eternals - Draconith Skywing.cat
Stormcast Eternals - Library.cat
Stormcast Eternals.cat
Sylvaneth - Library.cat
Sylvaneth - The Evergreen Hunt.cat
Sylvaneth.cat
""".strip().split(
    "\n"
)
BSDATA_URL_ROOT = (
    "https://raw.githubusercontent.com/BSData/age-of-sigmar-4th/refs/heads/main/"
)
FACTION_BSDATA = {
    "__misc__": "Age of Sigmar 4.0.gst",
    "Beasts of Chaos": "Beasts of Chaos - Library.cat",
    "Blades of Khorne": "Blades of Khorne - Library.cat",
    "Bonesplitterz": "Bonesplitterz - Library.cat",
    "Cities of Sigmar": "Cities of Sigmar - Library.cat",
    "Daughters of Khaine": "Daughters of Khaine - Library.cat",
    "Disciples of Tzeentch": "Disciples of Tzeentch - Library.cat",
    "Flesh-eater Courts": "Flesh-eater Courts - Library.cat",
    "Fyreslayers": "Fyreslayers - Library.cat",
    "Gloomspite Gitz": "Gloomspite Gitz - Library.cat",
    "Hedonites of Slaanesh": "Hedonites of Slaanesh - Library.cat",
    "Idoneth Deepkin": "Idoneth Deepkin - Library.cat",
    "Ironjawz": "Ironjawz - Library.cat",
    "Kharadron Overlords": "Kharadron Overlords - Library.cat",
    "Kruleboyz": "Kruleboyz - Library.cat",
    "Lumineth Realm-lords": "Lumineth Realm-lords - Library.cat",
    "Maggotkin of Nurgle": "Maggotkin of Nurgle - Library.cat",
    "Nighthaunt": "Nighthaunt - Library.cat",
    "Ogor Mawtribes": "Ogor Mawtribes - Library.cat",
    "Ossiarch Bonereapers": "Ossiarch Bonereapers - Library.cat",
    "Seraphon": "Seraphon - Library.cat",
    "Skaven": "Skaven - Library.cat",
    "Slaves to Darkness": "Slaves to Darkness - Library.cat",
    "Sons of Behemat": "Sons of Behemat - Library.cat",
    "Soulblight Gravelords": "Soulblight Gravelords - Library.cat",
    "Stormcast Eternals": "Stormcast Eternals - Library.cat",
    "Sylvaneth": "Sylvaneth - Library.cat",
}


def retrieve_one_bsdata(filename):
    needs_update = False
    r = requests.get(BSDATA_URL_ROOT + filename)
    file_path = os.path.join(THIS_DIR, "BSData", filename)
    if (
        not os.path.exists(file_path)
        or r.content.decode("utf-8", "replace").strip() != read_file(file_path).strip()
    ):
        needs_update = True
        outfile = open(file_path, mode="w", encoding="utf-8")
        outfile.write(r.content.decode("utf-8", "replace"))
        outfile.close()
    json_path = file_path + ".json"
    if needs_update or not os.path.exists(json_path):
        subprocess.check_output(
            ["lua", os.path.join(THIS_DIR, "aos-carlscribe-preprocess.lua"), file_path]
        )


def retrieve_bsdata():
    with multiprocessing.Pool() as pool:
        pool.map(retrieve_one_bsdata, BSDATA_FILES)


def append_jsons_to_script():
    global NEW_SCRIPT
    for faction, filename in FACTION_BSDATA.items():
        json_path = os.path.join(THIS_DIR, "BSData", filename) + ".json"
        json_data = read_file(json_path)
        assert "]=]" not in json_data
        NEW_SCRIPT += '\n\nBSDATA_JSONS["' + faction + '"] = [=[' + json_data + "]=]"


def update_obj(obj):
    found_thing_to_update = False
    if isinstance(obj, dict):
        for k, v in dict(obj.items()).items():
            if k == "LuaScript" and isinstance(v, str):
                if v.strip() == NEW_SCRIPT:
                    continue
                if v.startswith(SCRIPT_HEADER):
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
    retrieve_bsdata()
    append_jsons_to_script()
    print(strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()), "Downloaded BSData")
    things = list(sys.argv[1:])
    file_list = []
    for item in things:
        expand_thing(item, file_list)
    file_list.sort(key=lambda path: (os.path.getmtime(path), path))
    for file in file_list:
        update_file(file)
    print(strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()), "Done. Press enter to exit.")
    input()
