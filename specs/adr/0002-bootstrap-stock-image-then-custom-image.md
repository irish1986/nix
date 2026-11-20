# 0002. Bootstrap from the stock image first, then from a custom image built from the flake

- Status: Proposed
- Date: 2026-11-19

## Context

ADR 0001 rules out nixos-anywhere, so a WSL machine must be bootstrapped from a `.wsl` image installed on the Windows side. NixOS-WSL documents two ways to get from an image to this repository's configuration:

- **Path A, stock image then first rebuild.** Install the release `nixos.wsl`, enable flakes, then run `sudo nixos-rebuild --flake <repo>#<host>` once.
  - Needs no build machine, and every step is visible, which suits learning.
  - It is several manual steps per machine.
  - If the flake renames the default user away from `nixos`, the first activation must be `nixos-rebuild boot` followed by a distro restart. `switch` can misconfigure the new user.
  - Behind a TLS-intercepting corporate proxy, the stock image may be unable to fetch the flake at all, because it doesn't trust the corporate CA.
- **Path B, custom image built from the flake.** Run `sudo nix run .#nixosConfigurations.<host>.config.system.build.tarballBuilder` to produce a `.wsl`, then install it on each machine.
  - Every machine starts identical: user, CA certificates, flakes and the GitOps agent are all in place from first boot.
  - A NixOS-WSL maintainer recommends it for the corporate-CA problem (NixOS-WSL#918).
  - It needs a Linux host with Nix and root, which can be a Path A instance.
  - Files added with `--extra-files` are baked into the image, so the image must not carry secrets.

A third option, `wsl --export` / `wsl --import` of a configured distro, copies machine state (machine-id, keys, `/var/lib/comin`) rather than building from git, so it is not considered.

Evidence: [research note §1 and §3](../projects/research-nixos-wsl-comin-bootstrap.md#correct-bootstrap-alternatives-all-primary-sourced).

## Decision

1. The first machine is bootstrapped with **Path A**, done by hand from a how-to guide in `docs/`. The guide uses `nixos-rebuild boot` plus a restart for the first activation whenever the username changes.
2. Once the flake works on that machine, every further machine, and any rebuild of the first, uses **Path B**: a `.wsl` image built from this repository's flake.
3. Images never contain secrets. Secrets such as the age key and the repository token are placed after install, by a documented manual step.
4. If the corporate proxy blocks Path A on the first machine, Path B becomes the starting point, with the corporate CA in `security.pki.certificateFiles`. The image would then be built on a machine outside the proxy, or on a plain Nix install.

## Consequences

- Path A doubles as the learning exercise. Its guide must cover enabling flakes on the stock image, the `boot` versus `switch` rule, and the recovery shell.
- Path B needs a place to store built images, and a rule for when to rebuild them, since an old image is just a starting point that the flake then updates.
- The secrets bootstrap is a separate decision, still to be made: an age `keyFile` placed by hand, or an OpenSSH host key (see research open question 10).
- "Identical" means identical configuration. Per-install identity (`/etc/machine-id`, host keys, `/var/lib/comin`) still differs between machines.
