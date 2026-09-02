---
description: Show epic-watch watcher health, per lane
---

The scripts live in this skill's directory. Resolve it once per session:

```bash
EW="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/watching-an-epic"
```

# epic-watch status

Report every watcher on this machine and, per lane: last success, last run, consecutive
failures, breaker state, and any alert.

```bash
$EW/scripts/config.sh list
$EW/scripts/config.sh health-get <name>
```

Read it carefully rather than printing it raw:

- **`last_success` absent or old while `last_run` is recent** means runs are happening and
  none of them completed cleanly. Look at `last_error`.
- **`last_error.class: degraded`** means a capability was never configured on this machine,
  most often no `SLACK_USER_TOKEN`. Not a fault, and not something a reset fixes.
- **`breaker: open`** means three consecutive failures. The lane still fires, throttled to
  one in six, so it recovers on its own once the cause clears.
- **`launch_failure`** comes from the launcher, which runs before any of the skill's own
  scripts are reachable: a missing config, an env file whose mode is not 0600, or a recorded
  skill root it cannot resolve. Fix the cause, not the symptom.

A launcher failure that has since resolved is stale. Clear it once the cause is fixed, so a
repaired watcher stops reporting an alert:

```bash
$EW/scripts/config.sh clear-launch-failure <name>
```

`reset` closes the breaker, zeroes the counters, and clears the marker:

```bash
$EW/scripts/config.sh reset <name> <lane>
```

Resetting a lane whose underlying cause is unfixed just re-trips it. Say so rather than
resetting on the user's behalf.
