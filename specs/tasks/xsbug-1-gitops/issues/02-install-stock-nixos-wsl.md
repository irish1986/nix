# Install stock NixOS-WSL beside Ubuntu

Type: task (HITL)
Status: resolved
Blocked by: none

## Question

Get a stock NixOS-WSL distro running on `XSBUG-1` next to `Ubuntu-26.04`, without touching Ubuntu or the default distro, and learn how to get out of trouble before changing anything.

The agent writes `docs/how-to/install-nixos-wsl.md` from the official [install guide](https://nix-community.github.io/NixOS-WSL/install.html) and [ADR 0002](../../../adr/0002-bootstrap-stock-image-then-custom-image.md) Path A. The user follows it and fixes it. It covers:

- downloading `nixos.wsl` from release `2605.7.2` and checking its `.sha256`;
- `wsl --install --from-file` with a name and location;
- first login as `nixos`;
- how to stop, start and unregister the distro;
- the recovery shell (`nixos-wsl-recovery`) and how to boot an older generation.

**Done when:** the user can start, stop and enter the NixOS distro, and has opened the recovery shell once. The answer records the distro name and install location.

## Answer

Resolved 2026-11-19. The user followed `docs/how-to/install-nixos-wsl.md` from Windows PowerShell 5.1. The agent checked the result read-only.

- **Distro:** `NixOS` (WSL 2), installed from release `2605.7.2` with its checksum verified. The disk image is at `C:\Users\irish\AppData\Local\wsl\NixOS`. The default distro is still `kali-linux`, and `Ubuntu-26.04` is untouched.
- **Stock state:** `nixos-version` is `26.05.20260603.6b31628 (Yarara)`, `hostname` is `nixos`, the user is `nixos` with passwordless sudo, and there is one generation (`system -> system-1-link`).
- **The first install attempt registered nothing** for this Windows user (`WSL_E_DISTRO_NOT_FOUND`). The second attempt worked.
- **The recovery shell fails as documented** because of upstream bug [NixOS-WSL#1042](https://github.com/nix-community/NixOS-WSL/issues/1042), open on 2026-11-19.
  - The error is `nixos-enter: cannot execute: required file not found`, exit code 127. `nixos-enter`'s interpreter is `/nix/store/…-bash/bin/bash`, and `/nix` doesn't exist in the WSL system distro (Azure Linux 3.0).
  - The workaround makes the store visible first: `wsl -d NixOS --system --user root -- sh -c "mkdir -p /nix && mount --bind /mnt/wslg/distro/nix /nix"`. With it, the user opened the recovery shell. The guide's step 7 now includes it.
- `--` passes through correctly in PowerShell 5.1, so it wasn't the cause.
