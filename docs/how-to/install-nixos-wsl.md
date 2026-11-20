# Install stock NixOS-WSL beside Ubuntu

**Goal:** a stock NixOS distro running on this Windows computer next to your existing distros, plus the know-how to stop it, restart it, get into it when it's broken, and remove it. Nothing in this guide changes Ubuntu or your default distro.

**Time:** about 30 minutes, mostly the 550 MB download.

**Source:** NixOS-WSL [install guide](https://github.com/nix-community/NixOS-WSL/blob/2605.7.2/docs/src/install.md) and [recovery shell](https://github.com/nix-community/NixOS-WSL/blob/2605.7.2/docs/src/troubleshooting/recovery-shell.md), release `2605.7.2`. This is Path A in [ADR 0002](../../specs/adr/0002-bootstrap-stock-image-then-custom-image.md).

Run every command in **Windows PowerShell** (a PowerShell tab in Windows Terminal), unless a step says "inside NixOS".

---

## 1. Check WSL and what's installed

```powershell
wsl --version
wsl --list --verbose
```

- `WSL version` must be **2.4.4 or later**. This computer had 3.0.5 on 2026-11-19.
- Note which distro has the `*`. That's your default (here `kali-linux`). This guide does not change it.
- There must be no existing distro named `NixOS`. If there is one, pick another name in step 4.

## 2. Download the image

```powershell
$dl = "$env:USERPROFILE\Downloads"
$base = "https://github.com/nix-community/NixOS-WSL/releases/download/2605.7.2"
Invoke-WebRequest "$base/nixos.wsl" -OutFile "$dl\nixos.wsl"
Invoke-WebRequest "$base/nixos.wsl.sha256" -OutFile "$dl\nixos.wsl.sha256"
```

## 3. Verify the checksum

```powershell
(Get-FileHash "$dl\nixos.wsl" -Algorithm SHA256).Hash
Get-Content "$dl\nixos.wsl.sha256"
```

The two hashes must match; PowerShell prints its hash in upper case, which doesn't matter. On 2026-11-19 the published value was:

```
e7180ad555fdcb8e1e057e2ef056de467603a5e502ff8531053738371be3f6b9
```

If they differ, delete the file and download again. Never install an image whose hash doesn't match.

> Both files come from the same GitHub release, so this catches a corrupted or truncated download. It doesn't prove who built the image.

## 4. Install it

Pick the distro **name** and the **location** of its disk image.

- The name `NixOS` matches every NixOS-WSL doc. The Host name (`xsbug-1`) is set later by the flake, not by WSL.
- An explicit location tells you where the virtual disk lives. The default is a random GUID folder under `%LOCALAPPDATA%\wsl`.

```powershell
wsl --install --from-file "$dl\nixos.wsl" --name NixOS --location "$env:LOCALAPPDATA\wsl\NixOS"
```

If it drops you into a NixOS shell straight away, that's fine: go on to step 5 there.

## 5. First look inside NixOS

```powershell
wsl -d NixOS
```

**Inside NixOS:**

```sh
whoami                          # nixos: the stock default user
nixos-version                   # 26.05...
hostname                        # the stock image's hostname
sudo -n true && echo "passwordless sudo"   # NixOS-WSL's default
ls -l /nix/var/nix/profiles/    # system -> system-1-link: your first generation
exit
```

Don't run `nixos-rebuild` or `nix-channel` yet. The first rebuild comes from the flake in [First flake rebuild on xsbug-1](../../specs/tasks/xsbug-1-gitops/issues/06-first-flake-rebuild.md).

## 6. Stop and start it

```powershell
wsl --terminate NixOS      # stops only NixOS
wsl --list --verbose       # NixOS: Stopped, Ubuntu still Running
wsl -d NixOS -- nixos-version   # starts it again and runs one command
```

> **Avoid `wsl --shutdown` for now.** It stops **every** distro and the WSL VM, including the Ubuntu workbench and anything running in it. You'll use it deliberately later, in the restart test.

## 7. Open the recovery shell once

This is how you get into NixOS when a bad configuration stops it from starting. Practise it now, while nothing is broken.

```powershell
wsl --terminate NixOS
wsl -d NixOS --system --user root -- /mnt/wslg/distro/bin/nixos-wsl-recovery
```

You're now root in a chroot of your NixOS system. Look around, then leave:

```sh
ls -l /nix/var/nix/profiles/
exit
```

To boot an **older generation** after a bad rebuild, pass its profile link. The path is relative to the NixOS root, and you only need this once you have more than one generation:

```powershell
wsl -d NixOS --system --user root -- /mnt/wslg/distro/bin/nixos-wsl-recovery --system /nix/var/nix/profiles/system-1-link
```

## 8. Know how to remove it (don't run this now)

```powershell
wsl --unregister NixOS     # deletes the distro and its whole disk, no undo
```

That's the "start over" button: unregister, then repeat from step 4. The downloaded `nixos.wsl` can be reused.

---

## Record the result

Put these in the ticket's answer:

- the distro **name** and **location** you used;
- the output of `wsl -d NixOS -- nixos-version` and `wsl -d NixOS -- hostname`;
- anything in this guide that was wrong or unclear (fix the guide, too).
