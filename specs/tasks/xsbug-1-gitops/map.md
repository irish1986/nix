# Map: xsbug-1 follows git

Label: wayfinder:map

**Next step:** [Write the flake skeleton for xsbug-1](issues/05-write-flake-skeleton.md) is now unblocked. [Install stock NixOS-WSL beside Ubuntu](issues/02-install-stock-nixos-wsl.md) and [Publish the repo to GitHub](issues/03-publish-repo-to-github.md) can be done in any order. [Can comin deploy to the system profile on WSL?](issues/04-comin-system-profile-research.md) is being researched by an agent.

## Destination

`xsbug-1`, the first Home Host, runs NixOS-WSL from this repository's flake in the [ADR 0005](../../adr/0005-host-role-feature-layout.md) layout, with a minimal Person setup (shell, git, editor) on Account `irish`. A commit pushed to the public GitHub repository reaches `xsbug-1` within about 2 minutes, and that state is still active after `wsl --shutdown` and a restart. comin is the first choice ([ADR 0003](../../adr/0003-comin-for-gitops-pending-wsl-restart-test.md)), but any way of syncing from git is acceptable.

## Notes

- **Why this map exists:** this is the 3rd or 4th attempt. Earlier ones stalled because they designed without running anything, the scope kept growing, the thread was lost between sessions, and the agent built things the user never learned to run.
- **Execution is part of this map.** It doesn't stop at a plan: the hands-on tickets are on the route.
  - The **agent writes** code and how-to guides, with explanations, for the user to review.
  - The **user runs** every install, rebuild, comin step, test and `git push`. The agent never runs these and never pushes.
- **Session size:** about 1 hour per ticket, ending in a committed state. End every session by updating **Next step** above and committing.
- **Guides:** every hands-on ticket produces or updates a how-to in `docs/`. The user follows it step by step and fixes what's wrong, so each guide is proven.
- **Scope guard:** new ideas go to `specs/intents/`, not onto this map, unless they block the destination.
- **Workbench vs target:** the user edits and commits in the `Ubuntu-26.04` distro and pushes to GitHub. `xsbug-1` (the NixOS distro) only pulls. Ubuntu stays the fallback throughout.
- **Skills:** grilling tickets call `grilling` and `domain-modeling`; research tickets call `research`. Use terms from [GLOSSARY](../../GLOSSARY.md).
- **Standing rules:**
  - Never name the user's employer or its industry; say "work".
  - Git flow is branch, then fast-forward merge into `main`, then delete the branch.
  - Research branches stay local.
- **Facts at charting (2026-11-19):**
  - WSL 3.0.5 on Windows computer `XSBUG-1`.
  - Existing distros: `Ubuntu-26.04`, `kali-linux` (the default) and `docker-desktop-data`.
  - The GitHub repo `irish1986/nixos` does not exist yet.
- **Tracker:** local markdown. Tickets live in `issues/NN-<slug>.md`, each with `Type:`, `Status:` (open, claimed or resolved) and `Blocked by:` lines.

## Decisions so far

<!-- one line per resolved ticket: [title](issues/NN-slug.md): gist -->

- [Decide the minimal Person setup](issues/01-minimal-person-setup.md): zsh with oh-my-zsh and p10k, vim as `$EDITOR`, and VS Code Remote via a `vscode-remote` Feature in the `wsl` Role. git identity is in the Person, using the GitHub noreply email.

## Not yet specified

- **If the restart test fails:** whether mitigation (a) in ADR 0003 (pointing the `system` profile at the comin generation after each deploy) is safe enough, or whether another git-sync approach is needed. The research ticket and the test results will sharpen this into tickets.
- **README step 2:** refresh it to point at the proven guides once the first rebuild works.
- **Rollback drill:** whether the destination should include deliberately rolling back a bad commit, or whether surviving a restart is proof enough.

## Out of scope

- **Commit signing for comin:** deferred to right after the destination ([intent](../../intents/comin-commit-signing.md)).
- **Keeping the distro alive without an open terminal:** Windows-side setup, out of scope per the project brief ([intent](../../intents/distro-keep-alive.md)).
- **Porting the full daily Ubuntu setup** (dev toolchains, GUI apps, dotfile polish): the destination only needs a minimal Person setup ([intent](../../intents/port-daily-setup.md)).
- **The other two Home Hosts and any Work Host:** separate efforts once `xsbug-1` works ([Work Host intent](../../intents/work-host-settings.md)).
- **Path B custom images and the secrets tool:** not needed for one Host bootstrapped by hand (ADR 0002 Path A).
