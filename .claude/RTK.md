# RTK - Rust Token Killer

Token-optimized CLI proxy (60-90% savings on dev operations). A Claude Code hook rewrites shell commands transparently (`git status` becomes `rtk git status`), so normal use needs no action.

Invoke `rtk` directly for its own subcommands:

```bash
rtk gain              # Token savings analytics
rtk gain --history    # Command usage history with savings
rtk discover          # Analyze Claude Code history for missed opportunities
rtk proxy <cmd>       # Execute a raw command without filtering (for debugging)
```

If `rtk gain` is not a recognized subcommand, the wrong `rtk` is on PATH: reachingforthejack/rtk (Rust Type Kit) rather than the token proxy.
