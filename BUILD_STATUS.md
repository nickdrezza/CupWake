# Build status

Checked on 13 October 2026 on arm64 macOS 27 with Apple Swift 6.4.
This file records local checks before the v0.2.0 preview release.

## Passed

- Six tests passed. They checked one owned child, default sleep assertion creation and
  release, an unexpected child exit, exit when the watched process ends, startup failure,
  and an old exit callback after a new child starts.
- The icon test passed at 1× and 2×. Off has no steam. On has fill and steam.
  The rendered icons were inspected on light and dark backgrounds.
- The release build passed. The property list passed validation.
  The local ad hoc signature passed strict validation and uses Hardened Runtime.
- The release bundle launched. No `caffeinate` child was present after launch.

The app has three source files and one test target. The old UI, policy core, power monitor,
Low Power mode, timer, and automatic-sleep adapter were removed.
The README contains the warning against use in a backpack or an enclosed space.

## Commands

```sh
sh Scripts/test.sh
sh Scripts/build-app.sh
plutil -lint dist/CupWake.app/Contents/Info.plist
codesign --verify --strict --verbose=2 dist/CupWake.app
```

Logs and icon previews are in `.build/`. The bundle is in `dist/CupWake.app`.
The Apple test tools report optional missing search paths and a macOS 14 test-framework target.
These warnings did not prevent the tests or build.

## Open checks

The UI tool timed out when it connected to the menu-bar-only app. Its Finder screenshot was
blank. Physical left-click, right-click, and VoiceOver behavior could not be verified with
that tool. The native actions are implemented, but no UI test result is claimed.

Other macOS versions and Intel hardware were not tested. Energy use was not measured.
The app does not monitor battery or heat. It does not detect an enclosed space.
The v0.2.0 preview archive is for Apple silicon. It has a local ad hoc signature.
Developer ID signing, notarization, Intel runtime checks, and other OS checks remain open.
No system power or security setting was changed.
