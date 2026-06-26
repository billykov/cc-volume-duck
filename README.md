# cc-volume-duck

Ducks your Mac's system volume while you hold **space** to dictate in iTerm, then
restores it to the exact level on release. Like a radio DJ's fader: the music
drops while the mic is open, so dictation quality (and your focus) isn't fought
by whatever was playing.

Built for dictating into Claude Code in iTerm, but it works for any
hold-to-talk flow in iTerm.

## How it works

A tiny native Swift daemon listens for the space key via a CoreGraphics event
tap (listen-only, it never modifies your keystrokes). When you hold space past a
short threshold and iTerm is frontmost, it fades the volume down to a target
level; on release it fades back to where it was. Config is hot-reloaded, no
restart needed.

## Install

```sh
./install.sh
```

Requires the Xcode command line tools (`xcode-select --install`). The installer
compiles the daemon, packages it as `~/Applications/cc-duck.app`, ad-hoc signs
it, and sets up a launchd agent so it starts on login.

On first launch macOS prompts for **Accessibility** permission. Toggle
`cc-duck` ON in **System Settings -> Privacy & Security -> Accessibility**.
You can grant it whenever you get to it: macOS caches the trust decision per
process, so the daemon doesn't sit and poll. It exits, and launchd relaunches
it every ~10s; the first relaunch after you grant comes up trusted and starts
working. No manual restart needed. (It's Accessibility, not Input Monitoring,
because the event tap registers there.)

## Configure

Edit `~/.claude/scripts/cc-duck.json` (changes apply live):

| Field            | Meaning                                        | Default |
|------------------|------------------------------------------------|---------|
| `target`         | Volume to duck to, 0-100                        | 10      |
| `hold_threshold` | Seconds to hold space before ducking           | 0.15    |
| `fade_duration`  | Seconds for the fade in/out                     | 0.12    |
| `fade_steps`     | Number of volume steps in a fade                | 10      |

The `hold_threshold` keeps a normal space tap (typing) from triggering a duck.

## Uninstall

```sh
./uninstall.sh           # remove app + autostart, keep config
./uninstall.sh --purge   # also remove config and reset the Accessibility grant
```

## Notes

- macOS only (uses `osascript` for volume and a CGEvent tap for the key).
- Re-running `install.sh` re-signs the app, which changes its code hash and
  invalidates the Accessibility grant. The old `cc-duck` row may still show ON
  but won't work (it's bound to the previous hash). Remove it with the `-`
  button (or run `tccutil reset Accessibility com.billykov.cc-duck`), then grant
  again so the new binary gets a clean entry.
- Only ducks when iTerm is the frontmost app.
