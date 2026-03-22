# Translate MP3GainExpress from Objective-C to Swift

Replaces all Objective-C source files with Swift equivalents, preserving identical runtime behavior. No SwiftUI — AppKit/XIB UI is unchanged.

## Files replaced

| ObjC | Swift |
|---|---|
| `main.m` + `Mp3GainMacAppDelegate.h/.m` | `Mp3GainMacAppDelegate.swift` (`@NSApplicationMain`) |
| `Preferences/m3gPreferences.h/.m` | `Preferences/m3gPreferences.swift` |
| `Process/m3gInputItem.h/.m` | `Process/m3gInputItem.swift` |
| `Process/m3gInputList.h/.m` | `Process/m3gInputList.swift` |
| `Process/Mp3GainTask.h/.m` | `Process/Mp3GainTask.swift` |
| `Window/M3GWindow.h/.m` | `Window/M3GWindow.swift` |
| `Language/M3GLanguageSelectorController.h/.m` | `Language/M3GLanguageSelectorController.swift` |
| `MP3GainExpress-Prefix.pch` | removed |

## Translation decisions

- `@NSApplicationMain` on `Mp3GainMacAppDelegate` replaces `main.m` — no `main.swift` needed
- `m3gPreferences` becomes a proper Swift singleton via `static let shared`
- ObjC `NSMutableArray<Mp3GainTask*>` task queues become `[Mp3GainTask]`
- `MP3GActionType` enum converted from ObjC `typedef enum` to Swift `enum`
- Magic numbers extracted as named constants: `defaultDbLevel` (89.0 dB aacgain baseline), `minVolume`/`maxVolume` (valid input range)
- `M3GLanguageSelectorController.supportedLanguages` made `static let` so window height derives from `languages.count` rather than a manually-synced constant

## Project file

- All ObjC `PBXBuildFile`/`PBXFileReference` entries replaced with Swift equivalents
- `GCC_PRECOMPILE_PREFIX_HEADER` / `GCC_PREFIX_HEADER` removed from both Debug and Release configs
- `SWIFT_VERSION = 5.0` added to target build settings

