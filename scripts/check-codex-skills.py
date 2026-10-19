#!/usr/bin/env python3
"""Check shared skill discovery through Codex's real app-server (no model requests)."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True


def list_skills(cwd, codex_home=None):
    environment = dict(os.environ)
    if codex_home is not None:
        environment['CODEX_HOME'] = str(codex_home)
    with subprocess.Popen(['codex', 'app-server', '--stdio'], cwd=cwd, env=environment,
                          stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                          stderr=subprocess.DEVNULL) as process:
        def send(message):
            process.stdin.write((json.dumps(message) + '\n').encode())
            process.stdin.flush()

        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ)
        pending = b''
        send({'id': 1, 'method': 'initialize', 'params': {
            'clientInfo': {'name': 'dotfiles_skill_check', 'version': '1.0'}}})
        try:
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                if not selector.select(min(1, max(0, deadline - time.monotonic()))):
                    continue
                chunk = os.read(process.stdout.fileno(), 65536)
                if not chunk:
                    raise RuntimeError('Codex app-server exited before replying')
                pending += chunk
                while b'\n' in pending:
                    line, pending = pending.split(b'\n', 1)
                    message = json.loads(line)
                    if message.get('id') not in (1, 2):
                        continue
                    if 'error' in message:
                        raise RuntimeError('Codex rejected the skill-discovery request')
                    if message['id'] == 1:
                        send({'method': 'initialized'})
                        send({'id': 2, 'method': 'skills/list', 'params': {
                            'cwds': [str(cwd)], 'forceReload': True}})
                    else:
                        return message['result']['data']
            raise TimeoutError('Codex skills/list timed out')
        finally:
            selector.close()
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def verify(cwd, skills_root, expected, codex_home=None):
    results = list_skills(cwd, codex_home)
    found = {Path(skill['path']): skill for result in results for skill in result['skills']}
    missing = [name for name in expected
               if not found.get(skills_root / name / 'SKILL.md', {}).get('enabled', True)
               or skills_root / name / 'SKILL.md' not in found]
    assert not missing, 'Codex cannot discover deployed global skills: ' + ', '.join(missing)
    print(f'PASS: Codex discovers all {len(expected)} deployed shared skills from {cwd}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cwd', type=Path, help='Also check the real global skills from this working directory')
    args = parser.parse_args()
    if not shutil.which('codex'):
        parser.error('Install Codex CLI to run this integration check')
    spec = importlib.util.spec_from_file_location('installer', ROOT / 'install.py')
    installer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(installer)
    expected = sorted(p.parent.name for p in (ROOT / 'shared/agents/skills').glob('*/SKILL.md'))
    with tempfile.TemporaryDirectory(prefix='dotfiles-codex-skills-') as directory:
        target = Path(directory).resolve()
        (target / '.git').mkdir()
        home = target / 'codex-home'
        home.mkdir()
        files = installer.files_for(['agents'], 'macos' if sys.platform == 'darwin' else 'omarchy')
        installer.deploy(files, target, True)
        verify(target, target / '.agents/skills', expected, home)
    if args.cwd:
        verify(args.cwd.resolve(), Path.home() / '.agents/skills', expected)


if __name__ == '__main__':
    main()
