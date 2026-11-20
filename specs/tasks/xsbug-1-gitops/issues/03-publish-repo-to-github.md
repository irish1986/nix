# Publish the repo to GitHub

Type: task (HITL)
Status: open
Blocked by: none

## Question

Create the public repository `irish1986/nixos` and push `main` from the Ubuntu workbench, so later tickets can rebuild from `github:irish1986/nixos` and comin can pull from it ([ADR 0004](../../../adr/0004-public-repo-home-and-work-hosts.md)).

The agent writes `docs/how-to/publish-repo.md`. It covers:

- a pre-push check: every commit and file is free of employer references and secrets (`git grep` across all refs);
- rewriting the author of every commit made before the switch to the GitHub noreply email (`13018674+irish1986@users.noreply.github.com`), as decided in "Decide the minimal Person setup";
- creating the repo;
- adding the remote;
- pushing `main`;
- the day-to-day loop: branch, merge, push.

The user does every step. The agent never pushes.

**Done when:** `main` is on GitHub and `gh repo view irish1986/nixos` shows it public.
