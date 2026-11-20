# Research: NixOS-WSL + comin + bootstrap (nixos-anywhere check)

- **Date:** 2026-11-19
- **Scope:** git-based NixOS flake for a WSL2 workstation on Windows 11, redeployable identically on any Windows 11 + WSL2 machine, synced pull-based with comin. Windows-side setup out of scope. Input for later ADRs/specs/how-to; this is **not** a how-to.
- **Method:** primary sources only (repo source at pinned commits, official docs, release notes, maintainer comments). Secondary sources are flagged. Statements marked **[inference]** are my reading of source code and not stated by the project; statements marked **[verify]** need hands-on confirmation.
- **Source snapshots used** (permalinks below point at these):
  - NixOS-WSL `main` @ [`05721a4`](https://github.com/nix-community/NixOS-WSL/tree/05721a428830972f025a8575b1a19c418d422d1b) (2026-11-11); latest release [`2605.7.2`](https://github.com/nix-community/NixOS-WSL/releases/tag/2605.7.2) (2026-06-06).
  - comin `main` @ [`c847682`](https://github.com/nlewo/comin/tree/c84768279d6c8cd0cb26c2a367890f5e63776b9e) (2026-11-18); latest release [`v0.14.0`](https://github.com/nlewo/comin/releases/tag/v0.14.0) (2026-07-19).
  - nixos-anywhere `main` @ [`58132e1`](https://github.com/nix-community/nixos-anywhere/tree/58132e1d1f813b845382a2aeca4203b18d2ac807) (2026-10-28); latest release [`1.13.0`](https://github.com/nix-community/nixos-anywhere/releases/tag/1.13.0) (2025-11-13).
  - Microsoft WSL: latest release [`3.0.5`](https://github.com/microsoft/WSL/releases/tag/3.0.5) (2026-11-03); WSL kernel [`linux-msft-wsl-6.18.58.1`](https://github.com/microsoft/WSL2-Linux-Kernel/releases/tag/linux-msft-wsl-6.18.58.1) (2026-10-27).

Shorthand used in links: `NWSL` = `https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b`, `COMIN` = `https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e`, `NA` = `https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807` (all links below are written out in full).

---

## TL;DR / verdicts

1. **nixos-anywhere cannot be used to install NixOS into WSL2. Verdict: not applicable as a target-side bootstrap.** It works by kexec-ing into an installer, wiping disks with disko, running `nixos-install` and rebooting ([README](https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807/README.md#L44-L52), [`--phases` default `kexec,disko,install,reboot`](https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807/src/nixos-anywhere.sh#L28-L31)). A WSL2 distro has no kernel, bootloader or disk of its own: NixOS-WSL disables all of them ([wsl-distro.nix L114-121](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-distro.nix#L114-L121)). nixos-anywhere itself sees WSL as a container (`systemd-detect-virt --container` → `wsl`) and warns that "kexec will likely not work" ([nixos-anywhere.sh L705-707](https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807/src/nixos-anywhere.sh#L705-L707)). Where the belief probably comes from: nixos-anywhere lists "Windows systems using WSL2" as a supported **source** machine, meaning the machine you run the deploy from, not the target ([docs/requirements.md L12-16](https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807/docs/requirements.md#L12-L16)).
2. **Recommended bootstrap (both manual, both from NixOS-WSL's official docs):**
   - **Path A, for learning and the first machine:** install the stock `nixos.wsl` release, then run `sudo nixos-rebuild … --flake <your repo>#<host>` once, then hand over to comin.
   - **Path B, the repeatable "golden image" for every machine:** build your own `nixos.wsl` from your flake with `sudo nix run .#nixosConfigurations.<host>.config.system.build.tarballBuilder` ([building.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/building.md)), then `wsl --install --from-file` it on each Windows machine. B is the closest thing to "identical on any machine". It is also the path a NixOS-WSL maintainer recommends when a corporate TLS-intercepting CA must be present from first boot ([NixOS-WSL#918](https://github.com/nix-community/NixOS-WSL/issues/918)).
3. **comin works on any systemd NixOS, but has one significant WSL-specific gap [inference from source, verify].**
   - comin records `switch` and `boot` deployments in its own profile, `/nix/var/nix/profiles/system-profiles/comin` ([profile.go L14-18, L85-113](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/profile/profile.go#L14-L113)). It never touches `/nix/var/nix/profiles/system`.
   - NixOS-WSL's boot shim always activates `/nix/var/nix/profiles/system/activate` when the distro starts ([shim.rs L94](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/utils/src/shim.rs#L94-L100)).
   - So after every distro restart (idle shutdown, `wsl --shutdown`, Windows reboot), the system would likely fall back to the last **`nixos-rebuild`** generation.
   - comin would then **not** redeploy. It skips a deployment whose out-path and operation match its persisted last deployment ([deployer.go L170-186](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/deployer/deployer.go#L170-L186)).
   - The same class of bug has already been reported for lanzaboote, which also only reads the `system` profile ([comin#144](https://github.com/nlewo/comin/issues/144), [comin#86](https://github.com/nlewo/comin/issues/86)).
   - comin `boot` operations, and `switch` operations that switch inhibitors downgrade to `boot` ([comin PR #156](https://github.com/nlewo/comin/pull/156)), would likely **never** take effect on WSL.
   - **This must be tested before any ADR commits to comin-on-WSL.**
4. **comin needs the distro running.** WSL stops idle distros: `instanceIdleTimeout` defaults to 15 s and `vmIdleTimeout` to 60 s ([wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config), source [MicrosoftDocs L248, L283](https://github.com/MicrosoftDocs/WSL/blob/526e57752f7241dc7e98f14b1033905e8e675587/WSL/wsl-config.md#L248)). Microsoft states that "systemd services will NOT keep your WSL instance alive" ([systemd.md](https://learn.microsoft.com/en-us/windows/wsl/systemd)). comin therefore only polls while you have a session open, or while some Windows-side mechanism keeps the distro alive. That mechanism is out of scope.
5. **Version pins (as of 2026-11-19):** nixpkgs `nixos-26.05`; NixOS-WSL `release-26.05` (which tracks `nixos-26.05`); comin `v0.14.0`. At `v0.14.0` the module is exported as `nixosModules.comin`. `nixosModules.default` exists **only on `main` since 2026-11-06** ([commit cd4c473](https://github.com/nlewo/comin/commit/cd4c473)), even though the README on `main` now uses `.default`. home-manager `release-26.05` is optional. NixOS 26.11 has not been branched in nixpkgs as of this date (only `nixos-26.05`/`nixos-unstable` heads exist).
6. **Security headline points:**
   - The stock NixOS-WSL gives the default user passwordless sudo and makes that user a Nix trusted user ([wsl-distro.nix L181-191](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-distro.nix#L181-L191)).
   - Windows interop and Windows `PATH` appending are **on** by default ([wsl-conf.nix L77-88](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-conf.nix#L77-L88)).
   - The NixOS firewall service is disabled on WSL ([systemd/default.nix L19](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/systemd/default.nix#L19)).
   - comin's Prometheus exporter listens on **all interfaces, port 4243** by default ([module-options.nix L130-143](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module-options.nix#L130-L143)).
   - comin supports GPG and SSH commit-signature verification, but checks only the **tip** commit ([howtos.md L65-84](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/howtos.md#L65-L84)).

---

## 1. NixOS-WSL installation (current state)

### Release and artifact format
- **Latest release:** [`2605.7.2` "Yearning Yarara"](https://github.com/nix-community/NixOS-WSL/releases/tag/2605.7.2), published 2026-06-06.
  - Assets: `nixos.wsl`, `nixos.aarch64.wsl` and `.sha256` files for each.
  - aarch64 builds were added in this release (#990).
- **File format history:** releases have shipped a **`.wsl`** file since `2411.6.0`, which "is the first one to ship as a `.wsl` file" ([2411.6.0 notes](https://github.com/nix-community/NixOS-WSL/releases/tag/2411.6.0)). Before that the artifact was `nixos-wsl.tar.gz` ([install.md footnote](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/install.md)).
  - The `.wsl` file is a gzip'd tar: the builder pipes `tar … | pigz > "$out"` with `out="nixos.wsl"` ([build-tarball.nix L90-91, L176-184](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/build-tarball.nix#L90-L184)).
  - It also contains `/etc/wsl-distribution.conf`, which sets the default name `NixOS` and an icon ([build-tarball.nix L9-14, L163-165](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/build-tarball.nix#L9-L14)).
- **Which nixpkgs a release tracks:** the tag `2605.7.2` and branch `release-26.05` both pin `nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05"`, while `main` pins `nixos-unstable` ([main flake.nix L5](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/flake.nix#L5)).
  - Release branches that exist: `release-24.11`, `release-25.05`, `release-25.11`, `release-26.05` (from `git ls-remote`, 2026-11-19).
  - The tarball adds a `nixos-wsl` channel that points at the matching branch: `main` if built from unstable, otherwise `release-<ver>` ([build-tarball.nix L16-25, L158-161](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/build-tarball.nix#L16-L25)).
  - The release notes give the channel commands for moving between releases ([2605.7.2 notes](https://github.com/nix-community/NixOS-WSL/releases/tag/2605.7.2)).

### WSL version requirements
- Tested with the **Microsoft Store version of WSL 2**. Older "inbox" versions are supported on a best-effort basis only ([install.md L5-6](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/install.md#L5)).
- Installing by double-clicking the file, or with `wsl --install --from-file nixos.wsl`, requires **WSL ≥ 2.4.4**. `--name` and `--location` override the default name (`NixOS`) and the VHD location (default `%localappdata%\wsl\{GUID}`) ([install.md L9-22](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/install.md#L9-L22), [README](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/README.md)).
- On WSL < 2.4.4, use `wsl --import NixOS $env:USERPROFILE\NixOS nixos.wsl --version 2` ([install.md L25-38](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/install.md#L25-L38)).
- The troubleshooting page says to update with `wsl --update` and to check the version with `wsl --version` ([troubleshooting/README.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/troubleshooting/README.md)).
- Observed on the research host, not a requirement: WSL 3.0.5.0, kernel 6.18.58.1.

### Default user and first boot
- **Default user is `nixos`**, a member of `wheel`, with uid `mkDefault 1000` ([wsl-distro.nix L71-75, L175-179](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-distro.nix#L71-L179)).
  - The user has **no password**, and `security.sudo.wheelNeedsPassword = mkDefault false` ([L191](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-distro.nix#L191)).
  - WSL's `[user] default` is set to this user ([systemd/native/default.nix L46-51](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/systemd/native/default.nix#L46-L51)).
- **Post-install steps in the docs** ([install.md L53-75](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/install.md#L53-L75)):
  - Set a password with `passwd`. This is only needed if you enable `wheelNeedsPassword`.
  - Run `sudo nix-channel --update` once before `nixos-rebuild`.
  - Optionally run `wsl -s NixOS`.
  - **Doc inconsistency:** install.md says `wheelNeedsPassword = true` "is the default". That is NixOS's default, but NixOS-WSL overrides it to `false` (see above).
- **The stock image is channel-based, not flake-enabled.** The default `nixosConfigurations` sets `nixpkgs.flake.source = lib.mkForce null` and creates root channels. Its comment says: "Per default the resulting systems aren't flake-enabled, so rebuilds would fail" ([flake.nix L44-67](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/flake.nix#L44-L67)).
  - The generated `/etc/nixos/configuration.nix` imports `<nixos-wsl/modules>` and pins `system.stateVersion` to the image's release ([build-tarball.nix L27-54](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/build-tarball.nix#L27-L54)).
- **Recovery:** `wsl -d NixOS --system --user root -- /mnt/wslg/distro/bin/nixos-wsl-recovery` chroots into the system. With `--system /nix/var/nix/profiles/system-42-link` it boots an older generation ([recovery-shell.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/troubleshooting/recovery-shell.md), [recovery.nix](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/recovery.nix)). There is **no boot menu** for rollbacks; the open feature request is [NixOS-WSL#396](https://github.com/nix-community/NixOS-WSL/issues/396).

### Renaming the default user
- Set `wsl.defaultUser`. When you build your own tarball, that is all you need: the user is created automatically.
- **On an already-installed system the procedure is strict** ([change-username.md L7-19](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/how-to/change-username.md#L7-L19)):
  - Edit the config, then run `sudo nixos-rebuild boot`. "**Do not use `nixos-rebuild switch`!** It may lead to the new user account being misconfigured."
  - Then: `wsl -t NixOS` → `wsl -d NixOS --user root exit` → `wsl -t NixOS` → open a new shell.
- Implication for the bootstrap: if the flake sets a non-`nixos` user, the **first** flake activation on a stock image must use `boot`, not `switch`. A custom tarball (Path B) avoids this entirely.

### Converting to a flake-based config
- **The official how-to** says: add a `nixos-wsl` input and `nixos-wsl.nixosModules.default` ([nix-flakes.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/how-to/nix-flakes.md)).
  - Its example uses `nixos-unstable` + `NixOS-WSL/main` and `stateVersion = "25.05"`.
  - The `release-26.05` copy of the doc is identical, i.e. it does not use a release branch.
  - Maintainers acknowledge the flake docs are "very bare-bones" ([NixOS-WSL#604](https://github.com/nix-community/NixOS-WSL/issues/604)).
- **`nixos-rebuild --flake`**:
  - It defaults to `/etc/nixos/flake.nix` if that exists. If `#name` is omitted, it uses the current hostname ([nixos-rebuild(8), nixos-26.05](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/by-name/ni/nixos-rebuild-ng/nixos-rebuild.8.scd#L301-L306)).
  - Flakes must be enabled on the stock image first (`nix.settings.experimental-features`), because the image is not flake-enabled (see above).
  - Private repos need git credentials or Nix `access-tokens` ([nix.conf `access-tokens`](https://nix.dev/manual/nix/latest/command-ref/conf-file.html#conf-access-tokens)).
- **`switch` vs `boot` on WSL:**
  - `system.build.installBootLoader` is `true`, i.e. a no-op ([wsl-distro.nix L121](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-distro.nix#L121)).
  - Both commands update `/nix/var/nix/profiles/system`.
  - At every distro start the shim remounts `/nix/store` read-only, runs `/nix/var/nix/profiles/system/activate`, then execs that profile's systemd ([shim.rs L55-122](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/utils/src/shim.rs#L55-L122)).
  - So `boot` takes effect at the next distro start (`wsl -t NixOS`), not at a Windows reboot.

---

## 2. NixOS-WSL module: options and limitations

**Rendered options reference:** <https://nix-community.github.io/NixOS-WSL/options.html>. The source modules are listed in [modules/default.nix](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/default.nix).

### Key options

| Option | Default | Notes / source |
|---|---|---|
| `wsl.enable` | false | Enables everything below. It disables `boot.initrd`, `boot.kernel`, GRUB and modprobe config, `console`, `dhcpcd`, `timesyncd` and `powerManagement` ([wsl-distro.nix L113-191, L255-256](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-distro.nix#L113-L256)). |
| `wsl.defaultUser` | `"nixos"` | See §1 ([L71-75](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-distro.nix#L71-L75)). |
| `wsl.useWindowsDriver` | false | Uses the Windows host GPU/OpenGL/CUDA libraries from `/usr/lib/wsl/lib` via `hardware.graphics.extraPackages` ([L8-58, L126-130](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-distro.nix#L8-L58)). |
| `wsl.startMenuLaunchers` | false | rsyncs `.desktop` files and icons from the system, per-user (home-manager) and `~/.nix-profile` into `/usr/share` so that WSLg shows them in the Windows Start Menu ([L194-218](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-distro.nix#L194-L218)). Open bug: new per-user packages are only picked up on the next rebuild ([#1116](https://github.com/nix-community/NixOS-WSL/issues/1116)). |
| `wsl.extraBin` | list | Files placed in `/bin` for WSL's own tooling (`wslpath`, `sh`, `mount`, `bash`, `true`, `login`) ([L88-109, L232-242](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-distro.nix#L232-L242)). |
| `wsl.wslConf.*` | see right | Freeform INI rendered to `/etc/wsl.conf` ([wsl-conf.nix](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-conf.nix)).<br>`automount.{enabled=true, root="/mnt", options="metadata,uid=1000,gid=100", mountFsTab=false, ldconfig=false}`<br>`boot.{systemd=true, command="", initTimeout=null}`<br>`interop.{enabled=true, appendWindowsPath=true}`<br>`network.{generateHosts=true, generateResolvConf=true, hostname=config.networking.hostName}`<br>`user.default` (forced to `defaultUser`) |
| `wsl.interop.register` | false | Re-registers the `WSLInterop` binfmt handler. You need it if you add any other `boot.binfmt` registrations ([interop.nix L4-41](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/interop.nix)). There is an open bug where binfmt plus emulated systems fails to activate ([#1109](https://github.com/nix-community/NixOS-WSL/issues/1109)). |
| `wsl.interop.includePath` | true | Keeps the Windows `PATH` in the Linux `PATH` via `split-path` ([interop.nix](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/interop.nix), [native/default.nix L85-91](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/systemd/native/default.nix#L85-L91)). |
| `wsl.usbip.{enable, autoAttach, snippetIpAddress}` | off | Integration with usbipd-win (pinned `auto-attach.sh` v4.2.0). Enables udev ([usbip.nix](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/usbip.nix)). Open bug: autoAttach not working ([#1069](https://github.com/nix-community/NixOS-WSL/issues/1069)). |
| `wsl.docker-desktop.enable` | off | Docker Desktop integration: extra `/bin` tools and adds `defaultUser` to the `docker` group ([docker-desktop.nix](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/docker-desktop.nix)). For native Docker, use the standard `virtualisation.docker`; `wsl.docker-native` was removed ([default.nix L15-16](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/default.nix)). |
| `wsl.ssh-agent.{enable, package, users}` | off | **New in 2605.** A user service running `wsl2-ssh-agent` that bridges to the Windows ssh-agent and sets `SSH_AUTH_SOCK` ([ssh-agent.nix](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/ssh-agent.nix), [2605.7.2 notes](https://github.com/nix-community/NixOS-WSL/releases/tag/2605.7.2)). |
| `wsl.tarball.configPath` | null | A directory copied into the image's `/etc/nixos` (instead of the default `configuration.nix`) when building a tarball ([build-tarball.nix L57-63, L168-174](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/build-tarball.nix#L57-L174)). |
| `wsl.nativeSystemd` | **removed** | `mkRemovedOptionModule`: "Native systemd is now always enabled as support for syschdemd has been removed" ([systemd/default.nix L7](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/systemd/default.nix#L7)). The legacy syschdemd container hack was removed in 2411.6.0 ([notes](https://github.com/nix-community/NixOS-WSL/releases/tag/2411.6.0), [design.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/design.md)). Any guide that sets `wsl.nativeSystemd` is outdated. |

### Limitations and known issues
- **Kernel, bootloader and init:** WSL uses its own kernel and bootloader, so NixOS-WSL disables both ([wsl-distro.nix L114-121](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-distro.nix#L114-L121)). The kernel is Microsoft's and is shared by the single WSL2 VM; a custom one can be set via `.wslconfig` `kernel`, and Intune can forbid that ([wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config), [intune](https://learn.microsoft.com/en-us/windows/wsl/intune)). NixOS kernel options (`boot.kernelPackages`, `boot.kernelParams`, kernel modules) therefore don't apply.
- **systemd:**
  - systemd is PID 1, behind a Rust shim ([design.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/design.md), [shim.rs](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/utils/src/shim.rs)).
  - Emergency mode, `systemd-oomd` (as `mkDefault`), the firewall unit and udev (as `mkDefault`) are disabled ([systemd/default.nix](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/systemd/default.nix)).
  - Open bugs: user-session issues ([#888](https://github.com/nix-community/NixOS-WSL/issues/888), [#375](https://github.com/nix-community/NixOS-WSL/issues/375)), polkit agents ([#1025](https://github.com/nix-community/NixOS-WSL/issues/1025)), cryptsetup hangs without udev ([#958](https://github.com/nix-community/NixOS-WSL/issues/958)).
- **Lifecycle:**
  - Services do not keep the distro alive (Microsoft: [systemd.md](https://learn.microsoft.com/en-us/windows/wsl/systemd)).
  - `[general] instanceIdleTimeout` (default 15000 ms; `-1` disables) and `[wsl2] vmIdleTimeout` (default 60000 ms) are set in `.wslconfig` on the Windows side ([wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)).
  - Changes to `wsl.conf` apply only after the distro fully stops ("8-second rule", same page).
- **Networking and DNS:**
  - DHCP is handled by Windows.
  - By default WSL generates `/etc/hosts` and `/etc/resolv.conf`. NixOS-WSL then disables `resolvconf` and warns if `services.resolved` or `networking.nameservers` conflict ([wsl-distro.nix L132-173, L258-268](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-distro.nix#L132-L268)).
  - `networking.extraHosts` has no effect while `generateHosts=true` ([wsl-conf.nix L126-127](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-conf.nix#L126-L127)).
  - Windows-side `.wslconfig` controls `networkingMode` (NAT/mirrored/…), `dnsTunneling`, `autoProxy`, `firewall` (Hyper-V firewall) and `localhostForwarding` ([wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)).
  - Corporate TLS interception: without the corporate CA in the image you hit a chicken-and-egg problem; the maintainer's answer is a custom tarball with `security.pki.*` ([#918](https://github.com/nix-community/NixOS-WSL/issues/918)).
- **GUI (WSLg / X11):**
  - NixOS-WSL bind-mounts the WSLg X11 socket at `/tmp/.X11-unix/X0` ([wsl-distro.nix L144-154](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-distro.nix#L144-L154)). Making WSLg optional is an open request ([#266](https://github.com/nix-community/NixOS-WSL/issues/266)).
  - The Discourse thread [74553](https://discourse.nixos.org/t/undesired-behavior-of-x11-apps-in-nixos-on-wsl/74553) (2026-01-21) is a **single unanswered post**: KiCad launched inside an xrdp/Plasma X11 session opens on the Windows desktop via WSLg instead, and crashes. No root cause has been established.
  - [inference] The likely cause is that WSLg's `DISPLAY`/`WAYLAND_DISPLAY` environment leaks into the xrdp session. Treat GUI-in-xrdp as unsupported territory.
- **VS Code Remote:**
  - The server ships a Node binary that needs `/lib64/ld-linux-x86-64.so.2`.
  - Option 1 is `programs.nix-ld.enable = true` (more robust, global). Option 2 is K900's `vscode-remote-workaround` module (patches the server; "sometimes breaks on updates").
  - Both need `wget` ([vscode.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/how-to/vscode.md)).
  - The nix-ld module is in nixpkgs at [`nixos/modules/programs/nix-ld.nix`](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/programs/nix-ld.nix).
- **Other open bugs worth knowing about:** Windows drives not mounted on boot ([#846](https://github.com/nix-community/NixOS-WSL/issues/846), [#1112](https://github.com/nix-community/NixOS-WSL/issues/1112)); `environment.sessionVariables.PATH` interferes with rebuilds ([#472](https://github.com/nix-community/NixOS-WSL/issues/472)); GPU acceleration on AMD ([#623](https://github.com/nix-community/NixOS-WSL/issues/623)).

---

## 3. nixos-anywhere and WSL2

### What nixos-anywhere requires (target side)
- **The pipeline:** connect over SSH → kexec into a NixOS installer (unless already in one) → disko partitions and formats the disk → `nixos-install` → reboot ([README L44-52](https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807/README.md#L44-L52)).
  - Default phases: `kexec,disko,install,reboot`. The disko phase "first unmount[s] and destroy[s] all filesystems on the disks" ([docs/cli.md](https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807/docs/cli.md)).
- **Target requirements:** either already running a NixOS installer, or x86-64/aarch64 Linux with kexec support and ≥ 1 GB RAM (README) or 1.5 GB (requirements.md; the two docs disagree). It must be reachable over the network ([README L66-83](https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807/README.md#L66-L83), [requirements.md](https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807/docs/requirements.md)).
- **Container detection:** it runs `systemd-detect-virt --container` ([get-facts.sh L12](https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807/src/get-facts.sh#L12)) and warns "does not support running from a '<x>' container. kexec will likely not work" ([nixos-anywhere.sh L705-707](https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807/src/nixos-anywhere.sh#L700-L707)).
  - systemd's `detect_container()` classifies WSL as container `wsl` from `/proc/sys/kernel/osrelease` ([systemd virt.c](https://github.com/systemd/systemd/blob/2200a9c743109ff2221999bcdbe6ebcea1cd781f/src/basic/virt.c#L659-L665)).
  - Confirmed on the research host: `systemd-detect-virt --container` → `wsl`.
- **WSL is listed only as a source OS:** "Source Machine … Windows systems using WSL2" ([requirements.md L12-16](https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807/docs/requirements.md#L12-L16)). No issue in the nixos-anywhere tracker discusses WSL as a target (`gh search issues wsl`, 2026-11-19).

### Why it does not apply to WSL2
- **No kernel or bootloader of its own:** NixOS-WSL sets `boot.kernel.enable = false`, `boot.initrd.enable = false`, `boot.loader.grub.enable = false` and a no-op `installBootLoader` ([wsl-distro.nix L114-121](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-distro.nix#L114-L121)). All WSL2 distros share one Microsoft-managed VM kernel ([wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config): ".wslconfig … settings for the virtual machine powering WSL 2 (RAM, kernel to boot…)").
  - The WSL kernel config does have `CONFIG_KEXEC_FILE=y` (`CONFIG_KEXEC` unset) ([config-wsl L310-314](https://github.com/microsoft/WSL2-Linux-Kernel/blob/cb72127e44b2e7ab56d1b9a59c8138474c5ccf0a/arch/x86/configs/config-wsl#L310-L314)).
  - [inference] Even if a kexec succeeded from inside the distro's namespace, it would replace the **shared utility VM's** kernel underneath every distro and the WSL init/Plan 9/interop plumbing. The result would not be a registered WSL distro.
- **No "disk" to partition:** a WSL distro's root filesystem is a VHDX managed by `wsl.exe` (`--location`, `defaultVhdSize`) ([install.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/install.md), [wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)). disko's model (partition table, ESP, bootloader) does not map onto it.
- **WSL distros are created from Windows,** with `wsl --install --from-file` / `wsl --import`. Microsoft's enterprise guidance for distributing an approved image is exactly `wsl --export` / `wsl --import` ([enterprise.md](https://learn.microsoft.com/en-us/windows/wsl/enterprise)).

**Verdict:** nixos-anywhere is **not** a WSL2 bootstrap tool. Running it *from* WSL2 against a real server or VM is supported. This is not tested hands-on here: per the instructions, nothing was run.

### Correct bootstrap alternatives (all primary-sourced)

| Path | What | Source | Pros | Cons |
|---|---|---|---|---|
| **A. Stock image + first rebuild** | Install `nixos.wsl` → enable flakes → `sudo nixos-rebuild switch\|boot --flake <repo>#<host>` | [install.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/install.md), [nix-flakes.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/how-to/nix-flakes.md), [nixos-rebuild(8)](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/by-name/ni/nixos-rebuild-ng/nixos-rebuild.8.scd#L301-L306) | No build machine needed; best for learning | Several manual steps per machine; must use `boot` + restart if the username changes ([change-username.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/how-to/change-username.md)); a TLS-intercepting proxy can block it ([#918](https://github.com/nix-community/NixOS-WSL/issues/918)) |
| **B. Custom image from own flake** | `sudo nix run .#nixosConfigurations.<host>.config.system.build.tarballBuilder [-- --extra-files DIR --chown PATH UID:GID] [out.wsl]` → `wsl --install --from-file out.wsl` | [building.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/building.md), [build-tarball.nix](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/build-tarball.nix) | Identical image on every machine: user, CA certificates, flakes and comin preconfigured; `wsl.tarball.configPath` can embed the repo in `/etc/nixos` | Needs a Linux host with Nix and root, which can be a Path-A NixOS-WSL instance; the image must be stored or distributed; `--extra-files` secrets end up **inside the image** |
| C. Export/import | `wsl --export` a configured distro → `wsl --import` elsewhere | [enterprise.md](https://learn.microsoft.com/en-us/windows/wsl/enterprise) | Microsoft-blessed distribution route | Copies machine state (machine-id, keys, `/var/lib/comin`), so it is not "from git" |

- **Tarball builder internals:**
  - Runs as root ([L85-88](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/build-tarball.nix#L85-L88)).
  - Runs `nixos-install --root $root --no-root-passwd --system <toplevel> --substituters ""` ([L151-156](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/build-tarball.nix#L151-L156)), so the closure is copied from the local store.
  - Adds the `nixos-wsl` channel only if `nix.channel.enable` ([L158-161](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/build-tarball.nix#L158-L161)).
  - Produces a reproducibly-ordered tar (`--sort=name --mtime=@1 --numeric-owner`) ([L176-184](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/build-tarball.nix#L176-L184)).

---

## 4. comin

### Model
- **Pull-based agent:** a systemd service polls git remotes and deploys `nixosConfigurations.<hostname>`. A new commit on `main` deploys "in the next 60 seconds" by default ([readme](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/readme.md)).
  - It supports flake and non-flake repos (`repositoryType = "nix"` + `systemAttr`) and nix-darwin ([howtos.md](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/howtos.md)).
- **Hostname matching:**
  - `services.comin.hostname` defaults to `config.networking.hostName` and selects `nixosConfigurations."<hostname>"`.
  - An assertion requires it to be non-empty ([module-options.nix L16-59](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module-options.nix#L16-L59)).
  - The value comes from the **Nix config**, written into `comin.yaml` ([comin-config.nix L13](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/comin-config.nix#L13)), not from the runtime hostname.
- **Branches and commit selection** ([design.md L1-33](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/design.md#L1-L33), [howtos.md L1-22](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/howtos.md#L1-L22)):
  - Each remote has a `main` branch (default name `main`, operation `switch`) and a `testing` branch (default `testing-<hostname>`, operation `test`, so the bootloader is untouched).
  - comin refuses force-pushed `main` branches, and only accepts a `testing` branch that sits on top of `main`.
  - Remotes are ordered. A local path remote with `poller.period = 2` is allowed, with an explicit warning that it could "be used by an attacker to update your machine".
- **Deploy mechanics:**
  - Evaluate → build → run `<outPath>/bin/switch-to-configuration <op>` directly; this is not `nixos-rebuild` ([executor/utils.go L251-268](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/executor/utils.go#L251-L268)).
  - For `switch`/`boot`, it sets the profile `/nix/var/nix/profiles/system-profiles/comin` ([profile.go](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/profile/profile.go#L78-L113)).
  - The service runs as root with `restartIfChanged = false`; comin restarts itself when its unit changes. `Restart=always` ([module.nix L58-82](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module.nix#L58-L82)).
  - The service gets `CURL_CA_BUNDLE = security.pki.caBundle` and `networking.proxy.envVars`, which matters behind a corporate proxy.
- **State:**
  - Stored in `/var/lib/comin` ([comin-config.nix L14](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/comin-config.nix#L14)).
  - Losing it forgets the last-deployed commit, which allows a rollback to an older signed commit ([howtos.md L137-151](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/howtos.md#L137-L151)).
  - Retention: `retention.deployment_{boot_entry,successful,any}_capacity` (3/3/5).
- **Rollback:**
  - There is no dedicated rollback command. Roll back by pushing a revert commit to `main`, since force-pushes backwards are refused ([design.md](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/design.md#L1-L33)), or use NixOS generations.
  - `comin deployment submit-latest` replaces the deprecated `switch-latest` ([release-notes](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/release-notes.md), [cmd/deployment.go](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/cmd/deployment.go)).
- **CLI** ([cmd/](https://github.com/nlewo/comin/tree/c84768279d6c8cd0cb26c2a367890f5e63776b9e/cmd)): `status` (with `--oneline`), `watch`, `events`, `fetch`, `eval`, `build`, `list`, `suspend`/`resume`, `confirmation accept|show`, `deployment list|latest|retention-list|submit-latest`, `desktop`.
  - The CLI talks to the agent over gRPC on a Unix socket, default `/run/comin-grpc.sock`, mode `0770`, group `users`. These settings are exposed as options **only on `main`**, not in v0.14.0 ([module-options.nix L154-182](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module-options.nix#L154-L182)).
- **Prometheus:**
  - `exporter.{listen_address = "" (all interfaces), port = 4243, openFirewall = false}` ([module-options.nix L125-153](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module-options.nix#L125-L153)).
  - Metrics include `comin_build_info`, `comin_deployment_info`, `comin_fetch_count`, `comin_is_suspended`, `comin_need_to_reboot`, `comin_last_{fetch,eval,build,deployment}_failed` ([prometheus.go](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/prometheus/prometheus.go#L36-L69)).
  - `comin_host_info` is deprecated (v0.11.0).
- **Hooks:**
  - `postDeploymentCommand` receives `COMIN_PHASE=deploy`, `COMIN_GIT_SHA`, `COMIN_GIT_REF`, `COMIN_GIT_MSG`, `COMIN_HOSTNAME`, `COMIN_GENERATION`, `COMIN_STATUS` (`init|running|done|failed`) and `COMIN_ERROR_MSG`.
  - `postBuildCommand` is **main only** ([module-options.nix L350-380](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module-options.nix#L350-L380)).
  - `buildConfirmer`/`deployConfirmer` take `mode = without|auto|manual`, with `autoconfirm_duration` 120 s ([L381-442](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module-options.nix#L381-L442)). Manual mode gives a human approval gate before deployment.
- **Commit signatures:**
  - `gpgPublicKeyPaths` holds armored public keys; `sshAllowedSignersPath` is an OpenSSH allowed-signers file with `namespaces=` supported (both present in v0.14.0).
  - If either is set, comin only evaluates signed commits, and "only the last commit needs to be signed" ([howtos.md L65-84](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/howtos.md#L65-L84)).
  - Unsigned commits are logged and skipped ([manager.go](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/manager/manager.go#L188-L196)); the implementation is in [repository/git.go L232-320](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/repository/git.go#L232-L320).
- **Private repo authentication** ([authentication.md](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/authentication.md), [module-options.nix L199-239](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module-options.nix#L199-L239)):
  - Token: `remotes.*.auth.access_token_path` with `username` (default `comin`). This takes a GitLab `read_repository` PAT or a GitHub fine-grained/classic PAT.
  - SSH (v0.14.0+): `auth.ssh_deploy_key_path` plus `ssh_known_hosts_path` (default `/etc/ssh/ssh_known_hosts`; the host key must be present).
  - A remote may set at most one of token or SSH ([module.nix L41-44](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module.nix#L41-L44)).
  - The generated `comin.yaml` is in the world-readable Nix store but contains only *paths* to secrets.
  - `debug = true` "secrets are shown!".
- **Other options:**
  - `machineId`: deploy only if `/etc/machine-id` matches. Useful to prevent several machines with the same hostname from all applying a `testing-<hostname>` branch ([howtos.md L49-63](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/howtos.md#L49-L63)).
  - `evalTimeout`/`buildTimeout`: 1800 s each.
  - `buildAttemptsLimit` (0 = forever) and `buildRetryTimer` (30 s): main only.
  - `submodules`, `repositorySubdir`, `desktop.enable` (DBus notifications).
- **Packaging:** comin is **not** in nixpkgs (`pkgs/by-name/co/comin` is absent on `nixos-26.05` and `nixos-unstable`). The module falls back to `self.packages.${system}.comin` from comin's own flake ([module.nix L57](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module.nix#L57)).
  - comin needs Go 1.25 ([go.mod](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/go.mod#L3)). `nixos-26.05` ships Go 1.26 as the default, so `inputs.nixpkgs.follows = "nixpkgs"` is fine.
- **Version notes:**
  - `v0.14.0` (GitHub release 2026-07-19) added SSH auth, SSH signature verification, timeouts and switch inhibitors. Its release-notes file is mis-dated "2025-07-19" ([release-notes.md L7](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/release-notes.md#L7)).
  - `main` has about 40 unreleased commits, including `nixosModules.default`, gRPC socket options, build retry and `postBuildCommand`.
  - The comin flake's own `nixpkgs` input is unpinned `github:NixOS/nixpkgs` (master), so always set `follows`.

### NixOS module options (complete list at v0.14.0 / main)
- **Present in both v0.14.0 and main:** `enable`, `package`, `hostname`, `repositoryType`, `repositorySubdir` (renamed from `flakeSubdirectory`), `systemAttr`, `submodules`, `evalTimeout`, `buildTimeout`, `exporter.*`, `remotes[].{name,url,auth.*,timeout,branches.{main,testing}.{name,operation},poller.period}`, `debug`, `machineId`, `gpgPublicKeyPaths`, `sshAllowedSignersPath`, `postDeploymentCommand`, `buildConfirmer.*`, `deployConfirmer.*`, `desktop.{enable,title}`, `retention.*`.
- **Main only** (diff of option names): `buildAttemptsLimit`, `buildRetryTimer`, `grpc.{unix_socket_path,unix_socket_mode,unix_socket_group}`, `postBuildCommand`.
- **References:** [nix/module-options.nix @main](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module-options.nix), [@v0.14.0](https://github.com/nlewo/comin/blob/v0.14.0/nix/module-options.nix), and the generated [docs/generated-module-options.md](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/generated-module-options.md).

### WSL2-specific concerns
- **No WSL mentions upstream:** neither comin nor NixOS-WSL issues mention the other (`gh search issues --repo nlewo/comin wsl` and `--repo nix-community/NixOS-WSL comin`, both empty on 2026-11-19).
- **The systemd service itself:** comin is a plain `wantedBy = multi-user.target` service ([module.nix L58-82](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module.nix#L58-L82)). NixOS-WSL runs a real systemd, so the unit runs. Nothing in comin is WSL-aware.
- **Distro must be running:** see TL;DR #4. Polling only happens while the instance is alive. After the distro starts, comin fetches immediately on its next poll. Settings like `instanceIdleTimeout=-1`, or keeping a session open, live on the Windows side and are out of scope.
- **`switch` persistence across distro restarts (the main risk) [inference, verify]:**
  1. comin `switch` → `switch-to-configuration switch` (updates `/run/current-system`) plus `nix-env --profile /nix/var/nix/profiles/system-profiles/comin --set <out>`. It **does not** update `/nix/var/nix/profiles/system` ([profile.go L85-113](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/profile/profile.go#L85-L113)).
  2. On a real NixOS this still persists across reboots, because bootloader builders enumerate `system-profiles/*` (the comment in profile.go cites the systemd-boot builder). The comin maintainer confirms it works with systemd-boot and GRUB but not with lanzaboote, which only reads `system` ([comin#144](https://github.com/nlewo/comin/issues/144)). Users report the same "reverts to prev state on reboot" symptom ([comin#86](https://github.com/nlewo/comin/issues/86), open).
  3. NixOS-WSL has no bootloader builder. Its shim hard-codes `/nix/var/nix/profiles/system/activate` and `/nix/var/nix/profiles/system/systemd/...` ([shim.rs L94, L116](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/utils/src/shim.rs#L94-L122)).
  4. After restart, comin loads its persisted last deployment ([cmd/run.go L113](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/cmd/run.go#L113)). It re-evaluates HEAD but skips deployment, because the out-path and operation equal the persisted ones ([deployer.go L170-186](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/deployer/deployer.go#L170-L186)).
  5. **Expected outcome:** the running system silently diverges from `comin status` until the next commit.
  6. **Candidate mitigations, all untested:**
     - (a) A `postDeploymentCommand` that, on `COMIN_STATUS=done` for `main`, runs `nix-env -p /nix/var/nix/profiles/system --set "$(readlink -f /run/current-system)"`.
     - (b) An upstream comin feature to use the `system` profile. The maintainer points at nixos-rebuild-ng's profile support in #144.
     - (c) Bootstrapping and updating via `nixos-rebuild` only (no comin).
- **`boot` operations and switch inhibitors:**
  - On WSL, `switch-to-configuration boot` only calls the no-op `installBootLoader`. Combined with point 3 above, a comin `boot` deployment never becomes active [inference].
  - comin automatically turns `switch` into `boot` when NixOS switch inhibitors change ([PR #156](https://github.com/nlewo/comin/pull/156), [store/deployment.go L113-146](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/store/deployment.go#L113-L146)).
- **Reboot detection:** `NeedToRebootLinux` compares `/run/current-system/kernel` with `/run/booted-system/kernel` ([reboot.go](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/utils/reboot.go#L22-L47)). With `boot.kernel.enable = false` these links presumably don't exist; the function logs and returns false, so `comin_need_to_reboot` is meaningless on WSL [inference].
  - NixOS-WSL creates `/run/booted-system` during activation ([native/default.nix L57-61](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/systemd/native/default.nix#L57-L61)).
- **Username or uid changes pushed through comin:** NixOS-WSL requires `boot` + restart for `wsl.defaultUser` changes ([change-username.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/how-to/change-username.md)). comin `main` uses `switch`, so such changes should not be shipped via comin [inference].
- **The same hostname on many machines:** every machine with the same `nixosConfigurations` name follows `main` and `testing-<hostname>` in lockstep. Use `machineId` (per machine) to target a test ([howtos.md L49-63](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/howtos.md#L49-L63)).

---

## 5. Recommended repo and flake layout

What each primary source prescribes:
- **NixOS-WSL:** the `nixos-wsl.nixosModules.default` + `wsl.enable = true` + `system.stateVersion` pattern ([nix-flakes.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/how-to/nix-flakes.md)). Building an image needs the same `nixosConfigurations.<host>` ([building.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/building.md)).
- **comin:** input with `inputs.nixpkgs.follows = "nixpkgs"`, the module, `services.comin.{enable,remotes}`, and a `nixosConfigurations` name equal to the hostname ([readme](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/readme.md)).
- **home-manager:** `home-manager.nixosModules.home-manager`, branch `release-26.05` exists ([flake.nix@release-26.05](https://github.com/nix-community/home-manager/blob/release-26.05/flake.nix#L13-L14)). comin has no standalone home-manager support ([features.md](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/features.md), [comin#11](https://github.com/nlewo/comin/issues/11)). Use home-manager **as a NixOS module** so that comin deploys it with the system.
- **sops-nix / agenix:** `sops-nix.nixosModules.sops` ([flake.nix](https://github.com/Mic92/sops-nix/blob/master/flake.nix)) and `agenix.nixosModules.default` ([flake.nix](https://github.com/ryantm/agenix/blob/main/flake.nix), latest release 0.18.0, 2026-09-27).

Pinning rationale:
- `nixos-26.05` is the current stable branch; NixOS-WSL `release-26.05` is built against it.
- comin `v0.14.0` is the latest tag.
- `flake.lock` pins exact revisions; comin deploys whatever lock is committed.
- Do not bump `system.stateVersion` after the first install ([default configuration comment](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/build-tarball.nix#L46-L52)).

Minimal skeleton. It is *derived* from the docs above. It has not been built here.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    comin = {
      url = "github:nlewo/comin/v0.14.0";   # module is nixosModules.comin at this tag
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # optional:
    # home-manager = { url = "github:nix-community/home-manager/release-26.05"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = { self, nixpkgs, nixos-wsl, comin, ... }: {
    nixosConfigurations.wsl-workstation = nixpkgs.lib.nixosSystem {   # name == networking.hostName == comin hostname
      system = "x86_64-linux";
      modules = [
        nixos-wsl.nixosModules.default
        comin.nixosModules.comin
        ({ ... }: {
          wsl.enable = true;
          wsl.defaultUser = "<user>";
          networking.hostName = "wsl-workstation";
          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          services.comin = {
            enable = true;
            remotes = [{
              name = "origin";
              url = "https://github.com/<org>/<repo>.git";
              branches.main.name = "main";
              # auth.access_token_path = "/run/secrets/...";   # private repo
            }];
            # exporter.listen_address = "127.0.0.1";
            # sshAllowedSignersPath = ./allowed_signers;     # or gpgPublicKeyPaths
          };
          system.stateVersion = "26.05";
        })
      ];
    };
  };
}
```

Suggested layout. This is a convention, not mandated by any source:
- `flake.nix` and `flake.lock`
- `hosts/<host>/default.nix`
- `modules/{wsl,comin,security,dev}.nix`
- `home/<user>.nix`
- `secrets/` (sops- or age-encrypted, plus `.sops.yaml`)
- `allowed_signers` (public keys only)

---

## 6. Security-relevant notes (AppSec lens)

- **Trust boundary is the Windows user:**
  - Any process running as the Windows user can run `wsl.exe -d NixOS -u root …` ([basic-commands](https://learn.microsoft.com/en-us/windows/wsl/basic-commands)).
  - In the other direction, interop (`[interop] enabled`, default true) lets any Linux process launch Windows executables as that user, and `appendWindowsPath` (default true) puts Windows `PATH` entries into Linux `$PATH` ([wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config), [wsl-conf.nix L77-88](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-conf.nix#L77-L88)).
  - Windows drives are automounted read/write under `/mnt` with `uid=1000` ([wsl-conf.nix L25-54](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-conf.nix#L25-L54)).
  - Hardening knobs: `wsl.wslConf.interop.enabled = false`, `wsl.wslConf.interop.appendWindowsPath = false`, `wsl.interop.includePath = false`, `wsl.wslConf.automount.enabled = false`, or tighter mount options. Each has usability costs: VS Code, `explorer.exe` and clipboard integration rely on interop [inference].
- **Privilege defaults:**
  - Passwordless sudo for wheel (`mkDefault false`).
  - The default user is added to `nix.settings.trusted-users` whenever sudo needs no password; the source comment says "effectively root access" ([wsl-distro.nix L181-191](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/wsl-distro.nix#L181-L191)).
  - Setting `security.sudo.wheelNeedsPassword = true` removes both, but then a password must be provisioned ([install.md L53-62](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/install.md#L53-L62)).
- **Network exposure:**
  - The NixOS firewall unit is disabled under WSL ([systemd/default.nix L19](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/systemd/default.nix#L19)), so `networking.firewall.*` and comin's `exporter.openFirewall` give no protection.
  - Filtering is on the Windows side: Hyper-V firewall (`[wsl2] firewall`, default true) and `localhostForwarding` (default true), which makes ports bound to wildcard **or localhost** inside WSL reachable from Windows `localhost` ([wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)).
  - comin's exporter binds all interfaces on 4243 by default ([module-options.nix L130-143](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module-options.nix#L130-L143)). Pin it to `127.0.0.1` or accept Windows-local exposure.
- **comin control socket:** on `main`, the gRPC socket is `0770`, group `users`. Every normal user is in `users`, so any local user can suspend, resume and confirm deployments ([module-options.nix L154-182](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module-options.nix#L154-L182)). v0.14.0 hard-codes its own socket permissions [verify].
- **Supply chain and integrity:**
  - **Signature checks:** enable `sshAllowedSignersPath` or `gpgPublicKeyPaths`. Only the tip commit is verified ([howtos.md L65-84](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/howtos.md#L65-L84)), so intermediate commits from other authors are accepted under a signed tip. Signing keys must be protected accordingly.
  - **Push and rollback rules:** `main` force-push rollback is refused, but deleting `/var/lib/comin` re-enables a rollback to any older signed commit ([howtos.md L137-151](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/howtos.md#L137-L151)).
  - **Approval gate:** `deployConfirmer.mode = "manual"` adds a human approval step ([module-options.nix L412-442](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module-options.nix#L412-L442)).
  - **Lock file:** `flake.lock` pins every input. Updates come from a committed, signed lock bump, not from the machine. A local-path remote is an attack surface (comin's own warning, [howtos.md L31-32](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/howtos.md#L31-L32)).
  - **Third-party flakes are code execution:** comin and NixOS-WSL are third-party flakes evaluated as root. Pin them to tags or revisions and review diffs on bump. comin's unpinned upstream `nixpkgs` input means `follows` is mandatory.
- **Secrets:**
  - sops-nix ([README](https://github.com/Mic92/sops-nix)) and agenix ([README](https://github.com/ryantm/agenix)) both decrypt at activation, using host keys.
  - sops-nix defaults `sops.age.sshKeyPaths` to the ed25519 keys from `services.openssh.hostKeys` ([module source L386-392](https://github.com/Mic92/sops-nix/blob/master/modules/sops/default.nix#L386-L392)). That "requires OpenSSH to be enabled" ([README L245](https://github.com/Mic92/sops-nix/blob/master/README.md#L245)). NixOS-WSL does not enable sshd by default, so on WSL either enable openssh (host keys only) or use `sops.age.keyFile` / `generateKey`.
  - **Bootstrap ordering:** the age key and the comin repo token must exist on the machine *before* comin can fetch or decrypt. Options are manual placement, or `tarballBuilder --extra-files`; the latter **embeds the secret in the image** ([building.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/building.md)), so the image becomes secret material.
  - **comin tokens:** use a read-only token (GitLab `read_repository`, GitHub fine-grained read-only) or a read-only SSH deploy key ([authentication.md](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/authentication.md)).
- **`wsl.ssh-agent`:** private keys stay in the Windows agent, which is good for hardware-backed keys. Any process of the enabled users can still request signatures via `SSH_AUTH_SOCK` ([ssh-agent.nix](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/modules/ssh-agent.nix)).
- **Auto-upgrades vs comin:**
  - `system.autoUpgrade` runs `nixos-rebuild switch|boot [--upgrade] [--flake …]` on a timer ([auto-upgrade.nix](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/tasks/auto-upgrade.nix#L23-L311)). It writes the `system` profile, which survives WSL restarts, unlike comin (§4).
  - With `--upgrade` or input updates it can deploy a state that is not in git. Running both would fight over the active generation [inference]. Choose one.
  - comin fits "git is the source of truth" better, subject to the §4 WSL caveat.
- **Enterprise controls (Windows side, informational):**
  - Intune policies can disable custom kernels, kernel command lines, custom networking modes, user firewall overrides, the debug shell and so on ([intune](https://learn.microsoft.com/en-us/windows/wsl/intune)).
  - Microsoft Defender for Endpoint has a WSL plug-in. The recommended way to distribute images is `wsl --export`/`--import` ([enterprise](https://learn.microsoft.com/en-us/windows/wsl/enterprise)).
  - Check work IT policy before relying on `.wslconfig` changes.

---

## 7. Assessment of user-provided references

| Reference | Type | Assessment |
|---|---|---|
| [nix-community/NixOS-WSL](https://github.com/nix-community/NixOS-WSL) | **Primary** | Authoritative. README quick start = `.wsl` double-click, WSL ≥ 2.4.4. |
| [NixOS-WSL install docs](https://nix-community.github.io/NixOS-WSL/install.html) | **Primary** | Current. Minor inconsistency: says `wheelNeedsPassword = true` "is the default", but the module defaults it to `false`. The flakes how-to is bare-bones ([#604](https://github.com/nix-community/NixOS-WSL/issues/604)). |
| [nixos.org/download](https://nixos.org/download/) | **Primary** (Nix) | Covers installing **Nix on another WSL distro** (multi-user needs systemd; "WSL versions 0.67.6 and above"). That is a different approach from NixOS-WSL. It lists `nixos-26.05` as current. |
| [nixos.wiki/wiki/WSL](https://nixos.wiki/wiki/WSL) | Secondary (legacy unofficial wiki) | **Not retrievable** (Cloudflare block, 2026-11-19). The official wiki is [wiki.nixos.org/wiki/WSL](https://wiki.nixos.org/wiki/WSL) (nixos.org links to wiki.nixos.org). It is current: `nixos.wsl` double-click, WSL ≥ 2.4.4, plus a Task Scheduler/VBS trick to start the distro at logon, which is relevant to comin's "distro must be running". Prefer it over nixos.wiki. |
| [Medium: NixOS on WSL – best of both worlds](https://medium.com/@piyushkumarsingh.nmims/nixos-on-wsl-the-best-of-both-worlds-bdcaba54ee58) | Secondary | **Not retrievable** (bot challenge). Not assessed. |
| [Reddit: NixOS-WSL is awesome](https://www.reddit.com/r/NixOS/comments/1eguj7b/nisoswsl_is_awesome/) | Secondary, anecdotal | **Not retrievable** (fetch blocked). Not assessed. |
| [dev.to: Using Nix on Windows the right way](https://dev.to/jajera/using-nix-on-windows-the-right-way-14ki) | Secondary | Recommends **Ubuntu on WSL + the Nix installer**, not NixOS-WSL. Not relevant to a NixOS-on-WSL target. Useful tip: keep projects on the Linux filesystem, not `/mnt/c` (anecdotal). |
| [andrewowen.net: NixOS full-screen on WSL2](https://andrewowen.net/blog/running-nixos-full-screen-on-wsl2/) | Secondary (2026-03-26) | xrdp + Plasma 6 X11 on port 3390, plus `security.pki.certificateFiles`. Channel-based (`<nixos-wsl/modules>`), `stateVersion 25.05`. This is the same setup as the unresolved Discourse 74553 KiCad/WSLg issue. Uses `services.xrdp.openFirewall`, which has no effect because WSL disables the NixOS firewall unit. |
| [greghilston.com: NixOS on WSL](https://www.greghilston.com/post/nixos-on-wsl/) | Secondary (2024-12-17) | **Outdated:** uses `nixos-wsl.tar.gz` + `wsl --import` (pre-2411 format) and DISM steps. Symlinks a host config into `/etc/nixos`; no flakes. |
| [forrestjacobs.com: NixOS on WSL](https://forrestjacobs.com/nixos-on-wsl/) | Secondary (2023-01-22) | **Outdated/contradicted:** NixOS-WSL 22.05 installer, `wsl.nativeSystemd = true` (now a removed option), rename via `switch` (docs now say use `boot`). The `~/.ssh` → `/mnt/c/...` symlink puts private keys on NTFS where Windows processes can read them, which is a security concern. Its flake structure (`nixosConfigurations.<hostname>` + NixOS-WSL module with `follows`) is still valid. |
| [HN item 40781473](https://news.ycombinator.com/item?id=40781473) | Secondary, anecdotal (2024-06-24) | A comment in the komorebi thread recommends NixOS-WSL with the [LGUG2Z/nixos-wsl-starter](https://github.com/LGUG2Z/nixos-wsl-starter) template ("single flake… on all my machines"). Opinion only. The template was not reviewed here. |
| [Discourse 74553](https://discourse.nixos.org/t/undesired-behavior-of-x11-apps-in-nixos-on-wsl/74553) | Secondary (community forum, 2026-01-21) | Single post, **no replies**: KiCad escapes the xrdp session to WSLg. Useful as a known-issue pointer only; no fix exists. |

---

## 8. Addendum (2026-11-19): work-specific settings in a public repo

This asks how a **public** flake can serve Work Hosts whose work-specific settings (corporate root CA, proxy, internal domains) must not appear in plain text. Sources are pinned to comin v0.14.0 (ed92afc), comin `main` (c847682) and NixOS-WSL `main` (05721a4).

- **Encrypted secrets cannot carry build-time settings.**
  - sops-nix: "It is not possible to use secrets at evaluation time… decrypts secrets only in the activation phase" ([README](https://github.com/Mic92/sops-nix#using-secrets-at-evaluation-time)).
  - agenix also decrypts at activation, and warns that `builtins.readFile` on a secret can put the cleartext in the world-readable store ([reference](https://github.com/ryantm/agenix/blob/main/doc/reference.md)).
  - `security.pki.certificateFiles` is built into a `cacert` bundle in the store ([ca.nix](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/security/ca.nix)), and `networking.proxy` values become store-resident env vars ([networking.nix](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/networking.nix)). Whatever a Work Host builds is readable on that Host anyway; the concern is only the public repo.
- **WSL helps with the proxy, not the CA.**
  - `autoProxy` (Windows 11, default `true`) passes the Windows HTTP proxy to processes WSL launches ([wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config), [networking](https://learn.microsoft.com/en-us/windows/wsl/networking#auto-proxy), [LxssHttpProxy.h](https://github.com/microsoft/WSL/blob/master/src/windows/service/exe/LxssHttpProxy.h)). systemd services such as comin and nix-daemon probably don't inherit it [inference].
  - There is no WSL or NixOS-WSL mechanism to import Windows trusted root certificates ([wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config), [NixOS-WSL modules](https://github.com/nix-community/NixOS-WSL/tree/main/modules)).
- **comin and private flake inputs.**
  - comin's `auth.access_token_path` / `ssh_deploy_key_path` authenticate only its own go-git fetch of the remote ([git.go L83-100](https://github.com/nlewo/comin/blob/v0.14.0/internal/repository/git.go#L83-L100)).
  - Evaluation execs `nix` as root with the unit's inherited environment ([executor/utils.go L22-78](https://github.com/nlewo/comin/blob/v0.14.0/internal/executor/utils.go#L22-L78), [module.nix L16-80](https://github.com/nlewo/comin/blob/v0.14.0/nix/module.nix#L16-L80)). Private *inputs* therefore authenticate through Nix's own `access-tokens` or `netrc-file` ([nix.conf](https://nix.dev/manual/nix/stable/command-ref/conf-file.html)).
  - `nix.settings` lands in the world-readable store, so a token belongs in a secret file pulled in with `nix.extraOptions = "!include /run/secrets/…"` [inference: `!include` is documented, the pattern is not].
- **Patterns that work.**
  - **Inverted flake (fits best):** a private repo whose flake takes this public flake as an input (no auth needed) and defines the Work Hosts' `nixosConfigurations`. comin's `remotes[].url` points at the private repo with its own credential ([authentication.md](https://github.com/nlewo/comin/blob/v0.14.0/docs/authentication.md)). Public changes reach Work Hosts only after a `flake.lock` bump is committed in the private repo [inference].
  - **Private input of the public flake:** works, but needs Nix-level credentials on every Host that evaluates it, and the public `flake.lock` reveals the private repo's URL.
  - comin has no `--override-input` option ([module-options.nix](https://github.com/nlewo/comin/blob/v0.14.0/nix/module-options.nix)).
  - sops-nix points to git-agecrypt for eval-time secrets ([README](https://github.com/Mic92/sops-nix#using-secrets-at-evaluation-time)). That was not evaluated here.

---

## Open questions / things to verify hands-on

1. **comin + NixOS-WSL persistence (highest priority).** After a comin `switch`, run `wsl -t NixOS`, restart, and compare `readlink /run/current-system` with `/nix/var/nix/profiles/system` and `/nix/var/nix/profiles/system-profiles/comin`. Check whether comin redeploys. Then test mitigation (a) in §4.
2. What happens to a comin `boot` deployment on WSL, and does any NixOS-WSL change trigger switch inhibitors (e.g. a systemd or dbus implementation change)?
3. Does `comin status` / `comin_need_to_reboot` behave sensibly without `/run/*/kernel`?
4. **Idle behaviour:** how long does the NixOS distro stay up with comin running and no sessions, under the Windows-side `instanceIdleTimeout`/`vmIdleTimeout` that work IT allows? Is changing `.wslconfig` permitted by Intune policy?
5. First flake activation on a stock image when `wsl.defaultUser` ≠ `nixos`: confirm `boot` + `wsl -t` works as documented.
6. **Tarball (Path B):** build from a NixOS-WSL instance. Confirm that `wsl --install --from-file` of a custom `.wsl` works on WSL 3.0.x, and that the corporate CA (`security.pki.certificateFiles`) makes the first `nix` fetch work behind the proxy. Check whether WSL `autoProxy` env vars reach systemd services such as comin, or whether `networking.proxy` is needed.
7. Exact v0.14.0 gRPC socket permissions. Check whether `comin` CLI works as a non-root user.
8. Whether to track comin `main` (gets `nixosModules.default`, `postBuildCommand`, gRPC options, retry) or stay on `v0.14.0` until the next tag.
9. NixOS 26.11 timing, and when NixOS-WSL cuts `release-26.11` / `2611.*`. Plan a stable-to-stable bump procedure. Release notes show the channel-based procedure; a flake-based one is just an input bump.
10. **Secrets bootstrap:** decide between age `keyFile` placed manually and an openssh host key. Decide where the comin repo token lives before sops can decrypt (chicken-and-egg).
11. **Interop hardening trade-offs:** test VS Code Remote-WSL, clipboard and `wslview` with `interop.enabled = false` / `appendWindowsPath = false`.
12. **Machine identity:** `/etc/machine-id`, SSH host keys and `/var/lib/comin` are per install and not in git. Decide whether "identical" includes them.

---

## Sources

### Primary
- **NixOS-WSL** (repo @ `05721a4`):
  - [README](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/README.md), [flake.nix](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/flake.nix)
  - Docs: [install.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/install.md), [building.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/building.md), [design.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/design.md), [how-to/nix-flakes.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/how-to/nix-flakes.md), [how-to/change-username.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/how-to/change-username.md), [how-to/vscode.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/how-to/vscode.md), [troubleshooting](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/troubleshooting/README.md), [recovery-shell.md](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/troubleshooting/recovery-shell.md)
  - Modules: [modules/](https://github.com/nix-community/NixOS-WSL/tree/05721a428830972f025a8575b1a19c418d422d1b/modules); [utils/src/shim.rs](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/utils/src/shim.rs)
  - Rendered docs: [options](https://nix-community.github.io/NixOS-WSL/options.html), [install](https://nix-community.github.io/NixOS-WSL/install.html)
  - Releases: [2605.7.2](https://github.com/nix-community/NixOS-WSL/releases/tag/2605.7.2), [2411.6.0](https://github.com/nix-community/NixOS-WSL/releases/tag/2411.6.0)
  - Issues: [#396](https://github.com/nix-community/NixOS-WSL/issues/396), [#604](https://github.com/nix-community/NixOS-WSL/issues/604), [#918](https://github.com/nix-community/NixOS-WSL/issues/918) (maintainer reply), [#1109](https://github.com/nix-community/NixOS-WSL/issues/1109), [#266](https://github.com/nix-community/NixOS-WSL/issues/266)
- **comin** (repo @ `c847682`, tag `v0.14.0`):
  - [readme](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/readme.md)
  - Docs: [howtos](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/howtos.md), [authentication](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/authentication.md), [advanced-config](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/advanced-config.md), [design](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/design.md), [features](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/features.md), [release-notes](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/release-notes.md), [generated-module-options](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/generated-module-options.md)
  - Nix: [nix/module.nix](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module.nix), [nix/module-options.nix](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module-options.nix), [nix/comin-config.nix](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/comin-config.nix), [flake.nix @v0.14.0](https://github.com/nlewo/comin/blob/v0.14.0/flake.nix)
  - Go source: [internal/profile/profile.go](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/profile/profile.go), [internal/deployer/deployer.go](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/deployer/deployer.go), [internal/manager/manager.go](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/manager/manager.go), [internal/utils/reboot.go](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/utils/reboot.go), [internal/executor/utils.go](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/executor/utils.go), [internal/repository/git.go](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/repository/git.go), [internal/store/deployment.go](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/store/deployment.go), [internal/prometheus/prometheus.go](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/prometheus/prometheus.go)
  - Commit [cd4c473](https://github.com/nlewo/comin/commit/cd4c473); [PR #156](https://github.com/nlewo/comin/pull/156); issues [#144](https://github.com/nlewo/comin/issues/144) (maintainer comment), [#86](https://github.com/nlewo/comin/issues/86) (maintainer comment), [#11](https://github.com/nlewo/comin/issues/11); [release v0.14.0](https://github.com/nlewo/comin/releases/tag/v0.14.0)
- **nixos-anywhere** (repo @ `58132e1`): [README](https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807/README.md), [docs/requirements.md](https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807/docs/requirements.md), [docs/cli.md](https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807/docs/cli.md), [src/nixos-anywhere.sh](https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807/src/nixos-anywhere.sh), [src/get-facts.sh](https://github.com/nix-community/nixos-anywhere/blob/58132e1d1f813b845382a2aeca4203b18d2ac807/src/get-facts.sh), [release 1.13.0](https://github.com/nix-community/nixos-anywhere/releases/tag/1.13.0)
- **Microsoft WSL:**
  - learn.microsoft.com: [wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config) (source [MicrosoftDocs/WSL @526e577](https://github.com/MicrosoftDocs/WSL/blob/526e57752f7241dc7e98f14b1033905e8e675587/WSL/wsl-config.md)), [systemd](https://learn.microsoft.com/en-us/windows/wsl/systemd), [intune](https://learn.microsoft.com/en-us/windows/wsl/intune), [enterprise](https://learn.microsoft.com/en-us/windows/wsl/enterprise), [basic-commands](https://learn.microsoft.com/en-us/windows/wsl/basic-commands)
  - Releases: [WSL 3.0.5](https://github.com/microsoft/WSL/releases/tag/3.0.5); [WSL2-Linux-Kernel config-wsl](https://github.com/microsoft/WSL2-Linux-Kernel/blob/cb72127e44b2e7ab56d1b9a59c8138474c5ccf0a/arch/x86/configs/config-wsl)
- **systemd:** [src/basic/virt.c](https://github.com/systemd/systemd/blob/2200a9c743109ff2221999bcdbe6ebcea1cd781f/src/basic/virt.c#L659-L665)
- **nixpkgs (`nixos-26.05`):** [nixos-rebuild(8)](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/by-name/ni/nixos-rebuild-ng/nixos-rebuild.8.scd), [auto-upgrade.nix](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/tasks/auto-upgrade.nix), [nix-ld.nix](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/programs/nix-ld.nix); Nix manual [`access-tokens`](https://nix.dev/manual/nix/latest/command-ref/conf-file.html#conf-access-tokens)
- **Secrets and home-manager:** [sops-nix](https://github.com/Mic92/sops-nix) ([README](https://github.com/Mic92/sops-nix/blob/master/README.md), [modules/sops/default.nix](https://github.com/Mic92/sops-nix/blob/master/modules/sops/default.nix)), [agenix](https://github.com/ryantm/agenix), [home-manager release-26.05 flake.nix](https://github.com/nix-community/home-manager/blob/release-26.05/flake.nix)
- **NixOS:** [nixos.org/download](https://nixos.org/download/), [wiki.nixos.org/wiki/WSL](https://wiki.nixos.org/wiki/WSL) (official wiki)

### Secondary (anecdotal / unverified unless corroborated above)
- [Discourse 74553](https://discourse.nixos.org/t/undesired-behavior-of-x11-apps-in-nixos-on-wsl/74553) (unanswered user report)
- [andrewowen.net (2026-03-26)](https://andrewowen.net/blog/running-nixos-full-screen-on-wsl2/)
- [greghilston.com (2024-12-17)](https://www.greghilston.com/post/nixos-on-wsl/)
- [forrestjacobs.com (2023-01-22)](https://forrestjacobs.com/nixos-on-wsl/)
- [dev.to/jajera](https://dev.to/jajera/using-nix-on-windows-the-right-way-14ki)
- [HN 40781473 (2024-06-24)](https://news.ycombinator.com/item?id=40781473)
- [microsoft/WSL#9968](https://github.com/microsoft/WSL/issues/9968) (community explanation of idle timers; superseded by the documented `instanceIdleTimeout`)
- Not retrievable: [nixos.wiki/wiki/WSL](https://nixos.wiki/wiki/WSL) (legacy unofficial wiki), [Medium article](https://medium.com/@piyushkumarsingh.nmims/nixos-on-wsl-the-best-of-both-worlds-bdcaba54ee58), [Reddit thread](https://www.reddit.com/r/NixOS/comments/1eguj7b/nisoswsl_is_awesome/)
