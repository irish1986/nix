# Run the WSL restart test

Type: task (HITL)
Status: open
Blocked by: 04, 07

## Question

Does the comin-deployed state survive `wsl --shutdown` and a restart on `xsbug-1`? Run the test from [ADR 0003](../../../adr/0003-comin-for-gitops-pending-wsl-restart-test.md), with the checks sharpened by "Can comin deploy to the system profile on WSL?":

1. Push a commit and let comin deploy it.
2. Run `wsl --shutdown`, then start the distro again.
3. Compare `/run/current-system` with `profiles/system` and `system-profiles/comin`, and check whether comin redeploys.

The answer records the raw results and updates ADR 0003:

- **Pass:** Accepted.
- **Pass only with the mitigation:** Accepted with the mitigation.
- **Fail:** the fog in "Not yet specified" graduates into tickets for another git-sync approach.

**Done when:** the destination's finish line is met (push → applied → still active after restart), or the failure is recorded and the follow-up tickets exist.
