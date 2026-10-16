#!/usr/bin/env python3
"""Preview or install dotfiles on macOS and Omarchy. Python 3.11+ required."""
import argparse
import datetime
import json
import os
import re
import platform
import pwd
import tempfile
from pathlib import Path
import shlex
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
LINUX_DEFAULT = ('agents', 'zsh', 'git', 'fzf', 'tmux', 'nvim', 'kvim', 'yazi', 'mise')
# Desktop/terminal packages are deliberately excluded.
PACKAGES = {
    'zsh': ('zsh',), 'git': ('git', 'git-lfs'),
    'fzf': ('fzf', 'fd', 'ripgrep', 'bat', 'jq', 'sqlite'),
    'tmux': ('tmux',), 'nvim': ('neovim', 'base-devel', 'unzip'),
    'kvim': ('neovim', 'base-devel', 'unzip', 'tree-sitter-cli', 'curl', 'tar'), 'vim': ('vim',),
    'emacs': ('emacs',), 'yazi': ('yazi', 'ffmpeg', '7zip', 'poppler',
                              'imagemagick', 'mpv', 'perl-image-exiftool', 'mediainfo'),
    'mise': (), 'zed': (), 'pi': (), 'herdr': (), 'agents': (),
}


MAC_DEFAULT = ('agents', 'zsh', 'alacritty', 'git', 'fzf', 'tmux', 'nvim', 'kvim', 'mise', 'herdr', 'pi', 'zed')
MAC_PACKAGES = set(PACKAGES) | {'alacritty', 'ghostty', 'aerospace'}

# Source paths are independent of their destinations under the target home.
SHARED_CONFIGS = {
    name: ((f'shared/{name}', f'.config/{name}'),)
    for name in ('nvim', 'kvim', 'fzf', 'yazi', 'zed', 'herdr')
} | {
    'zsh': (('shared/zsh/zshrc', '.zshrc'), ('shared/zsh/zshenv', '.zshenv'),
            ('shared/zsh/custom', '.zsh-custom')),
    'git': (('shared/git/gitconfig', '.gitconfig'),),
    'tmux': (('shared/tmux/tmux.conf', '.tmux.conf'),),
    'vim': (('shared/vim', '.vim'),),
    'emacs': (('shared/emacs', '.config/emacs'),
              ('shared/emacs-bootstrap.el', '.emacs.d/init.el')),
    'pi': (('shared/pi', '.pi/agent'),),
    'agents': (('shared/agents', '.agents'),),
}
PLATFORM_CONFIGS = {
    'omarchy': {'mise': (('linux/mise/config.toml', '.config/mise/config.toml'),)},
    'macos': {'mise': (('macos/mise/config.toml', '.config/mise/config.toml'),)} | {
        name: ((f'macos/{name}', f'.config/{name}'),)
        for name in ('alacritty', 'ghostty', 'aerospace')
    },
}


def config_mappings(system):
    return SHARED_CONFIGS | PLATFORM_CONFIGS[system]


def files_for(packages, system):
    # Only versioned or nonignored source files belong in a deployment. Plugin
    # checkouts, secrets and runtime state can live inside configuration folders.
    mappings = [mapping for package in packages for mapping in config_mappings(system)[package]]
    result = subprocess.check_output(
        ['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard', '--',
         *(source for source, _ in mappings)], cwd=ROOT)
    files = {}
    for name in sorted(set(os.fsdecode(result).split('\0')) - {''}):
        source = ROOT / name
        if not source.is_file() and not source.is_symlink():
            continue
        if source.name in ('.gitignore', '.DS_Store'):
            continue
        matches = [(Path(destination) / Path(name).relative_to(base) if Path(name) != Path(base)
                    else Path(destination)) for base, destination in mappings
                   if Path(name) == Path(base) or Path(base) in Path(name).parents]
        if len(matches) != 1:
            raise ValueError(f'Source must have exactly one destination: {name}')
        relative = matches[0]
        if relative in files:
            raise ValueError(f'Duplicate target: {relative}')
        files[relative] = source
    return files


def owned_directory_link(destination, relative):
    if not destination.is_symlink() or not destination.is_dir():
        return False
    try:
        source = destination.resolve().relative_to(ROOT)
    except ValueError:
        return False
    return any(source == Path(base) / relative.relative_to(destination)
               for system in PLATFORM_CONFIGS for mappings in config_mappings(system).values()
               for base, destination in mappings
               if relative == Path(destination) or Path(destination) in relative.parents)


def deploy(files, target, apply):
    parents = sorted({parent for relative in files for parent in relative.parents
                      if parent != Path('.')}, key=lambda p: (len(p.parts), str(p)))
    for relative in parents:
        destination = target / relative
        if destination.is_symlink() and not owned_directory_link(destination, relative):
            raise ValueError(f'Parent is an unrelated directory symlink: {destination}')
        if destination.exists() and not destination.is_dir():
            raise ValueError(f'Parent must be a directory: {destination}')
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    backup = target / '.local/state/dotfiles/backups' / stamp
    changed, unfolded = [], []
    try:
        for relative in parents:
            destination = target / relative
            if not destination.is_symlink():
                continue
            print(f'EXPAND directory link: {destination}', flush=True)
            if not apply:
                continue
            source = destination.resolve()
            saved = backup / '.directory-links' / str(len(unfolded))
            saved.parent.mkdir(parents=True, exist_ok=True)
            destination.rename(saved)
            unfolded.append((destination, saved))
            destination.mkdir()
            for child in source.iterdir():
                (destination / child.name).symlink_to(child)
        if unfolded:
            (backup / 'directory-links.json').write_text(json.dumps([
                {'path': str(path), 'backup': str(saved), 'link': os.readlink(saved)}
                for path, saved in unfolded], indent=2) + '\n')
        for relative, source in files.items():
            destination = target / relative
            if destination.exists() and destination.resolve() == source.resolve():
                continue
            exists = os.path.lexists(destination)
            print(f'{"BACKUP + LINK" if exists else "LINK"} {destination} -> {source}', flush=True)
            if not apply:
                continue
            saved = backup / relative if exists else None
            if saved:
                saved.parent.mkdir(parents=True, exist_ok=True)
                destination.rename(saved)
            changed.append((destination, saved))
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.symlink_to(source)
    except (OSError, ValueError):
        for destination, saved in reversed(changed):
            if destination.is_symlink():
                destination.unlink()
            if saved is not None:
                saved.rename(destination)
        for destination, saved in reversed(unfolded):
            if destination.is_dir() and not destination.is_symlink():
                shutil.rmtree(destination)
            saved.rename(destination)
        raise
    if apply:
        print(f'Applied {len(changed)} file links; expanded {len(unfolded)} directory links. '
              f'Backups, if needed: {backup}', flush=True)


def plugin_specs(packages):
    """Read active declarations; ignore commented examples and preserve tmux pins."""
    specs = []
    if 'zsh' in packages:
        specs.append(('https://github.com/ohmyzsh/ohmyzsh.git', '.oh-my-zsh', None))
        config = (ROOT / 'shared/zsh/zshrc').read_text()
        declaration = re.search(r'^plugins=\(([^)]*)\)', config, re.MULTILINE)
        if not declaration:
            raise ValueError('Cannot find the Zsh plugin declaration')
        for name in shlex.split(declaration.group(1)):
            if name == 'git':  # Bundled with Oh My Zsh.
                continue
            if name not in ('zsh-autosuggestions', 'zsh-syntax-highlighting'):
                raise ValueError(f'Add an explicit upstream for Zsh plugin: {name}')
            specs.append((f'https://github.com/zsh-users/{name}.git',
                          f'.zsh-custom/plugins/{name}', None))
        specs.append(('https://github.com/rupa/z.git', '.config/z', None))
    if 'tmux' in packages:
        for line in (ROOT / 'shared/tmux/tmux.conf').read_text().splitlines():
            tokens = shlex.split(line, comments=True)
            if len(tokens) != 4 or tokens[:3] != ['set', '-g', '@plugin']:
                continue
            repository, _, ref = tokens[3].partition('#')
            if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
                raise ValueError(f'Unsupported tmux upstream: {repository}')
            name = repository.split('/')[1]
            specs.append((f'https://github.com/{repository}.git',
                          f'.tmux/plugins/{name}', ref or None))
    return specs


def install_plugins(specs, target, apply):
    for url, relative, ref in specs:
        destination = target / relative
        for parent in (destination, *destination.parents):
            if parent == target:
                break
            if parent.is_symlink() and (not destination.exists() or not parent.resolve().is_relative_to(ROOT)):
                raise ValueError(f'Plugin directory must not be an unrelated symlink: {parent}')
        if destination.exists():
            if not (destination / '.git').is_dir():
                raise ValueError(f'Existing plugin path is not a checkout: {destination}')
            origin = subprocess.check_output(
                ['git', '-C', str(destination), 'remote', 'get-url', 'origin'], text=True).strip()
            if origin != url:
                raise ValueError(f'Existing plugin has a different upstream: {destination}')
            if ref:
                expected = subprocess.check_output(
                    ['git', '-C', str(destination), 'rev-parse', f'{ref}^{{commit}}'], text=True).strip()
                head = subprocess.check_output(
                    ['git', '-C', str(destination), 'rev-parse', 'HEAD'], text=True).strip()
                if expected != head:
                    raise ValueError(f'Existing plugin does not match pin {ref}: {destination}')
            print(f'Plugin already installed: {destination}')
            continue
        command = ['git', 'clone', '--depth', '1']
        if ref:
            command += ['--branch', ref]
        print(shlex.join([*command, url, str(destination)]))
        if apply:
            destination.parent.mkdir(parents=True, exist_ok=True)
            # Clone next to the final path, then rename after success. A failed
            # download cannot leave an incomplete installation behind.
            with tempfile.TemporaryDirectory(prefix='.dotfiles-clone-', dir=destination.parent) as temp:
                checkout = Path(temp) / 'checkout'
                subprocess.run([*command, url, str(checkout)], check=True)
                checkout.rename(destination)


def require_tree_sitter_cli():
    binary = shutil.which('tree-sitter')
    if binary:
        result = subprocess.run([binary, '--version'], capture_output=True, text=True, check=True)
        version = re.search(r'tree-sitter (\d+)\.(\d+)\.(\d+)', result.stdout)
        if version and tuple(map(int, version.groups())) >= (0, 26, 1):
            return
    raise ValueError('Kvim requires tree-sitter-cli >=0.26.1 from Homebrew or Omarchy. '
                     'Use --install-packages; remove any obsolete npm tree-sitter-cli shadowing it.')


def sync_kvim_treesitter():
    """Apply the two API migration pins before loading Kvim's configuration."""
    lock = json.loads((ROOT / 'shared/kvim/nvim-pack-lock.json').read_text())['plugins']
    legacy_pins = {
        'nvim-treesitter': 'cf12346a3414fa1b06af75c79faebe7f76df080a',
        'nvim-treesitter-textobjects': '5ca4aaa6efdcc59be46b95a3e876300cfead05ef',
    }
    data = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share')))
    for name in ('nvim-treesitter', 'nvim-treesitter-textobjects'):
        path = data / 'kvim/site/pack/core/opt' / name
        if not path.exists():
            continue  # vim.pack installs missing plugins from the lockfile.
        revision = lock[name]['rev']
        head = subprocess.check_output(['git', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip()
        if head == revision:
            continue
        status = subprocess.check_output(
            ['git', '-C', str(path), 'status', '--porcelain', '--untracked-files=no'], text=True)
        remote = subprocess.check_output(
            ['git', '-C', str(path), 'remote', 'get-url', 'origin'], text=True).strip()
        if status or remote != lock[name]['src'] or head != legacy_pins[name]:
            raise ValueError(f'Preserve local plugin work; cannot migrate {path}')
        subprocess.run(['git', '-C', str(path), 'fetch', 'origin', revision], check=True)
        subprocess.run(['git', '-C', str(path), 'checkout', '--detach', revision], check=True)


def install_editor_plugins(packages, apply):
    for profile in ('nvim', 'kvim'):
        if profile not in packages:
            continue
        print(f'Initialize and verify Neovim profile: {profile}')
        if apply:
            if profile == 'kvim':
                require_tree_sitter_cli()
                sync_kvim_treesitter()
            for executable in ('nvim', 'make', 'cc'):
                if not shutil.which(executable):
                    raise ValueError(f'Neovim plugin installation requires {executable}')
            environment = {**os.environ, 'NVIM_APPNAME': profile,
                           'DOTFILES_NVIM_CHECK': str(ROOT / 'scripts/check-nvim-plugins.lua'),
                           'DOTFILES_NVIM_INSTALL': '1',
                           'PATH': str(Path.home() / '.local/bin') + os.pathsep + os.environ.get('PATH', '')}
            subprocess.run(['nvim', '--headless', '-c',
                            'lua dofile(vim.env.DOTFILES_NVIM_CHECK)'],
                           env=environment, check=True, timeout=600)


PI_PACKAGE = '@earendil-works/pi-coding-agent@1.3.0'


def configured_pi_sources():
    settings = json.loads((ROOT / 'shared/pi/settings.json').read_text())
    sources = []
    for entry in settings.get('packages', []):
        source = entry if isinstance(entry, str) else entry.get('source')
        npm_pin = r'npm:(?:@[A-Za-z0-9_.-]+/)?[A-Za-z0-9_.-]+@\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?'
        git_pin = r'git:github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[a-f0-9]{40}'
        if not isinstance(source, str) or not (re.fullmatch(npm_pin, source) or re.fullmatch(git_pin, source)):
            raise ValueError('Pi packages must have an exact npm version or Git commit pin')
        sources.append(source)
    return sources


def pi_executable():
    local = Path.home() / '.local/bin/pi'
    return str(local) if local.is_file() else shutil.which('pi')


def configure_pi_launcher():
    # File-URL imports used by the pinned Vim integration need the modular
    # entry's SDK resolver. Keep the npm-owned bin as a symlink for upgrades.
    prefix = Path.home() / '.local'
    entry = prefix / 'lib/node_modules/@earendil-works/pi-coding-agent/dist/cli.js'
    launcher = prefix / 'bin/pi'
    if not entry.is_file():
        return
    if not launcher.is_symlink() or not launcher.resolve().is_relative_to(entry.parent):
        raise ValueError('Pi launcher is not the expected npm-installed symlink')
    if launcher.resolve() != entry:
        with tempfile.TemporaryDirectory(prefix='.dotfiles-pi-', dir=launcher.parent) as directory:
            temporary = Path(directory) / 'pi'
            temporary.symlink_to(os.path.relpath(entry, launcher.parent))
            os.replace(temporary, launcher)
        print('Pi launcher uses the modular CLI for the configured extensions.')


def install_pi_agent(apply):
    prefix = Path.home() / '.local'
    manifest = prefix / 'lib/node_modules/@earendil-works/pi-coding-agent/package.json'
    if manifest.is_file() and (prefix / 'bin/pi').is_symlink():
        if json.loads(manifest.read_text()).get('version') == PI_PACKAGE.rsplit('@', 1)[1]:
            print('Pi CLI is already installed at the pinned version.')
            if apply:
                configure_pi_launcher()
            return
    arguments = ['npm', 'install', '--global', '--prefix', str(prefix), '--ignore-scripts', PI_PACKAGE]
    if not apply:
        command(arguments, False)
        return
    if not shutil.which('npm'):
        raise ValueError('Pi installation needs Node/npm; install Node with mise first')
    launcher = prefix / 'bin/pi'
    backup = None
    if launcher.is_file() and not launcher.is_symlink():
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
        backup = Path.home() / '.local/state/dotfiles/backups' / stamp / 'pi-launcher'
        backup.parent.mkdir(parents=True)
        launcher.rename(backup)
        print(f'Existing Pi launcher backed up: {backup}')
    try:
        command(arguments, True)
        configure_pi_launcher()
    except (OSError, subprocess.CalledProcessError):
        if backup is not None and not os.path.lexists(launcher):
            backup.rename(launcher)
        raise


def install_pi_plugins(packages, apply):
    if 'pi' not in packages:
        return
    sources = configured_pi_sources()
    print(f'Install and verify {len(sources)} pinned Pi packages; preserve resource filters.')
    if not apply:
        return
    configure_pi_launcher()
    executable = pi_executable()
    if not executable or not shutil.which('node'):
        raise ValueError('Install Pi and Node first, or include --install-packages')
    environment = {**os.environ, 'DOTFILES_PI_ENTRYPOINT': executable,
                   'PI_CODING_AGENT_DIR': str(Path.home() / '.pi/agent'),
                   'PI_SKIP_VERSION_CHECK': '1'}
    with tempfile.TemporaryDirectory(prefix='dotfiles-pi-check-') as directory:
        command(['node', str(ROOT / 'scripts/install-pi-packages.mjs'), '--install'],
                True, cwd=directory, env=environment, timeout=900)


def command(args, apply, **kwargs):
    print(shlex.join(map(str, args)), flush=True)
    if apply:
        subprocess.run(args, check=True, **kwargs)


def brew_path():
    found = shutil.which('brew')
    if found:
        return found
    for candidate in ('/opt/homebrew/bin/brew', '/usr/local/bin/brew'):
        if Path(candidate).is_file():
            return candidate
    return '/opt/homebrew/bin/brew' if platform.machine() in ('arm64', 'aarch64') else '/usr/local/bin/brew'


def download_installer(url, shell, apply, env=None):
    print(f'Download official installer: {url}', flush=True)
    if apply:
        with tempfile.TemporaryDirectory(prefix='dotfiles-installer-') as directory:
            destination = Path(directory) / 'install'
            subprocess.run(['curl', '--fail', '--silent', '--show-error', '--location',
                            '--proto', '=https', '--proto-redir', '=https',
                            url, '--output', str(destination)], check=True)
            subprocess.run([shell, str(destination)], env=env, check=True)


def install_system_packages(packages, system, apply):
    if system == 'macos':
        brew = brew_path()
        if not Path(brew).is_file():
            download_installer('https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh',
                               '/bin/bash', apply, {**os.environ, 'NONINTERACTIVE': '1'})
        prefix = str(Path(brew).parent)
        if apply:
            os.environ['PATH'] = prefix + os.pathsep + os.environ.get('PATH', '')
        command([brew, 'bundle', 'install', '--no-upgrade', '--file', str(ROOT / 'macos/Brewfile')], apply,
                env={**os.environ, 'HOMEBREW_NO_AUTO_UPDATE': '1', 'HOMEBREW_BUNDLE_NO_UPGRADE': '1'})
        extras = {'emacs': ['emacs'], 'vim': ['vim'], 'yazi': ['yazi'],
                  'ghostty': ['--cask', 'ghostty'], 'aerospace': ['--cask', 'nikitabobko/tap/aerospace'],
                  'zed': ['--cask', 'zed']}
        for name in packages:
            if name in extras:
                command([brew, 'install', *extras[name]], apply)
        return
    if not shutil.which('omarchy') or not shutil.which('pacman'):
        raise ValueError('Linux package installation requires Omarchy and pacman')
    dependencies = sorted({'wl-clipboard', 'xdg-utils'} | {
        dependency for package in packages for dependency in PACKAGES[package]})
    unavailable = [name for name in dependencies if subprocess.run(
        ['pacman', '-Si', name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode]
    if unavailable:
        raise ValueError('Packages absent from configured repositories: ' + ', '.join(unavailable))
    # A missing repository DB otherwise causes a late transaction failure even
    # when every requested package can be found in another repo.
    if apply:
        result = subprocess.run(['pacman', '-Sl'], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        if result.returncode or 'database file for' in result.stderr:
            raise ValueError('Package databases are incomplete. Run sudo pacman -Syu in your terminal first.')
    command(['omarchy', 'pkg', 'add', *dependencies], apply)


def install_haskell(apply):
    ghcup = Path.home() / '.ghcup/bin/ghcup'
    if not ghcup.is_file():
        download_installer('https://get-ghcup.haskell.org', '/bin/sh', apply,
            {**os.environ, 'BOOTSTRAP_HASKELL_NONINTERACTIVE': '1',
             'BOOTSTRAP_HASKELL_ADJUST_BASHRC': '0', 'BOOTSTRAP_HASKELL_MINIMAL': '1'})
    for name, executable in [('ghc', 'ghc'), ('cabal', 'cabal'), ('hls', 'haskell-language-server-wrapper')]:
        if not (ghcup.parent / executable).is_file():
            command([str(ghcup), 'install', name], apply)
            command([str(ghcup), 'set', name, 'recommended'], apply)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--apply', action='store_true', help='perform the previewed operations')
    mode.add_argument('--dry-run', action='store_true', help='preview only, the default')
    parser.add_argument('--platform', choices=('auto', 'macos', 'omarchy'), default='auto',
                        help='auto-detect, or preview another platform')
    parser.add_argument('--packages', help='comma-separated configuration packages')
    parser.add_argument('--target', type=Path, default=Path.home(), help='home directory or disposable deployment target')
    parser.add_argument('--install-packages', action='store_true', help='install Homebrew or Omarchy dependencies')
    parser.add_argument('--install-runtimes', action='store_true', help='install the selected mise runtime declaration')
    parser.add_argument('--install-plugins', action='store_true', help='install configured Zsh, tmux, Neovim, and Pi plugins')
    parser.add_argument('--install-haskell', action='store_true', help='install GHCup, GHC, Cabal, and HLS')
    parser.add_argument('--github-login', action='store_true', help='start GitHub CLI web authentication')
    parser.add_argument('--set-default-shell', action='store_true', help='make Zsh the login shell using chsh')
    args = parser.parse_args()
    host = {'darwin': 'macos', 'linux': 'omarchy'}.get(sys.platform)
    if not host:
        parser.error('Only macOS and Linux are supported')
    system = host if args.platform == 'auto' else args.platform
    if args.apply and system != host:
        parser.error('A different platform can only be previewed')
    allowed = MAC_PACKAGES if system == 'macos' else set(PACKAGES)
    default = MAC_DEFAULT if system == 'macos' else LINUX_DEFAULT
    packages = list(dict.fromkeys(name.strip() for name in (args.packages or ','.join(default)).split(',')))
    unknown = set(packages) - allowed
    if unknown:
        parser.error('Unsupported configuration packages for ' + system + ': ' + ', '.join(sorted(unknown)))
    target = args.target.expanduser().absolute()
    if not target.is_dir() or target.is_symlink():
        parser.error('--target must be an existing real home directory')
    software = any((args.install_packages, args.install_runtimes, args.install_plugins,
                    args.install_haskell, args.github_login, args.set_default_shell))
    if args.apply and software and target != Path.home():
        parser.error('Software installation and shell changes require the current home directory')
    runtime_package = 'mise'
    if args.install_runtimes and runtime_package not in packages:
        parser.error('--install-runtimes requires the ' + runtime_package + ' package')
    print(f'Platform: {system}. Mode: {"apply" if args.apply else "preview"}.', flush=True)
    print('Configuration packages: ' + ', '.join(packages), flush=True)
    files = files_for(packages, system)
    deploy(files, target, False)
    specs = plugin_specs(packages) if args.install_plugins else []
    if args.install_plugins:
        install_plugins(specs, target, False)
        install_editor_plugins(packages, False)
        install_pi_plugins(packages, False)
    if args.install_packages:
        install_system_packages(packages, system, args.apply)
    if args.apply:
        deploy(files, target, True)
    if args.install_runtimes:
        if args.apply and not shutil.which('mise'):
            raise ValueError('Install mise for your architecture before requesting runtimes')
        source = ROOT / PLATFORM_CONFIGS[system]['mise'][0][0]
        environment = {**os.environ, 'MISE_GLOBAL_CONFIG_FILE': str(target / '.config/mise/config.toml')}
        command(['mise', 'trust', '--yes', str(source)], args.apply, env=environment)
        command(['mise', 'install', '--yes'], args.apply, env=environment, cwd=target)
        if args.apply:
            os.environ['PATH'] = str(Path.home() / '.local/share/mise/shims') + os.pathsep + os.environ.get('PATH', '')
    if args.install_packages and 'pi' in packages:
        install_pi_agent(args.apply)
    if args.apply and args.install_plugins:
        # Runtime-backed tools, especially Kvim's Swift grammar generator,
        # must run after an explicitly requested mise installation.
        install_plugins(specs, target, True)
        install_editor_plugins(packages, True)
        install_pi_plugins(packages, True)
    if args.install_haskell:
        install_haskell(args.apply)
    if args.github_login:
        command(['gh', 'auth', 'login', '--hostname', 'github.com', '--web'], args.apply)
    if args.set_default_shell:
        shell = '/bin/zsh' if system == 'macos' else '/usr/bin/zsh'
        if pwd.getpwuid(os.getuid()).pw_shell != shell:
            if args.apply and shell not in Path('/etc/shells').read_text().splitlines():
                raise ValueError(f'{shell} is not listed in /etc/shells')
            command(['chsh', '-s', shell], args.apply)
        else:
            print('Zsh is already the default login shell.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
