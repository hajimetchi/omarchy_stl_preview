#!/usr/bin/env bash
set -euo pipefail

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
thumbnailer_bin="/usr/local/bin/stl-thumbnailer"
ownership_record="/var/lib/stl-preview/stl-thumbnailer.sha256"

# Both files are installed for read access by all users, so status checks are
# unprivileged and never prompt for a password.
if ! test -f "$thumbnailer_bin" || ! test -f "$ownership_record"; then
  printf 'not-installed\n'
  exit 1
fi
installed_hash="$(sha256sum "$thumbnailer_bin" | awk '{print $1}')" || {
  printf 'not-installed\n'
  exit 1
}
recorded_hash="$(cat "$ownership_record")" || {
  printf 'not-installed\n'
  exit 1
}
if [[ "$installed_hash" != "$recorded_hash" ]]; then
  printf 'not-installed\n'
  exit 1
fi

if python3 - "$data_home" "$config_home" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

data, config = map(Path, sys.argv[1:])
record = data / "stl-preview/ownership.json"
if not record.is_file():
    raise SystemExit(1)

try:
    state = json.loads(record.read_text())
    files = state["files"]
    expected_files = [
        data / "thumbnailers/stl-preview.thumbnailer",
        data / "mime/packages/stl-preview.xml",
    ]
    for path in expected_files:
        expected = files.get(str(path))
        if not expected or not path.is_file():
            raise SystemExit(1)
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise SystemExit(1)

    css = config / "gtk-4.0/gtk.css"
    start = "/* BEGIN stl_preview Nautilus transparent thumbnails */"
    end = "/* END stl_preview Nautilus transparent thumbnails */"
    expected_block = state.get("css_block")
    if not expected_block or not css.is_file():
        raise SystemExit(1)
    text = css.read_text()
    if start not in text or end not in text:
        raise SystemExit(1)
    block = start + text.split(start, 1)[1].split(end, 1)[0] + end
    if hashlib.sha256(block.encode()).hexdigest() != expected_block:
        raise SystemExit(1)
    installed_at = state.get("installed_at", "")
    print("installed|" + installed_at)
except (OSError, ValueError, KeyError, TypeError):
    raise SystemExit(1)
PY
then
  :
else
  printf 'not-installed\n'
  exit 1
fi
