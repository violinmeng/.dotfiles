#!/usr/bin/env python3
"""One-time source-layout migration; preview by default, preserve existing links."""
import argparse
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOVES = json.loads((ROOT / 'scripts/layout-moves.json').read_text())


def relocated(path):
    for old, new in MOVES.items():
        if path == Path(old) or Path(old) in path.parents:
            return Path(new) / path.relative_to(old)
    return None


def existing_links(home):
    # Never traverse symlinked directories or caches/plugin checkouts.
    roots = ['.config', '.pi', '.zsh-custom', '.vim', '.emacs.d']
    candidates = [p for p in home.iterdir() if p.is_symlink()]
    for name in roots:
        root = home / name
        if root.is_symlink() or not root.is_dir():
            continue
        for parent, dirs, files in os.walk(root, followlinks=False):
            candidates.extend(Path(parent) / name for name in dirs + files
                              if (Path(parent) / name).is_symlink())
            dirs[:] = [name for name in dirs if name not in
                       ('node_modules', 'npm', 'git', 'sessions', '.git')
                       and not (Path(parent) / name).is_symlink()]
    return sorted(set(candidates))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--home', type=Path, default=Path.home())
    args = parser.parse_args()
    # The old mise package contains a relative link to the root mise.toml;
    # move the actual declaration, not that link with its obsolete relative path.
    moves = [(ROOT / old, ROOT / new) for old, new in MOVES.items()
             if (ROOT / old).exists() and not (ROOT / old).is_symlink()]
    for old, new in moves:
        if new.exists():
            raise ValueError(f'Destination already exists: {new}')
    links = []
    for link in existing_links(args.home):
        original = os.readlink(link)
        target = Path(os.path.abspath(link.parent / original))
        if not target.is_relative_to(ROOT):
            continue
        replacement = relocated(target.relative_to(ROOT))
        if replacement is not None:
            links.append((link, original, ROOT / replacement))
    for old, new in moves:
        print(f'MOVE {old.relative_to(ROOT)} -> {new.relative_to(ROOT)}')
    for link, _, new in links:
        print(f'RELINK {link} -> {new}')
    if not args.apply:
        return
    completed, relinked = [], []
    pending = None
    try:
        for old, new in moves:
            new.parent.mkdir(parents=True, exist_ok=True)
            old.rename(new)
            completed.append((old, new))
        for link, original, new in links:
            if not new.exists():
                raise ValueError(f'Relocated target is missing: {new}')
            temporary = link.with_name(link.name + '.layout-migration')
            temporary.symlink_to(new)
            pending = temporary
            os.replace(temporary, link)
            pending = None
            relinked.append((link, original))
    except (OSError, ValueError):
        if pending is not None:
            pending.unlink()
        for link, original in reversed(relinked):
            link.unlink()
            link.symlink_to(original)
        for old, new in reversed(completed):
            old.parent.mkdir(parents=True, exist_ok=True)
            new.rename(old)
        raise
    print(f'Moved {len(completed)} sources; repaired {len(relinked)} existing links.')


if __name__ == '__main__':
    main()
