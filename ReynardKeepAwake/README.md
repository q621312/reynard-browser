# Reynard KeepAwake 2.0

Minimal Objective-C tweak/dylib intended for TrollStore injection into Reynard.

- Supported bundles: `com.minh-ton.Reynard` and `com.r2`
- Architecture: arm64
- Deployment target: iOS 14+
- Settings: adds a **保持屏幕常亮** switch as an extra section at the bottom of Reynard's Settings screen.
- Default: enabled when the preference has never been set.
- Persistence: the switch value is stored in the app's standard user defaults and survives relaunches.
- Behavior: when enabled, disables the idle timer only while Reynard is active; when disabled, restores the app's last requested idle-timer state immediately. Switching away from Reynard restores normal behavior. Low Power Mode is not modified.

## Build

The GitHub Actions workflow uses the Theos container and uploads `ReynardKeepAwake.dylib` plus `filter.plist` as the `ReynardKeepAwake-dylib` artifact.

## Test checklist

1. Inject only into the main Reynard app, not its Helper.
2. Open Settings and confirm the **保持屏幕常亮** switch appears at the bottom and is on by default.
3. Turn it off and confirm Auto-Lock works while Reynard remains open.
4. Turn it on again and confirm the screen stays awake without restarting Reynard.
5. Leave Reynard idle longer than Auto-Lock, including with Low Power Mode enabled.
6. Switch away and confirm normal Auto-Lock behavior in other apps.
7. Return to Reynard and confirm the preference is applied again.
8. Force-quit and relaunch Reynard; confirm the switch retains its previous state.

Successful compilation does not prove runtime compatibility; verify the Settings hooks and switch behavior on-device.
