# bootstrap

Sets up macOS and Arch Linux using [mise bootstrap](https://mise.jdx.dev/bootstrap.html). System packages and per-user configuration are separate. Run the system setup once per machine, then the user setup once for each account.

## Repository layout

~~~text
bootstrap/
├── .miserc.toml             # auto_env = true
├── mise.toml                # Shared user config: Oh My Zsh, Git, Kitty, LazyVim, Herdr keys
├── codex/tui.toml           # Codex TUI keys merged into existing config
├── claude/statusline.sh     # Claude Code status line script (symlinked)
├── claude/settings.json     # Claude settings keys merged into existing settings
├── herdr/keys.toml          # Herdr [keys] merged into existing config
├── scripts/bootstrap       # Installed as ~/.local/bin/bootstrap
├── mise.linux.toml          # Arch per-user config and login shell
├── mise.macos.toml          # macOS per-user config, defaults, LaunchAgents
├── mise.system-linux.toml   # Arch pacman/AUR packages and setup hook
├── mise.system-macos.toml   # Homebrew packages and prerequisites
└── global.toml              # Per-user Node, Python, Bun, Java
~~~

`mise.linux.toml` and `mise.macos.toml` load automatically based on OS because `auto_env` is enabled: by `.miserc.toml` inside this repository, and by `~/.config/mise/miserc.toml` (written by the user bootstrap) for `mise bootstrap --from` runs. On the very first run, add `-E macos` or `-E linux`. The `system-linux` and `system-macos` environments are **not** automatic; select them explicitly with `-E`.

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

This installs pacman packages (including `github-cli`, `openai-codex`, `fzf`, `neovim`) and 1Password and Herdr AUR packages. The package hook installs an AUR helper if missing and verifies the 1Password GPG key. The first run needs an interactive terminal. Packages are shared by all accounts and updated by pacman.

### User bootstrap (each account)

Sign in as the target non-root user:

~~~sh
mise bootstrap \
  --from https://github.com/okhomenko/bootstrap.git \
  --update --prompt-vars
~~~

When prompted for the private repository URLs, mise saves each answer in its
per-user state. To pass them without prompts, save them first with `mise vars`
as shown under [Private stages](#private-stages). Future `bootstrap update`
runs use those saved URLs to pull and apply both repositories.

This applies Oh My Zsh, `~/.zshrc` (including SSH prompt), Git and SSH settings, Kitty, LazyVim, user runtime tools, and the login shell (`/bin/zsh`). No pacman or AUR packages are installed.

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

## Codex CLI preferences

The common user bootstrap uses mise's TOML **merge** entry to manage only Codex's TUI preferences.

- Source: `codex/tui.toml`
- Target: `~/.codex/config.toml`
- Declaration in `mise.toml`:

~~~toml
[dotfiles]
"~/.codex/config.toml/tui" = { source = "codex/tui.toml", merge = true }
~~~

Mise adds or updates only `tui.status_line`, `tui.status_line_use_colors`, and `tui.terminal_title`. All other Codex settings, including existing model preferences, MCP servers, trusted projects, and local instructions, remain untouched. The status-line and title arrays are **replaced** with the declared arrays on every apply; changing them interactively in Codex may show up as drift until you update `codex/tui.toml`.

~~~sh
mise bootstrap --from https://github.com/okhomenko/bootstrap.git --update
mise dot status
~~~

Do not symlink or copy over the entire `~/.codex/config.toml`: Codex also writes settings there. Merge entries require mise 2026.10.4 or newer.

## Claude Code status line

`claude/statusline.sh` is symlinked to `~/.claude/statusline.sh`, and the keys
in `claude/settings.json` are merged into `~/.claude/settings.json`; other Claude
settings remain untouched. Besides `statusLine`, it disables away summaries
(`awaySummaryEnabled`) and the feedback survey
(`env.CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY`). The script
shows model, effort, folder, Git branch and changes, PR state, context usage,
session cost, duration, lines changed, and 5h/7d rate limits. It requires `jq`,
which the system bootstrap installs.

## Herdr prefix

On both macOS and Arch, `herdr/keys.toml` is merged into `~/.config/herdr/config.toml`,
setting the Herdr prefix to `ctrl+space` (Caps Lock is used as Esc, so the
default `ctrl+b` is awkward). Other Herdr settings remain untouched. After
applying, run `herdr server reload-config` to pick it up in a running server.

## GitHub URLs

`~/.gitconfig` rewrites `git@github.com:` and `ssh://git@github.com/` URLs to
HTTPS, so every GitHub remote uses the GitHub CLI credential helper. Which
GitHub account and Git identity each organization uses is private and belongs
in the private repository.

## GitHub CLI authentication

GitHub CLI is installed by the **system** bootstrap: `github-cli` on Arch or `gh` through Homebrew on macOS. Each user authenticates once through GitHub CLI's standard OAuth browser/device flow:

~~~sh
gh auth login --hostname github.com --web --git-protocol https
gh auth status
gh api user --jq .login
~~~

On an SSH-only machine, use the URL/device code shown in the terminal in a browser on another machine. No fine-grained PAT or 1Password service-account token is required.

The shared `~/.gitconfig` always configures GitHub HTTPS hosts to use `gh auth git-credential`, so Git cloning, fetching, pushing, and subsequent public/private bootstrap runs reuse the same user login. This is declarative and is not lost when bootstrap regenerates Git configuration.

One GitHub OAuth login can cover repositories in multiple organizations, subject to each organization's GitHub CLI OAuth app approvals and SSO requirements. Verify access individually with `gh repo view ORG/REPO`. The token may be stored in plaintext by GitHub CLI when no supported credential store is available; use `gh auth status` to inspect storage.

Do not call `gh auth logout` as part of bootstrap: it would remove the required login. Do not set an old `GH_TOKEN` or `GITHUB_TOKEN` globally, as these override the native login.

## Update, preview, and scope

After user setup, manage the bootstrap from any directory:

~~~sh
bootstrap update                        # Pull remote config and apply system + user setup
bootstrap upgrade                       # Update mise, upgrade packages and tools
bootstrap platform list                 # Show declared system packages and their state
bootstrap platform upgrade              # Upgrade installed system packages
bootstrap platform prune --dry-run      # Print Homebrew prune commands
bootstrap tools list                    # List global tools
bootstrap tools upgrade                 # Upgrade global tools and prune superseded versions
bootstrap tools prune                   # Remove unused tool versions
~~~

`bootstrap update` fast-forwards the checkout that owns the installed script,
then applies system packages and the full user bootstrap, including configured
private stages. It installs missing packages; use `upgrade` to upgrade
installed packages. Local changes that prevent a fast-forward stop the update.

`bootstrap upgrade` updates mise (`self-update` on macOS, pacman on Arch),
then upgrades installed platform packages and global mise tools within their
configured version ranges. Tool upgrades use `--prune` to immediately remove
superseded versions unless another tracked config needs them. This command
uses the current checkout; run `bootstrap update` first to refresh declarations.

Platform commands use this repository's system environment. On macOS this
includes Homebrew formulae and casks without requiring the `brew` executable;
on Arch it includes pacman/AUR packages and may require sudo. Platform prune
uses mise's Homebrew prune: it removes undeclared formulae (including manually
installed ones) that are not dependencies, plus unchanged mise-owned casks.
It does not clean old kegs or download caches. Pacman/AUR pruning is unsupported.
Platform prune is explicit and is not part of upgrade.

Tools commands use global configuration, including `~/.config/mise/conf.d/`,
instead of the caller's project. Explicit tools prune removes versions unused
by any tracked configuration, including projects. All commands accept
`--dry-run` to print the planned commands without executing them, fetching
remote changes, or running hooks. Run as your regular user.

For an existing installation, install the command once after this change is
available in the remote repository:

~~~sh
mise bootstrap --from https://github.com/okhomenko/bootstrap.git --only dotfiles --update
~~~

~~~sh
# Preview system packages on Arch:
mise -E system-linux bootstrap --from https://github.com/okhomenko/bootstrap.git --only packages --dry-run

# Preview this user's configuration:
mise bootstrap --from https://github.com/okhomenko/bootstrap.git --dry-run
~~~

Use `--update` to fast-forward the local bootstrap checkout after a repository change. Existing installs need no package removal. Never run the bootstrap as root. Do **not** use `--save-env` with `system-linux` or `system-macos`: that would persist system package declarations into normal user runs.

`global.toml` is linked to `~/.config/mise/conf.d/bootstrap.toml` only when the `runtimes` environment is selected, so global runtime changes are opt-in and tools remain user-owned. The public repository contains no credentials or personal Git identity.

## Private stages

When the saved values are Git URLs, the `bootstrap` task ends by applying the
personal `config` repository and then `config-cbee`:

1. On the first run, it checks with `git ls-remote` that the repository is
   readable, and stops with a hint if not.
2. It clones each repository into `~/code/<name>` (or fast-forwards an existing
   checkout) and applies its `mise.bootstrap.toml`, restricted to user-level
   phases (no packages).

The private repository needs a `mise.bootstrap.toml` at its root, in the same
format as this repository's `mise.toml`. Its user bootstrap skips package and system service phases. Put anything personal there, for
example:

- Personal Git identity and global hook settings in `config`'s
  `~/.config/git/private.gitconfig`, which this repository's `~/.gitconfig`
  includes. Git ignores the include while the file does not exist.
- Chargebee Git credentials, identity, and signing settings in `config-cbee`,
  included by the personal Git config when installed.
- Environment variables in a file under `~/.config/mise/conf.d/`, so they apply
  in every directory.
- SSH hosts as a block in `~/.ssh/config`.

For a private repository, **prefer HTTPS** and authenticate with native GitHub CLI before bootstrap:

~~~sh
gh auth login --hostname github.com --web --git-protocol https
mise vars private_bootstrap_repo=https://github.com/okhomenko/config.git
mise vars chargebee_bootstrap_repo=https://github.com/okhomenko/config-cbee.git
mise bootstrap --from https://github.com/okhomenko/bootstrap.git --update
~~~

`mise vars` stores both URLs outside the repositories. `--prompt-vars` also
stores answers supplied interactively. Use `mise vars private_bootstrap_repo`
and `mise vars chargebee_bootstrap_repo` to inspect them. Set either value to
`skip` to omit that stage. Sign in to GitHub CLI for the Chargebee account
before using its work remotes.

An SSH URL remains supported, but requires an SSH key and agent with access to the repository. 1Password SSH agent integration is optional and independent of the GitHub CLI OAuth login.

GitHub's SSH host keys are added to `~/.ssh/known_hosts`, so the first
connection does not stop at a host-key prompt.

## Change and reapply configuration

Edit the appropriate repository, commit, and push it to GitHub. Shared settings
belong in `bootstrap`; personal Git identity and global hook settings belong
in `config`; Chargebee Git settings belong in `config-cbee`. Then apply the
published versions:

~~~sh
bootstrap update
git config --includes --show-origin --get user.name
git config --includes --show-origin --get user.email
~~~

`bootstrap update` fast-forwards the public checkout. Its private stages read
the saved repository URLs and fast-forward both checkouts before applying them.
A checkout with uncommitted changes must be cleaned up before it can be updated.

To change the answer later:

```sh
mise vars private_bootstrap_repo=https://github.com/you/private.git
mise vars chargebee_bootstrap_repo=https://github.com/you/work-config.git
mise vars unset private_bootstrap_repo   # ask again on the next --prompt-vars run
```

## Scope

The system phase runs under a regular sudo-capable user; the user phase configures the current user's home directory. Personal credentials, 1Password vaults, SSH agents, and Codex sessions are per-user.

Avoid using another dotfile manager such as Home Manager to own the same files. Git reads both `~/.gitconfig` and `~/.config/git/config`, and `~/.config/mise/config.toml` overrides files in `~/.config/mise/conf.d/`. Use `mise config ls` to inspect loaded config files.

## Applying on an existing Omarchy desktop

Linux bootstrap adds Kitty shortcuts, split navigation, and top tabs in a managed
block, preserving Omarchy's theme include, colors, and local font size. It configures
SSH to use the 1Password agent at `~/.1password/agent.sock` for the `arch` and
`remote-arch` hosts only (GitHub uses HTTPS). Enable the agent in the 1Password
desktop app first. macOS keeps its own Kitty settings and uses the agent socket
in 1Password's group container for the same hosts.

Preview and apply user configuration explicitly on Linux:

~~~sh
mise -E linux bootstrap --from https://github.com/okhomenko/bootstrap.git --update --only repos,dotfiles,mise-shell-activate
~~~

This leaves system packages, the login shell, runtime installations, and the
private-stage task alone. Apply the private repository's dotfiles separately.
If Zsh is not installed, preserve the current login shell; Zsh configuration
can be prepared without selecting it as the login shell.

Global runtime declarations are opt-in: add `-E runtimes` when bootstrapping
to deploy `global.toml`. Review its versions first, then run `mise install`
explicitly to install them. Existing deployed runtime files are not removed.
