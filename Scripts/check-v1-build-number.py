#!/usr/bin/env python3
"""Fail closed unless the candidate exceeds every published Sparkle build."""
import argparse
import json
import pathlib
import re
import subprocess
import xml.etree.ElementTree as ET

NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"


def released_builds(data):
    root = ET.fromstring(data)
    values = [node.text for node in root.findall(f".//{{{NS}}}version")]
    values += [node.attrib[f"{{{NS}}}version"] for node in root.iter()
               if f"{{{NS}}}version" in node.attrib]
    if not values:
        raise ValueError("published appcast has no Sparkle build numbers")
    builds = []
    for value in values:
        if not value or not re.fullmatch(r"[0-9]+(?:\.[0-9]+)*", value):
            raise ValueError("published appcast contains an unsupported build number")
        builds.append(tuple(map(int, value.split("."))))
    return builds


def check(candidate, feeds):
    if not re.fullmatch(r"[1-9][0-9]*", candidate) or int(candidate) < 100:
        raise ValueError("candidate build must be an integer at least 100")
    builds = [build for feed in feeds for build in released_builds(feed)]
    if not builds:
        raise ValueError("no published appcasts found; cannot verify historical builds")
    if (int(candidate),) <= max(builds):
        raise ValueError("candidate build must exceed every published build")
    return max(builds)


def gh(*args):
    return subprocess.run(["gh", *args], check=True, stdout=subprocess.PIPE).stdout


def published_feeds(repository, candidate_version=None):
    raw = gh("api", f"repos/{repository}/releases?per_page=100", "--paginate", "--slurp")
    releases = [release for page in json.loads(raw) for release in page if not release["draft"]]
    if candidate_version is not None:
        if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", candidate_version):
            raise ValueError("rollback must use a stable semantic version")
        candidate = tuple(map(int, candidate_version.split(".")))
        stable = [tuple(map(int, release["tag_name"][1:].split(".")))
                  for release in releases if not release["prerelease"]
                  and re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", release["tag_name"])]
        if stable and candidate <= max(stable):
            raise ValueError("rollback version must exceed every published stable version")
    assets = [asset for release in releases for asset in release["assets"]
              if asset["name"] in ("appcast-arm64.xml", "appcast-x86_64.xml", "quosparr-appcast-arm64.xml", "quosparr-appcast-x86_64.xml")]
    return [gh("api", asset["url"], "-H", "Accept: application/octet-stream") for asset in assets]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="mygo.json")
    parser.add_argument("--repository", default="Licoy/Quosparr")
    parser.add_argument("--require-new-version", action="store_true", help="also exceed all published stable product versions for rollback")
    parser.add_argument("--appcasts", nargs="+", help="explicit offline fixtures, never an automatic fallback")
    args = parser.parse_args()
    if args.require_new_version and args.appcasts:
        parser.error("rollback version history cannot be verified from quosparr-appcast-only fixtures")
    config = json.loads(pathlib.Path(args.config).read_text())
    candidate = str(config["macos"]["infoPlist"]["CFBundleVersion"])
    feeds = ([pathlib.Path(file).read_bytes() for file in args.appcasts]
             if args.appcasts else published_feeds(args.repository, config["version"] if args.require_new_version else None))
    maximum = check(candidate, feeds)
    print(f"Build {candidate} exceeds published maximum {'.'.join(map(str, maximum))}")


if __name__ == "__main__":
    main()
