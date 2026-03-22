//
//  Mp3GainMacAppDelegate.swift
//  MP3Gain Express for Mac OS X
//

import AppKit
import UniformTypeIdentifiers
import Sparkle

@NSApplicationMain
class Mp3GainMacAppDelegate: NSObject, NSApplicationDelegate {
    // Valid target volume range accepted by aacgain
    private static let minVolume: Float = 50.0
    private static let maxVolume: Float = 100.0
    private var inputList = m3gInputList()
    private var tasks: [Mp3GainTask] = []
    private var cancelCurrentOperation = false
    private var updaterController: SPUStandardUpdaterController!
    private var windowKeyObserver: NSObjectProtocol?

    @IBOutlet weak var window: NSWindow!
    @IBOutlet var vwMainBody: NSView!
    @IBOutlet var tblFileList: NSTableView!
    @IBOutlet var txtTargetVolume: NSTextField!
    @IBOutlet var pnlProgressView: NSPanel!
    @IBOutlet var lblStatus: NSTextField!
    @IBOutlet var pbTotalProgress: NSProgressIndicator!
    @IBOutlet var btnCancel: NSButton!
    @IBOutlet var vwSubfolderPicker: NSView!
    @IBOutlet var ddlSubfolders: NSPopUpButton!
    @IBOutlet var mnuAdvancedGain: NSMenu!
    @IBOutlet var chkAvoidClipping: NSButton!
    @IBOutlet var btnAdvancedMenu: NSButton!
    @IBOutlet var chkAlbumGain: NSButton!
    @IBOutlet var wndPreferences: NSWindow!
    @IBOutlet var pnlWarning: NSPanel!
    @IBOutlet var chkDoNotWarnAgain: NSButton!
    @IBOutlet var lblWarningMessage: NSTextField!
    @IBOutlet var tbiAddFile: NSToolbarItem!
    @IBOutlet var tbiAddFolder: NSToolbarItem!
    @IBOutlet var tbiClearFile: NSToolbarItem!
    @IBOutlet var tbiClearAll: NSToolbarItem!
    @IBOutlet var mnuCheckForUpdates: NSMenuItem!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        tblFileList.dataSource = inputList
        tblFileList.delegate = inputList
        tblFileList.registerForDraggedTypes([.URL])

        // Wrap the preferences content view in a view controller so that
        // viewServiceDidTerminateWithError: is handled, suppressing the
        // TUINSRemoteViewController console warning on open/close.
        let prefsVC = M3GPreferencesViewController(nibName: nil, bundle: nil)
        prefsVC.view = wndPreferences.contentView!
        wndPreferences.contentViewController = prefsVC

        // Apply the same suppression to any other application window that
        // becomes key without a content view controller (e.g. Sparkle's update
        // dialog, which uses a WKWebView for release notes).
        windowKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.injectViewControllerIfNeeded(notification)
        }

        let prefs = m3gPreferences.shared
        pnlWarning.title = NSLocalizedString("WarningTitle", comment: "Warning")
        lblWarningMessage.stringValue = NSLocalizedString(
            "WarningText",
            comment: "In some situations the modifications made by MP3Gain could damage your files. If you have never used this application before or are concerned about the results, please backup your original files before making changes to them."
        )
        if prefs.rememberOptions {
            txtTargetVolume.floatValue = prefs.volume
            chkAvoidClipping.state = prefs.noClipping ? .on : .off
        }
        if !prefs.hideWarning {
            chkDoNotWarnAgain.title = NSLocalizedString("DontWarnAgain", comment: "Do not show this warning again")
            pnlWarning.orderFront(nil)
        }

        // Set toolbar images as template so they get inverted automatically in dark mode
        if let addSong = NSImage(named: "AddSong.png") {
            addSong.isTemplate = true
            tbiAddFile.image = addSong
        }
        if let addFolder = NSImage(named: "AddFolder.png") {
            addFolder.isTemplate = true
            tbiAddFolder.image = addFolder
        }
        if let clearSong = NSImage(named: "ClearSong.png") {
            clearSong.isTemplate = true
            tbiClearFile.image = clearSong
        }
        if let clearAll = NSImage(named: "ClearAll.png") {
            clearAll.isTemplate = true
            tbiClearAll.image = clearAll
        }
        if #available(macOS 11.0, *) {
            mnuCheckForUpdates.image = NSImage(
                systemSymbolName: "arrow.triangle.2.circlepath",
                accessibilityDescription: "Check for updates"
            )
        }

        // Add Language menu to the menu bar (inserted before the Help menu, which is always last)
        let mainMenu = NSApp.mainMenu!
        let languageMenuItem = NSMenuItem()
        languageMenuItem.title = NSLocalizedString("Language menu", comment: "Language")
        let languageMenu = NSMenu(title: NSLocalizedString("Language menu", comment: "Language"))
        languageMenuItem.submenu = languageMenu
        let selectLanguageItem = NSMenuItem(
            title: NSLocalizedString("Select Language menu item", comment: "Select Language..."),
            action: #selector(showLanguageSelector(_:)),
            keyEquivalent: "l"
        )
        selectLanguageItem.keyEquivalentModifierMask = .command
        selectLanguageItem.target = self
        languageMenu.addItem(selectLanguageItem)
        mainMenu.insertItem(languageMenuItem, at: mainMenu.numberOfItems - 1)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if let observer = windowKeyObserver {
            NotificationCenter.default.removeObserver(observer)
            windowKeyObserver = nil
        }
        let prefs = m3gPreferences.shared
        if prefs.rememberOptions {
            let targetVol = txtTargetVolume.floatValue
        if targetVol >= Mp3GainMacAppDelegate.minVolume && targetVol <= Mp3GainMacAppDelegate.maxVolume {
                prefs.volume = targetVol
            }
            prefs.noClipping = (chkAvoidClipping.state == .on)
        }
    }

    @IBAction func showPreferences(_ sender: Any) {
        wndPreferences.makeKeyAndOrderFront(self)
    }

    private func injectViewControllerIfNeeded(_ notification: Notification) {
        guard let win = notification.object as? NSWindow,
              win.contentViewController == nil,
              let contentView = win.contentView else { return }
        let vc = M3GPreferencesViewController(nibName: nil, bundle: nil)
        vc.view = contentView
        win.contentViewController = vc
    }

    @IBAction func btnAddFiles(_ sender: Any) {
        let fbox = NSOpenPanel()
        if #available(macOS 12.0, *) {
            fbox.allowedContentTypes = [
                UTType(filenameExtension: "mp3")!,
                UTType(filenameExtension: "mp4")!,
                UTType(filenameExtension: "m4a")!
            ]
        } else {
            fbox.allowedFileTypes = ["mp3", "mp4", "m4a"]
        }
        fbox.allowsOtherFileTypes = true
        fbox.allowsMultipleSelection = true
        fbox.beginSheetModal(for: window) { result in
            if result == .OK {
                for url in fbox.urls where url.isFileURL {
                    self.inputList.addFile(url.path)
                }
                self.tblFileList.reloadData()
            }
        }
    }

    @IBAction func btnAddFolder(_ sender: Any) {
        let fbox = NSOpenPanel()
        fbox.allowsMultipleSelection = true
        fbox.canChooseDirectories = true
        fbox.canChooseFiles = false
        ddlSubfolders.removeAllItems()
        ddlSubfolders.addItem(withTitle: NSLocalizedString("None", comment: "None"))
        ddlSubfolders.addItem(withTitle: NSLocalizedString("1_below", comment: "1 subfolder below"))
        ddlSubfolders.addItem(withTitle: NSLocalizedString("2_below", comment: "2 subfolders below"))
        ddlSubfolders.addItem(withTitle: NSLocalizedString("3_below", comment: "3 subfolders below"))
        ddlSubfolders.addItem(withTitle: NSLocalizedString("4_below", comment: "4 subfolders below"))
        ddlSubfolders.addItem(withTitle: NSLocalizedString("5_below", comment: "5 subfolders below"))
        fbox.accessoryView = vwSubfolderPicker
        if fbox.responds(to: #selector(getter: NSOpenPanel.isAccessoryViewDisclosed)) {
            fbox.isAccessoryViewDisclosed = true
        }
        fbox.beginSheetModal(for: window) { result in
            if result == .OK {
                let depthAmount = self.ddlSubfolders.indexOfSelectedItem
                for url in fbox.urls {
                    self.inputList.addDirectory(url.path, subFoldersRemaining: depthAmount)
                }
                self.tblFileList.reloadData()
            }
        }
    }

    @IBAction func btnClearFile(_ sender: Any) {
        let selRows = tblFileList.selectedRowIndexes
        var idx = selRows.last
        while let curIdx = idx {
            inputList.remove(at: curIdx)
            idx = selRows.integerLessThan(curIdx)
        }
        tblFileList.reloadData()
    }

    @IBAction func btnClearAll(_ sender: Any) {
        inputList.clear()
        tblFileList.reloadData()
    }

    private func checkValidOperation() -> Bool {
        let gain = txtTargetVolume.floatValue
        if gain < Mp3GainMacAppDelegate.minVolume || gain >= Mp3GainMacAppDelegate.maxVolume {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("InvalidVolume", comment: "Invalid target volume!")
            alert.informativeText = NSLocalizedString(
                "VolumeInfo",
                comment: "The target volume should be a number between 50 and 100 dB."
            )
            alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK"))
            alert.runModal()
            return false
        }
        return true
    }

    @IBAction func btnAnalyze(_ sender: Any) {
        if checkValidOperation() && inputList.count > 0 {
            window.beginSheet(pnlProgressView, completionHandler: nil)
            lblStatus.stringValue = NSLocalizedString("Working", comment: "Working...")
            pbTotalProgress.usesThreadedAnimation = true
            pbTotalProgress.startAnimation(self)
            pbTotalProgress.minValue = 0.0
            pbTotalProgress.maxValue = Double(inputList.count)
            pbTotalProgress.doubleValue = 0.0
            btnCancel.isEnabled = true
            cancelCurrentOperation = false

            let albumGain = chkAlbumGain.state == .on
            doAnalysis(album: albumGain)
        }
    }

    private func getNumConcurrentTasks() -> Int {
        return m3gPreferences.shared.numProcesses
    }

    private func doAnalysis(album: Bool) {
        tasks = []
        if !album || inputList.count == 1 {
            for i in 0..<inputList.count {
                let task = Mp3GainTask.task(withFile: inputList.object(at: i), action: .analyze)
                task.desiredDb = Double(txtTargetVolume.floatValue)
                task.onProcessingComplete = { [weak task] in
                    if let t = task { self.handleTaskCompletion(t) }
                }
                tasks.append(task)
            }
        } else {
            //This is an album - Do not process it twice because reprocessing doesn't use single file data.
            let task = Mp3GainTask.task(withFiles: inputList.allObjects(), action: .analyze)
            task.desiredDb = Double(txtTargetVolume.floatValue)
            task.onProcessingComplete = { [weak task] in
                if let t = task { self.handleTaskCompletion(t) }
            }
            tasks.append(task)
        }
        for i in 0..<min(tasks.count, getNumConcurrentTasks()) {
            tasks[i].process()
        }
    }

    private func handleTaskCompletion(_ task: Mp3GainTask) {
        DispatchQueue.main.async {
            var replacement = self.tasks.filter { $0 !== task }
            if task.failureCount == 1 {
                //Re-add file to end of the list on the first failure.
                replacement.append(task)
            }
            self.tasks = replacement
            let total = Double(self.inputList.count - replacement.count)
            self.pbTotalProgress.doubleValue = total

            let filesLeft = replacement.count
            if filesLeft == 0 {
                self.window.endSheet(self.pnlProgressView) //Tell the sheet we're done.
                self.pnlProgressView.orderOut(self)  //Let's hide the sheet.
                self.tblFileList.reloadData()
                self.tasks = []
            } else {
                //Find next file to begin processing
                for nextTask in replacement {
                    //Album task MUST be processed last, so check files left even though it should
                    //always be at the end of the list.
                    if !nextTask.inProgress && (filesLeft == 1 || nextTask.files.count == 1) {
                        nextTask.process()
                        break
                    }
                }
            }
        }
    }

    @IBAction func btnApplyGain(_ sender: Any) {
        if checkValidOperation() && inputList.count > 0 {
            window.beginSheet(pnlProgressView, completionHandler: nil)
            lblStatus.stringValue = NSLocalizedString("Working", comment: "Working...")
            pbTotalProgress.usesThreadedAnimation = true
            pbTotalProgress.startAnimation(self)
            pbTotalProgress.minValue = 0.0
            pbTotalProgress.maxValue = Double(inputList.count)
            pbTotalProgress.doubleValue = 0.0
            btnCancel.isEnabled = true
            cancelCurrentOperation = false

            let albumGain = chkAlbumGain.state == .on
            let avoidClipping = chkAvoidClipping.state == .on
            doModify(noClip: avoidClipping, albumMode: albumGain)
        }
    }

    private func doModify(noClip: Bool, albumMode: Bool) {
        tasks = []
        if !albumMode || inputList.count == 1 {
            for i in 0..<inputList.count {
                let task = Mp3GainTask.task(withFile: inputList.object(at: i), action: .apply)
                task.noClipping = noClip
                task.desiredDb = Double(txtTargetVolume.floatValue)
                task.onProcessingComplete = { [weak task] in
                    if let t = task { self.handleTaskCompletion(t) }
                }
                tasks.append(task)
            }
        } else {
            //Album mode - Don't process twice because it doesn't use analyze data
            let task = Mp3GainTask.task(withFiles: inputList.allObjects(), action: .apply)
            task.noClipping = noClip
            task.desiredDb = Double(txtTargetVolume.floatValue)
            task.onProcessingComplete = { [weak task] in
                if let t = task { self.handleTaskCompletion(t) }
            }
            tasks.append(task)
        }
        for i in 0..<min(tasks.count, getNumConcurrentTasks()) {
            tasks[i].process()
        }
    }

    @IBAction func doGainRemoval(_ sender: Any) {
        if inputList.count > 0 {
            window.beginSheet(pnlProgressView, completionHandler: nil)
            lblStatus.stringValue = NSLocalizedString("Working", comment: "Working...")
            pbTotalProgress.usesThreadedAnimation = true
            pbTotalProgress.startAnimation(self)
            pbTotalProgress.minValue = 0.0
            pbTotalProgress.maxValue = Double(inputList.count)
            pbTotalProgress.doubleValue = 0.0
            btnCancel.isEnabled = true
            cancelCurrentOperation = false
            undoModify()
        }
    }

    private func undoModify() {
        tasks = []
        for i in 0..<inputList.count {
            let task = Mp3GainTask.task(withFile: inputList.object(at: i), action: .undo)
            task.onProcessingComplete = { [weak task] in
                if let t = task { self.handleTaskCompletion(t) }
            }
            tasks.append(task)
        }
        for i in 0..<min(tasks.count, getNumConcurrentTasks()) {
            tasks[i].process()
        }
    }

    @IBAction func btnCancel(_ sender: Any) {
        //Clicking cancel stops after the currently processing files are done.
        //It removes any that haven't started yet.
        cancelCurrentOperation = true
        lblStatus.stringValue = NSLocalizedString("Canceling", comment: "Canceling")
        btnCancel.isEnabled = false

        //Rebuild the pending file list without tasks that haven't started yet.
        tasks = tasks.filter { $0.inProgress }
        let total = Double(inputList.count - tasks.count)
        pbTotalProgress.doubleValue = total
    }

    @IBAction func btnShowAdvanced(_ sender: Any) {
        mnuAdvancedGain.popUp(positioning: nil, at: btnAdvancedMenu.frame.origin, in: vwMainBody)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    @IBAction func checkForUpdates(_ sender: Any) {
        updaterController.checkForUpdates(sender)
    }

    @IBAction func showLanguageSelector(_ sender: Any) {
        M3GLanguageSelectorController.sharedController.showForWindow(window)
    }
}
