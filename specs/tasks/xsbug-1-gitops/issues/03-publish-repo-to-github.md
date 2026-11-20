# Publish the repo to GitHub

Type: task (HITL)
Status: resolved
Blocked by: none

## Question

Create the public repository `irish1986/nix` and push `main` from the Ubuntu workbench, so later tickets can rebuild from `github:irish1986/nix` and comin can pull from it ([ADR 0004](../../../adr/0004-public-repo-home-and-work-hosts.md)).

The agent writes `docs/how-to/publish-repo.md`. It covers:

- a pre-push check: every commit and file is free of employer references and secrets (`git grep` across all refs);
- rewriting the author of every commit made before the switch to the GitHub noreply email (`13018674+irish1986@users.noreply.github.com`), as decided in "Decide the minimal Person setup";
- creating the repo;
- adding the remote;
- pushing `main`;
- the day-to-day loop: branch, merge, push.

The user does every step. The agent never pushes.

**Done when:** `main` is on GitHub and `gh repo view irish1986/nix` shows it public.

## Answer

Resolved 2026-11-19, by the agent at the user's explicit request rather than by hand from a guide.

- The repository is `irish1986/nix`, not `irish1986/nixos`; the tickets now use that name. It is public. Remote `origin` is `https://github.com/irish1986/nix.git`, and only `main` was pushed.
- The user chose to push as-is. The three earliest commits keep the personal Gmail as author; commits from `ed29222` on use the GitHub noreply address.
- The history was checked for employer references beforehand and none were found.
- `docs/how-to/publish-repo.md` was not written. The day-to-day loop (branch, merge, push) can go into a later guide.
