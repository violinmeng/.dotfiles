#!/usr/bin/env python3
"""Exercise ZIP setup and SSH recovery in disposable homes, with no downloads."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import socket
import stat
import subprocess
import sys
import tempfile
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
tempfile.tempdir = str(Path(tempfile.gettempdir()).resolve())
spec = importlib.util.spec_from_file_location('setup_installer', ROOT / 'install.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


def run(*args, **kwargs):
    result = subprocess.run(args, text=True, capture_output=True, **kwargs)
    assert result.returncode == 0, result.stdout + result.stderr
    return result


with tempfile.TemporaryDirectory(prefix='dotfiles-zip-') as directory:
    base = Path(directory)
    archive = base / 'dotfiles.zip'
    sources = json.loads((ROOT / 'install-manifest.json').read_text())['files']
    support = ['install.py', 'install-manifest.json', 'scripts/restore_ssh.py',
               'scripts/check-nvim-plugins.lua', 'scripts/install-pi-packages.mjs']
    with zipfile.ZipFile(archive, 'w') as output:
        for name in sources + support:
            output.write(ROOT / name, 'dotfiles/' + name)
    with zipfile.ZipFile(archive) as source:
        source.extractall(base)
    extracted = base / 'dotfiles'
    assert not (extracted / '.git').exists()
    # Added local data must never become managed configuration in archive mode.
    (extracted / 'shared/pi/auth.json').write_text('{"fixture":"do not deploy"}')
    (extracted / 'shared/zsh/zshrc.local.sh').write_text('private fixture')
    (extracted / 'shared/pi/generated-private.txt').write_text('private fixture')
    home = base / 'home'
    home.mkdir()
    environment = {**os.environ, 'HOME': str(home)}
    result = run(sys.executable, str(extracted / 'install.py'), '--platform', 'omarchy',
                 '--setup', '--dry-run', env=environment, cwd=base)
    for expected in ['.config/hypr/bindings.lua', '.config/foot/foot.ini',
                     'mise install --yes', 'npm install', 'fuse2', 'satty',
                     'install-arch.sh', 'WeChatLinux_', '11 pinned Pi packages']:
        assert expected in result.stdout, expected
    assert not list(home.iterdir()), 'Setup preview changed the target home'
    # Exercise the actual archive CLI with Linux file routing on the Mac host.
    launcher = 'import runpy,sys; sys.platform="linux"; runpy.run_path(sys.argv.pop(1),run_name="__main__")'
    arguments = [sys.executable, '-c', launcher, str(extracted / 'install.py'),
                 '--platform', 'omarchy', '--apply', '--packages', 'agents,zsh,mise,pi']
    run(*arguments, env=environment, cwd=base)
    assert (home / '.zshrc').resolve() == extracted / 'shared/zsh/zshrc'
    assert (home / '.config/mise/config.toml').resolve() == extracted / 'linux/mise/config.toml'
    assert not (home / '.pi/agent/auth.json').exists()
    assert not (home / '.pi/agent/generated-private.txt').exists()
    assert not (home / '.zshrc.local.sh').exists()
    assert (home / '.agents/skills/show-me/SKILL.md').is_file()
    result = run(*arguments, env=environment, cwd=base)
    assert 'Applied 0 files' in result.stdout
    # A broken ZIP must fail instead of reporting a partial deployment as done.
    (extracted / 'shared/zsh/zshenv').unlink()
    result = subprocess.run(arguments, env=environment, cwd=base, text=True, capture_output=True)
    assert result.returncode and 'missing a managed source' in result.stderr
print('PASS: GitHub ZIP preview, real deployment, repeat run, credential exclusion, missing-source refusal')

with tempfile.TemporaryDirectory(prefix='dotfiles-setup-') as directory:
    base = Path(directory)
    home, keys = base / 'home', base / 'ssh-backup'
    (home / '.config/hypr').mkdir(parents=True)
    (home / '.config/hypr/hyprland.lua').write_text('-- factory configuration\n')
    keys.mkdir()
    (keys / 'id_ed25519').write_text('encrypted-key-fixture\n')
    events = []

    def record_command(arguments, apply, **kwargs):
        if apply:
            events.append(arguments[:2])

    arguments = ['install.py', '--setup', '--apply', '--restore-ssh', str(keys)]
    with patch.object(sys, 'argv', arguments), patch.object(sys, 'platform', 'linux'), \
         patch.object(os, 'geteuid', return_value=1000), patch.object(Path, 'home', return_value=home), \
         patch.object(installer, 'install_system_packages') as packages, \
         patch.object(installer, 'install_omarchy_apps') as apps, \
         patch.object(installer, 'install_pi_agent') as pi, \
         patch.object(installer, 'install_plugins'), \
         patch.object(installer, 'install_editor_plugins', side_effect=lambda p, a: events.append(['editor']) if a else None), \
         patch.object(installer, 'install_pi_plugins'), \
         patch.object(installer, 'validate_omarchy_setup') as desktop, \
         patch.object(installer, 'command', side_effect=record_command), \
         patch.object(installer.shutil, 'which', return_value='/usr/bin/tool'), patch.dict(os.environ):
        for _ in range(2):
            assert installer.main() == 0
        selected, system, apply = packages.call_args.args
        assert {'pi', 'zed', 'mise', 'kvim', 'agents'} <= set(selected)
        assert system == 'omarchy' and apply and packages.call_args.kwargs['setup']
        apps.assert_called_with(True)
        pi.assert_called_with(True)
        desktop.assert_called_with(True)
    assert (home / '.config/foot/foot.ini').resolve() == ROOT / 'linux/foot/foot.ini'
    assert (home / '.config/hypr/bindings.lua').resolve() == ROOT / 'linux/hypr/bindings.lua'
    assert (home / '.config/hypr/hyprland.lua').read_text() == '-- factory configuration\n'
    assert (home / '.ssh/id_ed25519').read_bytes() == (keys / 'id_ed25519').read_bytes()
    assert events.index(['mise', 'install']) < events.index(['editor'])
    assert not any(event[0] in ('gh', 'chsh', 'ssh-add') for event in events)
print('PASS: complete setup routing, actual desktop deployment and SSH restore, retry, runtimes before plugins, deferred login')

with patch.object(installer, 'download_installer') as download, \
     patch.object(installer, 'install_wechat') as wechat, \
     patch.object(installer.shutil, 'which', return_value='/usr/bin/zed'), \
     patch.object(Path, 'is_file', return_value=False), \
     patch.object(installer.subprocess, 'run') as process:
    installer.install_omarchy_apps(False)
    process.assert_not_called()
    assert download.call_args_list[0].args == (
        'https://persistent.oaistatic.com/codex-app-prod/linux/install-arch.sh', ['sudo', '/bin/bash'], False)
    assert download.call_args_list[1].args == ('https://zed.dev/install.sh', '/bin/sh', False)
    wechat.assert_called_once_with(False)
with patch.object(installer, 'download_installer') as download, \
     patch.object(installer, 'install_wechat'), \
     patch.object(installer.shutil, 'which', return_value='/usr/bin/zed'), \
     patch.object(installer.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)):
    installer.install_omarchy_apps(True)
    download.assert_not_called()
print('PASS: official ChatGPT/Zed installers, preview without execution, already-installed apps preserved')

with patch.object(installer, 'command') as execute, \
     patch.object(installer.shutil, 'which', side_effect=lambda name: None if name == 'codex' else '/usr/bin/' + name):
    try:
        installer.validate_omarchy_setup(True)
    except ValueError as error:
        assert 'codex' in str(error)
    else:
        raise AssertionError('Setup reported success with a missing Codex executable')
    execute.assert_not_called()
print('PASS: final setup verification refuses incomplete software installation')


def elf(machine):
    return b'\x7fELF\x02\x01' + b'\x00' * 12 + machine.to_bytes(2, 'little')


for architecture, machine, suffix in [('aarch64', 183, 'arm64'), ('x86_64', 62, 'x86_64')]:
    with tempfile.TemporaryDirectory(prefix='dotfiles-wechat-') as directory:
        home = Path(directory) / 'home with spaces'
        home.mkdir()
        calls = []

        def download(arguments, apply, **kwargs):
            calls.append(arguments)
            Path(arguments[-1]).write_bytes(elf(machine))

        with patch.object(Path, 'home', return_value=home), \
             patch.object(installer.platform, 'machine', return_value=architecture), \
             patch.object(installer, 'command', side_effect=download), \
             patch.object(installer.shutil, 'which', return_value=None):
            installer.install_wechat(False)
            assert not list(home.iterdir())
            installer.install_wechat(True)
            installer.install_wechat(True)
        assert len(calls) == 1 and calls[0][-3].endswith(f'WeChatLinux_{suffix}.AppImage')
        app = home / 'Applications/WeChat.AppImage'
        assert os.access(app, os.X_OK)
        entry = (home / '.local/share/applications/wechat-appimage.desktop').read_text()
        assert f'Exec="{app}" %U' in entry and '~/' not in entry
        assert not list(app.parent.glob('.dotfiles-wechat-*'))
with tempfile.TemporaryDirectory(prefix='dotfiles-wechat-fail-') as directory:
    home = Path(directory)

    def failed_download(arguments, apply, **kwargs):
        Path(arguments[-1]).write_bytes(b'partial')
        raise subprocess.CalledProcessError(1, arguments)

    with patch.object(Path, 'home', return_value=home), \
         patch.object(installer.platform, 'machine', return_value='aarch64'), \
         patch.object(installer, 'command', side_effect=failed_download):
        try:
            installer.install_wechat(True)
        except subprocess.CalledProcessError:
            pass
        else:
            raise AssertionError('Download failure was ignored')
    assert not (home / 'Applications/WeChat.AppImage').exists()
    assert not list((home / 'Applications').iterdir())
print('PASS: WeChat ARM64/x86_64 selection, executable and launcher, spaces, retry, interrupted-download cleanup')

with tempfile.TemporaryDirectory(prefix='ssh-') as directory:
    base = Path(directory)
    source, home = base / 'backup', base / 'home'
    (source / 'config.d').mkdir(parents=True)
    home.mkdir()
    (source / 'id_ed25519').write_text('encrypted-key-fixture\n')
    (source / 'id_ed25519.pub').write_text('public-key-fixture\n')
    (source / 'config.d/work').write_text('Host fixture\n')
    with socket.socket(socket.AF_UNIX) as agent:
        agent.bind(str(source / 's'))
        installer.restore_ssh(source, home, False)
        assert not list(home.iterdir())
        (home / '.ssh').mkdir(mode=0o755)
        (home / '.ssh/id_ed25519').write_text('old-key-fixture\n')
        (home / '.ssh/unrelated').write_text('keep this key\n')
        assert installer.restore_ssh(source, home, True) == 3
        assert installer.restore_ssh(source, home, True) == 0
    assert not (home / '.ssh/s').exists()
    assert (home / '.ssh/unrelated').read_text() == 'keep this key\n'
    for relative, mode in [('id_ed25519', 0o600), ('id_ed25519.pub', 0o644), ('config.d/work', 0o600)]:
        output = home / '.ssh' / relative
        assert output.read_bytes() == (source / relative).read_bytes()
        assert stat.S_IMODE(output.stat().st_mode) == mode
    assert stat.S_IMODE((home / '.ssh').stat().st_mode) == 0o700
    assert stat.S_IMODE((home / '.ssh/config.d').stat().st_mode) == 0o700
    backups = list((home / '.local/state/dotfiles/backups').glob('*/ssh/id_ed25519'))
    assert len(backups) == 1 and backups[0].read_text() == 'old-key-fixture\n'
    assert stat.S_IMODE(backups[0].parent.stat().st_mode) == 0o700
    (source / 'escape').symlink_to(base)
    try:
        installer.restore_ssh(source, home, True)
    except ValueError:
        pass
    else:
        raise AssertionError('SSH backup symlink was accepted')
    (source / 'escape').unlink()
    (home / '.ssh/id_ed25519').write_text('restore-on-failure\n')
    with patch.object(shutil, 'copyfile', side_effect=OSError('simulated failure')):
        try:
            installer.restore_ssh(source, home, True)
        except OSError:
            pass
        else:
            raise AssertionError('SSH copy failure was ignored')
    assert (home / '.ssh/id_ed25519').read_text() == 'restore-on-failure\n'
print('PASS: SSH preview, byte-for-byte restore, private permissions, conflicts, unrelated keys, sockets, symlinks, rollback')
print('Omarchy setup checks passed. No packages were installed or account logins started.')
