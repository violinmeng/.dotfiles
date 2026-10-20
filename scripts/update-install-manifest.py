#!/usr/bin/env python3
"""Update or check the source allowlist shipped in GitHub ZIP downloads."""
import argparse
import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('dotfiles_installer', ROOT / 'install.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='fail if the checked-in manifest needs updating')
    args = parser.parse_args()
    if not (ROOT / '.git').exists():
        parser.error('Regenerate the manifest in a Git checkout, before publishing the download')
    manifest = {'version': 1, 'files': [name for name in installer.source_names()
                                     if Path(name).name not in ('.gitignore', '.DS_Store')
                                     and (ROOT / name).is_file()]}
    content = json.dumps(manifest, indent=2) + '\n'
    output = ROOT / 'install-manifest.json'
    if args.check:
        if not output.is_file() or output.read_text() != content:
            print('Run python3 scripts/update-install-manifest.py after changing managed sources.', file=sys.stderr)
            return 1
        print('Archive source manifest is current.')
    else:
        output.write_text(content)
        print(f'Wrote {len(manifest["files"])} managed source paths to {output.name}.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
