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

## Install (step by step, no experience needed)

This takes about 5 minutes. You'll copy and paste a few lines into the Terminal
app. macOS only.

### Step 1 - Open the Terminal app

Press **Cmd (⌘) + Space**, type `Terminal`, and press **Return**. A window with
a text prompt opens. You'll paste commands here and press **Return** after each.

### Step 2 - Install Apple's developer tools (one-time)

Copy this line, paste it into Terminal, press **Return**:

```sh
xcode-select --install
```

- If a popup appears, click **Install** and wait for it to finish (a few
  minutes).
- If it says "command line tools are already installed", great, skip ahead.

### Step 3 - Download this project

**Easiest way (no extra setup):**
1. Go to **https://github.com/billykov/cc-volume-duck**
2. Click the green **`< > Code`** button, then **Download ZIP**.
3. Open your **Downloads** folder and double-click the ZIP to unzip it. You'll
   get a folder named `cc-volume-duck-main`.

Then point Terminal at that folder by pasting this and pressing **Return**:

```sh
cd ~/Downloads/cc-volume-duck-main
```

(If you know git, you can instead run
`git clone https://github.com/billykov/cc-volume-duck.git && cd cc-volume-duck`.)

### Step 4 - Run the installer

Paste this and press **Return**:

```sh
bash install.sh
```

It will compile the tool and set it up to start automatically. When it finishes
it prints "Installed and running."

### Step 5 - Give it permission (this is the important one)

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

### Step 6 - Try it

Open an **iTerm** window, play some music or a video, then **hold the space bar**
for about a second. The volume should fade down. **Let go** and it fades back.

> Note: right now it only kicks in when **iTerm** is the active window. If you
> use the regular Terminal app or another one, it won't trigger (yet).

### If it doesn't work

Open Terminal and paste this to see what happened:

```sh
tail -n 50 ~/Library/Logs/cc-duck.log
```

Send that text to whoever shared this with you. Nine times out of ten it's the
Accessibility permission from Step 5. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

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
- Only ducks when iTerm is the frontmost app.
