#!/usr/bin/env bash
set -euo pipefail
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
thumbnailer_bin="/usr/local/bin/stl-thumbnailer"
ownership_record="/var/lib/stl-preview/stl-thumbnailer.sha256"
if sudo test -f "$ownership_record" && sudo test -f "$thumbnailer_bin"; then
  installed_hash="$(sudo sha256sum "$thumbnailer_bin" | awk '{print $1}')"
  recorded_hash="$(sudo cat "$ownership_record")"
  if [[ "$installed_hash" == "$recorded_hash" ]]; then
    sudo rm -- "$thumbnailer_bin" "$ownership_record"
  else
    printf 'Leaving %s in place: its contents no longer match this plugin\'s ownership record.\n' "$thumbnailer_bin" >&2
  fi
elif sudo test -f "$ownership_record"; then
  printf 'Leaving stale ownership record at %s because %s is missing.\n' "$ownership_record" "$thumbnailer_bin" >&2
fi
python3 - "$data_home" "$config_home" <<'PY'
import hashlib, json, sys
from pathlib import Path
data, config = map(Path, sys.argv[1:])
record = data / "stl-preview/ownership.json"
if not record.exists():
    print(f"No user ownership record at {record}; leaving user files untouched.")
    raise SystemExit
state = json.loads(record.read_text())
for name, expected in state.get("files", {}).items():
    path = Path(name)
    if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() == expected:
        path.unlink()
    elif path.exists():
        print(f"Leaving changed user file in place: {path}", file=sys.stderr)
css = config / "gtk-4.0/gtk.css"
start, end = "/* BEGIN stl_preview Nautilus transparent thumbnails */", "/* END stl_preview Nautilus transparent thumbnails */"
if css.exists() and state.get("css_block"):
    text = css.read_text()
    if start in text and end in text:
        before, rest = text.split(start, 1)
        body, after = rest.split(end, 1)
        block = start + body + end
        if hashlib.sha256(block.encode()).hexdigest() == state["css_block"]:
            css.write_text((before.rstrip() + "\n" + after.lstrip()).lstrip("\n"))
        else:
            print(f"Leaving edited CSS block in place: {css}", file=sys.stderr)
record.unlink()
try:
    record.parent.rmdir()
except OSError:
    pass
PY
command -v update-mime-database >/dev/null && update-mime-database "$data_home/mime" || true
printf 'Removed STL preview support:\n'
printf '  - Removed unchanged plugin-owned user registrations and style block.\n'
printf '  - Left edited or unowned user files and thumbnail caches untouched.\n'
printf 'Restart Nautilus to apply the changes.\n'
