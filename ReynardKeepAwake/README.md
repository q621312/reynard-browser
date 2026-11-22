# Reynard KeepAwake 1.0

Minimal Objective-C tweak/dylib intended for TrollStore injection into Reynard.

- Target bundle: `com.minh-ton.Reynard`
- Architecture: arm64
- Deployment target: iOS 14+
- Behavior: disables the idle timer while Reynard is foreground-active, then restores Reynard's last requested idle-timer state on resign-active/background. Low Power Mode is not modified.

## Build

The GitHub Actions workflow uses the Theos container and uploads `ReynardKeepAwake.dylib` plus `filter.plist` as the `ReynardKeepAwake-dylib` artifact.

## Test checklist

1. Inject only into the main Reynard app, not its Helper.
2. Leave Reynard idle longer than Auto-Lock.
3. Repeat with Low Power Mode enabled.
4. Switch away and confirm the other app's normal Auto-Lock behavior.
5. Return to Reynard and confirm the screen stays awake.
6. Remove/disable injection and verify normal behavior.

This is an untested build prototype; successful compilation does not prove device behavior.