# Translate MP3GainExpress from Swift + XIB to SwiftUI

Replaces all AppKit/XIB-based UI files with pure SwiftUI equivalents. The model and processing layers (`m3gInputItem`, `m3gInputList`, `Mp3GainTask`, `m3gPreferences`) are unchanged.

## Files replaced

| Swift + XIB | SwiftUI |
|---|---|
| `Mp3GainMacAppDelegate.swift`<br>(`@NSApplicationMain`) | `MP3GainApp.swift`<br> (`@main struct MP3GainApp: App`) |
| `Base.lproj/MainMenu.xib` | `Views/ContentView.swift` |
| `Window/M3GWindow.swift` | removed, no custom `NSWindow` subclass needed |
| `Preferences/M3GPreferencesViewController.swift`<br>+ Preferences XIB | `Views/PreferencesView.swift` |
| `Language/M3GLanguageSelectorController.swift`<br>+ LanguageSelector XIB | `Language/LanguageSelectorView.swift` |
| Progress / Warning window XIBs | `ProcessingSheetView`<br>+ `WarningSheetView`<br>(inline in `ContentView.swift`) |
| _(none)_ | `Model/AppViewModel.swift`<br>(new `ObservableObject` state layer) |

## Translation decisions

- `@NSApplicationMain` on `Mp3GainMacAppDelegate` replaced by `@main struct MP3GainApp: App`; the `NSApplicationDelegate` is bridged back in via `@NSApplicationDelegateAdaptor(AppDelegate.self)` to preserve `applicationShouldTerminateAfterLastWindowClosed` and `applicationSupportsSecureRestorableState`
- `WindowGroup` + `Settings` scenes replace the XIB-defined main window and preferences panel; `Settings { PreferencesView() }` adds the "Settings…" / "Preferences…" menu item (`⌘,`) automatically
- `AppViewModel: ObservableObject` introduced to replace the controller logic that was spread across the XIB outlets/actions and `Mp3GainMacAppDelegate`; all `@Published` properties drive the SwiftUI views reactively
- `ContentView` (`SwiftUI.Table`) replaces the `NSTableView` defined in `MainMenu.xib`; `Table` requires macOS 13+
- Toolbar replaced by a plain `HStack` of `Button(style: .plain)` views ("fake toolbar") because `NSToolbar` from the XIB did not map cleanly to SwiftUI toolbar APIs on macOS 13; toolbar icons (AddSong / AddFolder / ClearSong / ClearAll) moved from the `Toolbar-icons/` folder into `Assets.xcassets` imagesets so `Image("name")` picks them up correctly
- Progress and warning dialogs become `.sheet(isPresented:)` modifiers on `ContentView`, eliminating two separate `NSWindow`/XIB pairs
- Drag-and-drop handled by `.dropDestination(for: URL.self)` on the `Table`, replacing the `NSDraggingDestination` delegate methods that were wired in the XIB
- `NSOpenPanel` (AppKit) is still used for file/folder picking via `AppViewModel.showAddFilesPanel()` and `showAddFolderPanel()`; no pure-SwiftUI file picker equivalent exists for the required feature set on macOS 13
- `M3GWindow` (`NSWindow` subclass with `isMovableByWindowBackground`) removed — the `VisualEffectView` (`NSViewRepresentable` wrapping `NSVisualEffectView`) provides the frosted-glass background directly in SwiftUI without needing a custom window
- ViewBridge warning suppression previously handled by `M3GPreferencesViewController` and an `NSWindow.didBecomeKeyNotification` observer in `AppDelegate` is no longer needed: the SwiftUI `Settings` scene manages the preferences window internally and the `NSPanel`-exclusion observer is dropped
- `m3gInputItem` is a reference type (`NSObject`) mutated in-place by `Mp3GainTask`; `AppViewModel.tableVersion: UUID` is incremented after each processing batch to force SwiftUI `Table` to re-read the updated data
- Language selector promoted from an `NSWindowController`-managed XIB window to a SwiftUI `.sheet()` in `ContentView`, keeping the same list-based UI via a `List` with selection binding; language change still writes to `UserDefaults` key `AppleLanguages` and prompts for a restart

## Project file

- All XIB `PBXBuildFile`/`PBXFileReference` entries removed
- New Swift source entries added for `MP3GainApp.swift`, `AppViewModel.swift`, `ContentView.swift`, `PreferencesView.swift`, and `LanguageSelectorView.swift`
- `MACOSX_DEPLOYMENT_TARGET` raised to `13.0` to satisfy `SwiftUI.Table` availability requirement
- `SWIFT_VERSION` remains `5.0`
