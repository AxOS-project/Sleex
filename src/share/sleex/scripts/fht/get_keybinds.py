#!/usr/bin/env -S _/bin/sh _-c "source $(eval echo $SLEEX_VIRTUAL_ENV)/bin/activate && exec python -E "$0" "$@""
import argparse
import re
import os
import json
import toml
from typing import Dict, List, Any

TITLE_REGEX = r"^#+!"
HIDE_COMMENT = "[hidden]"

parser = argparse.ArgumentParser(description='Sleex TOML keybind reader')
parser.add_argument('--path', type=str, default="/etc/sleex/compositor/keybinds.toml", help='path to config file')
args = parser.parse_args()

class Section(dict):
    def __init__(self, name: str):
        self["name"] = name
        self["children"] = []
        self["keybinds"] = []

def parse_toml_config(path: str):
    expanded_path = os.path.expanduser(os.path.expandvars(path))
    if not os.access(expanded_path, os.R_OK):
        return "error"

    with open(expanded_path, "r") as f:
        lines = f.readlines()

    with open(expanded_path, "r") as f:
        full_data = toml.load(f)

    keybinds_data = full_data.get("keybinds", {})
    
    root = Section("")
    stack = [(0, root)] # (level, section_object)

    for line in lines:
        clean_line = line.strip()
        
        if re.match(TITLE_REGEX, clean_line):
            level = clean_line.count('#')
            name = clean_line.replace('!', '').replace('#', '').strip()
            new_section = Section(name)
            
            while stack and stack[-1][0] >= level:
                stack.pop()
            
            stack[-1][1]["children"].append(new_section)
            stack.append((level, new_section))
            continue

        if HIDE_COMMENT in line or not clean_line or clean_line.startswith("["):
            continue

        if "=" in clean_line:
            key_part = clean_line.split("=")[0].strip()
            base_key = key_part.split(".")[0]
            
            if base_key in keybinds_data:
                data = keybinds_data[base_key]
                if not any(kb["key"] == base_key for kb in stack[-1][1]["keybinds"]):
                    
                    comment = ""
                    if "#" in line and HIDE_COMMENT not in line:
                        comment = line.split("#")[-1].strip()

                    mods = base_key.split("-")
                    actual_key = mods.pop()
                    
                    if isinstance(data, dict):
                        dispatcher = data.get("action", "")
                        params = str(data.get("arg", ""))
                    else:
                        dispatcher = data
                        params = ""

                    stack[-1][1]["keybinds"].append({
                        "mods": mods,
                        "key": actual_key,
                        "dispatcher": dispatcher,
                        "params": params,
                        "comment": comment
                    })
                    # keybinds_data.pop(base_key) 

    return root

if __name__ == "__main__":
    result = parse_toml_config(args.path)
    print(json.dumps(result, indent=2))