# bootstrap

Sets up macOS and Arch Linux using [mise bootstrap](https://mise.jdx.dev/bootstrap.html). System packages and per-user configuration are separate. Run the system setup once per machine, then the user setup once for each account.

## Repository layout

~~~text
bootstrap/
├── .miserc.toml             # auto_env = true
├── mise.toml                # Shared user config: Oh My Zsh, Git, Kitty, LazyVim
├── mise.linux.toml          # Arch per-user config and login shell
├── mise.macos.toml          # macOS per-user config, defaults, LaunchAgents
├── mise.system-linux.toml   # Arch pacman/AUR packages and setup hook
├── mise.system-macos.toml   # Homebrew packages and prerequisites
└── global.toml              # Per-user Node, Python, Bun, Java
~~~

`mise.linux.toml` and `mise.macos.toml` load automatically based on OS because `.miserc.toml` enables `auto_env`. The `system-linux` and `system-macos` environments are **not** automatic; select them explicitly with `-E`.

## Arch Linux

### System bootstrap (once per machine)

Install minimal prerequisites:

~~~sh
sudo pacman -Syu
sudo pacman -S --needed mise git zsh
~~~

Apply machine packages from a regular user with sudo access:

~~~sh
mise -E system-linux bootstrap \
  --from https://github.com/okhomenko/bootstrap.git \
  --only packages --update
~~~

This installs pacman packages (including `github-cli`, `openai-codex`, `fzf`, `neovim`) and 1Password AUR packages. The package hook installs an AUR helper if missing and verifies the 1Password GPG key. The first run needs an interactive terminal. Packages are shared by all accounts and updated by pacman.

### User bootstrap (each account)

Sign in as the target non-root user:

~~~sh
mise bootstrap \
  --from https://github.com/okhomenko/bootstrap.git \
  --update --prompt-vars
~~~

This applies Oh My Zsh, `~/.zshrc` (including SSH prompt), Git and SSH settings, Kitty, LazyVim, user runtime tools, and the login shell (`/usr/bin/zsh`). No pacman or AUR packages are installed.

When adding a new user to an already provisioned Arch machine, run only the user command. Start a new login session after changing the shell.

Verify:

~~~sh
command -v mise gh codex git nvim fzf
test -d ~/.oh-my-zsh
mise doctor
~~~

## macOS

### System bootstrap (once per machine)

On a fresh Mac, install Command Line Tools and mise:

~~~sh
xcode-select --install
curl -fsSL https://mise.run | sh
~~~

Complete the Command Line Tools installation, then apply packages from an admin account:

~~~sh
~/.local/bin/mise -E system-macos bootstrap \
  --from https://github.com/okhomenko/bootstrap.git \
  --only packages --update
~~~

This installs Homebrew packages and casks (including 1Password, Kitty, and development CLIs).

### User bootstrap (each account)

~~~sh
~/.local/bin/mise bootstrap \
  --from https://github.com/okhomenko/bootstrap.git \
  --update --prompt-vars
~~~

This applies shared dotfiles, runtimes, LazyVim, macOS user defaults, LaunchAgents, and Sublime Text Package Control. The Sublime setup hook runs after the `dotfiles` phase, not the system package phase. Start a new login session afterwards.

## Update, preview, and scope

~~~sh
# Preview system packages on Arch:
mise -E system-linux bootstrap --from https://github.com/okhomenko/bootstrap.git --only packages --dry-run

# Preview this user's configuration:
mise bootstrap --from https://github.com/okhomenko/bootstrap.git --dry-run
~~~

Use `--update` to fast-forward the local bootstrap checkout after a repository change. Existing installs need no package removal. Never run the bootstrap as root. Do **not** use `--save-env` with `system-linux` or `system-macos`: that would persist system package declarations into normal user runs.

`global.toml` is linked to `~/.config/mise/conf.d/bootstrap.toml` for each account, so runtime tools remain user-owned. The public repository contains no credentials or personal Git identity.

## Private stage

When the answer is a Git URL, the `bootstrap` task ends by applying that
repository:

1. On the first run, it checks with `git ls-remote` that the repository is
   readable, and stops with a hint if not.
2. It clones the repository into `~/code/<name>` and applies its
   `mise.bootstrap.toml`, restricted to user-level phases (no packages).

The private repository needs a `mise.bootstrap.toml` at its root, in the same
format as this repository's `mise.toml`. Its user bootstrap skips package and system service phases. Put anything personal there, for
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

The system phase runs under a regular sudo-capable user; the user phase configures the current user's home directory. Personal credentials, 1Password vaults, SSH agents, and Codex sessions are per-user.

Avoid using another dotfile manager such as Home Manager to own the same files. Git reads both `~/.gitconfig` and `~/.config/git/config`, and `~/.config/mise/config.toml` overrides files in `~/.config/mise/conf.d/`. Use `mise config ls` to inspect loaded config files.
