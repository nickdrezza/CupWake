# CupWake

**Keep your Mac awake. One click.**

An empty cup means Off. A filled cup with steam means On.

A small native macOS app that keeps agents and other tasks running with the lid closed.
Click to turn it on. Click again to turn it off. That is the whole app.

The [v0.2.0 preview](https://github.com/nickdrezza/CupWake/releases/tag/v0.2.0) prevents idle sleep only.
Build this branch to use the new lid control. This change has no published release yet.

## One cup. Two states.

- **Empty cup:** Off.
- **Filled cup with steam:** On. CupWake prevents idle sleep and lid-close sleep.
- **Right-click:** Quit CupWake. Control-click works too.

CupWake starts Off. It has no window, settings, timer, or saved state.
It has no package dependencies.

> **Do not use CupWake while your Mac is in a backpack or an enclosed space.**
> Keep the Mac on an open surface with airflow. CupWake does not monitor heat or battery charge.

## Install

The preview download is for **Apple silicon** Macs with macOS 13 or later.
Unzip the file, move `CupWake.app` to Applications, and open it.

This preview has a local ad hoc signature. It has no Developer ID signature or notarization.
macOS can block a downloaded copy. You can build from source instead.
See [Apple's distribution guide](https://developer.apple.com/developer-id/) for the signing requirements.

## What On does

CupWake starts one guard process from its own executable. The guard holds a
`PreventUserIdleSystemSleep` assertion. It also disables lid-close sleep with the
`kPMSetClamshellSleepState` control on `IOPMrootDomain`. No external display or administrator
password is required on the tested Mac.

CupWake does not hold a display-sleep assertion. It does not change display timers, brightness,
screen-lock settings, or persistent power settings. The display can turn off as usual.
An explicit Apple-menu Sleep command can still put the Mac to sleep.

The lid control is an internal Apple interface. It can change between macOS versions.
The guard repeats the request at least once per second while it receives a heartbeat.
CupWake shows On only after the assertion and the lid request succeed. A successful request
does not prove that physical lid-close behavior works on every Mac.

Off and Quit close the guard pipe. The guard restores lid sleep, releases its assertion, and exits.
A CupWake crash also closes the pipe. If CupWake stops responding, the guard restores sleep
after 15 seconds without a heartbeat. If the guard is killed, the running app restores lid sleep.
If macOS rejects a restore request, the guard or app retries before it reports Off.

If both the app and guard are forcibly killed, cleanup cannot run. Restart the Mac to clear
the temporary lid control. Do not run another lid-control app at the same time. These apps
share the same system control. Other apps can still prevent idle sleep after CupWake turns Off.

If startup fails, the cup stays Off and the app sounds a beep. CupWake does not start agents,
change network access, or repair an agent connection. A working network and remote-access
service are still required to reach an agent.

| Setting | Action | Result |
| --- | --- | --- |
| On | Close the lid | CupWake requests continued system operation. Agents can continue to run. |
| On | Let the display turn off | The system stays awake. Display sleep remains allowed. |
| On | Lock the screen | Background agents can continue to run. |
| On | Select Apple menu → Sleep | Manual sleep remains allowed. Agents pause while the Mac sleeps. |
| On | Click the cup | The guard restores lid sleep and idle sleep. The cup then shows Off. |
| On | Quit CupWake | The guard restores sleep and exits. |
| Off | Click the cup | The cup shows On after both power requests succeed. |
| Off | Close the lid | Normal macOS lid behavior applies. |
| Either | Restart and open CupWake | CupWake starts Off. |

See [BUILD_STATUS.md](BUILD_STATUS.md) for the hardware checks that remain open.

## Build from source

Use Swift 6 or later on macOS 13 or later. Tests require macOS 14 or later.

```sh
git clone https://github.com/nickdrezza/CupWake.git
cd CupWake
sh Scripts/test.sh
sh Scripts/build-app.sh
open dist/CupWake.app
```

Tests use fake power controls and temporary guard processes. They do not put the Mac to sleep.
The build script creates a locally signed app with Hardened Runtime in `dist/`.
It does not install the app or change system settings. Do not build as root.

To create a release archive and SHA-256 checksum:

```sh
sh Scripts/package-release.sh
```

## Inside the cup

| File | Purpose |
| --- | --- |
| `CupWakeApp.swift` | Menu-bar item, click actions, and Quit. |
| `AwakeController.swift` | One owned guard, heartbeat, startup check, and exit cleanup. |
| `AwakeWorker.swift` | Idle assertion, lid request, timeout, and restore. |
| `LidSleepControl.swift` | IOKit calls and session ownership. |
| `CupIcon.swift` | Vector cup icons at one position. On has fill and steam. |

No network request, power monitor, or privileged helper is used.
The parent sends a heartbeat every two seconds. It prevents App Nap while the guard runs.
Stopping the guard does not block the main thread. Old exit callbacks cannot clear a new guard.
Tests cover process ownership, cleanup order, restore errors, cancellation, startup errors,
and both icons at 1× and 2×.
See [BUILD_STATUS.md](BUILD_STATUS.md) for the checks and limits of this build.

## License

Copyright 2026 Nick. [GPL-3.0-only](LICENSE).
