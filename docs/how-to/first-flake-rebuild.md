# First flake rebuild: turn stock NixOS into xsbug-1

**Goal:** the stock `NixOS` distro becomes the Host `xsbug-1`, built from this repo's flake. That means Account `irish`, the minimal Person setup and pinned inputs. Then you apply one change by hand to feel the edit, push, rebuild loop before comin automates it.

**Before you start:** [Install stock NixOS-WSL beside Ubuntu](install-nixos-wsl.md) is done, the flake skeleton is on GitHub (`irish1986/nix`), and you can open the recovery shell (step 7 of that guide).

**Time:** about 1 hour; the first build downloads a few GB.

**Sources:**
- NixOS-WSL [change-username](https://github.com/nix-community/NixOS-WSL/blob/2605.7.2/docs/src/how-to/change-username.md);
- nixpkgs `nixos-rebuild-ng` on `nixos-26.05`, which adds `--extra-experimental-features "nix-command flakes"` to its own `nix` calls, so it needs no flake setup;
- [ADR 0002](../../specs/adr/0002-bootstrap-stock-image-then-custom-image.md) Path A.

Where each command runs is marked:
- **NixOS:** a shell from `wsl -d NixOS`;
- **PowerShell:** Windows PowerShell;
- **Ubuntu:** the workbench.

---

## Part 1: Create `flake.lock` (NixOS, as `nixos`)

The repo has no lock file yet, so a build would use whatever is newest on each input's branch. Lock it first, so every build after this one uses the same versions.

The stock image has `nix` but no `git`, and plain `nix` commands need flakes turned on per command:

```sh
alias nixf='nix --extra-experimental-features "nix-command flakes"'

# git, temporarily, from the same nixpkgs release; clone the repo
nixf shell github:NixOS/nixpkgs/nixos-26.05#git -c git clone https://github.com/irish1986/nix ~/nix

cd ~/nix
nixf flake lock            # writes flake.lock; downloads the input sources
nixf flake metadata        # shows each input and the revision it's locked to

# hand the file to the workbench through the Windows drive
cp flake.lock /mnt/c/Users/irish/Downloads/flake.lock
```

## Part 2: Commit the lock file (Ubuntu)

```sh
cd ~/git/irish1986/nixos
git switch -c chore/flake-lock
cp /mnt/c/Users/irish/Downloads/flake.lock .
git add flake.lock && git commit -m "Lock flake inputs"
```

Then merge it into `main` and push. You can ask the agent to "merge the branch into main and push". Note the commit:

```sh
git rev-parse HEAD         # e.g. 1a2b3c4… — used as <sha> below
```

## Part 3: First rebuild (NixOS, as `nixos`)

Build from GitHub **at that exact commit**. Pinning the commit in the flake reference means Nix can't pick up a stale cached copy of `main`. Use `boot`, **not `switch`**, because the Account changes from `nixos` to `irish` (NixOS-WSL change-username, step 3).

```sh
sudo nixos-rebuild boot --flake github:irish1986/nix/<sha>#xsbug-1
```

- This is the first time the skeleton is evaluated and built, so errors are likely. Copy the **whole** error to the agent. The fix comes as a new commit; push it and rerun with the new `<sha>`.
- When it ends without an error, the new generation is set as the one to start next. Nothing has changed in the running system yet.

```sh
ls -l /nix/var/nix/profiles/   # system -> system-2-link now
exit
```

## Part 4: Restart into xsbug-1 (PowerShell)

The change-username sequence, steps 4 to 7:

```powershell
wsl -t NixOS                       # stop the distro
wsl -d NixOS --user root exit      # start it once as root so the new generation activates
wsl -t NixOS                       # stop it again
wsl -d NixOS                       # open a shell: you should now be irish
```

If it doesn't start, or you land in a broken shell, use the recovery shell (install guide, step 7) and boot `system-1-link`.

## Part 5: Check it's xsbug-1 (NixOS, as `irish`)

```sh
whoami                         # irish
hostname                       # xsbug-1
echo $SHELL                    # …/bin/zsh, with your powerlevel10k prompt
git config user.email          # 13018674+irish1986@users.noreply.github.com
echo $EDITOR                   # vim
id                             # includes wheel
sudo -n true && echo ok        # passwordless sudo (NixOS-WSL default)
nixos-rebuild list-generations # 1 = stock, 2 = flake, current
```

Optional: from this shell, run `code .`. VS Code on Windows should open the folder through Remote-WSL, which is what the `vscode-remote` Feature is for.

## Part 6: The manual loop, once

Make one small change and apply it by hand.

**Ubuntu:** add an alias to your Person in `people/simon/default.nix`, inside `programs.zsh = { … }`:

```nix
shellAliases.ll = "ls -l";
```

Commit it on a branch, then merge and push (or ask the agent), and note the new `<sha>`.

**NixOS (as `irish`):**

```sh
sudo nixos-rebuild switch --flake github:irish1986/nix/<new-sha>#xsbug-1
exec zsh                       # reload the shell
ll                             # works
nixos-rebuild list-generations # 3 is current
```

`switch` is fine now, because the Account isn't changing. To see a rollback, run `sudo nixos-rebuild switch --rollback`: `ll` disappears in a new shell. Switch back by rerunning the `switch` command above.

---

## Record the result

Put these in the ticket's answer:

- the `<sha>` of each rebuild and what each fixed, if there were errors;
- the output of the Part 5 checks;
- anything in this guide that was wrong or unclear (fix the guide, too).
