#!/usr/bin/env python3

import sys
import os
import json
import tomli
import tomli_w
import xml.etree.ElementTree as ET
import yaml

def usage():
    print("Usage: ./convert.sh input.{yaml,json,xml,toml} output.{yaml,json,xml,toml}", file=sys.stderr)
    sys.exit(1)

def load_yaml(path):
    with open(path, 'r') as f:
        return yaml.safe_load(f)

def load_json(path):
    with open(path, 'r') as f:
        return json.load(f)

def load_toml(path):
    with open(path, 'rb') as f:
        return tomli.load(f)

def load_xml(path):
    def xml_to_dict(elem):
        children = list(elem)
        if not children:
            return elem.text or ""
        d = {}
        for child in children:
            if child.tag in d:
                if not isinstance(d[child.tag], list):
                    d[child.tag] = [d[child.tag]]
                d[child.tag].append(xml_to_dict(child))
            else:
                d[child.tag] = xml_to_dict(child)
        return d
    tree = ET.parse(path)
    root = tree.getroot()
    return {root.tag: xml_to_dict(root)}

def dump_yaml(data, path):
    with open(path, 'w') as f:
        yaml.safe_dump(data, f)

def dump_json(data, path):
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)

def dump_toml(data, path):
    with open(path, 'wb') as f:
        f.write(tomli_w.dumps(data).encode('utf-8'))

def dump_xml(data, path):
    def build_xml(name, obj):
        if isinstance(obj, dict):
            el = ET.Element(name)
            for k, v in obj.items():
                el.append(build_xml(k, v))
            return el
        elif isinstance(obj, list):
            el = ET.Element(name)
            for i in obj:
                el.append(build_xml("item", i))
            return el
        else:
            el = ET.Element(name)
            el.text = str(obj)
            return el
    root = build_xml("root", data)
    tree = ET.ElementTree(root)
    tree.write(path, encoding="unicode", xml_declaration=True)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        usage()

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    ext_in = os.path.splitext(input_file)[1].lower().lstrip(".")
    ext_out = os.path.splitext(output_file)[1].lower().lstrip(".")

    loaders = {
        "yaml": load_yaml,
        "yml": load_yaml,
        "json": load_json,
        "toml": load_toml,
        "xml": load_xml,
    }

    dumpers = {
        "yaml": dump_yaml,
        "yml": dump_yaml,
        "json": dump_json,
        "toml": dump_toml,
        "xml": dump_xml,
    }

    if ext_in not in loaders or ext_out not in dumpers:
        print(f"Unsupported conversion: {ext_in} → {ext_out}", file=sys.stderr)
        usage()

    print(f"[+] Converting {input_file} ({ext_in}) → {output_file} ({ext_out})")

    try:
        data = loaders[ext_in](input_file)
        dumpers[ext_out](data, output_file)
        print("[✔] Done!")
    except Exception as e:
        print(f"[!] Conversion failed: {e}", file=sys.stderr)
        sys.exit(1)

