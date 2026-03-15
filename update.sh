#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION_FILE="$ROOT/version.json"

python3 - "$VERSION_FILE" "${1:-}" <<'PY'
import base64
import json
import sys
import urllib.request
from pathlib import Path

version_file = Path(sys.argv[1])
mode = sys.argv[2] if len(sys.argv) > 2 else ""


def parse_semver(raw_version: str) -> tuple[int, int, int]:
    major, minor, patch = raw_version.split(".")
    return int(major), int(minor), int(patch)


def attr_name_for(version: str) -> str:
    return f"nodejs_v{version.replace('.', '_')}"


def sri_from_hex(sha256_hex: str) -> str:
    return "sha256-" + base64.b64encode(bytes.fromhex(sha256_hex)).decode("ascii")


def load_current() -> dict:
    return json.loads(version_file.read_text())


def fetch_json(url: str):
    with urllib.request.urlopen(url) as response:
        return json.load(response)


def fetch_text(url: str) -> str:
    with urllib.request.urlopen(url) as response:
        return response.read().decode("utf-8")


platform_assets = {
    "x86_64-linux": "linux-x64",
    "aarch64-linux": "linux-arm64",
    "x86_64-darwin": "darwin-x64",
    "aarch64-darwin": "darwin-arm64",
}

current = load_current()
index = fetch_json("https://nodejs.org/dist/index.json")
lts_releases = [entry for entry in index if entry.get("lts")]
if not lts_releases:
    raise SystemExit("Failed to discover any LTS releases from nodejs.org/dist/index.json")

latest = max(lts_releases, key=lambda entry: parse_semver(entry["version"].lstrip("v")))
latest_version = latest["version"].lstrip("v")

print(f"Current version: {current['version']}")
print(f"Latest LTS version: {latest_version}")

needs_update = current["version"] != latest_version
print(f"UPDATE_NEEDED={'true' if needs_update else 'false'}")
print(f"NEW_VERSION={latest_version}")

if mode != "--update":
    sys.exit(0)

release_root = f"https://nodejs.org/dist/v{latest_version}"
checksums = {}
for line in fetch_text(f"{release_root}/SHASUMS256.txt").splitlines():
    line = line.strip()
    if not line:
        continue
    parts = line.split()
    if len(parts) != 2:
        continue
    sha256_hex, asset_name = parts
    checksums[asset_name] = sha256_hex

assets = {}
hashes = {}
for system, suffix in platform_assets.items():
    asset_name = f"node-v{latest_version}-{suffix}.tar.xz"
    sha256_hex = checksums.get(asset_name)
    if not sha256_hex:
        raise SystemExit(f"Missing checksum for {asset_name}")
    assets[system] = asset_name
    hashes[system] = sri_from_hex(sha256_hex)

updated = {
    "version": latest_version,
    "lts": latest["lts"],
    "attr": attr_name_for(latest_version),
    "assets": assets,
    "hashes": hashes,
}

version_file.write_text(json.dumps(updated, indent=2) + "\n")
print(f"Updated {version_file.name} to {latest_version}")
PY

