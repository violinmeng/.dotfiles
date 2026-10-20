#!/usr/bin/env python3
"""Restore an external .ssh backup. Preview by default; never print key contents."""
import argparse
import datetime
import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile

REPOSITORY = Path(__file__).resolve().parents[1]


def restore_ssh(source, target, apply=False):
    source = Path(source).expanduser().resolve(strict=True)
    target = Path(target).expanduser().absolute()
    if not source.is_dir() or not target.is_dir() or target.is_symlink():
        raise ValueError('Use an SSH backup directory and an existing real target home')
    target = target.resolve()
    destination = target / '.ssh'
    if source.is_relative_to(REPOSITORY) or destination.is_relative_to(REPOSITORY):
        raise ValueError('SSH backups and restored keys must stay outside the dotfiles repository')
    if source == destination or source in destination.parents or destination in source.parents:
        raise ValueError('SSH backup and destination must be separate directories')
    files = []
    directories = {destination}

    def fail_on_unreadable_directory(error):
        raise error

    for parent, children, names in os.walk(source, followlinks=False,
                                           onerror=fail_on_unreadable_directory):
        for name in children + names:
            path = Path(parent) / name
            if path.is_symlink():
                raise ValueError(f'SSH backup contains a symlink; export regular files first: {path}')
            relative = path.relative_to(source)
            if path.is_dir():
                directories.add(destination / relative)
            elif path.is_file():
                files.append((relative, path))
            else:
                print(f'SKIP SSH runtime entry: {relative}')
    if not files:
        raise ValueError('The SSH backup contains no regular files')
    for path in directories | {destination / relative for relative, _ in files}:
        for parent in (path, *path.parents):
            if parent == target:
                break
            if parent.is_symlink():
                raise ValueError(f'SSH destination must not contain symlinks: {parent}')
        if path.exists() and (path in directories) != path.is_dir():
            raise ValueError(f'SSH destination has a conflicting file type: {path}')
        if os.path.lexists(path) and not path.is_dir() and not path.is_file():
            raise ValueError(f'SSH destination is not a regular file: {path}')
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    backup = target / '.local/state/dotfiles/backups' / stamp / 'ssh'
    for parent in backup.parents:
        if parent == target:
            break
        if parent.is_symlink():
            raise ValueError(f'SSH backup destination must not contain symlinks: {parent}')
    changed, modes = [], {}
    restored = 0
    try:
        for directory in sorted(directories, key=lambda p: len(p.parts)):
            if apply:
                if directory.exists():
                    modes[directory] = stat.S_IMODE(directory.stat().st_mode)
                directory.mkdir(parents=True, exist_ok=True, mode=0o700)
                directory.chmod(0o700)
        for relative, path in sorted(files):
            output = destination / relative
            mode = 0o644 if path.name.endswith('.pub') or path.name == 'known_hosts' else 0o600
            identical = output.is_file() and output.read_bytes() == path.read_bytes()
            if not identical:
                print(f'RESTORE SSH: {relative}' + (' (back up existing file)' if output.exists() else ''))
                if apply:
                    saved = None
                    if output.exists():
                        backup.mkdir(parents=True, exist_ok=True, mode=0o700)
                        saved = backup / relative
                        saved.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                        output.rename(saved)
                    changed.append((output, saved))
                    with tempfile.TemporaryDirectory(prefix='.dotfiles-ssh-', dir=output.parent) as directory:
                        temporary = Path(directory) / 'key'
                        shutil.copyfile(path, temporary)
                        temporary.chmod(mode)
                        os.replace(temporary, output)
                    restored += 1
            elif apply and stat.S_IMODE(output.stat().st_mode) != mode:
                modes[output] = stat.S_IMODE(output.stat().st_mode)
                output.chmod(mode)
    except (OSError, ValueError):
        for output, saved in reversed(changed):
            if output.is_file():
                output.unlink()
            if saved:
                saved.rename(output)
        for path, mode in modes.items():
            if path.exists():
                path.chmod(mode)
        raise
    if apply:
        print(f'SSH: restored {restored} files. Directory mode 0700; private/config files 0600. '
              f'Conflicts, if any: {backup}')
    else:
        print(f'SSH preview: {len(files)} regular files; destination {destination}. '
              'Add --apply to restore keys and permissions.')
    return restored


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='backup .ssh directory outside this repository')
    parser.add_argument('--target', type=Path, default=Path.home(), help='target home, defaults to your home')
    parser.add_argument('--apply', action='store_true', help='restore keys and permissions')
    args = parser.parse_args()
    restore_ssh(args.source, args.target, args.apply)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
