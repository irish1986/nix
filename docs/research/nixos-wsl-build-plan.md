# Bootstrap NixOS on WSL2 from your own flake

Install the stock **NixOS-WSL 2605.7.2** image. Then switch it, in a single `nixos-rebuild boot`, to a flake in `irish1986/nix` that pins **`nixos-26.05`, `home-manager/release-26.05` and `NixOS-WSL/release-26.05`**. Pin the NixOS-WSL **branch**, not the tag: current WSL (2.9.8 and later, so today's stable 3.0.1 is very likely affected) breaks `nixos-rebuild switch` unless the system has the `/bin/true` fix, which exists only on the branch ([Issue #1100](https://github.com/nix-community/NixOS-WSL/issues/1100)). None of the three sources is safe to copy as a whole. The LGUG2Z starter's best piece is its `mkNixosConfiguration` helper with Home Manager wired in, but it is pinned to the end-of-life 24.11 and would break against 26.05 in at least five places ([nixos-wsl-starter](https://github.com/LGUG2Z/nixos-wsl-starter/tree/780c583f22046e238306d24c99cf09cd02d8f1aa)). frankper's "The One Nix" has the right multi-host shape, but its own roadmap says the Windows import has never been smoke-tested ([issues-roadmap.md](https://gitlab.com/frankper/the-one-nix/-/blob/main/readme/issues-roadmap.md)). Upstream NixOS-WSL is the authority on `wsl.*` options, though its flake example still uses `nixos-unstable` with stateVersion "25.05" ([nix-flakes.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/how-to/nix-flakes.md)). The timing also matters. NixOS 26.05 loses support on **2026-12-31** and 26.11 is due in late November ([NixOS 26.05 announcement](https://nixos.org/blog/announcements/2026/nixos-2605/)). A repo started today will go through its first release upgrade within about eight weeks, so the plan below treats upgrades and recovery as first-class phases rather than afterthoughts.

## Three sources, one verdict: borrow patterns, not repos

Each source answers a different question, and each is out of date in its own way. **Upstream NixOS-WSL** is the only source for what the `wsl.*` module actually does. Its latest tag is 2605.7.2 (2026-06-06), tracking NixOS 26.05, and since 2505.7.0 it has kept a `release-YY.MM` branch per NixOS release while `main` follows `nixos-unstable` ([2505.7.0 release notes](https://github.com/nix-community/NixOS-WSL/releases/tag/2505.7.0)). The maintainers say plainly that tags are not cut regularly: "Please always track the correct branch for your nixos release" ([Issue #1071](https://github.com/nix-community/NixOS-WSL/issues/1071)). The documentation site is built from `main`, so it lists options such as `wsl.wslLib` that `release-26.05` does not have. Read the branch source before trusting an option.

**The LGUG2Z starter** is effectively abandoned. Its last commit was 2025-04-27, its last release tarball was 2024-12-24, and it pins NixOS and Home Manager 24.11 plus NixOS-WSL `main` ([starter repo](https://github.com/LGUG2Z/nixos-wsl-starter/tree/780c583f22046e238306d24c99cf09cd02d8f1aa)). Against 26.05 it breaks in several places. `du-dust` is now a `throw`. The whole `nodePackages` set has been removed ([nixpkgs 26.05 aliases.nix](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/top-level/aliases.nix)). Home Manager moved `programs.git.extraConfig`/`userName`/`userEmail` under `programs.git.settings` and split delta into `programs.delta` ([HM git.nix](https://github.com/nix-community/home-manager/blob/release-26.05/modules/programs/git.nix)). nix-index-database renamed `hmModules` to `homeModules`. Its committed `secrets.json` is read through `${self}`, which puts tokens into the world-readable Nix store. Its `mkNixosConfiguration` helper, the shared `specialArgs` passed into Home Manager via `extraSpecialArgs`, and its Home Manager defaults (`useGlobalPkgs`, `useUserPackages`, `backupFileExtension`) are still the best small-repo pattern in any of the three sources. The one fork that is current, `k7o/nixos-wsl-starter`, confirms the modern shape: release-26.05 branches everywhere, `programs.nix-ld.enable`, and Windows Git Credential Manager ([k7o fork](https://github.com/k7o/nixos-wsl-starter)).

**The One Nix** is a very active 2026 repository (release 26.09.2, 2026-09-27), built around `hosts/<name>/`, a `lib/mkHost.nix`, Home Manager as a NixOS module, and WSL as just another host with an `isWsl` flag ([mkHost.nix](https://gitlab.com/frankper/the-one-nix/-/blob/main/lib/mkHost.nix)). Its WSL module is five lines and worth copying almost verbatim ([modules/nixos/wsl](https://gitlab.com/frankper/the-one-nix/-/blob/main/modules/nixos/wsl/default.nix)). Its guide's main idea is to build your own `nixos-wsl.tar.gz` from the flake, so first boot already has your user, which avoids the username-change sequence entirely ([guide](https://frankper.gitlab.io/the-one-nix/guides/manage-nixos-in-wsl/)). The rest is weaker. That workflow assumes you already have a Linux machine with Nix. It uses the older `.tar.gz` plus `wsl --import` flow. It pins NixOS-WSL `main` against stable nixpkgs. Its ~150-key `settings.nix` and feature-gate system is built for the author's ~18 hosts. With sops off, every user gets `initialPassword = "test1234"` ([users README](https://gitlab.com/frankper/the-one-nix/-/blob/main/modules/nixos/users/README.md)). Most importantly, the CHANGELOG records the Windows import/boot test as "pending an operator run" ([CHANGELOG](https://gitlab.com/frankper/the-one-nix/-/blob/main/CHANGELOG.md)).

| Source | Adopt | Avoid or change |
|---|---|---|
| **NixOS-WSL (upstream)** | `nixosModules.default`; `release-26.05` branch input with `follows`; the `.wsl` install via `wsl --install --from-file`; the change-username sequence (`boot`, not `switch`); `programs.nix-ld` for VS Code; `wsl.ssh-agent` (new in 2605); the recovery shell; the `tarballBuilder` for re-imaging | The flake example's `nixos-unstable`/`main`/`"25.05"` values; the 2605.7.2 **tag** (it lacks the `/bin/true` fix); options documented on the site but only present on `main` (`wsl.wslLib`, Docker Desktop 4.80 binaries) |
| **LGUG2Z starter** | The `mkNixosConfiguration` helper; HM `useGlobalPkgs`/`useUserPackages`/`backupFileExtension`; the `pkgs.unstable` overlay idea; `nix-index-database` + comma; direnv + nix-direnv; `trusted-users`; `appendWindowsPath = false` with Windows tools added by absolute path; `enableAllTerminfo`; a `formatter` output; CI that builds the system on every push | Its 24.11 pins and NixOS-WSL `main`; plaintext `secrets.json`; passing a custom `pkgs =` to `nixosSystem` (this bypasses `nixpkgs.*` options); legacy `nixPath` channel entries; stateVersion 22.05/22.11; the `nodejs_18` VS Code hack; JeezyVim/NUR inputs (big transitive lock trees that broke builds in [#20](https://github.com/LGUG2Z/nixos-wsl-starter/issues/20)); the starter's own release tarball |
| **The One Nix** | `hosts/<name>/` per host; a `lib/` builder; a `modules/nixos/wsl` module imported only by WSL hosts; `wsl.defaultUser` derived from one user definition; the "bake your own tarball" idea, kept for re-imaging and recovery; `programs.nh` for rebuilds; deferring sops on WSL until key delivery is decided | The settings/feature-gate framework (too heavy for 1–3 hosts); the `.tar.gz` naming; NixOS-WSL `main` on stable nixpkgs; the `test1234` default password; `nix flake lock --update-input` (deprecated spelling); treating the guide as a field-tested runbook |

## Pin release branches now, because WSL 3.0 and the stock image disagree

The newest known issue is also the one most likely to bite on day one. WSL 2.9.8 and later write a `wsl-mnt-guard.service` with `ExecStart=/bin/true`, and NixOS-WSL's minimal `/bin` has no `true`. As a result, `switch-to-configuration` aborts when it restarts `sysinit-reactivation.target`. The fix was merged to `main` (PR #1101) and to `release-26.05` on 2026-09-10, but **no tag contains it** ([Issue #1100](https://github.com/nix-community/NixOS-WSL/issues/1100); [PR #1101](https://github.com/nix-community/NixOS-WSL/pull/1101)). The current stable WSL is **3.0.1, released 2026-09-29**, which follows the 2.9.x pre-release line ([microsoft/WSL releases](https://github.com/microsoft/WSL/releases)). The stock 2605.7.2 image is therefore likely to fail its first `switch` on a fully updated Windows. The plan sidesteps this in two ways: the first rebuild uses `nixos-rebuild boot`, which upstream requires for a username change anyway, and the flake pins the branch that has the fix.

Note what this machine already has. The repo currently lives in an **Ubuntu 26.04 WSL distro where the user `irish` is UID 1000** (observed in this workspace). Every WSL distro shares one VM, one kernel and one global `.wslconfig`, and that interacts badly with an open upstream bug. NixOS-WSL issue #888 reports "Failed to start the systemd user session" when another distro with the same UID 1000 was started first. It is labelled an upstream WSL bug (microsoft/WSL#13188) ([Issue #888](https://github.com/nix-community/NixOS-WSL/issues/888)). One commenter traced their case to slow units (Docker at 33 s, Home Manager at 20 s) exceeding WSL's 10-second init timeout. The new `wsl.wslConf.boot.initTimeout` option, on the branch since July 2026 and not in the tag, addresses that variant.

| Issue (Oct 2026) | Symptom | Status | Mitigation in this plan |
|---|---|---|---|
| WSL ≥ 2.9.8 needs `/bin/true` ([#1100](https://github.com/nix-community/NixOS-WSL/issues/1100)) | `nixos-rebuild switch` fails restarting `sysinit-reactivation.target` | Fixed on `release-26.05`, untagged | Pin the branch; first rebuild uses `boot`; drop-in fallback below |
| Headless dbus during user-unit reload ([#1074](https://github.com/nix-community/NixOS-WSL/issues/1074)) | "Unable to autolaunch a dbus-daemon without a $DISPLAY"; worse with `guiApplications=false` | Open | Keep WSLg on (the default); if it hits, use `nixos-rebuild boot` + `wsl -t NixOS` |
| User session fails when another distro started first ([#888](https://github.com/nix-community/NixOS-WSL/issues/888)) | "Failed to start the systemd user session" | Open, upstream WSL bug | `wsl --shutdown` and start NixOS first; raise `wsl.wslConf.boot.initTimeout` if slow units are the cause |
| `services.envfs` ([#1009](https://github.com/nix-community/NixOS-WSL/issues/1009), [#846](https://github.com/nix-community/NixOS-WSL/issues/846)) | Distro hangs at load; `C:\` fails to mount | Known; envfs breaks `/bin/mount` | Never enable envfs; use nix-ld |
| Docker Desktop 4.80+ ([#1081](https://github.com/nix-community/NixOS-WSL/issues/1081)) | Integration fails for lack of `install`/`mv` in `/bin` | Fixed on `main` only | Use native `virtualisation.docker`, or add both binaries via `wsl.extraBin` |
| Recovery shell "bad interpreter" ([#1042](https://github.com/nix-community/NixOS-WSL/issues/1042)) | `nixos-wsl-recovery` cannot exec `nixos-enter` | Open | Bind-mount `/nix` first (Phase 8) |
| Drive-mount failures on WSL 2.9.10 ([#1112](https://github.com/nix-community/NixOS-WSL/issues/1112)) | "Failed to translate 'C:\…'" after upgrade | Open, cause unknown (2026-09-29) | Watch the issue; keep an export before WSL updates |
| Default user not trusted ([#1024](https://github.com/nix-community/NixOS-WSL/issues/1024)) | "you are not a trusted user" | Open | `nix.settings.trusted-users` includes the user |
| AMD GPU / ROCm ([#623](https://github.com/nix-community/NixOS-WSL/issues/623)) | No acceleration | Open | NVIDIA only via `wsl.useWindowsDriver` |

Plenty of current-looking advice is stale. Any guide that uses `wsl.nativeSystemd`, `wsl.docker-native`, `wsl.docker` or `nixos-wsl.tar.gz` predates 2025: syschdemd was removed in 2411.6.0, and native Docker now needs no workarounds ([2411.6.0 release](https://github.com/nix-community/NixOS-WSL/releases/tag/2411.6.0)). `nixfmt-rfc-style` is now a deprecated alias of `nixfmt` ([nixpkgs #425583](https://github.com/NixOS/nixpkgs/issues/425583)). nh reads `NH_FLAKE` rather than `FLAKE` ([nh](https://github.com/nix-community/nh)). `wslu`/`wslview` was archived on 2025-03-01 ([wslu](https://github.com/wslutilities/wslu)). Mismatched Home Manager and nixpkgs branches trigger a version-mismatch warning, and the fix is to align branches, never to change stateVersion ([Discourse](https://discourse.nixos.org/t/version-mismatch-in-my-flake-home-manager-26-05-nixpkgs-25-11/73112)).

## A plain flake with one builder grows from WSL to bare metal and macOS

The community advice for a repo that starts with one host and grows to a few is consistent: write a hand-rolled flake, learn the module system, and add flake-parts only when you want reusable flake-level modules. Avoid snowfall-lib, which is "not been super actively maintained" and "gives all users managed by it sudo privileges by default" ([NixOS Discourse](https://discourse.nixos.org/t/easy-hosts-ez-config-snowfall-what-do-you-use/61240)). The layout below combines the starter's helper, The One Nix's host/module split, and the Misterio77/ryan4yin conventions. It keeps three portability rules. First, `home/irish/default.nix` never mentions `wsl.*` or `/mnt/c`. Second, overlays live on the system side, because `useGlobalPkgs` ignores `nixpkgs.*` set inside Home Manager. Third, each host file holds only host facts: hostname, stateVersion, imports and per-host Home Manager additions.

```
irish1986/nix/
├── flake.nix  flake.lock
├── lib/default.nix                  # mkNixos (later mkDarwin, mkHome)
├── hosts/
│   └── wsl/default.nix              # host facts + imports; no hardware-configuration.nix on WSL
├── modules/
│   ├── nixos/
│   │   ├── common/default.nix       # nix settings, user, shell, nh — every NixOS host
│   │   ├── wsl/default.nix          # nixos-wsl import + wsl.* + nix-ld — WSL hosts only
│   │   └── docker.nix
│   └── darwin/                      # later
├── home/irish/
│   ├── default.nix                  # portable HM (Linux + macOS)
│   ├── git.nix  shell.nix
│   └── wsl.nix                      # WSL-only HM: clip.exe, explorer.exe, code, GCM
├── overlays/default.nix             # pkgs.unstable.<name>
└── .github/workflows/{check,update}.yml
```

**`flake.nix`**. Every input follows the one `nixpkgs`, and NixOS-WSL is pinned to the release branch:

```nix
{
  description = "irish1986 — NixOS (WSL, later bare metal) + nix-darwin + Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/release-26.05"; # branch, NOT the 2605.7.2 tag
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      mylib = import ./lib { inherit inputs self; };
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in {
      overlays = import ./overlays { inherit inputs; };

      nixosConfigurations = {
        wsl = mylib.mkNixos { hostname = "wsl"; username = "irish"; };
        # desktop = mylib.mkNixos { hostname = "desktop"; username = "irish"; };
      };
      # darwinConfigurations.mac = mylib.mkDarwin { hostname = "mac"; username = "irish"; };

      formatter.x86_64-linux = (pkgsFor "x86_64-linux").nixfmt-tree;
      checks.x86_64-linux.wsl = self.nixosConfigurations.wsl.config.system.build.toplevel;
      devShells.x86_64-linux.default = (pkgsFor "x86_64-linux").mkShell {
        packages = with (pkgsFor "x86_64-linux"); [ nixfmt-tree nil nh statix deadnix ];
      };
    };
}
```

**`lib/default.nix`**. This is the starter's helper rewritten so it no longer passes a custom `pkgs`. Overlays go through `nixpkgs.overlays`, as in The One Nix and the [Home Manager manual](https://nix-community.github.io/home-manager/nix-flakes/nixos.html):

```nix
{ inputs, self }:
{
  mkNixos = { hostname, username, system ? "x86_64-linux", extraModules ? [ ] }:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs self hostname username; };
      modules = [
        {
          nixpkgs.hostPlatform = system;
          nixpkgs.overlays = builtins.attrValues self.overlays;
          nixpkgs.config.allowUnfree = true;
        }
        ../hosts/${hostname}
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "hm-bak"; # existing ~/.bashrc etc. would otherwise abort activation
            extraSpecialArgs = { inherit inputs self hostname username; };
            users.${username} = ../home/${username};
          };
        }
      ] ++ extraModules;
    };
}
```

**`hosts/wsl/default.nix`**. Per-host Home Manager additions merge into the same user, because `home-manager.users.<name>` is a submodule:

```nix
{ hostname, username, ... }:
{
  imports = [
    ../../modules/nixos/common
    ../../modules/nixos/wsl
    ../../modules/nixos/docker.nix
  ];
  networking.hostName = hostname;          # also feeds wsl.conf [network] hostname
  time.timeZone = "America/Toronto";       # FIXME
  system.stateVersion = "26.05";           # = /etc/nixos/configuration.nix of the stock image; never bump
  home-manager.users.${username}.imports = [ ../../home/${username}/wsl.nix ];
}
```

**`modules/nixos/common/default.nix`** is portable to any NixOS host. Pick **one** garbage collector. Here it is nh's `clean`, so `nix.gc` stays off ([nh](https://github.com/nix-community/nh)):

```nix
{ pkgs, username, ... }:
{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" username ];   # NixOS-WSL #1024
    auto-optimise-store = true;
  };
  programs.nh = {
    enable = true;
    clean = { enable = true; extraArgs = "--keep-since 14d --keep 5"; };
    flake = "/home/${username}/git/irish1986/nix"; # sets NH_FLAKE
  };
  programs.zsh.enable = true;
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };
  environment.enableAllTerminfo = true;
  environment.systemPackages = with pkgs; [ git vim wget curl ];
}
```

**`modules/nixos/wsl/default.nix`** is The One Nix's module plus the upstream VS Code fix and the starter's PATH hygiene:

```nix
{ inputs, pkgs, username, ... }:
{
  imports = [ inputs.nixos-wsl.nixosModules.default ];

  wsl = {
    enable = true;
    defaultUser = username;
    startMenuLaunchers = true;                       # also picks up HM apps since 2605 (#960)
    wslConf.interop.appendWindowsPath = false;       # no 9P lookups in every completion; add .exe by path
    ssh-agent.enable = true;                         # bridge to the Windows OpenSSH agent (2605+)
    # interop.register = true;                       # uncomment if `code`/.exe fail to launch (Discussion #945)
    # wslConf.boot.initTimeout = 30000;              # only if user session times out (#888); branch-only option
  };

  programs.nix-ld.enable = true;                     # VS Code/Cursor server node binary needs /lib64 loader
  environment.systemPackages = [ pkgs.wget ];        # required by the VS Code server bootstrap
}
```

**`modules/nixos/docker.nix`** and **`overlays/default.nix`**:

```nix
# modules/nixos/docker.nix
{ username, ... }:
{
  virtualisation.docker = { enable = true; autoPrune.enable = true; };
  users.users.${username}.extraGroups = [ "docker" ]; # the starter left this as a FIXME
}

# overlays/default.nix
{ inputs, ... }:
{
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };
}
```

Growing the repo then only adds files. A bare-metal NixOS host gets `hosts/<name>/{default.nix,hardware-configuration.nix}` and a bootloader, imports `modules/nixos/common` but not `modules/nixos/wsl`, and registers with one `mkNixos` line. NixOS-WSL hosts never have a `hardware-configuration.nix` ([Discussion #605](https://github.com/nix-community/NixOS-WSL/discussions/605)). A Mac needs a `nix-darwin` input, a `mkDarwin` that calls `darwinSystem` with `home-manager.darwinModules.home-manager` and the same `home-manager` block, and `modules/darwin/`. The exact nix-darwin 26.05 branch name was not verified in this research. **26.05 is the last release that supports x86_64-darwin**, so an Intel Mac would stall on 26.05 while everything else moves on ([NixOS 26.05 announcement](https://nixos.org/blog/announcements/2026/nixos-2605/)). Revisit flake-parts (with easy-hosts) once there are three or more hosts or darwin joins. Until then the `lib/` builder is enough.

## Native Linux tooling wins, except for SSH keys and the editor

The defaults below choose native Nix-managed tools over Windows bridges wherever the bridge has a history of breaking. The two exceptions are SSH keys and the editor: there, the Windows side is the source of truth, and NixOS-WSL now has first-class support.

**VS Code and its forks.** The Remote-WSL server downloads a dynamically linked node that expects `/lib64/ld-linux-x86-64.so.2`. Upstream's recommended fix is `programs.nix-ld.enable = true` plus `wget`, which is "more robust but might impact other programs". K900's workaround module is the alternative that "sometimes breaks on updates" ([vscode how-to](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/how-to/vscode.md)). The same fix covers Cursor and other VS Code forks, because they all fetch a node server. With `appendWindowsPath = false`, `code .` needs an alias to the absolute path of the Windows `code` script, and some users also needed `wsl.interop.register = true` before `code` would launch ([Discussion #945](https://github.com/nix-community/NixOS-WSL/discussions/945)). One open issue is that the VS Code server ignores the user's default shell ([#579](https://github.com/nix-community/NixOS-WSL/issues/579)), so set the integrated terminal profile in VS Code itself.

**Docker.** Use native `virtualisation.docker`. Docker Desktop integration has broken repeatedly because it assumes an FHS distro. Version 4.45 called `whoami` outside `$PATH` ([docker/for-win #14931](https://github.com/docker/for-win/issues/14931)), and 4.80+ needs `install`/`mv` binaries that only NixOS-WSL `main` provides ([#1081](https://github.com/nix-community/NixOS-WSL/issues/1081)). If Docker Desktop is already in use for the Ubuntu distro, leave its WSL integration **off** for NixOS so that two daemons don't compete for `/var/run/docker.sock`. If you must enable it, set `wsl.docker-desktop.enable = true` and add `{ src = "${pkgs.coreutils}/bin/install"; }` and `{ src = "${pkgs.coreutils}/bin/mv"; }` to `wsl.extraBin`, which replicates the main-only fix.

**Git and SSH.** The repo remote is `git@github.com:irish1986/nix.git` (SSH). The cleanest setup is to load the key into the Windows OpenSSH agent and set `wsl.ssh-agent.enable = true`. That runs `wsl2-ssh-agent` as a user service and exports `SSH_AUTH_SOCK`, so native Linux `ssh`, git and Nix fetches all see the key ([modules/ssh-agent.nix](https://github.com/nix-community/NixOS-WSL/blob/main/modules/ssh-agent.nix)), and the Ubuntu distro can share the same agent. 1Password's official WSL method, `core.sshCommand ssh.exe`, does *not* give Linux tools an agent socket ([1Password WSL](https://www.1password.dev/ssh/integrations/wsl)). For HTTPS remotes, point `credential.helper` at Windows' `git-credential-manager.exe` by absolute path ([GCM wsl.md](https://github.com/git-ecosystem/git-credential-manager/blob/main/docs/wsl.md)). One related point: rebuild unprivileged. `nh os switch`, or `nixos-rebuild switch --sudo` as used in upstream issue reports ([#1109](https://github.com/nix-community/NixOS-WSL/issues/1109)), evaluates and fetches as your user and elevates only for activation. That keeps your agent available for private inputs and avoids the slow single-threaded builds one user saw under `sudo nixos-rebuild` ([Discussion #619](https://github.com/nix-community/NixOS-WSL/discussions/619)).

**Home Manager content.** `home/irish/default.nix` carries the portable environment. `wsl.nix` carries the Windows glue:

```nix
# home/irish/default.nix — portable (NixOS module now, darwin/standalone later)
{ pkgs, inputs, ... }:
{
  imports = [ inputs.nix-index-database.homeModules.nix-index ./git.nix ./shell.nix ];
  home.stateVersion = "26.05";                     # HM release at first activation; never bump
  home.packages = with pkgs; [ ripgrep fd jq bat dust htop gh just ]; # dust, not du-dust
  programs.direnv = { enable = true; nix-direnv.enable = true; };
  programs.nix-index-database.comma.enable = true;
}

# home/irish/git.nix — HM 26.05 option names
{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "Simon Harvey";
      user.email = "you@example.com";              # FIXME
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };
  programs.delta = { enable = true; enableGitIntegration = true; }; # delta is its own module in 26.05; verify option name
}

# home/irish/shell.nix
{ ... }:
{
  programs.zsh.enable = true;
  programs.starship.enable = true;
  programs.fzf.enable = true;
  programs.zoxide.enable = true;                   # plain `z`; don't hijack `cd` like the starter
}

# home/irish/wsl.nix — WSL-only glue
{ ... }:
let win = "/mnt/c/Users/FIXME-WINDOWS-USER"; in
{
  home.shellAliases = {
    pbcopy   = "/mnt/c/Windows/System32/clip.exe";
    pbpaste  = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command Get-Clipboard";
    explorer = "/mnt/c/Windows/explorer.exe";
    code     = "'${win}/AppData/Local/Programs/Microsoft VS Code/bin/code'";
  };
  home.sessionVariables.BROWSER = "/mnt/c/Windows/explorer.exe";
  # HTTPS remotes only:
  # programs.git.settings.credential.helper = "/mnt/c/Program\\ Files/Git/mingw64/bin/git-credential-manager.exe";
}
```

**Secrets.** Start with none in the repo. When you need them, use sops-nix with age. On WSL, use an explicit `sops.age.keyFile` rather than the SSH host key, since sshd is usually off there ([sops-nix](https://github.com/Mic92/sops-nix)). The One Nix deliberately defers sops on WSL until it has decided how the key reaches the distro from Windows. That is a reasonable position for now.

## The build plan, phase by phase

### Phase 0 — Prepare Windows (once, about 20 minutes)

| Step | Where | Command / action | Why |
|---|---|---|---|
| 0.1 | PowerShell | `wsl --update` then `wsl --version` | NixOS-WSL is tested on the Store WSL; `.wsl` install needs ≥ 2.4.4; recovery needs a current WSL ([#1021](https://github.com/nix-community/NixOS-WSL/issues/1021)) |
| 0.2 | PowerShell | `wsl --list --verbose` | Confirm Ubuntu is still there; it shares the VM and `.wslconfig` with NixOS |
| 0.3 | `%UserProfile%\.wslconfig` | Set `[wsl2] memory=`, `processors=`, `swap=`; `[experimental] sparseVhd=true`. Add `networkingMode=mirrored` only for VPN/localhost needs on Windows 11 22H2+ | Defaults are 50% of RAM and all cores; `autoMemoryReclaim` already defaults to `dropCache` ([MS wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)). Mirrored mode changes Ubuntu's networking too |
| 0.4 | Windows | Install VS Code + WSL extension, Windows Terminal, a Nerd Font; start the `ssh-agent` service and `ssh-add` your GitHub key | The terminal renders fonts; the Windows agent feeds `wsl.ssh-agent` |
| 0.5 | PowerShell | Download `nixos.wsl` and `nixos.wsl.sha256` from [2605.7.2](https://github.com/nix-community/NixOS-WSL/releases/tag/2605.7.2); compare `(Get-FileHash .\nixos.wsl).Hash` | About 578 MB; use `nixos.aarch64.wsl` on Snapdragon |

### Phase 1 — Author the skeleton in the repo you already have

Write the files from the previous section in the existing Ubuntu checkout at `/home/irish/git/irish1986/nix`, then `git add -A` and push. Flakes only see git-tracked files, which is the most common "No such file or directory" trap ([nix-starter-configs](https://github.com/Misterio77/nix-starter-configs); [starter #17](https://github.com/LGUG2Z/nixos-wsl-starter/issues/17)). Ubuntu has no Nix, so evaluation first happens inside NixOS. Do not commit `flake.lock` yet. It is generated on the first build.

### Phase 2 — Install the stock image

```powershell
wsl --install --from-file .\nixos.wsl --name NixOS --location D:\WSL\NixOS
wsl -d NixOS
```

`--name` and `--location` are documented upstream. The default location is `%localappdata%\wsl\{GUID}` ([install.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/install.md)). On WSL older than 2.4.4, use `wsl --import NixOS D:\WSL\NixOS .\nixos.wsl --version 2` instead.

### Phase 3 — First boot and cutover to the flake (the delicate part)

| Step | Where | Command | Why |
|---|---|---|---|
| 3.1 | NixOS (user `nixos`) | `nixos-wsl-version; grep stateVersion /etc/nixos/configuration.nix` | Confirm 2605.x and that stateVersion is `"26.05"`; copy that exact value into `hosts/wsl` |
| 3.2 | NixOS | `sudo nix-channel --update` | Upstream's required first step; it makes `nix-shell -p` work ([install.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/install.md)) |
| 3.3 | NixOS | `nix-shell -p git --run "git clone https://github.com/irish1986/nix.git /tmp/nix"` | No SSH key in the distro yet. For a private repo, run `git bundle create /mnt/c/Users/<you>/nix.bundle --all` in Ubuntu and clone the bundle |
| 3.4 | NixOS | `cd /tmp/nix && sudo env NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild boot --flake .#wsl` | **`boot`, not `switch`**. Upstream requires this when `wsl.defaultUser` changes ([change-username.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/how-to/change-username.md)), and it also avoids the `/bin/true` abort on the old image. The explicit `#wsl` is needed because the hostname is still `nixos` |
| 3.5 | PowerShell | `wsl -t NixOS; wsl -d NixOS --user root exit; wsl -t NixOS` | Applies the new generation as root, then restarts |
| 3.6 | PowerShell | `wsl -d NixOS` then `whoami; hostname; echo $SSH_AUTH_SOCK` | Expect `irish`, `wsl` and a `wsl2-ssh-agent.sock` path |
| 3.7 | NixOS (`irish`) | `mkdir -p ~/git/irish1986 && git clone git@github.com:irish1986/nix.git ~/git/irish1986/nix` | Clone via the bridged agent; the repo now sits at the same path as in Ubuntu |
| 3.8 | NixOS | `cd ~/git/irish1986/nix && nh os switch` | First real `switch`, now on the branch with `/bin/true`. Commit and push `flake.lock` |
| 3.9 | NixOS | `ls /home` and remove `/home/nixos` once empty of anything useful | Upstream does not migrate or delete the old home |

If 3.8 still fails on `wsl-mnt-guard`, add the upstream pre-fix drop-in to `modules/nixos/wsl`: `systemd.services."wsl-mnt-guard" = { overrideStrategy = "asDropin"; unitConfig.ConditionPathIsMountPoint = "/mnt/wsl"; serviceConfig = { ExecStart = [ "" "${pkgs.coreutils}/bin/true" ]; ExecStop = [ "" "-${pkgs.util-linux}/bin/mount --make-rslave /mnt/wsl" ]; }; };` ([#1100](https://github.com/nix-community/NixOS-WSL/issues/1100)). If the old channel-era `imports = [ <nixos-wsl/modules> ]` ever shows up in an error, it is a leftover from `/etc/nixos`. The flake must use only `inputs.nixos-wsl.nixosModules.default` ([#1071](https://github.com/nix-community/NixOS-WSL/issues/1071)). Whether to make NixOS the default distro (`wsl -s NixOS`) can wait until it has replaced Ubuntu for daily work.

### Phase 4 — Home Manager

Home Manager is already active from Phase 3, because `mkNixos` imports it. This phase is where you move your environment over. Copy settings from Ubuntu dotfiles into `home/irish/*.nix` one tool at a time and rebuild after each one. Expect `*.hm-bak` files the first time Home Manager meets an existing dotfile, and delete them once you have checked them. Keep anything Windows-specific in `wsl.nix` so the same `home/irish` imports cleanly on a Mac later. The two version knobs, `system.stateVersion` and `home.stateVersion`, both stay at `"26.05"` for the life of this install.

### Phase 5 — Dev tooling acceptance tests

| Check | Command | Pass condition / fix |
|---|---|---|
| Windows interop | `cmd.exe /c ver` (by path if needed: `/mnt/c/Windows/System32/cmd.exe`) | Prints a Windows version. If "exec format error", set `wsl.interop.register = true` |
| VS Code | `code .` in the repo | Remote window opens. "Could not start dynamically linked executable" means nix-ld is missing: check `ls /lib64/ld-linux-x86-64.so.2`. For connection issues, `"remote.WSL2.connectionMethod": "wsl2VMAddress"` on Windows ([Discussion #92](https://github.com/nix-community/NixOS-WSL/discussions/92)) |
| SSH | `ssh -T git@github.com` | Greets `irish1986` via the Windows agent |
| Docker | `docker run --rm hello-world` | Works without sudo once you have logged in again after joining the `docker` group |
| direnv | `echo 'use flake' > .envrc && direnv allow` in a project with `devShells` | Shell loads; `nix-direnv` caches it |
| Clipboard | `echo hi \| pbcopy` | Pasted on Windows. For Unicode or Neovim, prefer `win32yank.exe` |
| Repos on ext4 | Keep code under `~` | Accessing `/mnt/c` crosses filesystems and is slow ([MS filesystems](https://learn.microsoft.com/en-us/windows/wsl/filesystems)) |

### Phase 6 — Maintenance rhythm and CI

Run `nix flake update`, then `nh os switch` weekly, and commit the lock. nh builds as your user and shows a closure diff before activating ([nh](https://github.com/nix-community/nh)). When a `switch` refuses ("Switching into this system is not recommended", for example on a dbus change) or user units fail to reload, the maintainer-endorsed fallback is `nh os boot` followed by `wsl -t NixOS` from Windows ([#1039](https://github.com/nix-community/NixOS-WSL/issues/1039)). Some problems clear only after a full `wsl --shutdown` ([troubleshooting](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/troubleshooting/README.md)). Run `nix fmt` before committing.

Add two GitHub Actions workflows. `check.yml` runs on every push: `actions/checkout@v6`, `DeterminateSystems/determinate-nix-action@v3`, then `nix flake check -L`. Because `checks.x86_64-linux.wsl` is the WSL toplevel, this builds the whole system on an ubuntu-latest runner. `update.yml` runs `DeterminateSystems/update-flake-lock` on a weekly cron. PRs opened by Actions do not trigger other workflows unless you pass a PAT as `token` ([update-flake-lock](https://github.com/DeterminateSystems/update-flake-lock)). Each lock bump then arrives as a PR that CI has already built. Before updating WSL itself on Windows, take a quick export (Phase 8), because the open drive-mount regression appeared "since last upgrade" ([#1112](https://github.com/nix-community/NixOS-WSL/issues/1112)).

### Phase 7 — Upgrade to 26.11 before 26.05 expires on 2026-12-31

NixOS 26.11 "Zokor" is expected in late November, and 26.05 support ends on 2026-12-31 ([NixOS 26.05 announcement](https://nixos.org/blog/announcements/2026/nixos-2605/); [endoflife.date](https://endoflife.date/nixos)). In past releases the NixOS-WSL tag lagged the NixOS release by 3–9 months, so wait for the **`release-26.11` branch**, not a 2611 tag. Check with `git ls-remote https://github.com/nix-community/NixOS-WSL 'refs/heads/release-*'`. If the branch has not appeared by mid-December, you can stay on 26.05 until the 31st. Moving NixOS-WSL to `main` on stable nixpkgs is the riskier fallback, because `main` already diverges, for example in bootspec handling ([#1071](https://github.com/nix-community/NixOS-WSL/issues/1071)).

| Step | Command / action |
|---|---|
| 7.1 | `git switch -c upgrade-26.11`; take a Phase 8 export |
| 7.2 | Edit three URLs: `nixos-26.11`, `home-manager/release-26.11`, `NixOS-WSL/release-26.11` (and nix-darwin's 26.11 branch if a Mac exists by then) |
| 7.3 | `nix flake update` then `nix build .#nixosConfigurations.wsl.config.system.build.toplevel`. Fix renames and removals; read the NixOS 26.11 release notes and `home-manager news` |
| 7.4 | `nh os boot`, then from Windows `wsl -t NixOS`, reopen, re-run the Phase 5 checks |
| 7.5 | Merge to `main`. **Leave both stateVersions at "26.05"**: they record the original install, not the running release |

### Phase 8 — Backup and recovery, from cheapest to heaviest

The flake in git defines the system, so you can rebuild the OS from it. What needs backing up is state: `~`, Docker volumes and anything not under version control. Work through the layers from the top.

| Layer | When | How |
|---|---|---|
| Generation rollback | A bad rebuild that still boots | `sudo nixos-rebuild switch --rollback`, or `nh os switch` on the previous commit |
| Recovery shell | The distro won't start | `wsl -d NixOS --system --user root -- /mnt/wslg/distro/bin/nixos-wsl-recovery`, adding `--system /nix/var/nix/profiles/system-42-link` to activate an older generation ([recovery-shell.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/troubleshooting/recovery-shell.md)). If it reports "bad interpreter", first run `wsl -d NixOS --system --user root -- /bin/sh -c "mkdir -p /nix && mount --bind /mnt/wslg/distro/nix /nix"` ([#1042](https://github.com/nix-community/NixOS-WSL/issues/1042)) |
| Bypass a broken shell | Login environment is broken | `wsl -d NixOS --user root --exec /run/current-system/sw/bin/sh`, then `export PATH=/run/current-system/sw/bin:/run/current-system/sw/sbin` ([#846](https://github.com/nix-community/NixOS-WSL/issues/846)) |
| Full snapshot | Before upgrades and WSL updates, and monthly | `wsl --terminate NixOS; wsl --export NixOS D:\backups\nixos-YYYY-MM-DD.vhdx --vhd`. Test-restore it as a separate instance: `wsl --import NixOS-restore D:\WSL\NixOS-restore <file> --vhd` ([MS basic commands](https://learn.microsoft.com/en-us/windows/wsl/basic-commands)). NixOS-WSL does not test this path upstream, so do one restore drill |
| Re-image from the flake | Clean rebuild, a second PC, or disaster | Inside NixOS: `sudo nix run .#nixosConfigurations.wsl.config.system.build.tarballBuilder` writes `nixos.wsl` with `irish` already set, so no username sequence is needed ([building.md](https://github.com/nix-community/NixOS-WSL/blob/main/docs/src/building.md)). Install with `wsl --install --from-file`, then restore `~` from the export |
| Disk hygiene | VHDX grows | `nh clean all` → `sudo fstrim -av` → `wsl --shutdown` → `Optimize-VHD` (needs Hyper-V tools; one user reclaimed 400 GB, [Discussion #1104](https://github.com/nix-community/NixOS-WSL/discussions/1104)), or `wsl --manage NixOS --set-sparse true` |

## Conclusion

The three sources look like competing templates, but they fit together. Upstream decides which branch and options are real. The starter supplies the helper function. The One Nix supplies the repo shape and the one idea worth keeping for later, building your own `nixos.wsl` from the flake. Here that idea is used as a recovery and re-imaging tool rather than as the install path, because a Windows-only machine needs the stock image to bootstrap anyway. The strongest lesson is how fast this stack drifts. A seventeen-month-old template no longer evaluates, the newest tag can't `switch` on the newest WSL, and the docs site describes a branch you shouldn't run. The defence is structural: pin release branches rather than tags, let CI build every lock bump, and keep host facts out of shared modules.

Two choices carry most of the risk and are easy to get right now. First, run the user cutover as a `boot` followed by a WSL restart, which avoids both the username misconfiguration and the `/bin/true` failure. Second, treat the 26.11 bump in November–December as a dress rehearsal for every future upgrade, while the repo is still small. The remaining uncertainty sits with Microsoft rather than Nix: WSL 3.0's pace and the open user-session and drive-mount regressions mean a `wsl --export` before each Windows-side update costs little, and is the cheapest way to recover from a bad one.
