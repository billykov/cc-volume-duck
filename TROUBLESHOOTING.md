# Troubleshooting cc-volume-duck

The failure mode of this tool is almost always **Accessibility permission**.
Start with the log.

## First: read the log

```sh
tail -n 50 ~/Library/Logs/cc-duck.log
```

What the lines mean:

| Log line | Meaning | Action |
|----------|---------|--------|
| `no Accessibility permission yet; exiting for launchd to relaunch` (repeating every ~10s) | Not granted (or grant is stale, see below). The daemon exits and relaunches until granted. | Grant Accessibility. If already "on", see "Stale grant". |
| `listening (Accessibility OK ...)` | Granted, event tap is live. It's working. | If it still doesn't duck, see "Granted but no duck". |
| `duck 60 -> 10` / `restore -> 60` | A duck/restore actually fired. | Working as intended. |

No log file at all? The launchd agent isn't loaded. Re-run `./install.sh`.

## Symptom: granted permission but nothing happens

### Stale grant after a reinstall/update (most common during development)
macOS keys the Accessibility grant to the app's **code signature hash**. This
tool is ad-hoc signed, so every recompile/re-sign (i.e. every `install.sh` run)
produces a new hash. The old `cc-duck` row in System Settings keeps showing
**ON**, but it's bound to the previous binary, so the running app reads as
untrusted. A plain OFF/ON toggle does **not** rebind it.

Fix:
```sh
tccutil reset Accessibility com.billykov.cc-duck
```
Then open System Settings -> Privacy & Security -> Accessibility and toggle
`cc-duck` ON again (a clean, fresh grant bound to the current binary). The
daemon picks it up on its next relaunch (~10s).

### Trust is cached per process
`AXIsProcessTrusted()` returns the same value for a process's whole life, so a
process that started before you granted will never notice the grant. That's why
the daemon exits and relies on launchd to relaunch a fresh process rather than
polling in place. If you ever launch it by hand (`open` / shell), restart it
after granting.

### Wrong permission category
The permission is **Accessibility**, NOT Input Monitoring. The CGEvent tap is
listen-only and registers under Accessibility on modern macOS (Darwin 24/25+).
If you only enabled Input Monitoring, it won't work.

## Symptom: ducks, but only sometimes
It only ducks when **iTerm is the frontmost app** (by design, so space in other
apps doesn't duck). And a quick tap won't trigger it: you must hold past
`hold_threshold` (default 0.15s). Both are configurable in
`~/.claude/scripts/cc-duck.json` (hot-reloaded, no restart).

## Symptom: it duck-and-doesn't-restore (volume stuck low)
The saved volume lives in `/tmp/cc-vol.txt`. If the daemon was killed mid-duck,
restore the volume manually and delete the file:
```sh
osascript -e 'set volume output volume 50'
rm -f /tmp/cc-vol.txt
```

## Developer notes

- **Logging:** use `NSLog`, not `print`. Under launchd, `print` (stdout) is
  block-buffered and a redirected log file stays empty until the buffer fills;
  `NSLog` goes to stderr (captured to the log file) and the unified log
  immediately. `log show` did NOT reliably capture `NSLog` from an
  `open`-launched process from inside a sandboxed shell; launchd
  `StandardErrorPath` to a file is the reliable read.
- **launchd respawn:** `KeepAlive=true` respawns on any exit (including exit 0),
  throttled to ~10s. That throttle is the upper bound on first-run activation
  latency after granting.
- **Manual reset for a clean-room test:**
  ```sh
  ./uninstall.sh --purge   # removes app, agent, config, and the AX grant
  ./install.sh             # from zero
  ```
- **History:** an earlier Python/pynput approach was abandoned. Python 3.9
  couldn't compile pyobjc, and the binary couldn't be granted TCC permission
  (symlink / "not trusted"). The native Swift binary in an ad-hoc signed .app is
  the working approach.
