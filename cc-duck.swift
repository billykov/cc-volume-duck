import Cocoa
import CoreGraphics
import ApplicationServices

let CONFIG_FILE = (NSHomeDirectory() as NSString).appendingPathComponent(".claude/scripts/cc-duck.json")
let SAVE_FILE = "/tmp/cc-vol.txt"

struct Config: Codable {
    var target: Int = 20
    var hold_threshold: Double = 0.15
    var fade_duration: Double = 0.25
    var fade_steps: Int = 10
}

var cfg = Config()
var cfgMtime: Date = .distantPast

func loadConfig() {
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: CONFIG_FILE),
          let mtime = attrs[.modificationDate] as? Date, mtime > cfgMtime else { return }
    if let data = try? Data(contentsOf: URL(fileURLWithPath: CONFIG_FILE)),
       let loaded = try? JSONDecoder().decode(Config.self, from: data) {
        cfg = loaded; cfgMtime = mtime
    }
}

func runScript(_ script: String) -> String {
    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", script]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch(); task.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func getVol() -> Int { Int(runScript("output volume of (get volume settings)")) ?? 50 }
func setVol(_ v: Int) { let _ = runScript("set volume output volume \(v)") }

func fade(from start: Int, to end: Int) {
    let steps = cfg.fade_steps
    let delay = cfg.fade_duration / Double(steps)
    for i in 1...steps {
        let v = Int(Double(start) + Double(end - start) * Double(i) / Double(steps))
        setVol(v)
        Thread.sleep(forTimeInterval: delay)
    }
}

// Frontmost app must be a terminal. macOS has no API that says "this is a
// terminal", so we match common ones by name. Add yours here if it's missing.
let TERMINALS = ["iterm", "terminal", "warp", "alacritty", "kitty", "hyper", "wezterm", "ghostty", "tabby", "rio"]

func isTerminalActive() -> Bool {
    let app = runScript("name of (info for (path to frontmost application))").lowercased()
    return TERMINALS.contains { app.contains($0) }
}

var ducked = false
var spaceHeld = false
var holdTimer: Timer?

func doDuck() {
    loadConfig()
    guard spaceHeld, !ducked, isTerminalActive() else { return }
    let current = getVol()
    guard current > cfg.target else { return }
    try? String(current).write(toFile: SAVE_FILE, atomically: true, encoding: .utf8)
    ducked = true
    NSLog("cc-duck: duck \(current) -> \(cfg.target)")
    DispatchQueue.global().async { fade(from: current, to: cfg.target) }
}

// CGEvent taps register under Accessibility. Surface the prompt + list entry.
// AX trust is cached per-process: a process that starts untrusted will NEVER see
// a grant the user makes afterwards. So we don't poll-wait - we exit, and launchd
// (KeepAlive) relaunches us. The next process reads trust fresh, and once the user
// has toggled cc-duck on it passes this check and proceeds.
// ponytail: relies on the launchd KeepAlive agent; ~10s relaunch throttle is the
// ceiling on how fast it starts after granting. Fine for a one-time first run.
let promptOpt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
if !AXIsProcessTrustedWithOptions(promptOpt) {
    NSLog("cc-duck: no Accessibility permission yet; exiting for launchd to relaunch. Toggle 'cc-duck' on in System Settings -> Privacy & Security -> Accessibility.")
    exit(0)
}

let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: CGEventMask(eventMask),
    callback: { _, type, event, _ in
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == 49 else { return Unmanaged.passRetained(event) } // 49 = space

        if type == .keyDown && !spaceHeld {
            spaceHeld = true
            loadConfig()
            DispatchQueue.main.async {
                holdTimer = Timer.scheduledTimer(withTimeInterval: cfg.hold_threshold, repeats: false) { _ in
                    DispatchQueue.global().async { doDuck() }
                }
            }
        } else if type == .keyUp {
            spaceHeld = false
            holdTimer?.invalidate(); holdTimer = nil
            if ducked {
                ducked = false
                if let saved = try? String(contentsOfFile: SAVE_FILE, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                   let savedVol = Int(saved) {
                    try? FileManager.default.removeItem(atPath: SAVE_FILE)
                    NSLog("cc-duck: restore -> \(savedVol)")
                    DispatchQueue.global().async { fade(from: getVol(), to: savedVol) }
                }
            }
        }
        return Unmanaged.passRetained(event)
    },
    userInfo: nil
) else {
    print("Failed to create event tap - check Input Monitoring permission")
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
loadConfig()
NSLog("cc-duck: listening (Accessibility OK, target=\(cfg.target))")
CFRunLoopRun()
