# cc-volume-duck

Ducks your Mac's system volume while you hold **space** to dictate in your
terminal, then restores it to the exact level on release. Like a radio DJ's
fader: the music drops while the mic is open, so dictation quality (and your
focus) isn't fought by whatever was playing.

Built for dictating into Claude Code, but it works for any hold-to-talk flow in
a terminal (iTerm, Terminal, Warp, and other common terminals).

## How it works

A tiny native Swift daemon listens for the space key via a CoreGraphics event
tap (listen-only, it never modifies your keystrokes). When you hold space past a
short threshold and a terminal is frontmost, it fades the volume down to a target
level; on release it fades back to where it was. Config is hot-reloaded, no
restart needed.

## Install

macOS only. Takes a couple of minutes.

### Step 1 - Apple developer tools (one-time)

```sh
xcode-select --install
```

If a popup appears, click **Install** and wait. If it says they're already
installed, skip ahead.

### Step 2 - Clone and run the installer

```sh
git clone https://github.com/billykov/cc-volume-duck.git && cd cc-volume-duck
./install.sh
```

It compiles the tool and sets it up to start automatically. When it finishes it
prints "Installed and running."

### Step 3 - Give it permission (this is the important one)

The tool needs macOS **Accessibility** permission to notice when you hold the
space bar. macOS will not let it work until you allow it.

1. Open **System Settings** (the gear icon).
2. Click **Privacy & Security** in the left sidebar.
3. Click **Accessibility**.
4. Find **cc-duck** in the list and turn its switch **ON** (it turns blue).
   Enter your password or Touch ID if asked.
   - If you don't see `cc-duck` yet, wait about 10 seconds and it will appear.

That's it. Within ~10 seconds it starts working on its own. You do **not** need
to restart anything.

### Step 4 - Try it

Open your **terminal** window (iTerm, Terminal, Warp, etc.), play some music or
a video, then **hold the space bar** for about a second. The volume should fade
down. **Let go** and it fades back.

> Note: it only kicks in when a **terminal** window is active, so holding space
> in other apps won't duck. If your terminal isn't recognized, see
> [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

### If it doesn't work

Open Terminal and paste this to see what happened:

```sh
tail -n 50 ~/Library/Logs/cc-duck.log
```

Send that text to whoever shared this with you. Nine times out of ten it's the
Accessibility permission from Step 3. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Configure

Edit `~/.claude/scripts/cc-duck.json` (changes apply live):

| Field            | Meaning                                        | Default |
|------------------|------------------------------------------------|---------|
| `target`          | Volume to duck to, 0-100                       | 10      |
| `hold_threshold`  | Seconds to hold space before ducking           | 0.15    |
| `fade_duration`   | Seconds for the fade in/out                    | 0.12    |
| `fade_steps`      | Number of volume steps in a fade               | 10      |
| `extra_terminals` | Extra app names to treat as terminals          | `[]`    |

The `hold_threshold` keeps a normal space tap (typing) from triggering a duck.

### IDE-embedded terminals (VS Code, Cursor)

By default it only ducks in standalone terminals (iTerm, Terminal, Warp,
Ghostty, etc.). IDE-integrated terminals are **not** covered: to macOS the
frontmost app is the IDE (`Code`, `Cursor`), not a terminal, and there's no API
to tell "focused in the terminal pane" apart from "editing a file."

You can opt in. The installer asks, or add the app names yourself any time
(applies live, no reinstall):

```json
{ "extra_terminals": ["code", "cursor"] }
```

Trade-off: with this on, holding space ducks whenever that app is frontmost,
**including while you edit a file**, not just in the terminal pane. If that's
annoying, run Claude Code in a standalone terminal instead.

## Uninstall

```sh
./uninstall.sh           # remove app + autostart, keep config
./uninstall.sh --purge   # also remove config and reset the Accessibility grant
```

## Troubleshooting

It logs to `~/Library/Logs/cc-duck.log`. If it isn't ducking, check that first:

```sh
tail -n 50 ~/Library/Logs/cc-duck.log
```

Almost every issue is the Accessibility grant. See
[TROUBLESHOOTING.md](TROUBLESHOOTING.md) for the symptom -> cause -> fix table.

## Notes

- macOS only (uses `osascript` for volume and a CGEvent tap for the key).
- Re-running `install.sh` re-signs the app, which changes its code hash and
  invalidates the Accessibility grant. The old `cc-duck` row may still show ON
  but won't work (it's bound to the previous hash). Remove it with the `-`
  button (or run `tccutil reset Accessibility com.billykov.cc-duck`), then grant
  again so the new binary gets a clean entry.
- Only ducks when a terminal is the frontmost app. The built-in list is
  `TERMINALS` near the top of `cc-duck.swift`. To add one without recompiling,
  use `extra_terminals` in the config (see Configure).
