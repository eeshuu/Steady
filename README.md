# Steady — two calm minutes before the call

Steady is an iOS app that uses the front camera to read your **breathing rate, pulse, HRV and facial expression** with the [Presage SmartSpectra SDK](https://github.com/Presage-Security/SmartSpectra). It then runs a breathing exercise that **adapts to you in real time**.

Built for the [DEV Presage SmartSpectra SDK Challenge](https://dev.to/challenges/presage-2026-11-04).

> Steady is a wellness tool, not a medical device. It doesn't diagnose or treat anything.

## How it responds to live signals

| Live signal (SmartSpectra) | What Steady does with it |
|---|---|
| **Breathing rate** | The guide starts at *your* measured rate, not a fixed number. Every 30 s it compares your live rate to the guide. If you're keeping up, it slows by 1 breath/min toward 6/min. If you're 2.5+ above, it holds. If you're 5+ above, it eases back up. |
| **Chest breathing trace** | Drawn live under the orb so you can see your own breath next to the guide. |
| **Pulse** | Shows a neutral comparison with your check-in: "Pulse is 6 bpm lower than at check-in." |
| **Expressions** | If a tense expression dominates (angry, fear, sad, disgust, contempt), a soft cue says "Let your jaw and forehead soften." |
| **HRV (RMSSD)** | Shown before and after on the summary screen. |
| **Validation status** | The "Signal good / Adjusting" chip and the SDK's own guidance text (lighting, framing, motion). |

## Flow

1. **Consent:** a plain-language explanation of the camera and data use, an opt-in toggle for SDK diagnostics (off by default), and an explicit agreement toggle.
2. **Check-in (20–45 s):** sit still while SmartSpectra locks on and takes a baseline.
3. **Breathe (about 2 min, open-ended):** the adaptive orb, with optional haptics on each inhale and exhale so you can close your eyes.
4. **Summary:** before → after for breathing, pulse and HRV. **Done** discards everything.

## Setup

Requirements: Xcode 16+ (SmartSpectra 3.5.0 is a Swift 6 tools package), **a physical iPhone running iOS 17+** (the simulator has no camera), and a free Presage API key.

1. Get an API key: register at <https://physiology.presagetech.com/auth/register>, then copy the key from your portal.
2. Clone the repo and add your key:
   ```bash
   git clone <this repo>
   cd Steady
   cp Steady/App/Secrets.example.swift Steady/App/Secrets.swift
   # edit Secrets.swift: delete the #if false / #endif lines and paste your key
   ```
3. Generate the Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen):
   ```bash
   brew install xcodegen
   xcodegen generate
   open Steady.xcodeproj
   ```
   This pulls `SmartSpectra-Swift` **3.5.0** through Swift Package Manager.
4. Choose your Team under **Signing & Capabilities** and change the bundle ID if needed.
5. Run on your iPhone and allow camera access. Readings settle after a few seconds in good, even light.

### Without XcodeGen

Create a new iOS App project named **Steady** (SwiftUI, iOS 17). Then:

1. Add the package `https://github.com/Presage-Security/SmartSpectra-Swift` at version 3.5.0.
2. Drag in the `Steady/App`, `Steady/Model` and `Steady/Views` folders and delete the template `ContentView.swift` and the template app file.
3. Add **Privacy - Camera Usage Description** to the target's Info tab.

## Consent and data handling

- **Camera:** iOS asks for permission, and Steady shows its own consent screen before the camera ever starts. The camera runs only during check-in and breathing. It stops when you finish, tap Stop, or leave the app. Steady never monitors in the background.
- **Storage:** none. No video, images or vital signs are written to disk. Readings sit in a short rolling buffer in memory, and **Done** clears it. The only things kept in `UserDefaults` are your two consent toggles.
- **Sharing:** Steady has no backend, analytics or AI service. The SmartSpectra SDK talks to Presage's servers using the app's API key (authentication and SDK operation).
- **SDK telemetry:** **off by default.** If you turn on "Share SDK diagnostics", the SDK sends session summaries and device-readiness reports to Presage: device model, OS, performance and quality counts. Per [Presage's telemetry docs](https://smartspectra.presagetech.com/docs/telemetry-and-privacy), these contain no raw video frames and no measured vital-sign values. They are authenticated, so they are not anonymous, and Presage's policies govern how long they're kept.
- **Retention and deletion:** nothing to delete on Steady's side. Delete the app to clear the consent toggles.
- **Limits:** wellness estimates only. No diagnosis, treatment or medical decision-making.

## Project layout

```
Steady/
  App/       SteadyApp.swift (SDK config), Secrets.example.swift
  Model/     VitalsStore.swift (in-memory buffers), BreathPacer.swift (adaptive pacing)
  Views/     Consent, CheckIn, Breathe, Summary
project.yml  XcodeGen spec
```

## License

MIT
