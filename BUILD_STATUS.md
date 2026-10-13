# Build status

Checked on 13 October 2026 on arm64 macOS 27.0.1 with Apple Swift 6.4.
This file records local checks for the lid-close change on `codex/closed-lid-awake`.
No new release was published.

## Passed

- Ten tests passed. They checked cleanup order, assertion failure, lid-request failure,
  restore retry, one owned guard, normal shutdown, startup failure, killed-guard cleanup,
  canceled startup, and the cup icons at 1× and 2×.
- The release build passed. The property list passed validation.
  The local ad hoc signature passed strict validation and uses Hardened Runtime.
- The signed guard created one `PreventUserIdleSystemSleep` assertion. It did not create
  a display-sleep assertion. The IOKit lid request succeeded without administrator rights.
- Closing the guard pipe released its assertion and exited with status 0.
- With no heartbeat, the guard restored lid sleep and exited after 15.07 seconds.
- A harness used the app's `AwakeController` and the signed guard. Heartbeats kept the guard
  alive for 17 seconds. A second guard was rejected. Killing the parent with SIGKILL caused
  the guard to exit and release its assertion.
- `pmset -g custom` had the same output before and after the native checks.
- The installed executable matched the tested release executable. One app process was running.
  It had no guard child, which confirms that the app started Off.
  The previous app is saved in `.build/CupWake-before-lid-fix.app`.

The restore claims above mean that the IOKit restore call succeeded and cleanup completed.
The registry does not expose this control's ownership bit. These checks do not prove physical
lid-close sleep behavior. The app does not use `pmset disablesleep` or change display settings.

## Commands

```sh
sh Scripts/test.sh
sh Scripts/build-app.sh
plutil -lint dist/CupWake.app/Contents/Info.plist
codesign --verify --strict --verbose=2 dist/CupWake.app
```

Native check results and the parent harness are in `.build/`.
The new bundle is in `dist/CupWake.app`.
The Apple test tools report optional missing search paths and a macOS 14 test-framework target.
These warnings did not prevent the tests or build.

## Open checks

The UI tool timed out when it connected to the menu-bar-only app. Its Finder screenshot was
blank. Physical left-click, right-click, and VoiceOver behavior could not be verified.
No new UI test result is claimed.

The lid must be closed on the actual Mac to verify continued execution and network access.
Test both battery and AC power, with no external display. Test power changes while the lid
is closed. Also test display sleep and an explicit Apple-menu Sleep command.
Remote agent access was not tested. CupWake does not configure a remote-access service.

The lid control is an internal Apple interface. Other macOS versions and Intel hardware were
not tested. Energy use was not measured. The app does not monitor battery or heat.
If both the app and guard are forcibly killed, cleanup cannot run. A restart clears the
temporary lid control. Do not use another lid-control app at the same time.

Developer ID signing and notarization remain open. This build has a local ad hoc signature.
