"""Resolve development inputs/outputs in the external UBERSHRIKE media library."""
from pathlib import Path
import json
import os

PROJECT = Path(__file__).resolve().parents[1]
LIBRARY = Path(os.environ.get("UBERSHRIKE_MEDIA_ROOT", PROJECT.parents[2])).resolve()
RULES = json.loads(Path(__file__).with_suffix(".json").read_text(encoding="utf-8"))


def media_path(logical_path: str) -> Path:
    matches = [prefix for prefix in RULES if logical_path == prefix or logical_path.startswith(prefix + "/")]
    if not matches:
        raise ValueError(f"No external media destination for {logical_path}")
    prefix = max(matches, key=len)
    output = (LIBRARY / (RULES[prefix] + logical_path[len(prefix):])).resolve()
    if not output.is_relative_to(LIBRARY) or output.is_relative_to(PROJECT):
        raise ValueError(f"Media destination must be outside the game project: {output}")
    (output if not output.suffix else output.parent).mkdir(parents=True, exist_ok=True)
    return output
