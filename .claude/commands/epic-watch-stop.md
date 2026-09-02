---
description: Unschedule an epic-watch watcher, keeping its state
---

The scripts live in this skill's directory. Resolve it once per session:

```bash
EW="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/watching-an-epic"
```

# Stop an epic-watch watcher

Remove the watcher's scheduler entries and its launcher. **State is kept**: the journal is
an append-only audit record of everything the watcher did, and the watermarks are what stop
a re-enabled watcher from re-reading history.

```bash
$EW/scripts/install-schedule.sh --unschedule <name>
```

Confirm which watcher before running it, then show `$EW/scripts/config.sh list` so the user can
see what remains.

Only if the user explicitly asks to delete the watcher's history as well:

```bash
$EW/scripts/install-schedule.sh --purge <name>
```

`--purge` destroys the journal. Say that out loud and get a yes before running it.
