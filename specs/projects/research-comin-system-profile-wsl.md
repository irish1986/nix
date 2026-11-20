# Research: can comin deploy to the system profile on WSL?

- **Date:** 2026-11-19
- **Ticket:** [04 — Can comin deploy to the system profile on WSL?](../tasks/xsbug-1-gitops/issues/04-comin-system-profile-research.md). Feeds [ADR 0003](../adr/0003-comin-for-gitops-pending-wsl-restart-test.md) and task [08 — Run the WSL restart test](../tasks/xsbug-1-gitops/issues/08-wsl-restart-test.md).
- **Background:** [research note §4](research-nixos-wsl-comin-bootstrap.md#wsl2-specific-concerns). comin writes `/nix/var/nix/profiles/system-profiles/comin`; the NixOS-WSL shim activates `/nix/var/nix/profiles/system` at every distro start.
- **Method:** primary sources only: source code pinned to a commit or tag, official docs, and maintainer comments. **[inference]** marks my reading of code that the project does not state. **[verify]** marks something only the hands-on test can settle. Nothing was built, installed or run. Sources were only read.
- **Source snapshots** (every link below points at one of these):
  - comin tag `v0.14.0` = [`ed92afc`](https://github.com/nlewo/comin/tree/ed92afc48978fb15a2535ebd5c5f63b3010e3b78) (released 2026-07-19); comin `main` = [`c847682`](https://github.com/nlewo/comin/tree/c84768279d6c8cd0cb26c2a367890f5e63776b9e) (2026-11-18).
  - NixOS-WSL `release-26.05` = [`a7a0227`](https://github.com/nix-community/NixOS-WSL/tree/a7a02274815637f2f31e91f93940e9ab31d9699b) (2026-11-11). `utils/src/shim.rs` and `modules/systemd/native/default.nix` are byte-identical on tag `2605.7.2` and on `main` @ `05721a4`.
  - nixpkgs `nixos-26.05` = [`3457b69`](https://github.com/NixOS/nixpkgs/tree/3457b69ac4aba6d9ea9a743370af160fb502db29) (2026-11-18).
  - Nix `master` = [`3705f35`](https://github.com/NixOS/nix/tree/3705f35ddcdca8d777c1d75b939eb6a3a4ac9ebb). I quote it for long-standing profile and GC behaviour, not for anything specific to one release.

---

## TL;DR

1. **comin has not added, and does not plan, a way to deploy into the `system` profile on NixOS.** The profile path is a hard-coded constant on both `v0.14.0` and `main`. The maintainer's position is that comin's own profile is by design and that consumers which only read `system` should learn about profiles (comin#144, #86, #109). The only upstream change that writes `system` is open PR [#232](https://github.com/nlewo/comin/pull/232). It covers **nix-darwin only**, comes from a non-member, was opened 2026-11-18 and has no review yet.
2. **Mitigation (a) is safe in principle but needs two fixes:**
   - Read the target from comin's profile, not from `/run/current-system`. Otherwise a `switch` that comin downgrades to `boot` (switch inhibitors) is never persisted.
   - Log through `logger`. comin discards hook output on success.

   A corrected script is in §2.6. A second option overrides NixOS-WSL's no-op `installBootLoader` (§2.7). It hooks the same point a real bootloader uses and has nixpkgs precedent (the LXC container module).
3. **NixOS-WSL has no option or hook to start from another profile.** The shim hard-codes `/nix/var/nix/profiles/system/activate` and `.../system/systemd/...`. The only alternative entry point is the manual recovery shell (`nixos-wsl-recovery --system <path>`). There are no open issues or PRs about this.
4. A hand-run checklist with expected results, with and without the mitigation, is in §4.

---

## 1. Has comin added or planned a way to deploy into `system`?

**Answer: no, as of 2026-11-19.**

### 1.1 Code: the profile path is a constant

- **v0.14.0:** `systemProfiles = "/nix/var/nix/profiles/system-profiles"`, `profileName = "comin"` ([profile.go L14-18](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/internal/profile/profile.go#L14-L18)). `SetSystemProfile` runs `nix-env --profile …/system-profiles/comin --set <outPath>` for `switch` and `boot` only ([L85-113](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/internal/profile/profile.go#L85-L113)).
- **main @ c847682:** the same constants and function, unchanged ([profile.go L14-18, L85-113](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/profile/profile.go#L14-L113)).
- **Options:** there is no `profile`/`profilePath`-style option on either ref ([module-options.nix @v0.14.0](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/nix/module-options.nix), [@main](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/nix/module-options.nix)).
- **Release notes:** they end at `v0.14.0` and have no "Unreleased" entry about profiles ([release-notes.md @main](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/docs/release-notes.md)).

### 1.2 Issues and PRs (state on 2026-11-19)

| Item | State | What it says |
|---|---|---|
| [#144](https://github.com/nlewo/comin/issues/144) "comin generations are not used by systemd-boot" | **closed** 2026-03-25 by the reporter | The maintainer [replied](https://github.com/nlewo/comin/issues/144#issuecomment-4105675572) that it only happens with lanzaboote, "which doesn't support profiles yet". He pointed at a lanzaboote PR, and at nixos-rebuild-ng's profile support as the model. The reporter then confirmed that systemd-boot works ([comment](https://github.com/nlewo/comin/issues/144#issuecomment-4126669524)). No comin change. |
| [#86](https://github.com/nlewo/comin/issues/86) "Comin changes not persistent with impermanence / secureboot" | **open**, last activity 2026-01-20 | A user diagnosed that lanzaboote globs only `system-*-link` ([comment](https://github.com/nlewo/comin/issues/86#issuecomment-3770462488)). They proposed either "comin should create new generations on the system profile" or a lanzaboote fix. The maintainer [pointed](https://github.com/nlewo/comin/issues/86#issuecomment-3771464361) at fixing it in lanzaboote (lanzaboote#135). The lanzaboote PR he had cited in #144, [lanzaboote#541](https://github.com/nix-community/lanzaboote/pull/541), was **closed unmerged** on 2026-07-25. |
| [#109](https://github.com/nlewo/comin/issues/109) "Where are the applied generations" | closed | The maintainer: "We are using a dedicated profile: `nixos-rebuild list-generations -p comin`. Note comin is not designed to be working with `nixos-rebuild`" ([comment](https://github.com/nlewo/comin/issues/109#issuecomment-3431197985)). |
| [PR #232](https://github.com/nlewo/comin/pull/232) "darwin: set the system profile after activation" | **open**, opened 2026-11-18, no review | **Darwin only.** After a successful `switch`/`boot` it runs `nix-env --profile /nix/var/nix/profiles/system --set <outPath>`, then `--delete-generations old`. Its motivation is the same as ours: nix-darwin's boot daemon activates `system`. The author notes that `--delete-generations old` breaks `darwin-rebuild --rollback`. It adds `SetDarwinSystemProfile` and calls it only from `deployDarwin`, so the Linux path is untouched. |
| [PR #197](https://github.com/nlewo/comin/pull/197) "redeploy a test generation a reboot discarded" | open, **changes requested** | The maintainer [prefers](https://github.com/nlewo/comin/pull/197) not to redeploy automatically. Instead, on start, comin would compare the last deployed store path with the running system. If they differ, it would set a `rollbacked` attribute and **suspend** until a human resumes it. This is planned, not implemented. |
| [PR #211](https://github.com/nlewo/comin/pull/211) / [PR #219](https://github.com/nlewo/comin/pull/219) / [#192](https://github.com/nlewo/comin/issues/192) | open (draft / open / open) | `IsAlreadyDeployed` reworks. They don't touch profiles, but §4 step 6 depends on the bug they fix. |
| `gh search issues --repo nlewo/comin wsl` | no results | No WSL discussion upstream. |

**[inference] What this means for WSL:**

- Waiting for comin to target `system` on Linux is not a plan. Nothing is open for Linux, and the maintainer's stance points the other way.
- If PR #232 merges, it sets a precedent: "a bootloader-less platform activates `system`, so comin also writes `system`". A WSL-specific upstream PR could follow it, but comin would have to detect WSL or gain an option.
- If the planned `rollbacked` detection lands, an *unmitigated* WSL host will **suspend comin after every restart**, because the running system will differ from the last deployment. Today it just diverges silently. Neither is acceptable without the mitigation. With the mitigation, the running system and comin's last deployment match after a restart, so the check stays quiet.

---

## 2. Is mitigation (a) safe?

The mitigation as stated in ADR 0003 is a `services.comin.postDeploymentCommand` that, on `COMIN_STATUS=done` for the main branch, runs `nix-env -p /nix/var/nix/profiles/system --set "$(readlink -f /run/current-system)"`.

### 2.1 When and how the hook runs (v0.14.0)

- **Order within one deployment** ([deployer.go L205-265](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/internal/deployer/deployer.go#L205-L265)):
  1. `NewDeployment` computes the operation from switch inhibitors.
  2. `deployerFunc` runs `deployLinux`:
     - **first** `SetSystemProfile` (writes `system-profiles/comin`, for `switch`/`boot` only);
     - then `RemoveProfiles`;
     - **then** `<outPath>/bin/switch-to-configuration <op>` ([executor/utils.go L293-319](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/internal/executor/utils.go#L293-L319)).
  3. `DeploymentFinished` sets the status.
  4. **Then** the hook runs ([L248-258](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/internal/deployer/deployer.go#L248-L258)).
  5. Only after the hook does the manager see `DeploymentDoneCh` and, if comin's unit changed, `os.Exit(0)` for a restart ([manager.go L253-264](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/internal/manager/manager.go#L253-L264)).
- **So the hook runs after the switch, synchronously, in the deployer goroutine.** It runs for every deployment that reaches `DeploymentFinished`, **including failed ones**. It runs before any comin self-restart. It does **not** run if a store update fails (`continue` at L248-251), or if comin or the distro dies mid-deployment [inference].
- **Status values:** `COMIN_STATUS` is the deployment's `Status` string ([post_deployment_command.go L34-36](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/internal/deployer/post_deployment_command.go#L34-L36)). After `DeploymentFinished` that string is `done` or `failed` ([store/deployment.go L29-41, L218-238](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/internal/store/deployment.go#L218-L238)). The option doc lists `init|running|…`, but the hook never sees those [inference from call order]. The "status always done" bug was fixed by [PR #169](https://github.com/nlewo/comin/pull/169), which is an ancestor of `v0.14.0` (checked with `git merge-base --is-ancestor 577889c v0.14.0`).
- **How it is invoked:** `exec.Command(command)` with **no arguments and no shell**. The environment is comin's own (`os.Environ()`) plus these variables ([post_deployment_command.go L42-65](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/internal/deployer/post_deployment_command.go#L42-L65)):
  - `COMIN_GIT_SHA`, `COMIN_GIT_REF`, `COMIN_GIT_MSG`, `COMIN_HOSTNAME`, `COMIN_GENERATION` (the comin generation UUID, **not** a profile generation number), `COMIN_STATUS`, `COMIN_ERROR_MSG`.
  - `COMIN_GIT_REF` is `"<remote name>/<branch name>"` (L18-20).
  - The v0.14.0 option doc also lists `COMIN_FLAKE_URL` ([module-options.nix L306-317](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/nix/module-options.nix#L306-L317)), but the code does not set it.
  - **No operation and no out-path variable is exported.**
  - On `main` the hook moved to [`utils.RunPostCommand`](https://github.com/nlewo/comin/blob/c84768279d6c8cd0cb26c2a367890f5e63776b9e/internal/utils/postcmd.go#L23-L44) and adds `COMIN_PHASE=deploy`. Everything else is the same.
- **Output:** captured with `CombinedOutput()`. On success it is logged at **debug** level only. On failure comin logs only the error, not the output (L56-62, deployer.go L254-257). **A hook that prints is therefore invisible in the journal unless `debug = true`.** Log through `logger` instead.
- **User and PATH:** the `comin` systemd unit sets no `User=`, so it runs **as root**. Its `path` is `config.nix.package` and `programs.ssh.package` ([module.nix L58-82](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/nix/module.nix#L58-L82)), plus NixOS's default service path: coreutils, findutils, gnugrep, gnused, systemd ([systemd-lib.nix L713-719](https://github.com/NixOS/nixpkgs/blob/3457b69ac4aba6d9ea9a743370af160fb502db29/nixos/lib/systemd-lib.nix#L713-L719)). So `nix-env` and `readlink` resolve. Pinning absolute paths is still better.

### 2.2 What `/run/current-system` and `system-profiles/comin` hold after each kind of deployment

Sources for this table:

- `computeOperation` ([store/deployment.go L408-421](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/internal/store/deployment.go#L408-L421)): `test` with changed inhibitors becomes `null`; `switch` with changed inhibitors becomes `boot`.
- The NixOS activation script always ends with `ln -sfn "$(readlink -f "$systemConfig")" /run/current-system`, even when snippets failed ([activation-script.nix L75-81](https://github.com/NixOS/nixpkgs/blob/3457b69ac4aba6d9ea9a743370af160fb502db29/nixos/modules/system/activation/activation-script.nix#L75-L81)).
- `switch-to-configuration boot` exits before activation ([switch-to-configuration-ng main.rs L1847-1865](https://github.com/NixOS/nixpkgs/blob/3457b69ac4aba6d9ea9a743370af160fb502db29/pkgs/by-name/sw/switch-to-configuration-ng/src/main.rs#L1847-L1865)).

| comin deployment | `COMIN_STATUS` | `/run/current-system` after | `system-profiles/comin` after | Original hook writes to `system` |
|---|---|---|---|---|
| main, `switch`, OK | done | new | new | new ✔ |
| main, `switch` downgraded to `boot` | done | **old** (unchanged) | **new** | **old** ✘: the boot deployment is never persisted, and on WSL it never takes effect |
| main, `switch`, activation or unit failure (exit 2/4) | failed | new (activation ran) [inference] | new (written before the switch) | nothing (gated) ✔ |
| testing, `test` | done | test generation | unchanged | nothing (gated on main) ✔. **Without the gate it would persist a test build.** |
| testing, `test` → `null` (inhibitors) | done | unchanged | unchanged | nothing (gated) ✔ |

**Conclusion:** the original hook's only correctness bug is the `boot` row. Taking the target from `readlink -f /nix/var/nix/profiles/system-profiles/comin` fixes it. For a `done` deployment on main, with main's operation `switch` or `boot`, that link was just set to this deployment's out-path (§2.1 order) [inference]. The fix depends on main's operation never being `test`; the corrected script asserts that.

### 2.3 Generation numbering, `list-generations`, `--rollback`

- **No new generation when nothing changed:**
  - `nix-env --set` calls `createGeneration` and then `switchLink` ([nix-env.cc L767-810](https://github.com/NixOS/nix/blob/3705f35ddcdca8d777c1d75b939eb6a3a4ac9ebb/src/nix/nix-env/nix-env.cc#L767-L810)).
  - `createGeneration` does not create a new link if the **highest-numbered** generation already points at the same path ([profiles.cc L61-96](https://github.com/NixOS/nix/blob/3705f35ddcdca8d777c1d75b939eb6a3a4ac9ebb/src/libstore/profiles.cc#L61-L96)).
  - nixos-rebuild-ng sets the profile with the same `nix-env -p <profile> --set` ([nix.py L634-672](https://github.com/NixOS/nixpkgs/blob/3457b69ac4aba6d9ea9a743370af160fb502db29/pkgs/by-name/ni/nixos-rebuild-ng/src/nixos_rebuild/nix.py#L634-L672)).
  - So a comin deployment of the same out-path that a manual `nixos-rebuild` already wrote creates no duplicate. Hook and manual generations share one monotonically increasing `system-N-link` sequence.
- **`nixos-rebuild list-generations`** reads `system-*-link` ([nix.py L422-450, L493-548](https://github.com/NixOS/nixpkgs/blob/3457b69ac4aba6d9ea9a743370af160fb502db29/pkgs/by-name/ni/nixos-rebuild-ng/src/nixos_rebuild/nix.py#L422-L548)). Hook-created generations show up like any other.
  - On WSL the kernel column shows `Unknown`, because there is no `kernel-modules` [inference from L513-519].
  - `--configuration-revision` shows the commit if `system.configurationRevision` is set.
  - `list-generations -p comin` reads comin's own profile (`Profile.from_arg` maps a non-`system` name to `system-profiles/<name>`, [models.py L200-212](https://github.com/NixOS/nixpkgs/blob/3457b69ac4aba6d9ea9a743370af160fb502db29/pkgs/by-name/ni/nixos-rebuild-ng/src/nixos_rebuild/models.py#L200-L212)).
- **`nixos-rebuild switch --rollback`:**
  - It runs `nix-env --rollback -p system`, then switches to the profile ([nix.py L603-611](https://github.com/NixOS/nixpkgs/blob/3457b69ac4aba6d9ea9a743370af160fb502db29/pkgs/by-name/ni/nixos-rebuild-ng/src/nixos_rebuild/nix.py#L603-L611)).
  - With the hook, the previous generation is usually the previous comin deployment, which is the meaningful rollback target.
  - The rollback survives a WSL restart, because the `system` link itself moved.
  - comin is unaware of it. It keeps reporting the newer deployment and won't redeploy that out-path until a new commit arrives (`IsAlreadyDeployed`, [deployer.go L163-179](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/internal/deployer/deployer.go#L163-L179)). This matches comin's behaviour on bare metal.
  - The next comin deployment's `--set` creates a new generation above the highest one; no number is reused.
  - Once the `rollbacked` idea from PR #197 lands, comin would suspend instead [inference].
- **Do not copy PR #232's `--delete-generations old`.** It removes every rollback target, which its own author flags.

### 2.4 Garbage collection

- **`nix-collect-garbage -d`:**
  - It recurses through `/nix/var/nix/profiles`, **including `system-profiles/`**, and deletes every non-current generation of every profile ([nix-collect-garbage.cc L25-59, L90-99](https://github.com/NixOS/nix/blob/3705f35ddcdca8d777c1d75b939eb6a3a4ac9ebb/src/nix/nix-collect-garbage/nix-collect-garbage.cc#L25-L99); [profiles.cc L175-185](https://github.com/NixOS/nix/blob/3705f35ddcdca8d777c1d75b939eb6a3a4ac9ebb/src/libstore/profiles.cc#L175-L185)).
  - **With the hook:** the current `system` generation is the running comin deployment, so it is kept. Old ones disappear, which is expected for `-d`.
  - **Without the hook:** `-d` keeps the stale manual generation as `system`'s current one, plus comin's current one. Nothing breaks immediately, but a restart still reverts.
  - In both cases `/run/current-system` is also a GC root ([activation-script.nix L284](https://github.com/NixOS/nixpkgs/blob/3457b69ac4aba6d9ea9a743370af160fb502db29/nixos/modules/system/activation/activation-script.nix#L284)).
- **`nix.gc`:** `options` defaults to `""`, which deletes no generations ([nix-gc.nix L63-68, L88](https://github.com/NixOS/nixpkgs/blob/3457b69ac4aba6d9ea9a743370af160fb502db29/nixos/modules/services/misc/nix-gc.nix#L63-L88)). `--delete-older-than Nd` keeps the current generation ([profiles.cc L187+](https://github.com/NixOS/nix/blob/3705f35ddcdca8d777c1d75b939eb6a3a4ac9ebb/src/libstore/profiles.cc#L187)). Both are safe with the hook.
- **Growth:** comin's retention only prunes `system-profiles/` and never touches `system-*-link` ([profile.go L27-76](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/internal/profile/profile.go#L27-L76)). So **with the hook, `system-*-link` grows by one per main deployment.** Use `nix.gc` with `--delete-older-than`, or occasionally run `nix-env -p /nix/var/nix/profiles/system --delete-generations +10` (`deleteGenerationsGreaterThan`, [profiles.cc L150-173](https://github.com/NixOS/nix/blob/3705f35ddcdca8d777c1d75b939eb6a3a4ac9ebb/src/libstore/profiles.cc#L150-L173)).
- **Never write the mirror into `system-profiles/`.** `removeProfiles` deletes every link there except `comin` that is missing from comin's history ([profile.go L52-74](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/internal/profile/profile.go#L52-L74)).

### 2.5 Races

- **With comin's own profile write:** none. comin writes `system-profiles/comin` and switches before `DeploymentFinished`. The hook then runs in the same goroutine, sequentially (§2.1). The two are also different profiles.
- **With a concurrent manual `nixos-rebuild`:**
  - `nix-env --set` does **not** take the profile lock; only the delete operations do (`lockProfile` is called in `deleteGenerations*`/`deleteOldGenerations`, not in `opSet`; [nix-env.cc L767-810](https://github.com/NixOS/nix/blob/3705f35ddcdca8d777c1d75b939eb6a3a4ac9ebb/src/nix/nix-env/nix-env.cc#L767-L810), [profiles.cc L279-283](https://github.com/NixOS/nix/blob/3705f35ddcdca8d777c1d75b939eb6a3a4ac9ebb/src/libstore/profiles.cc#L279-L283)).
  - Two simultaneous `--set` calls could both pick N+1, and the last writer wins [inference].
  - The window is milliseconds and needs a human `nixos-rebuild` at the same moment. Acceptable. Note that the hook itself runs after `switch-to-configuration` has released its own `/run/nixos/switch-to-configuration.lock` ([main.rs L1813-1827](https://github.com/NixOS/nixpkgs/blob/3457b69ac4aba6d9ea9a743370af160fb502db29/pkgs/by-name/sw/switch-to-configuration-ng/src/main.rs#L1813-L1827)).
- **With GC:** `createGeneration` registers the link through `addPermRoot`, which "blocks if the garbage collector is running" (profiles.cc L86-93).

### 2.6 Corrected hook (mitigation a′)

Compared with the ADR version, this script:

- reads the comin profile instead of `/run/current-system`, which fixes the `boot` row;
- computes the main refs from the comin config, so a renamed branch or remote can't silently disable it;
- asserts that main never uses `test`;
- does nothing if `system` already points there;
- refuses anything that isn't a NixOS toplevel;
- logs to the journal.

Illustrative only; it has not been built.

```nix
# e.g. modules/features/comin-wsl.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.services.comin;
  # COMIN_GIT_REF is "<remote name>/<branch name>" (v0.14.0 post_deployment_command.go L18-20)
  mainRefs = map (r: "${r.name}/${r.branches.main.name}") cfg.remotes;
  promote = pkgs.writeShellApplication {
    name = "comin-wsl-promote";
    runtimeInputs = [ config.nix.package pkgs.coreutils pkgs.util-linux ];
    text = ''
      log() { logger -t comin-wsl-promote -- "$*"; }

      if [ "''${COMIN_STATUS:-}" != done ]; then
        log "skip: status=''${COMIN_STATUS:-unset} ref=''${COMIN_GIT_REF:-unset}"
        exit 0
      fi
      case " ${lib.concatStringsSep " " mainRefs} " in
        *" ''${COMIN_GIT_REF:-} "*) ;;
        *) log "skip: ref=''${COMIN_GIT_REF:-unset} is not a main branch"; exit 0 ;;
      esac

      # Written by comin for switch/boot just before switch-to-configuration.
      target=$(readlink -e /nix/var/nix/profiles/system-profiles/comin)
      case "$target" in /nix/store/*) ;; *) log "abort: unexpected target $target"; exit 1 ;; esac
      if [ ! -e "$target/nixos-version" ] || [ ! -x "$target/activate" ]; then
        log "abort: $target is not a NixOS toplevel"; exit 1
      fi

      current=$(readlink -e /nix/var/nix/profiles/system || true)
      if [ "$current" = "$target" ]; then
        log "noop: system already at $target (commit ''${COMIN_GIT_SHA:-?})"
        exit 0
      fi
      nix-env --profile /nix/var/nix/profiles/system --set "$target"
      log "promoted $target (commit ''${COMIN_GIT_SHA:-?}) to /nix/var/nix/profiles/system"
    '';
  };
in
{
  assertions = [{
    assertion = lib.all (r: r.branches.main.operation != "test") cfg.remotes;
    message = "comin-wsl-promote: main branches must use switch or boot, so that system-profiles/comin is written";
  }];
  services.comin.postDeploymentCommand = "${promote}/bin/comin-wsl-promote";
}
```

Notes:

- `postDeploymentCommand` is typed `nullOr path` and executed without a shell, so it must be a single executable path (v0.14.0 L306-317).
- It also helps to set `system.configurationRevision = self.rev or "dirty";` in the flake. Then `nixos-version --configuration-revision` shows which commit is running, which makes §4 easier to read [inference; standard NixOS option].
- **Failure semantics:** a failed deployment is never promoted. On WSL there is no boot menu to pick an older generation, so promoting only known-good systems is the safer choice [inference].
  - This differs from bare-metal comin and from `nixos-rebuild`: both make the new generation the boot default even when the switch fails, because both write their profile before switching.
  - So after a failed comin switch, a WSL restart returns to the last *good* main deployment.

### 2.7 Alternative (mitigation a″): replace NixOS-WSL's no-op `installBootLoader`

- **What NixOS-WSL sets:** `system.build.installBootLoader = "${pkgs.coreutils}/bin/true"` ([wsl-distro.nix L67-75](https://github.com/nix-community/NixOS-WSL/blob/a7a02274815637f2f31e91f93940e9ab31d9699b/modules/wsl-distro.nix#L67-L75)).
- **How `switch-to-configuration` calls it:** for `switch` and `boot` only (never `test`), it calls `$INSTALL_BOOTLOADER <toplevel>` **before** activating ([main.rs L255-275, L1847-1850](https://github.com/NixOS/nixpkgs/blob/3457b69ac4aba6d9ea9a743370af160fb502db29/pkgs/by-name/sw/switch-to-configuration-ng/src/main.rs#L255-L275); [switchable-system.nix L53-67](https://github.com/NixOS/nixpkgs/blob/3457b69ac4aba6d9ea9a743370af160fb502db29/nixos/modules/system/activation/switchable-system.nix#L53-L67)).
- **Precedent:** nixpkgs' own LXC container module already uses this hook to make a bootloader-less system "bootable": `ln -fs "$1/init" /sbin/init` ([lxc-container.nix L129-132](https://github.com/NixOS/nixpkgs/blob/3457b69ac4aba6d9ea9a743370af160fb502db29/nixos/modules/virtualisation/lxc-container.nix#L129-L132)).

```nix
system.build.installBootLoader = lib.mkForce (pkgs.writeShellScript "wsl-promote-system-profile" ''
  set -eu
  profile=/nix/var/nix/profiles/system
  if [ "$(${pkgs.coreutils}/bin/readlink -f "$profile")" != "$1" ]; then
    ${config.nix.package}/bin/nix-env --profile "$profile" --set "$1"
  fi
'');
```

- **Pros [inference]:**
  - It covers `switch`, inhibitor-downgraded `boot` and `test` (not called) by construction, without depending on comin's environment variables or profile path.
  - It also covers a manual `…/bin/switch-to-configuration switch`.
  - It is a no-op for `nixos-rebuild switch|boot`, which set the profile first, and for `--rollback`, where the profile already equals `$1`.
- **Cons:**
  - It needs `mkForce` on an `internal` option ([activation-script.nix L244-264](https://github.com/NixOS/nixpkgs/blob/3457b69ac4aba6d9ea9a743370af160fb502db29/nixos/modules/system/activation/activation-script.nix#L244-L264), type `unique`) and silently overrides any future NixOS-WSL change to it.
  - It promotes **before** activation, like `nixos-rebuild`. A failing switch therefore persists.
  - NixOS-WSL's tarball builder runs `nixos-install` ([build-tarball.nix L151-156](https://github.com/nix-community/NixOS-WSL/blob/a7a02274815637f2f31e91f93940e9ab31d9699b/modules/build-tarball.nix#L151-L156)), which calls the bootloader hook inside the image chroot. It should be a no-op there [verify for Path B].
- **Use one of a′ or a″, not both.** Test a′ first because it stays inside ADR 0003's scope. Keep a″ as the fallback if a′ proves fragile, for example if comin's hook environment changes on `main`.

---

## 3. Does NixOS-WSL offer a way to start a profile other than `system`?

**No.**

- **The shim:** WSL runs `/sbin/init`. The `shimSystemd` activation snippet links `/sbin/init` to `systemd-shim` ([native/default.nix L54-57](https://github.com/nix-community/NixOS-WSL/blob/a7a02274815637f2f31e91f93940e9ab31d9699b/modules/systemd/native/default.nix#L54-L57)). The shim:
  - remounts `/` and `/nix/store`;
  - spawns the fixed path **`/nix/var/nix/profiles/system/activate`**;
  - then execs the fixed path **`/nix/var/nix/profiles/system/systemd/lib/systemd/systemd`** ([shim.rs L94-122](https://github.com/nix-community/NixOS-WSL/blob/a7a02274815637f2f31e91f93940e9ab31d9699b/utils/src/shim.rs#L94-L122)).

  There is no environment variable, argument, config file or Nix option in between. The file is identical on `release-26.05`, tag `2605.7.2` and `main` @ `05721a4`.
- **`/run/booted-system`** is created at the first activation after start, from `$systemConfig`, so it equals the `system` profile target ([native/default.nix L33-36](https://github.com/nix-community/NixOS-WSL/blob/a7a02274815637f2f31e91f93940e9ab31d9699b/modules/systemd/native/default.nix#L33-L36)). That makes it the restart-test witness of which profile was started.
- **`wsl.wslConf.boot.command`** is "a command to run when the distro is started" ([wsl-conf.nix L55-60](https://github.com/nix-community/NixOS-WSL/blob/a7a02274815637f2f31e91f93940e9ab31d9699b/modules/wsl-conf.nix#L55-L60)). It runs after init, so it cannot choose what the shim activates. Re-activating from it would be a second, racy activation [inference]. Not recommended.
- **Recovery shell:** `nixos-wsl-recovery --system /nix/var/nix/profiles/system-42-link` enters a chosen generation, but only as a manual chroot from the WSL system distribution, not as a normal start ([recovery-shell.md](https://github.com/nix-community/NixOS-WSL/blob/a7a02274815637f2f31e91f93940e9ab31d9699b/docs/src/troubleshooting/recovery-shell.md), [recovery.nix L8-18](https://github.com/nix-community/NixOS-WSL/blob/a7a02274815637f2f31e91f93940e9ab31d9699b/modules/recovery.nix#L8-L18)). It is useful as a break-glass path if a promoted generation fails to start.
- **Issues:** searching NixOS-WSL issues and PRs for "comin", "system profile activate", "generation boot" and "profiles/system" found nothing about selecting the profile. The closest is [#396](https://github.com/nix-community/NixOS-WSL/issues/396), "Allow rollbacks through the launcher" (open since 2024-01, filed by a member, no comments). [#867](https://github.com/nix-community/NixOS-WSL/issues/867) shows users re-activating `system-N-link/activate` by hand as a workaround for an unrelated bug.

---

## 4. Restart-test checklist (run by hand)

Run it on the first machine after task 07 (comin enabled). `NixOS` is the distro name shown by `wsl.exe -l -v`; substitute yours.

### 4.0 Setup

1. **Add a visible marker** to the host config. Bump its value in every test commit:

   ```nix
   environment.etc."comin-restart-test".text = "C1";   # bump per commit
   system.configurationRevision = self.rev or "dirty";  # optional, see §2.6
   ```

2. **Paste this helper into a shell inside the distro:**

   ```bash
   snap() {
     echo "up-since    $(uptime -s)"
     for l in /run/current-system /run/booted-system /nix/var/nix/profiles/system /nix/var/nix/profiles/system-profiles/comin; do
       printf '%-45s %s\n' "$l" "$(readlink -f "$l")"
     done
     echo "marker      $(cat /etc/comin-restart-test 2>/dev/null || echo '<absent>')"
     sudo comin status | sed -n '/Deployer/,$p'
   }
   ```

   Run this alongside it when needed:

   ```bash
   journalctl -b -u comin --no-pager | grep -E 'switch-to-configuration|skipping deployment|post deployment command'
   journalctl -b -t comin-wsl-promote --no-pager   # mitigation only
   sudo nixos-rebuild list-generations
   sudo nixos-rebuild list-generations -p comin
   ```

3. **Restart procedure, from Windows PowerShell:**

   ```powershell
   wsl.exe -l -v                       # NixOS  Running
   wsl.exe --terminate NixOS           # pass 1; repeat each restart step with: wsl.exe --shutdown
   wsl.exe -l -v                       # expect: NixOS  Stopped
   wsl.exe -d NixOS --user root -- readlink -f /run/current-system /run/booted-system /nix/var/nix/profiles/system /nix/var/nix/profiles/system-profiles/comin
   wsl.exe -d NixOS --user root -- cat /etc/comin-restart-test
   ```

   The `readlink` call starts the distro. Then open a normal shell, give comin a minute to fetch and evaluate, and run `snap` again.

Notation: `M` is the out-path of the last manual `nixos-rebuild switch` (marker `M`). `Cn` and `T` are the out-paths of test commits.

### 4.1 Run A: no mitigation (ADR "Pass/Fail" probe)

| Step | Action | Expected |
|---|---|---|
| A1 | Note `snap` after the manual rebuild | current = booted = system = `M`; comin profile absent or older; marker `M` |
| A2 | Push `C1` to `main`, wait for `comin status` "Deployment succeeded … Operation switch", Outpath `C1` | current = `C1`, booted = `M`, **system = `M`**, comin = `C1`, marker `C1` |
| A3 | Restart (§4.0 step 3) | `wsl -l -v` Stopped, then: **current = booted = system = `M`**, comin = `C1`, **marker `M`** |
| A4 | `snap` + journal after ≥ 1 poll | `comin status` still says succeeded / Outpath `C1`. **No** new `switch-to-configuration` line this boot; possibly `deployer: skipping deployment … has already been deployed` [verify]. ⇒ **Fail**: matches the ADR hypothesis. |
| A5 | Recovery: `sudo comin deployment submit-latest` | Forces a redeploy (`force=true`, [manager.go L113-129](https://github.com/nlewo/comin/blob/ed92afc48978fb15a2535ebd5c5f63b3010e3b78/internal/manager/manager.go#L113-L129)); current back to `C1`, system still `M`. |

If A3 instead shows current = `C1`, the hypothesis is wrong and the ADR passes as written. Record that and stop.

### 4.2 Run B: with mitigation a′ (§2.6) deployed

Ship the hook module itself through a manual `nixos-rebuild switch`, or through comin. In the comin case, the hook is active from the *next* deployment, because comin reads the old `comin.yaml` until it restarts.

| Step | Action | Expected |
|---|---|---|
| B1 | Push `C2` to `main` | current = `C2`, **system = `C2`** (new top `system-N-link`, `list-generations` marks it current), comin = `C2`, marker `C2`. Journal: `comin-wsl-promote: promoted /nix/store/…C2 …` |
| B2 | Restart (`--terminate`) | **current = booted = system = comin = `C2`**, marker `C2`. No new `switch-to-configuration` in comin's journal. ⇒ **Pass** |
| B3 | Restart again with `wsl.exe --shutdown` | Same as B2 |
| B4 | **Testing branch:** push `T` (marker `T`) to `testing-<hostname>`, branched from `main` HEAD | `comin status` Operation `test`; current = `T`, **system = `C2`**, comin = `C2`; promote log `skip: ref=<remote>/testing-… is not a main branch` |
| B5 | Restart | current = `C2`, marker `C2`. `comin status` may still show the `T` deployment; that is a known upstream limitation, see PR #197. Delete the testing branch. |
| B6 | **Failed deploy:** push `C3` = marker `C3` plus a unit that fails, e.g. `systemd.services.comin-fail-test = { wantedBy = [ "multi-user.target" ]; serviceConfig.Type = "oneshot"; script = "exit 1"; };` | "Deployment failed"; current = `C3` (activation ran, exit 4) [inference], comin = `C3`, **system = `C2`**; log `skip: status=failed` |
| B7 | Restart | current = `C2`, marker `C2`. The failing unit is gone. |
| B8 | Push `C4`: remove the failing unit **and** set marker `C4`. Not a pure revert: a pure revert has `C2`'s out-path and v0.14.0 may skip it as "already deployed" ([#192](https://github.com/nlewo/comin/issues/192), [report in #211](https://github.com/nlewo/comin/pull/211)). | current = system = comin = `C4` |
| B9 | **Inhibitor downgrade:** push `C5` adding `system.switch.inhibitors.comin-restart-test = "1";` (marker `C5`), then `C6` changing it to `"2"` (marker `C6`) | `C5`: Operation `switch`, all = `C5`. `C6`: Operation **`boot`**; current = `C5`, comin = `C6`, **system = `C6`** (the original ADR hook would leave `C5`) |
| B10 | Restart | current = booted = system = `C6`, marker `C6`. Remove the inhibitor in the next commit. |
| B11 | Optional GC: `sudo nix-collect-garbage -d`, then restart | `list-generations` shows only the current generation; after restart all = latest; marker latest |
| B12 | Optional rollback: `sudo nixos-rebuild switch --rollback`, then restart | Before restart: current = system = previous generation. After restart: same. comin still reports the newer deployment and does not redeploy until the next commit. |

**Interpreting results:**

- **A fails and B passes:** accept ADR 0003 with mitigation a′.
- **B2, B9 or B10 fails:** retry Run B with a″ (§2.7) instead of a′. If that fails too, supersede the ADR (option b/c in the research note).
- **Comin stuck:** if a restart lands while comin is mid-deployment (WSL idle shutdown), `comin status` may stay at "Deployment is running" ([#201](https://github.com/nlewo/comin/issues/201), open). Record it as a separate finding; the hook will not have run.

---

## Verdict

- **Upstream:** comin will not target `system` on Linux any time soon.
  - The path is hard-coded on `v0.14.0` and `main`, and no option exists.
  - The maintainer considers consumers that only read `system` to be the thing to fix (#144, #86, #109).
  - Only open PR #232 writes `system`, and only for nix-darwin. Do not wait for upstream.
- **Mitigation (a), as written in the ADR, is nearly safe.**
  - It is correctly gated against `test` and failed deployments, and the hook runs as root after the switch.
  - It does not persist `switch`→`boot` downgrades, because it reads `/run/current-system`.
  - Its output is invisible on success.
  - **Use the corrected hook a′ (§2.6).** It reads `system-profiles/comin`, asserts main ≠ `test`, does nothing if `system` is already current, and logs via `logger`.
  - Generation numbering, `list-generations`, `--rollback`, `nix-collect-garbage -d` and `nix.gc` all behave sensibly with it. `system-*-link` grows, so pair it with `nix.gc --delete-older-than`.
- **NixOS-WSL** always starts `/nix/var/nix/profiles/system` and offers no option or hook to change that. The fallback, if a′ misbehaves, is to override `installBootLoader` (a″), which nixpkgs' LXC module already does in a similar way.
- **Next step:** run §4 Run A, then Run B, and record the raw `snap` output in task 08 and ADR 0003.
