# bootstrap

Sets up macOS and Arch Linux with [`mise bootstrap`](https://mise.jdx.dev/bootstrap.html):
Homebrew on macOS, pacman on Arch, zsh with oh-my-zsh, kitty, Neovim with
LazyVim, Git defaults, and runtime tools (Node, Python, Bun, Java).
macOS-only preferences stay on macOS.

The repository holds no identity, credentials, or host details. Those come from
an optional private stage, described below.

## Repository layout

```text
bootstrap/
├── .miserc.toml       # auto_env = true
├── mise.toml          # shared dotfiles, repositories, bootstrap task
├── mise.macos.toml    # Homebrew, Apple settings, macOS-specific files
├── mise.linux.toml    # pacman packages, Linux-specific files
└── global.toml        # Node, Python, Bun, Java (linked globally)
```

Platform files are activated automatically by mise's `auto_env` setting.
Packages for one OS are never evaluated as part of the other OS's setup.

## Set up a Mac

1. Install the Xcode Command Line Tools and wait for the installer to finish.
   `mise bootstrap --from` needs a working `git` to clone this repository.

   ```sh
   xcode-select --install
   ```

2. Install mise:

   ```sh
   curl -fsSL https://mise.run | sh
   ```

3. Run the bootstrap:

   ```sh
   ~/.local/bin/mise bootstrap --from https://github.com/okhomenko/bootstrap.git --prompt-vars
   ```

   mise asks once for a private bootstrap repository. Press Enter to keep
   `skip`, or give a Git URL (see [Private stage](#private-stage)). The answer
   is saved in `~/.local/state/mise/vars.toml`, outside any config file, and
   later runs reuse it.

4. Open a new terminal.

mise keeps its checkout of this repository in
`~/.local/share/mise/bootstrap-repo`. The runtime tool list, `global.toml`, is
linked to `~/.config/mise/conf.d/bootstrap.toml`, so it applies in every
directory.

## Set up Arch Linux

The same repository supports Arch; mise selects `mise.linux.toml` on Arch and `mise.macos.toml` on macOS.
The shared `mise.toml` contains dotfiles, repositories, and bootstrap tasks. The Arch package list uses official repositories; pacman owns native package
versions and upgrades. The repository's `.miserc.toml` enables automatic
platform environments.

1. Install the bootstrap prerequisites as your regular user (sudo is only
   used to install pacman packages):

   ```sh
   sudo pacman -Syu
   sudo pacman -S --needed mise git zsh base-devel
   ```

2. Install an AUR helper if neither `paru` nor `yay` is available. This is
   a one-time machine preparation step; build it as your regular user, **not**
   using `sudo makepkg`:

   ```sh
   if ! command -v paru >/dev/null 2>&1 && ! command -v yay >/dev/null 2>&1; then
     mkdir -p ~/code
     git clone https://aur.archlinux.org/paru.git ~/code/paru
     (cd ~/code/paru && makepkg -si)
   fi
   ```

   Review the AUR PKGBUILD before the first install or any upgrade. The
   bootstrap AUR manager uses `--noconfirm` and does not prompt to inspect
   PKGBUILD changes.

3. Import 1Password's signing key for its AUR package:

   ```sh
   curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --import
   ```

4. Run the public bootstrap:

   ```sh
   mise bootstrap --from https://github.com/okhomenko/bootstrap.git --prompt-vars
   ```

5. Open a new zsh session and verify:

   ```sh
   command -v mise gh git kitty nvim op 1password
   pacman -Q 1password 1password-cli
   mise doctor
   mise bootstrap packages status
   ```

The Arch setup includes native packages such as `gh`, `kitty`, `lazygit`,
`neovim`, `fzf`, `fd`, `ripgrep`, `btop`, `tree-sitter-cli`, and the
JetBrains Mono Nerd font. It uses the existing `kitty/linux.conf`, Git
configuration, Oh My Zsh, LazyVim, and the global runtime configuration.

1Password Desktop (`1password`) and its CLI (`1password-cli`, binary `op`)
are installed from AUR, not Linuxbrew. Both are installed system-wide via
pacman after the AUR helper builds them under your normal account. 1Password
vaults, logins, and SSH agent state remain per user. Other optional apps (such
as Chrome and Sublime Text) are not installed by this Arch configuration.

**SSH agent:** unlike macOS, the public Arch bootstrap does not configure a
1Password SSH agent. Keep your existing SSH configuration until 1Password is
installed and its Linux socket is working. If you use 1Password later, the
Linux socket is `~/.1password/agent.sock`.

### If a previous bootstrap attempted Linuxbrew

Cancel the Homebrew prompt and run the updated bootstrap with `--update`;
existing bootstraps retain their previous checkout until explicitly updated:

```sh
mise bootstrap --from https://github.com/okhomenko/bootstrap.git --update
```

Preview planned native packages with `mise bootstrap packages apply --dry-run`
before approving installations.

## Update

```sh
mise bootstrap --from https://github.com/okhomenko/bootstrap.git --update
```

`--update` fast-forwards the checkout before applying it. Without it, mise
reapplies the commit it already has.

## Private stage

When the answer is a Git URL, the `bootstrap` task ends by applying that
repository:

1. On the first run, it checks with `git ls-remote` that the repository is
   readable, and stops with a hint if not.
2. It runs `mise -E bootstrap bootstrap --from <url>`, which clones the
   repository into `~/code/<name>` and applies its `mise.bootstrap.toml`.

The private repository needs a `mise.bootstrap.toml` at its root, in the same
format as this repository's `mise.toml`. Put anything personal there, for
example:

- Git identity and credential helpers in `~/.config/git/private.gitconfig`,
  which this repository's `~/.gitconfig` includes. Git ignores the include
  while the file does not exist.
- Environment variables in a file under `~/.config/mise/conf.d/`, so they apply
  in every directory.
- SSH hosts as a block in `~/.ssh/config`.

For an SSH URL such as `git@github.com:you/private.git`, Git authenticates
through your configured SSH agent. On a fresh Mac, the bootstrap installs
1Password in the same run, so private stage access may initially fail. Then:

1. Sign in to the 1Password app.
2. Turn on its SSH agent (Settings > Developer).
3. Make sure the SSH key for the GitHub account that can read the repository
   is in a vault the agent offers.
4. Rerun the bootstrap command (without `--prompt-vars`).

GitHub's SSH host keys are added to `~/.ssh/known_hosts`, so the first
connection does not stop at a host-key prompt.

The private checkout is yours to update: pull in `~/code/<name>`, then rerun
the bootstrap. `--update` fast-forwards only this repository's checkout.

To change the answer later:

```sh
mise vars private_bootstrap_repo=git@github.com:you/private.git
mise vars unset private_bootstrap_repo   # ask again on the next --prompt-vars run
```

## Scope

Use this on macOS or Arch Linux where nothing else manages the same files,
such as Home Manager. Git reads both `~/.gitconfig` and `~/.config/git/config`, and a
`~/.config/mise/config.toml` overrides the files in `~/.config/mise/conf.d/`.
`mise config ls` lists the config files mise loads, lowest precedence first.
