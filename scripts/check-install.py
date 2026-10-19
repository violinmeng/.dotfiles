#!/usr/bin/env python3
"""Verify the unified installer without changing the user's home or downloading software."""
import ast
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tomllib
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
# macOS exposes /private/var through /var; compare canonical fixture paths.
tempfile.tempdir = str(Path(tempfile.gettempdir()).resolve())


def run(*args, ok=True, **kwargs):
    result = subprocess.run(args, text=True, capture_output=True, **kwargs)
    if ok and result.returncode:
        raise AssertionError(f'{args}: {result.stdout}\n{result.stderr}')
    if not ok and not result.returncode:
        raise AssertionError(f'Unexpected success: {args}')
    return result


for file in [ROOT / 'install.py', Path(__file__)]:
    ast.parse(file.read_text())
for file in [ROOT / 'macos/mise/config.toml', ROOT / 'linux/mise/config.toml']:
    tomllib.loads(file.read_text())
for relative in ('scripts/check-nvim-plugins.lua',
                 'shared/kvim/lua/core/packages.lua',
                 'shared/kvim/lua/plugins/init.lua',
                 'shared/kvim/lua/plugins/lsp.lua',
                 'shared/kvim/lua/plugins/conform.lua',
                 'shared/kvim/lua/plugins/mini.lua'):
    run('lua', '-', str(ROOT / relative), input='assert(loadfile(arg[1]))\n')
zed = (ROOT / 'shared/zed/settings.json').read_text()
assert '/Users/' not in zed and '/opt/homebrew' not in zed
print('PASS: Python, Lua, TOML, and portable Zed paths')

with tempfile.TemporaryDirectory(prefix='dotfiles-linux-') as directory:
    target = Path(directory)
    command = [sys.executable, str(ROOT / 'install.py'), '--target', directory]
    run(*command, '--dry-run')
    assert not list(target.iterdir()), 'Preview changed the target'
    print('PASS: default preview makes no writes')
    original = target / '.tmux.conf'
    original.write_text('personal tmux settings\n')
    local_skill = target / '.agents/skills/personal-local/SKILL.md'
    local_skill.parent.mkdir(parents=True)
    local_skill.write_text('preserve local skill\n')
    run(*command, '--apply')
    assert original.is_symlink()
    assert original.resolve() == ROOT / 'shared/tmux/tmux.conf'
    assert (target / '.zshrc').resolve() == ROOT / 'shared/zsh/zshrc'
    assert (target / '.config/nvim/init.lua').resolve() == ROOT / 'shared/kvim/init.lua'
    assert not (target / '.config/kvim').exists()
    platform_directory = 'macos' if sys.platform == 'darwin' else 'linux'
    assert (target / '.config/mise/config.toml').resolve() == ROOT / platform_directory / 'mise/config.toml'
    skill_manifest = target / '.agents/skills/show-me/SKILL.md'
    assert skill_manifest.is_file() and not skill_manifest.is_symlink()
    assert skill_manifest.read_bytes() == (ROOT / 'shared/agents/skills/show-me/SKILL.md').read_bytes()
    assert (target / '.agents/.skill-lock.json').resolve() == ROOT / 'shared/agents/.skill-lock.json'
    assert local_skill.read_text() == 'preserve local skill\n' and not local_skill.is_symlink()
    backups = list((target / '.local/state/dotfiles/backups').glob('*/.tmux.conf'))
    assert len(backups) == 1 and backups[0].read_text() == 'personal tmux settings\n'
    assert not (target / '.config/hypr').exists()
    assert (target / '.config/alacritty').exists() == (sys.platform == 'darwin')
    assert not (target / '.config/ghostty').exists()
    print('PASS: actual links, original-file backup, desktop exclusions')
    result = run(*command, '--apply')
    assert 'Applied 0 files' in result.stdout
    assert len(list((target / '.local/state/dotfiles/backups').glob('*/.tmux.conf'))) == 1
    print('PASS: repeat application is idempotent')
    run(*command, '--platform', 'omarchy', '--packages', 'aerospace', ok=False)
    assert (target / '.zshrc').is_symlink()
    print('PASS: desktop package selection refused')

with tempfile.TemporaryDirectory(prefix='dotfiles-parent-') as directory:
    target = Path(directory)
    outside = target / 'outside'
    outside.mkdir()
    (target / '.config').symlink_to(outside)
    run(sys.executable, str(ROOT / 'install.py'), '--apply', '--target', directory, ok=False)
    assert not (target / '.zshrc').exists()
    assert not list(outside.iterdir())
    print('PASS: parent-symlink preflight prevents all writes')

spec = importlib.util.spec_from_file_location('linux_installer', ROOT / 'install.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)
assert set(installer.config_mappings('omarchy')) == set(installer.PACKAGES)
assert set(installer.config_mappings('macos')) == installer.MAC_PACKAGES
linux_files = installer.files_for(list(installer.PACKAGES), 'omarchy')
mac_files = installer.files_for(list(installer.MAC_PACKAGES), 'macos')
assert linux_files[Path('.config/mise/config.toml')] == ROOT / 'linux/mise/config.toml'
assert mac_files[Path('.config/mise/config.toml')] == ROOT / 'macos/mise/config.toml'
assert mac_files[Path('.config/alacritty/alacritty.toml')] == ROOT / 'macos/alacritty/alacritty.toml'
assert mac_files[Path('.zshrc')] == linux_files[Path('.zshrc')]
assert 'agents' in installer.LINUX_DEFAULT and 'agents' in installer.MAC_DEFAULT
assert not (ROOT / 'shared/nvim').exists()
for system in ('macos', 'omarchy'):
    mappings = installer.config_mappings(system)
    assert 'nvim' not in mappings
    files = installer.files_for(['kvim'], system)
    assert files[Path('.config/nvim/init.lua')] == ROOT / 'shared/kvim/init.lua'
    assert not any(p.is_relative_to('.config/kvim') for p in files)
assert 'kvim' in installer.LINUX_DEFAULT and 'kvim' in installer.MAC_DEFAULT
assert 'alias knvim="nvim"' in (ROOT / 'shared/zsh/zshrc').read_text()
assert mac_files[Path('.agents/.skill-lock.json')] == linux_files[Path('.agents/.skill-lock.json')]
assert Path('.pi/agent/settings.json') in linux_files
assert Path('.pi/agent/mcp.example.json') not in linux_files
assert mac_files[Path('.pi/agent/mcp.example.json')] == ROOT / 'macos/pi/mcp.example.json'
assert Path('.pi/agent/mcp.json') not in linux_files
assert Path('.pi/agent/mcp-auth.json') not in linux_files
assert not any(path.parts[:2] in (('.config', 'hypr'), ('.config', 'foot')) for path in linux_files)
assert 'shell=/usr/bin/zsh' in (ROOT / 'linux/foot/foot.ini').read_text().splitlines()
assert not any(path.name == '.gitignore' for path in linux_files)
print('PASS: explicit destinations, platform isolation, shared sources, optional desktop exclusion')
for private in ('shared/pi/auth.json', 'shared/pi/mcp.json',
                'shared/pi/mcp-auth.json', 'shared/pi/mcp.log', 'shared/pi/mcp.log.1',
                'shared/pi/npm/package.json',
                'shared/pi/git/private/file', 'shared/pi/sessions/session.jsonl',
                'shared/pi/models-store.json', 'shared/pi/web-search.json',
                'shared/zsh/custom/plugins/local-work/file', 'shared/vim/plugged/plugin/file',
                'shared/emacs/elpa/package/file', 'shared/zed/conversations/chat.json'):
    run('git', 'check-ignore', '--no-index', '-q', private, cwd=ROOT)
print('PASS: relocated ignore rules protect credentials, plugin work, and runtime state')

migration_spec = importlib.util.spec_from_file_location('layout_migration', ROOT / 'scripts/restructure.py')
migration = importlib.util.module_from_spec(migration_spec)
migration_spec.loader.exec_module(migration)
with tempfile.TemporaryDirectory(prefix='dotfiles-layout-') as directory:
    base = Path(directory)
    repo, home = base / 'repo', base / 'home'
    source, moved = repo / 'old/.config/app', repo / 'shared/app'
    source.mkdir(parents=True)
    (source / 'init.lua').write_text('return {}\n')
    (source / 'runtime').mkdir()
    (source / 'runtime/private').write_text('preserve local runtime')
    (home / '.config').mkdir(parents=True)
    (home / '.config/app').symlink_to(source)
    (home / 'unrelated').symlink_to(base / 'outside')
    arguments = ['restructure.py', '--home', str(home)]
    with patch.object(migration, 'ROOT', repo), \
         patch.object(migration, 'MOVES', {'old/.config/app': 'shared/app'}):
        with patch.object(sys, 'argv', arguments):
            migration.main()
        assert source.is_dir() and not moved.exists()
        with patch.object(sys, 'argv', arguments + ['--apply']):
            migration.main()
            migration.main()
        assert (home / '.config/app').resolve() == moved
        assert (moved / 'runtime/private').read_text() == 'preserve local runtime'
        assert os.readlink(home / 'unrelated') == str(base / 'outside')
        # A later clone has only new sources but still repairs old home links.
        (home / '.config/app').unlink()
        (home / '.config/app').symlink_to(source)
        with patch.object(sys, 'argv', arguments + ['--apply']):
            migration.main()
        assert (home / '.config/app').resolve() == moved
        # An interrupted relink restores both source locations and original links.
        moved.rename(source)
        (home / '.config/app').unlink()
        (home / '.config/app').symlink_to(source)
        with patch.object(sys, 'argv', arguments + ['--apply']), \
             patch.object(migration.os, 'replace', side_effect=OSError('relink failed')):
            try:
                migration.main()
            except OSError:
                pass
            else:
                raise AssertionError('Expected relink failure')
        assert source.is_dir() and not moved.exists()
        assert (home / '.config/app').resolve() == source
        assert not list(home.rglob('*.layout-migration'))
print('PASS: layout preview, live link repair, runtime preservation, repeat run, rollback')

with tempfile.TemporaryDirectory(prefix='dotfiles-rollback-') as directory:
    target = Path(directory)
    original = target / '.zshrc'
    original.write_text('keep me\n')
    with patch.object(Path, 'symlink_to', side_effect=OSError('simulated disk failure')):
        try:
            installer.deploy({Path('.zshrc'): ROOT / 'shared/zsh/zshrc'}, target, True)
        except OSError:
            pass
        else:
            raise AssertionError('Expected failure')
    assert not original.is_symlink() and original.read_text() == 'keep me\n'
    print('PASS: link failure restores the original file')

with tempfile.TemporaryDirectory(prefix='dotfiles-skill-manifest-') as directory:
    base = Path(directory)
    target = base / 'home'
    source = base / 'SKILL.md'
    source.write_text('---\nname: fixture\ndescription: Test skill.\n---\n')
    relative = Path('.agents/skills/fixture/SKILL.md')
    destination = target / relative
    destination.parent.mkdir(parents=True)
    destination.symlink_to(source)
    files = {relative: source}
    installer.deploy(files, target, False)
    assert destination.is_symlink(), 'Preview changed the skill manifest'

    def partial_copy(src, dst):
        Path(dst).write_text('partial write')
        raise OSError('simulated copy failure')

    with patch.object(installer.shutil, 'copy2', side_effect=partial_copy):
        try:
            installer.deploy(files, target, True)
        except OSError:
            pass
        else:
            raise AssertionError('Expected copy failure')
    assert destination.is_symlink() and destination.resolve() == source
    installer.deploy(files, target, True)
    assert not destination.is_symlink() and destination.read_bytes() == source.read_bytes()
    before = destination.stat().st_mtime_ns
    installer.deploy(files, target, True)
    assert destination.stat().st_mtime_ns == before, 'Unchanged skill was recopied'
    destination.write_text('preserve local edits')
    installer.deploy(files, target, True)
    saved = list((target / '.local/state/dotfiles/backups').glob('*/' + str(relative)))
    assert any(not p.is_symlink() and p.read_text() == 'preserve local edits' for p in saved)
    assert destination.read_bytes() == source.read_bytes()
    # Failure later in a mixed deployment also rolls back a completed copy.
    destination.write_text('restore this version')
    with patch.object(Path, 'symlink_to', side_effect=OSError('later link failure')):
        try:
            installer.deploy(files | {Path('.other'): source}, target, True)
        except OSError:
            pass
        else:
            raise AssertionError('Expected link failure')
    assert destination.read_text() == 'restore this version' and not destination.is_symlink()
    assert not (target / '.other').exists()
print('PASS: regular skill manifests, preview, symlink migration, copies, backups, rollback, idempotence')
grill_me = (ROOT / 'shared/agents/skills/grill-me/SKILL.md').read_text()
assert '../grilling/SKILL.md' in grill_me and 'Call the Skill tool' not in grill_me
assert (ROOT / 'shared/agents/skills/grill-me/../grilling/SKILL.md').is_file()

specs = installer.plugin_specs(['zsh', 'tmux'])
assert len(specs) == 6
assert ('https://github.com/catppuccin/tmux.git', '.tmux/plugins/tmux', 'v2.1.2') in specs
assert not any('sensible' in url or 'battery' in url for url, _, _ in specs)
assert installer.plugin_specs(['git', 'kvim']) == []
print('PASS: active plugin selection and pinned Catppuccin version')
with tempfile.TemporaryDirectory(prefix='dotfiles-plugin-') as directory:
    base = Path(directory)
    origin = base / 'origin'
    run('git', 'init', str(origin))
    run('git', '-C', str(origin), '-c', 'user.name=Test', '-c',
        'user.email=test@example.invalid', 'commit', '--allow-empty', '-m', 'fixture')
    run('git', '-C', str(origin), 'tag', 'v1')
    target = base / 'home'
    target.mkdir()
    fixture = [(origin.as_uri(), '.tmux/plugins/fixture', 'v1')]
    installer.install_plugins(fixture, target, False)
    assert not list(target.iterdir())
    installer.install_plugins(fixture, target, True)
    checkout = target / '.tmux/plugins/fixture'
    assert (checkout / '.git').is_dir()
    installer.install_plugins(fixture, target, True)
    assert not list(checkout.parent.glob('.dotfiles-clone-*'))
    outside = base / 'outside'
    outside.mkdir()
    (target / 'linked').symlink_to(outside)
    try:
        installer.install_plugins([(origin.as_uri(), 'linked/plugin', None)], target, True)
    except ValueError:
        pass
    else:
        raise AssertionError('Plugin installer wrote through a symlink')
    assert not list(outside.iterdir())
print('PASS: plugin preview, real clone, version pin, repeat run, symlink refusal')

with patch.object(installer.subprocess, 'run') as process:
    installer.install_editor_plugins(['git'], True)
    installer.install_editor_plugins(['kvim'], False)
    process.assert_not_called()
with patch.object(installer.shutil, 'which', return_value='/usr/bin/tool'), \
     patch.object(installer, 'require_tree_sitter_cli') as tree_sitter, \
     patch.object(installer, 'sync_kvim_treesitter') as sync, \
     patch.object(installer.subprocess, 'run') as process:
    installer.install_editor_plugins(['kvim'], True)
    tree_sitter.assert_called_once()
    sync.assert_called_once()
    assert process.call_count == 1
    assert process.call_args.kwargs['env']['NVIM_APPNAME'] == 'nvim'
    assert process.call_args.kwargs['check'] is True
    assert 'DOTFILES_NVIM_CHECK' in process.call_args.kwargs['env']
with patch.object(installer.shutil, 'which', return_value=None), \
     patch.object(installer, 'require_tree_sitter_cli'), \
     patch.object(installer, 'sync_kvim_treesitter'):
    try:
        installer.install_editor_plugins(['kvim'], True)
    except ValueError:
        pass
    else:
        raise AssertionError('Missing build tools were not reported')
print('PASS: Neovim preview, selected profile, checked execution, missing build tools')

for version, accepted in [('0.25.10', False), ('0.26.0', False), ('0.26.1', True), ('0.27.0', True)]:
    with patch.object(installer.shutil, 'which', return_value='/usr/bin/tree-sitter'), \
         patch.object(installer.subprocess, 'run', return_value=subprocess.CompletedProcess(
             ['tree-sitter', '--version'], 0, stdout='tree-sitter ' + version)):
        try:
            installer.require_tree_sitter_cli()
        except ValueError:
            assert not accepted, version
        else:
            assert accepted, version
print('PASS: supported Tree-sitter CLI versions accepted; obsolete CLI rejected')

with tempfile.TemporaryDirectory(prefix='dotfiles-ts-local-') as directory:
    base = Path(directory)
    checkout = base / 'data/nvim/site/pack/core/opt/nvim-treesitter'
    run('git', 'init', str(checkout))
    (checkout / 'local.lua').write_text('return 1\n')
    run('git', '-C', str(checkout), 'add', 'local.lua')
    run('git', '-C', str(checkout), '-c', 'user.name=Test', '-c',
        'user.email=test@example.invalid', 'commit', '-m', 'fixture')
    run('git', '-C', str(checkout), 'remote', 'add', 'origin',
        'https://github.com/nvim-treesitter/nvim-treesitter')
    (checkout / 'local.lua').write_text('preserve local plugin edits\n')
    head = run('git', '-C', str(checkout), 'rev-parse', 'HEAD').stdout.strip()
    with patch.dict(os.environ, {'XDG_DATA_HOME': str(base / 'data')}):
        try:
            installer.sync_kvim_treesitter()
        except ValueError as error:
            assert 'Preserve local plugin work' in str(error)
        else:
            raise AssertionError('Treesitter migration discarded local work')
    assert (checkout / 'local.lua').read_text() == 'preserve local plugin edits\n'
    assert run('git', '-C', str(checkout), 'rev-parse', 'HEAD').stdout.strip() == head
print('PASS: Treesitter API migration refuses modified plugin checkouts')

with tempfile.TemporaryDirectory(prefix='dotfiles-platform-') as directory:
    command = [sys.executable, str(ROOT / 'install.py'), '--target', directory]
    result = run(*command, '--platform', 'macos', '--packages', 'zsh,mise', '--install-packages')
    assert 'Platform: macos. Mode: preview.' in result.stdout
    assert 'brew bundle install' in result.stdout and 'omarchy pkg add' not in result.stdout
    assert not list(Path(directory).iterdir())
    if sys.platform == 'linux':
        run(*command, '--platform', 'macos', '--apply', ok=False)
        result = run(*command, '--packages', 'mise')
        assert 'linux/mise/config.toml' in result.stdout
    run(*command, '--packages', 'mise-linux', ok=False)
    run(*command, '--packages', 'stow', ok=False)
    run(*command, '--packages', 'nvim', ok=False)
    run(*command, '--packages', 'tmux,,zsh', ok=False)
print('PASS: macOS preview has no writes, platform guard, removed package refusal')

with patch.object(installer, 'command') as execute, \
     patch.object(installer, 'download_installer') as download, \
     patch.object(installer, 'brew_path', return_value='/nonexistent/brew'):
    installer.install_system_packages(['aerospace', 'zed'], 'macos', False)
    assert download.call_args.args[0].startswith('https://raw.githubusercontent.com/Homebrew/')
    commands = [call.args[0] for call in execute.call_args_list]
    assert commands[0][1:3] == ['bundle', 'install']
    assert any('nikitabobko/tap/aerospace' in command for command in commands)
    assert all('pacman' not in command and 'stow' not in command for command in commands)
with patch.object(installer.shutil, 'which', return_value='/usr/bin/tool'), \
     patch.object(installer.subprocess, 'run') as query, \
     patch.object(installer, 'command') as execute:
    query.return_value.returncode = 0
    installer.install_system_packages(['tmux'], 'omarchy', False)
    assert execute.call_args.args[0] == ['omarchy', 'pkg', 'add', 'tmux', 'wl-clipboard', 'xdg-utils']
print('PASS: Homebrew and Omarchy command routing')

with tempfile.TemporaryDirectory(prefix='dotfiles-source-') as directory:
    base = Path(directory)
    repository = base / 'repo'
    run('git', 'init', str(repository))
    source = repository / 'shared/app'
    source.mkdir(parents=True)
    (source / 'init.lua').write_text('return {}\n')
    (repository / '.gitignore').write_text('shared/app/runtime/\n')
    (source / 'runtime').mkdir()
    (source / 'runtime/private.txt').write_text('not for deployment')
    mappings = {'config': (('shared/app', '.config/app'),)}
    with patch.object(installer, 'ROOT', repository), \
         patch.object(installer, 'SHARED_CONFIGS', mappings):
        selected = installer.files_for(['config'], 'omarchy')
    assert Path('.config/app/init.lua') in selected
    assert not any('runtime' in path.parts for path in selected)
    home = base / 'home'
    (home / '.config').mkdir(parents=True)
    destination = home / '.config/app'
    destination.symlink_to(source)
    with patch.object(installer, 'ROOT', repository), \
         patch.object(installer, 'SHARED_CONFIGS', mappings):
        installer.deploy(selected, home, False)
        assert destination.is_symlink()
        installer.deploy(selected, home, True)
        assert destination.is_dir() and not destination.is_symlink()
        assert (destination / 'init.lua').resolve() == source / 'init.lua'
        assert (destination / 'runtime/private.txt').read_text() == 'not for deployment'
        installer.deploy(selected, home, True)
    assert (source / 'init.lua').read_text() == 'return {}\n'
    home2 = base / 'rollback-home'
    (home2 / '.config').mkdir(parents=True)
    destination2 = home2 / '.config/app'
    destination2.symlink_to(source)
    original_link = Path.symlink_to
    calls = []
    def fail_second_link(path, *args, **kwargs):
        calls.append(path)
        if len(calls) == 2:
            raise OSError('simulated expansion failure')
        return original_link(path, *args, **kwargs)
    with patch.object(installer, 'ROOT', repository), \
         patch.object(installer, 'SHARED_CONFIGS', mappings), \
         patch.object(Path, 'symlink_to', fail_second_link):
        try:
            installer.deploy(selected, home2, True)
        except OSError:
            pass
        else:
            raise AssertionError('Expansion should have failed')
    assert destination2.is_symlink() and destination2.resolve() == source
    assert (source / 'init.lua').read_text() == 'return {}\n'
print('PASS: ignored-file exclusion, old directory-link migration, repeat run, rollback')

with tempfile.TemporaryDirectory(prefix='dotfiles-order-') as directory:
    events = []
    def record_command(arguments, apply, **kwargs):
        if apply and arguments[:2] == ['mise', 'install']:
            events.append('runtimes')
    def record_editor(packages, apply):
        if apply:
            events.append('plugins')
    runtime_package = 'mise'
    arguments = ['install.py', '--apply', '--packages', runtime_package + ',kvim',
                 '--install-runtimes', '--install-plugins']
    with patch.object(sys, 'argv', arguments), \
         patch.object(Path, 'home', return_value=Path(directory)), \
         patch.object(installer, 'files_for', return_value={}), \
         patch.object(installer, 'deploy'), \
         patch.object(installer, 'install_plugins'), \
         patch.object(installer, 'install_editor_plugins', side_effect=record_editor), \
         patch.object(installer, 'command', side_effect=record_command), \
         patch.object(installer.shutil, 'which', return_value='/usr/bin/tool'), \
         patch.dict(os.environ):
        assert installer.main() == 0
    assert events == ['runtimes', 'plugins'], events
print('PASS: runtime installation precedes dependent editor plugin installation')

sources = installer.configured_pi_sources()
assert len(sources) == 11 and all(source.startswith(('npm:', 'git:')) for source in sources)
assert not any('pi-mcp-adapter' in source for source in sources)
pi_settings = json.loads((ROOT / 'shared/pi/settings.json').read_text())
assert not set(pi_settings.get('extensions', [])) & {
    '-builtin:mcp', '-builtin:codemode', '-builtin:tool-search'}
assert not {'mcp', 'mcpScript'} & json.loads(
    (ROOT / 'shared/pi/extensions/pi-tool-display/config.json').read_text())['customToolOverrides'].keys()
mcp_example = json.loads((ROOT / 'macos/pi/mcp.example.json').read_text())
assert set(mcp_example) == {'mcpServers'}
assert mcp_example['mcpServers']['figma']['exposure'] == 'codemode'
with tempfile.TemporaryDirectory(prefix='dotfiles-mcp-local-') as directory:
    target = Path(directory)
    private_config = target / '.pi/agent/mcp.json'
    private_config.parent.mkdir(parents=True)
    private_config.write_text('{"mcpServers":{"personal":{"url":"http://localhost:1234/mcp"}}}\n')
    original_mcp = private_config.read_bytes()
    private_auth = private_config.with_name('mcp-auth.json')
    private_auth.write_text('{"fixture":"preserve private credentials"}\n')
    original_auth = private_auth.read_bytes()
    for _ in range(2):
        run(sys.executable, str(ROOT / 'install.py'), '--apply', '--packages', 'pi',
            '--target', directory)
        assert private_config.read_bytes() == original_mcp and not private_config.is_symlink()
        assert private_auth.read_bytes() == original_auth and not private_auth.is_symlink()
    assert private_config.with_name('mcp.example.json').exists() == (sys.platform == 'darwin')
with tempfile.TemporaryDirectory(prefix='dotfiles-mcp-macos-') as directory:
    target = Path(directory)
    selected = installer.files_for(['pi'], 'macos')
    installer.deploy(selected, target, False)
    assert not list(target.iterdir()), 'macOS Pi preview changed the target'
    installer.deploy(selected, target, True)
    assert (target / '.pi/agent/mcp.example.json').resolve() == ROOT / 'macos/pi/mcp.example.json'
    assert not (target / '.pi/agent/mcp.json').exists(), 'Example must not activate Figma automatically'
print('PASS: native MCP selection, macOS-only Figma example, private config/auth preservation')
with patch.object(installer, 'command') as execute:
    installer.install_pi_plugins(['pi'], False)
    execute.assert_not_called()
with tempfile.TemporaryDirectory(prefix='dotfiles-pi-') as directory:
    home = Path(directory)
    package = home / '.local/lib/node_modules/@earendil-works/pi-coding-agent'
    (package / 'dist/bundle').mkdir(parents=True)
    (package / 'package.json').write_text('{"version":"1.3.0"}')
    modular = package / 'dist/cli.js'
    modular.write_text('// fixture')
    (package / 'dist/bundle/cli.js').write_text('// fixture')
    launcher = home / '.local/bin/pi'
    launcher.parent.mkdir(parents=True)
    launcher.symlink_to(package / 'dist/bundle/cli.js')
    with patch.object(Path, 'home', return_value=home), \
         patch.object(installer, 'command') as execute:
        installer.install_pi_agent(False)
        assert launcher.resolve() != modular
        installer.install_pi_agent(True)
        assert launcher.resolve() == modular
        installer.install_pi_agent(True)
        execute.assert_not_called()
    launcher.unlink()
    launcher.write_text('preserve existing launcher')
    with patch.object(Path, 'home', return_value=home), \
         patch.object(installer.shutil, 'which', return_value='/usr/bin/npm'), \
         patch.object(installer, 'command', side_effect=subprocess.CalledProcessError(1, ['npm'])):
        try:
            installer.install_pi_agent(True)
        except subprocess.CalledProcessError:
            pass
        else:
            raise AssertionError('Expected npm failure')
    assert launcher.read_text() == 'preserve existing launcher'
    (home / 'shared/pi').mkdir(parents=True)
    (home / 'shared/pi/settings.json').write_text('{"packages":["npm:unpinned@latest"]}')
    with patch.object(installer, 'ROOT', home):
        try:
            installer.configured_pi_sources()
        except ValueError:
            pass
        else:
            raise AssertionError('Unpinned Pi source accepted')
if shutil.which('node'):
    run('node', '--check', str(ROOT / 'scripts/install-pi-packages.mjs'))
    run('node', '--check', str(ROOT / 'scripts/check-pi-image-paste.mjs'))
print('PASS: Pi pins, preview, compatible launcher, repeat run, failed-install restoration')

if shutil.which('zsh'):
    for relative in ('shared/zsh/zshenv', 'shared/zsh/zshrc', 'shared/fzf/fzf.zsh'):
        run('zsh', '-n', str(ROOT / relative))
    with tempfile.TemporaryDirectory(prefix='dotfiles-zsh-') as directory:
        target = Path(directory)
        shutil.copy(ROOT / 'shared/zsh/zshenv', target / '.zshenv')
        shutil.copy(ROOT / 'shared/zsh/zshrc', target / '.zshrc')
        # Startup checks must not activate runtimes from the host's mise state.
        fake_mise = target / '.local/bin/mise'
        fake_mise.parent.mkdir(parents=True)
        fake_mise.write_text('#!/bin/sh\n[ "$1" = activate ]\n')
        fake_mise.chmod(0o755)
        shell_env = {**os.environ, 'HOME': directory, 'ZDOTDIR': directory,
                     'SHELL': '/bin/bash', 'ZSH': directory + '/missing-omz',
                     'TERM': 'xterm-256color', 'XDG_DATA_HOME': directory + '/.local/share',
                     'XDG_CONFIG_HOME': directory + '/.config',
                     'ANDROID_HOME': directory + '/Android/Sdk', 'MISE_QUIET': '1',
                     'MISE_GLOBAL_CONFIG_FILE': directory + '/.config/mise/config.toml'}
        result = run('zsh', '-i', '-c',
                     'print -r -- "$PNPM_HOME"; print -r -- "$ANDROID_HOME"; print -r -- "SHELL=$SHELL"',
                     env=shell_env)
        pnpm_directory = '/Library/pnpm' if sys.platform == 'darwin' else '/.local/share/pnpm'
        assert directory + pnpm_directory in result.stdout
        assert directory + '/Android/Sdk' in result.stdout
        assert 'SHELL=' + shutil.which('zsh') in result.stdout
        assert not result.stderr, result.stderr
        fake_pi = target / '.local/bin/pi'
        fake_pi.parent.mkdir(parents=True, exist_ok=True)
        fake_pi.write_text('#!/bin/sh\nprintf pi\nprintf " <%s>" "$@"\nprintf "\\n"\n')
        fake_pi.chmod(0o755)
        shadow_pi = target / '.bun/bin/pi'
        shadow_pi.parent.mkdir(parents=True)
        shadow_pi.write_text('#!/bin/sh\necho wrong-launcher\n')
        shadow_pi.chmod(0o755)
        result = run('zsh', '-i', '-c',
                     'export PATH="$HOME/.bun/bin:$PATH"; '
                     'pi mcp list; pi auth check --provider openai; pi --version; pi', env=shell_env)
        assert result.stdout == ('pi <mcp> <list>\npi <auth> <check> <--provider> <openai>\n'
                                 'pi <--version>\npi <-c>\n'), result.stdout
        assert not result.stderr, result.stderr
    print('PASS: Zsh syntax, stale SHELL correction, isolated startup, Pi MCP/auth command routing')
else:
    print('SKIP: Zsh syntax/startup checks require installing zsh')
print('Installer checks passed.')
