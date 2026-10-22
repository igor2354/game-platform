"""Fail on missing game media, unlisted media or broken active resource paths.

Run before export. runtime_media.json records reviewed runtime dependencies,
not artistic approval; connected prototype textures are documented separately.
"""
from pathlib import Path
import fnmatch
import json
import os
import re
import sys

PROJECT = Path(__file__).resolve().parents[1]
MEDIA_EXT = {
    ".png", ".jpg", ".jpeg", ".webp", ".svg", ".gif", ".wav", ".ogg", ".mp3",
    ".mp4", ".mov", ".avi", ".blend", ".glb", ".gltf", ".psd", ".pdf", ".zip",
    ".ttf", ".otf", ".tga",
}


def main() -> int:
    expected = set(json.loads((PROJECT / "tools/runtime_media.json").read_text(encoding="utf-8")))
    files = []
    for parent, directories, names in os.walk(PROJECT):
        directories[:] = [d for d in directories if d not in {".git", ".godot", "__pycache__"}]
        files.extend(Path(parent) / name for name in names)
    actual = {p.relative_to(PROJECT).as_posix() for p in files if p.suffix.lower() in MEDIA_EXT}
    errors = [f"Unlisted media (move outside or approve and connect): {p}" for p in sorted(actual - expected)]
    errors += [f"Missing runtime media: {p}" for p in sorted(expected - actual)]

    presets = (PROJECT / "export_presets.cfg").read_text(encoding="utf-8")
    filters = re.findall(r'^exclude_filter="([^"]*)"', presets, re.M)
    for exclude in filters:
        for name in expected:
            if any(fnmatch.fnmatchcase(name, mask) for mask in exclude.split(",") if mask):
                errors.append(f"Export excludes runtime dependency: {name}")

    checked_refs = 0
    for p in files:
        relative = p.relative_to(PROJECT)
        if relative.parts[0] not in {"scripts", "scenes", "resources", "shaders"}:
            continue
        if p.suffix not in {".gd", ".tscn", ".tres", ".gdshader"}:
            continue
        for target in re.findall(r'res://([^"\'\n]+)', p.read_text(encoding="utf-8-sig")):
            if not Path(target).suffix:  # Dynamic resource directory prefix.
                continue
            checked_refs += 1
            if not (PROJECT / target).is_file():
                errors.append(f"Broken resource in {relative.as_posix()}: {target}")

    for p in files:
        if p.suffix != ".gd" or p.relative_to(PROJECT).parts[0] not in {"tools", "tests"}:
            continue
        text = p.read_text(encoding="utf-8-sig")
        if re.search(r'(?:save_png|save_jpg|save_webp)\s*\(\s*"res://', text):
            errors.append(f"Development image output still points inside project: {p.relative_to(PROJECT)}")

    for error in errors:
        print("FAIL", error)
    total = sum((PROJECT / name).stat().st_size for name in actual)
    print(f"Runtime media: {len(actual)} files, {total / 1048576:.2f} MiB; resource paths: {checked_refs}; errors: {len(errors)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
