# nix

[![check](https://github.com/irish1986/nix/actions/workflows/check.yml/badge.svg)](https://github.com/irish1986/nix/actions/workflows/check.yml)

My NixOS configuration. Today it describes one machine, **`bigbug-nixos`**: NixOS running as a WSL2 distro on `bigbug`, next to the existing Ubuntu-26.04 distro. It is a flake with Home Manager as a NixOS module, laid out so a bare-metal NixOS host or a Mac (nix-darwin) can be added later without restructuring.

If you have never used NixOS, read [Nix in ten minutes](#nix-in-ten-minutes) first, then follow [Install](#install) top to bottom. The reasoning behind the design (sources compared, known issues, version choices) is in [docs/research/nixos-wsl-build-plan.md](docs/research/nixos-wsl-build-plan.md).

- [Nix in ten minutes](#nix-in-ten-minutes)
- [What is in this repo](#what-is-in-this-repo)
- [Install](#install)
- [Everyday use](#everyday-use)
- [Upgrading NixOS (26.05 → 26.11)](#upgrading-nixos-2605--2611)
- [Troubleshooting and recovery](#troubleshooting-and-recovery)
- [CI](#ci)
- [Adding another machine later](#adding-another-machine-later)
- [Learn more](#learn-more)

## Nix in ten minutes

**Nix** is a package manager. Every package is built into its own folder under `/nix/store`, named by a hash of everything that went into it (`/nix/store/8xk…-ripgrep-14.1.1`). Nothing is installed "over" anything else, so two versions of a library can coexist and an upgrade can always be undone. The store is read-only: you never edit files in it.

**NixOS** is a Linux distribution built on Nix. Instead of running `apt install` and editing files under `/etc` by hand, you describe the whole system (packages, users, services, config files) in `.nix` files. Running `nixos-rebuild` (or `nh os switch`, its friendlier wrapper used here) builds that description and switches the machine to it. If it isn't in the config, it isn't on the system, and the same config produces the same system on any machine.

**Generations.** Every successful rebuild becomes a numbered *generation*. The previous ones are kept, so a bad change is undone by switching back to the last generation. Old generations are deleted by the garbage collector after a while (here: anything older than 14 days, always keeping the last 5).

**Modules and options.** A NixOS config is a set of *modules*: functions that return attribute sets of *options*, like `programs.zsh.enable = true;` or `time.timeZone = "America/Toronto";`. NixOS merges every module together, so different files can each set part of the config. Look options up at [search.nixos.org/options](https://search.nixos.org/options) and packages at [search.nixos.org/packages](https://search.nixos.org/packages).

**Flakes.** `flake.nix` is the entry point. Its `inputs` say where things come from (nixpkgs on the `nixos-26.05` branch, Home Manager, NixOS-WSL), and its `outputs` say what the repo provides (here, the `bigbug-nixos` system). `flake.lock` pins every input to an exact commit, so a rebuild today and a rebuild next month use the same packages until you deliberately update the lock. One gotcha: **a flake only sees files that git knows about.** A new file you haven't `git add`ed is invisible, and the error is a confusing "No such file or directory".

**Home Manager** does for your home directory what NixOS does for the system: dotfiles (`~/.gitconfig`, `~/.ssh/config`, `~/.config/zsh/.zshrc`) and per-user packages are generated from `home/irish/*.nix`. Because it runs as a NixOS module, one `nh os switch` applies both. Files Home Manager manages are read-only symlinks into the store; to change them, edit the `.nix` file and rebuild.

**stateVersion** (`system.stateVersion` and `home.stateVersion`, both `"26.05"`) records the release this machine was *first installed* with, so NixOS can keep compatible defaults for data on disk. It is not "the version I'm running". **Never change it**, including when you upgrade NixOS.

**NixOS-WSL** is the community project that makes NixOS run under WSL. It adds the `wsl.*` options (default user, `wsl.conf`, Windows interop) and replaces the bootloader and kernel parts that WSL provides itself.

## What is in this repo

```
flake.nix                    inputs (nixpkgs 26.05, home-manager, NixOS-WSL, nix-index-database) and outputs
flake.lock                   exact pinned versions of every input; updated weekly by CI
lib/default.nix              mkNixos: builds one host and wires in Home Manager for its user
hosts/bigbug-nixos/          host facts only: hostname, time zone, stateVersion, which modules to import
modules/nixos/common/        every NixOS host: flakes on, trusted user, nh, zsh, the `irish` user
modules/nixos/wsl/           WSL hosts only: NixOS-WSL, Windows PATH off, nix-ld (for VS Code)
modules/nixos/docker.nix     Docker engine inside NixOS, `irish` in the docker group
overlays/default.nix         pkgs.unstable.<name> for packages newer than 26.05 has
home/irish/default.nix       portable Home Manager: CLI tools, toolchains, direnv, comma
home/irish/git.nix           git config ported from Ubuntu, including SSH commit signing
home/irish/shell.nix         plain zsh
home/irish/ssh.nix           ~/.ssh/config ported from Ubuntu, plus the Linux ssh-agent
home/irish/wsl.nix           WSL-only glue: code, explorer, pbcopy/pbpaste, win32yank, BROWSER
.github/workflows/           check.yml (build on every push/PR), update.yml (weekly flake.lock PR)
docs/research/               the research report this repo was built from
```

What is deliberately **not** here:

- **Windows-side settings.** `.wslconfig` (memory, mirrored networking, sparse VHD), Windows Terminal and fonts are owned by the [dotfiles](https://github.com/irish1986/dotfiles) Ansible repo. `.wslconfig` is shared by every distro, so changing it affects Ubuntu too.
- **Secrets.** Nothing secret is committed. The SSH private key is copied in by hand (step 4 below).
- **claude and copilot.** They update themselves daily, so they come from their official installers into `~/.local/bin` (step 6), not from Nix.

## Install

You do steps 0–2 once from Windows. Allow about 45 minutes the first time. Commands are marked **PowerShell** (on Windows) or **NixOS** (inside the new distro).

### 0. Prepare Windows

**PowerShell:**

```powershell
wsl --update
wsl --version     # needs WSL 2.4.4 or later; bigbug has 3.0.1
wsl -l -v         # Ubuntu-26.04 stays as it is
```

Then check:

- **Docker Desktop**: in *Settings → Resources → WSL integration*, leave **NixOS off** once it appears. NixOS runs its own Docker engine, and two daemons must not share one socket.
- **VS Code** with the *WSL* extension is installed on Windows (it is, under `C:\Program Files\Microsoft VS Code`).
- `.wslconfig` is already managed by the dotfiles repo. Nothing to do.

### 1. Download and install the NixOS-WSL image

Download `nixos.wsl` from the [NixOS-WSL 2605.7.2 release](https://github.com/nix-community/NixOS-WSL/releases/tag/2605.7.2) (about 580 MB). This is the stock image: it boots as a user called `nixos` with a generic config. Step 3 switches it to this repo.

**PowerShell**, in the folder you downloaded to:

```powershell
wsl --install --from-file .\nixos.wsl --name NixOS --location $env:USERPROFILE\WSL\NixOS
```

`--location` puts the virtual disk somewhere you can find it for backups.

### 2. First boot

**PowerShell:**

```powershell
wsl -d NixOS
```

You are now user `nixos` inside NixOS. **NixOS:**

```sh
nixos-wsl-version                                  # expect 2605.x
grep stateVersion /etc/nixos/configuration.nix     # expect "26.05"; it must match hosts/bigbug-nixos
sudo nix-channel --update                          # one-time step upstream requires on a fresh image
```

`sudo` needs no password: NixOS-WSL lets the `wheel` group use it without one, and no password is set for any user.

### 3. Switch to this repo (the delicate step)

This replaces the generic config with this flake. It renames the user from `nixos` to `irish`, so it must be applied with `nixos-rebuild boot` and a restart, **not** `switch`: switching live to a renamed user misconfigures it, and the stock image's `switch` also fails on WSL 3.0 (NixOS-WSL issue [#1100](https://github.com/nix-community/NixOS-WSL/issues/1100); this repo pins the branch with the fix).

**NixOS** (still as `nixos`). The stock image has no git, so borrow one with `nix-shell -p`:

```sh
nix-shell -p git --run "git clone https://github.com/irish1986/nix.git /tmp/nix"
sudo env NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild boot --flake /tmp/nix#bigbug-nixos
exit
```

The first build downloads a few GB from the binary cache. When it finishes, **PowerShell**:

```powershell
wsl -t NixOS                       # stop the distro
wsl -d NixOS --user root exit      # start it once as root so the new generation activates
wsl -t NixOS                       # stop it again
wsl -d NixOS                       # open a shell
```

**NixOS**, you should now be `irish`:

```sh
whoami      # irish
hostname    # bigbug-nixos
echo $SHELL # .../bin/zsh
```

### 4. Bring your SSH key over from Ubuntu

The key is never committed. Copy it straight out of the Ubuntu distro. **NixOS:**

```sh
mkdir -p ~/.ssh && chmod 700 ~/.ssh
/mnt/c/Windows/System32/wsl.exe -d Ubuntu-26.04 --exec cat /home/irish/.ssh/id_ed25519 > ~/.ssh/id_ed25519
/mnt/c/Windows/System32/wsl.exe -d Ubuntu-26.04 --exec cat /home/irish/.ssh/id_ed25519.pub > ~/.ssh/id_ed25519.pub
chmod 600 ~/.ssh/id_ed25519
ssh -T git@github.com    # answer "yes" to the host key prompt; expect "Hi irish1986!"
```

`~/.ssh/config` and `~/.ssh/allowed_signers` already exist: Home Manager created them from `home/irish/ssh.nix` and `git.nix`. The ssh-agent runs as a user service and caches the key after first use (`AddKeysToAgent yes`).

### 5. Move the repo home and do the first real switch

**NixOS:**

```sh
mkdir -p ~/git/irish1986
git clone git@github.com:irish1986/nix.git ~/git/irish1986/nix
cd ~/git/irish1986/nix
nh os switch          # NH_FLAKE already points here, so no path is needed
rm -rf /tmp/nix
sudo rm -rf /home/nixos   # the old user's empty home; NixOS removed the user itself
```

`nh os switch` builds, shows a diff of what changes, then activates. This is the command you will use from now on.

### 6. One-time tool setup

**NixOS:**

```sh
gh auth login                                        # GitHub CLI; also git's HTTPS credential helper
rustup default stable                                # rustup is from Nix; the toolchain it downloads is yours
curl -fsSL https://claude.ai/install.sh | bash       # Claude Code into ~/.local/bin
curl -fsSL https://gh.io/copilot-install | bash      # Copilot CLI into ~/.local/bin
```

These installers download ordinary Linux binaries. NixOS can't run those by default (it has no `/lib64/ld-linux-x86-64.so.2`); `programs.nix-ld` in `modules/nixos/wsl` provides it, which is also what lets VS Code's server and uv-managed Pythons run.

`npm install -g` works too: it installs into `~/.npm-global` (set in `~/.npmrc`) because the Nix store is read-only.

### 7. Check everything works

| Check | Command (NixOS) | Expected |
|---|---|---|
| Windows interop | `/mnt/c/Windows/System32/cmd.exe /c ver` | Prints the Windows version. "exec format error": uncomment `interop.register` in `modules/nixos/wsl`, rebuild |
| VS Code | `code .` in the repo | A VS Code window opens connected to WSL: NixOS |
| Signed commits | `git commit --allow-empty -m test && git log --show-signature -1` | `Good "git" signature for simon.harvey.86@gmail.com`; then `git reset HEAD~` |
| Docker | `docker run --rm hello-world` | "Hello from Docker!" without sudo. Permission denied: run `wsl -t NixOS` once so the docker group applies |
| Clipboard | `echo hi \| pbcopy`, then paste in Windows | `hi` |
| Browser | `gh repo view --web` | Opens in the Windows browser |
| comma | `, cowsay moo` | Runs cowsay without installing it |
| Toolchains | `node -v; python3 -V; uv -V; cargo -V; ansible --version` | Node 24, Python 3, uv, Rust stable, Ansible |

When NixOS has replaced Ubuntu for daily work, make it the default distro with `wsl -s NixOS` (**PowerShell**). The Windows Terminal profile appears automatically.

## Everyday use

All commands run inside NixOS, from `~/git/irish1986/nix`.

### Change something

1. Edit a `.nix` file. Search [NixOS options](https://search.nixos.org/options) or [Home Manager options](https://home-manager-options.extranix.com/?release=release-26.05) for what to set.
2. If you created a new file: `git add` it (flakes ignore untracked files).
3. `nh os switch`. Read the diff it prints; if the build fails, nothing changed.
4. Commit and push.

### Add a package

Find the name with `nh search <word>` or [search.nixos.org/packages](https://search.nixos.org/packages), add it to `home.packages` in `home/irish/default.nix`, then `nh os switch`.

To try something without installing it: `, <program>` (comma) or `nix shell nixpkgs#<package>`. When 26.05's version is too old, use `pkgs.unstable.<package>` instead of `pkgs.<package>`.

### Update everything

The weekly CI PR updates `flake.lock` and builds the result. Merge it on GitHub, then:

```sh
git pull && nh os switch
```

Or do it locally: `nix flake update && nh os switch`, then commit `flake.lock`.

### Undo a change

| Situation | Do this |
|---|---|
| The last switch broke something but the shell works | `sudo nixos-rebuild switch --rollback` |
| You want an older state from git | `git checkout <commit> -- . && nh os switch` |
| See what generations exist | `nixos-rebuild list-generations` |
| The distro won't start at all | See [Troubleshooting](#troubleshooting-and-recovery) |

### Clean up disk space

Automatic: nh deletes generations older than 14 days every week, always keeping the last 5. Manual: `nh clean all --keep 3`. Old generations are what make rollback possible, so don't clean right after a risky change.

### Repo hygiene

```sh
nix fmt                 # format every .nix file
nix develop             # shell with nixfmt, nil (language server), statix, deadnix, nh
nix flake check         # what CI runs: evaluates and builds the whole system
```

### Project development environments

Toolchains here are global, pinned by `flake.lock`. When a project needs its own versions, give it a `flake.nix` with a `devShells.default` and an `.envrc` containing `use flake`; direnv (with nix-direnv) loads it automatically when you `cd` in.

### When `nh os switch` refuses or fails on WSL

Some changes (dbus, systemd itself, user renames) can't be applied live. Use:

```sh
nh os boot
```

then from **PowerShell** `wsl -t NixOS` and reopen. Some WSL problems only clear with a full `wsl --shutdown`, which also stops Ubuntu.

## Upgrading NixOS (26.05 → 26.11)

NixOS 26.05 stops getting security updates on **2026-12-31**; 26.11 is due late November 2026. NixOS-WSL publishes a `release-26.11` **branch** some time after NixOS does. Wait for it rather than for a tag:

```sh
git ls-remote https://github.com/nix-community/NixOS-WSL 'refs/heads/release-*'
```

Then:

1. `git switch -c upgrade-26.11`, and take a backup (see below).
2. In `flake.nix`, change the three branch names: `nixos-26.05` → `nixos-26.11`, `home-manager/release-26.05` → `release-26.11`, `NixOS-WSL/release-26.05` → `release-26.11`.
3. `nix flake update`, then `nix build .#nixosConfigurations.bigbug-nixos.config.system.build.toplevel`. Fix any renamed or removed options it reports; the [NixOS release notes](https://nixos.org/manual/nixos/stable/release-notes) and `home-manager news` list them.
4. `nh os boot`, then `wsl -t NixOS` from PowerShell, reopen, and re-run the checks in [step 7](#7-check-everything-works).
5. Push, let CI pass, merge.

**Do not change either `stateVersion`.** If Home Manager warns about a version mismatch, the fix is that its branch and nixpkgs' branch must match, not a stateVersion change.

## Troubleshooting and recovery

### Known issues (October 2026)

| Symptom | Cause | Fix |
|---|---|---|
| `switch` fails restarting `sysinit-reactivation.target` / `wsl-mnt-guard` | WSL ≥ 2.9.8 expects `/bin/true` ([#1100](https://github.com/nix-community/NixOS-WSL/issues/1100)) | Fixed on the pinned `release-26.05` branch. On an old lock: `nh os boot` + `wsl -t NixOS` |
| "Unable to autolaunch a dbus-daemon without a $DISPLAY" during switch | [#1074](https://github.com/nix-community/NixOS-WSL/issues/1074) | `nh os boot` + `wsl -t NixOS` |
| "Failed to start the systemd user session" | Another distro (Ubuntu) started first ([#888](https://github.com/nix-community/NixOS-WSL/issues/888)) | `wsl --shutdown`, start NixOS first; if it persists, uncomment `wslConf.boot.initTimeout` in `modules/nixos/wsl` |
| VS Code: "Could not start dynamically linked executable" | nix-ld missing | It is on here; check `ls /lib64/ld-linux-x86-64.so.2` |
| "you are not a trusted user" | Nix daemon trust ([#1024](https://github.com/nix-community/NixOS-WSL/issues/1024)) | `irish` is in `trusted-users`; restart the shell after the first switch |
| `C:\` fails to mount after a WSL update | [#1112](https://github.com/nix-community/NixOS-WSL/issues/1112), open | Back up before WSL updates; watch the issue |
| A guide tells you to enable `services.envfs` | | **Don't**: it can stop the distro from booting ([#1009](https://github.com/nix-community/NixOS-WSL/issues/1009)). nix-ld covers the same need |

### Recovery ladder, cheapest first

**Bad generation, shell still works.** `sudo nixos-rebuild switch --rollback`.

**The distro won't start.** Open the NixOS-WSL recovery shell from **PowerShell**:

```powershell
wsl -d NixOS --system --user root -- /mnt/wslg/distro/bin/nixos-wsl-recovery
```

To boot an older generation instead, add `--system /nix/var/nix/profiles/system-<N>-link` (list them with `ls /nix/var/nix/profiles/`). If it fails with "bad interpreter" ([#1042](https://github.com/nix-community/NixOS-WSL/issues/1042)), first run:

```powershell
wsl -d NixOS --system --user root -- /bin/sh -c "mkdir -p /nix && mount --bind /mnt/wslg/distro/nix /nix"
```

**Your login shell is broken** (bad zsh config):

```powershell
wsl -d NixOS --user root --exec /run/current-system/sw/bin/sh
```

then `export PATH=/run/current-system/sw/bin:/run/current-system/sw/sbin`, fix the repo, rebuild.

**Full backup** before NixOS upgrades, before Windows-side WSL updates, and monthly. **PowerShell:**

```powershell
wsl --terminate NixOS
wsl --export NixOS $env:USERPROFILE\WSL\backups\nixos-$(Get-Date -Format yyyy-MM-dd).vhdx --vhd
```

Restore it as a separate distro to test it (NixOS-WSL doesn't test export/import itself, so do one drill):

```powershell
wsl --import NixOS-restore $env:USERPROFILE\WSL\NixOS-restore <backup>.vhdx --vhd
```

**Start over from this repo.** The system is fully described here; only `~` and Docker volumes are state. Inside NixOS, build an image that already has `irish` and this config:

```sh
sudo nix run .#nixosConfigurations.bigbug-nixos.config.system.build.tarballBuilder
```

That writes `nixos.wsl`; install it as in step 1, skip steps 2–3, and restore your home from a backup.

**Disk keeps growing.** `nh clean all`, `sudo fstrim -av`, then from PowerShell `wsl --shutdown`. Sparse VHDs (set in `.wslconfig`) give the space back to Windows.

## CI

- **check** (`.github/workflows/check.yml`) runs on every push to `main` and every PR: `nix fmt -- --ci`, `statix` and `deadnix`, then `nix flake check`, which builds the whole `bigbug-nixos` system. If CI is green, `nh os switch` will build.
- **update-flake-lock** (`.github/workflows/update.yml`) runs every Saturday and opens a PR that updates `flake.lock`.

One-time setup so the weekly PR is checked too: GitHub doesn't run workflows on PRs opened with the default Actions token. Create a [fine-grained personal access token](https://github.com/settings/personal-access-tokens/new) for this repo only, with *Contents: read and write* and *Pull requests: read and write*, and save it as the repository secret `FLAKE_UPDATE_TOKEN` (*Settings → Secrets and variables → Actions*). Without it the PR still opens; run the check by hand from the Actions tab.

## Adding another machine later

- **Another NixOS machine (bare metal).** Run `nixos-generate-config` on it, copy `hardware-configuration.nix` into `hosts/<name>/`, write `hosts/<name>/default.nix` like `hosts/bigbug-nixos` but importing `modules/nixos/common` (not `wsl`) plus a bootloader, and add one line to `nixosConfigurations` in `flake.nix`. `home/irish` is reused as is.
- **A Mac.** Add a `nix-darwin` input, a `mkDarwin` next to `mkNixos` in `lib/default.nix` using `home-manager.darwinModules.home-manager`, and `modules/darwin/`. `home/irish/default.nix` already avoids anything Linux- or WSL-specific. Note that 26.05 is the last release supporting Intel Macs.
- At three or more hosts, consider [flake-parts](https://flake.parts) to cut repetition.

## Learn more

- [nix.dev](https://nix.dev): official tutorials; start with *First steps* and the Nix language basics.
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world): beginner-friendly, flake-first, close to how this repo is built.
- [NixOS manual](https://nixos.org/manual/nixos/stable/) and [Home Manager manual](https://nix-community.github.io/home-manager/).
- [NixOS-WSL docs](https://nix-community.github.io/NixOS-WSL/) (built from `main`; a few options there are not on `release-26.05` yet).
- [NixOS Discourse](https://discourse.nixos.org) for questions.
