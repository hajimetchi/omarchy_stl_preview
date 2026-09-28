#!/usr/bin/env python3
"""Count generated STL thumbnail cache entries from the user session."""
import ctypes
import fcntl
import json
import os
import select
import struct
import sys
import tempfile
import time
from pathlib import Path
from urllib.parse import unquote, urlsplit


def paths():
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    cache_home = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    stats_dir = data_home / "stl-preview"
    cache_dirs = [cache_home / "thumbnails" / size for size in ("normal", "large", "x-large", "xx-large")]
    return stats_dir, stats_dir / "thumbnail-count.json", stats_dir / "thumbnail-count.lock", cache_dirs


def source_uri(png_path):
    try:
        with png_path.open("rb") as image:
            if image.read(8) != b"\x89PNG\r\n\x1a\n":
                return None
            while True:
                header = image.read(8)
                if len(header) != 8:
                    return None
                length, kind = struct.unpack(">I4s", header)
                if length > 1024 * 1024:
                    return None
                chunk = image.read(length)
                if len(chunk) != length or len(image.read(4)) != 4:
                    return None
                if kind == b"tEXt":
                    key, sep, value = chunk.partition(b"\0")
                    if sep and key == b"Thumb::URI":
                        return value.decode("utf-8", errors="replace")
                if kind == b"IEND":
                    return None
    except OSError:
        return None


def is_stl_uri(uri):
    return bool(uri) and unquote(urlsplit(uri).path).lower().endswith(".stl")


def read_state(stats_path):
    try:
        state = json.loads(stats_path.read_text(encoding="utf-8"))
        if not isinstance(state, dict):
            raise ValueError("invalid thumbnail statistics")
        count = state.get("count", 0)
        if not isinstance(count, int) or isinstance(count, bool) or count < 0:
            raise ValueError("invalid thumbnail count")
        return {"count": count, "needs_migration": "seen" in state}
    except FileNotFoundError:
        return None


def write_state(stats_path, state):
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", dir=stats_path.parent, delete=False
    ) as temp:
        json.dump({"count": state["count"]}, temp, separators=(",", ":"))
        temp.write("\n")
        temp.flush()
        os.fsync(temp.fileno())
        temp_path = temp.name
    os.replace(temp_path, stats_path)


def initialize():
    stats_dir, stats_path, lock_path, _ = paths()
    stats_dir.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            state = read_state(stats_path)
            if state is None:
                write_state(stats_path, {"count": 0})
            elif state["needs_migration"]:
                write_state(stats_path, state)
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def record_uri(uri):
    if not is_stl_uri(uri):
        return True
    _, stats_path, lock_path, _ = paths()
    try:
        with lock_path.open("a+") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            try:
                state = read_state(stats_path)
                if state is None:
                    return False
                state["count"] += 1
                write_state(stats_path, state)
            finally:
                fcntl.flock(lock, fcntl.LOCK_UN)
    except (OSError, ValueError, TypeError) as error:
        print(f"stl-preview counter: {error}", file=sys.stderr)
    return True


def cache_snapshot(cache_dir):
    snapshot = {}
    try:
        for png_path in cache_dir.glob("*.png"):
            try:
                stat = png_path.stat()
                snapshot[png_path] = (stat.st_mtime_ns, stat.st_size)
            except OSError:
                continue
    except OSError:
        pass
    return snapshot


def poll_cache_dirs(stats_path, cache_dirs):
    # Establish a baseline so existing cache files are not counted as new
    # generation events when the watcher starts or inotify is unavailable.
    previous = {cache_dir: cache_snapshot(cache_dir) for cache_dir in cache_dirs}
    while stats_path.is_file():
        time.sleep(10)
        for cache_dir in cache_dirs:
            current = cache_snapshot(cache_dir)
            for png_path, stamp in current.items():
                if previous[cache_dir].get(png_path) != stamp:
                    record_uri(source_uri(png_path))
            previous[cache_dir] = current


def read_count():
    _, stats_path, _, _ = paths()
    try:
        # Migrate older files by retaining their count and dropping the
        # unbounded per-file hash list from disk.
        initialize()
        state = read_state(stats_path)
        print(state["count"] if state else 0)
    except (OSError, ValueError, TypeError):
        print(0)


def watch():
    _, stats_path, _, cache_dirs = paths()
    if not stats_path.is_file():
        return
    for cache_dir in cache_dirs:
        cache_dir.mkdir(parents=True, exist_ok=True)

    libc = ctypes.CDLL(None, use_errno=True)
    init = getattr(libc, "inotify_init1", None)
    add_watch = getattr(libc, "inotify_add_watch", None)
    if init is None or add_watch is None:
        poll_cache_dirs(stats_path, cache_dirs)
        return

    fd = init(os.O_NONBLOCK | getattr(os, "O_CLOEXEC", 0))
    if fd < 0:
        poll_cache_dirs(stats_path, cache_dirs)
        return

    mask = 0x00000008 | 0x00000080  # IN_CLOSE_WRITE | IN_MOVED_TO
    watched = {}
    for cache_dir in cache_dirs:
        wd = add_watch(fd, os.fsencode(cache_dir), mask)
        if wd >= 0:
            watched[wd] = cache_dir
    if not watched:
        os.close(fd)
        poll_cache_dirs(stats_path, cache_dirs)
        return

    try:
        while stats_path.is_file():
            ready, _, _ = select.select([fd], [], [], 2)
            if not ready:
                continue
            try:
                events = os.read(fd, 65536)
            except BlockingIOError:
                continue
            offset = 0
            while offset + 16 <= len(events):
                wd, event_mask, _, name_len = struct.unpack_from("iIII", events, offset)
                offset += 16
                name = events[offset:offset + name_len].split(b"\0", 1)[0]
                offset += name_len
                cache_dir = watched.get(wd)
                if cache_dir and event_mask & mask and name.lower().endswith(b".png"):
                    png_path = cache_dir / os.fsdecode(name)
                    uri = source_uri(png_path)
                    if uri is None and event_mask & 0x00000080:
                        # Retry briefly if the moved PNG is not visible yet.
                        for _ in range(4):
                            time.sleep(0.05)
                            uri = source_uri(png_path)
                            if uri is not None:
                                break
                    if uri is not None:
                        record_uri(uri)
    finally:
        os.close(fd)


if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "--watch"
    if action == "--initialize":
        initialize()
    elif action == "--read":
        read_count()
    elif action == "--watch":
        watch()
    else:
        raise SystemExit(f"unknown action: {action}")
