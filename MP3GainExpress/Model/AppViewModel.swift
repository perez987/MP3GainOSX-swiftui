//
//  AppViewModel.swift
//  MP3GainExpress
//

import AppKit
import UniformTypeIdentifiers
import Sparkle

class AppViewModel: ObservableObject {
    static let minVolume: Float = 50.0
    static let maxVolume: Float = 100.0

    // UI State
    @Published var items: [m3gInputItem] = []
    @Published var targetVolumeText: String = String(m3gPreferences.defaultDbLevel)
    @Published var albumGain: Bool = false
    @Published var avoidClipping: Bool = false
    @Published var isProcessing: Bool = false
    @Published var progress: Double = 0.0
    @Published var progressMax: Double = 1.0
    @Published var statusText: String = ""
    @Published var cancelEnabled: Bool = true
    @Published var processingLog: [String] = []
    @Published var showWarning: Bool = false
    @Published var showLanguageSelector: Bool = false
    @Published var selectedRows: Set<m3gInputItem.ID> = []
    @Published var showInvalidVolumeAlert: Bool = false
    // Incremented after each batch completes to force SwiftUI Table to re-read item data
    @Published var tableVersion: UUID = UUID()

    let updaterController: SPUStandardUpdaterController

    private var inputList = m3gInputList()
    private var tasks: [Mp3GainTask] = []
    private var cancelCurrentOperation = false
    private var pendingOperation: (() -> Void)?

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        let prefs = m3gPreferences.shared
        if prefs.rememberOptions {
            targetVolumeText = String(prefs.volume)
            avoidClipping = prefs.noClipping
        }
        showWarning = !prefs.hideWarning
    }

    func savePreferences() {
        let prefs = m3gPreferences.shared
        if prefs.rememberOptions {
            if let vol = Float(targetVolumeText),
               vol >= AppViewModel.minVolume && vol <= AppViewModel.maxVolume {
                prefs.volume = vol
            }
            prefs.noClipping = avoidClipping
        }
    }

    private var targetVolume: Double {
        Double(Float(targetVolumeText) ?? m3gPreferences.defaultDbLevel)
    }

    // MARK: - Validation

    private func checkValidOperation() -> Bool {
        let gain = Float(targetVolumeText) ?? 0
        if gain < AppViewModel.minVolume || gain >= AppViewModel.maxVolume {
            DispatchQueue.main.async { self.showInvalidVolumeAlert = true }
            return false
        }
        return true
    }

    // MARK: - File Management

    func addFiles(urls: [URL]) {
        for url in urls where url.isFileURL {
            inputList.addFile(url.path)
        }
        refreshItems()
    }

    func addDroppedURLs(_ urls: [URL]) {
        let fm = FileManager.default
        for url in urls where url.isFileURL {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    inputList.addDirectory(url.path, subFoldersRemaining: 5)
                } else {
                    inputList.addFile(url.path)
                }
            }
        }
        refreshItems()
    }

    func removeSelected() {
        let indices = selectedRows
            .compactMap { id in items.firstIndex { $0.id == id } }
            .sorted()
            .reversed()
        for idx in indices {
            inputList.remove(at: idx)
        }
        selectedRows = []
        refreshItems()
    }

    func clearAll() {
        inputList.clear()
        selectedRows = []
        refreshItems()
    }

    private func refreshItems() {
        items = inputList.allObjects()
    }

    // MARK: - File / Folder Open Panels

    func showAddFilesPanel() {
        let panel = NSOpenPanel()
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [
                UTType(filenameExtension: "mp3")!,
                UTType(filenameExtension: "mp4")!,
                UTType(filenameExtension: "m4a")!
            ]
        } else {
            panel.allowedFileTypes = ["mp3", "mp4", "m4a"]
        }
        panel.allowsOtherFileTypes = true
        panel.allowsMultipleSelection = true
        panel.begin { [weak self] result in
            if result == .OK { self?.addFiles(urls: panel.urls) }
        }
    }

    func showAddFolderPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        let accessory = SubfolderAccessoryView()
        panel.accessoryView = accessory.makeView()
        if panel.responds(to: #selector(getter: NSOpenPanel.isAccessoryViewDisclosed)) {
            panel.isAccessoryViewDisclosed = true
        }

        panel.begin { [weak self] result in
            if result == .OK {
                let depth = accessory.selectedDepth
                for url in panel.urls {
                    self?.inputList.addDirectory(url.path, subFoldersRemaining: depth)
                }
                self?.refreshItems()
            }
        }
    }

    // MARK: - Processing

    func analyze() {
        guard checkValidOperation(), inputList.count > 0 else { return }
        startProcessing { [weak self] in
            guard let self else { return }
            self.doAnalysis(album: self.albumGain)
        }
    }

    func applyGain() {
        guard checkValidOperation(), inputList.count > 0 else { return }
        startProcessing { [weak self] in
            guard let self else { return }
            self.doModify(noClip: self.avoidClipping, albumMode: self.albumGain)
        }
    }

    func undoGain() {
        guard inputList.count > 0 else { return }
        startProcessing { [weak self] in
            guard let self else { return }
            self.undoModify()
        }
    }

    /// Called by ProcessingSheetView.onAppear to begin the queued task after the sheet is visible.
    func runPendingOperation() {
        pendingOperation?()
        pendingOperation = nil
    }

    func cancel() {
        cancelCurrentOperation = true
        statusText = NSLocalizedString("Canceling", comment: "Canceling")
        cancelEnabled = false
        tasks = tasks.filter { $0.inProgress }
        progress = Double(inputList.count - tasks.count)
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    private func startProcessing(operation: @escaping () -> Void) {
        pendingOperation = operation
        isProcessing = true
        statusText = NSLocalizedString("Working", comment: "Working...")
        progress = 0.0
        progressMax = Double(inputList.count)
        cancelEnabled = true
        cancelCurrentOperation = false
        processingLog = []
    }

    private func getNumConcurrentTasks() -> Int {
        return m3gPreferences.shared.numProcesses
    }

    /// Logs the task description and starts processing it.
    private func startTask(_ task: Mp3GainTask) {
        processingLog.append(task.getDescription())
        task.process()
    }

    private func doAnalysis(album: Bool) {
        tasks = []
        if !album || inputList.count == 1 {
            for i in 0..<inputList.count {
                let task = Mp3GainTask.task(withFile: inputList.object(at: i), action: .analyze)
                task.desiredDb = targetVolume
                task.onProcessingComplete = { [weak task] in
                    if let t = task { self.handleTaskCompletion(t) }
                }
                tasks.append(task)
            }
        } else {
            let task = Mp3GainTask.task(withFiles: inputList.allObjects(), action: .analyze)
            task.desiredDb = targetVolume
            task.onProcessingComplete = { [weak task] in
                if let t = task { self.handleTaskCompletion(t) }
            }
            tasks.append(task)
        }
        for i in 0..<min(tasks.count, getNumConcurrentTasks()) {
            startTask(tasks[i])
        }
    }

    private func doModify(noClip: Bool, albumMode: Bool) {
        tasks = []
        if !albumMode || inputList.count == 1 {
            for i in 0..<inputList.count {
                let task = Mp3GainTask.task(withFile: inputList.object(at: i), action: .apply)
                task.noClipping = noClip
                task.desiredDb = targetVolume
                task.onProcessingComplete = { [weak task] in
                    if let t = task { self.handleTaskCompletion(t) }
                }
                tasks.append(task)
            }
        } else {
            let task = Mp3GainTask.task(withFiles: inputList.allObjects(), action: .apply)
            task.noClipping = noClip
            task.desiredDb = targetVolume
            task.onProcessingComplete = { [weak task] in
                if let t = task { self.handleTaskCompletion(t) }
            }
            tasks.append(task)
        }
        for i in 0..<min(tasks.count, getNumConcurrentTasks()) {
            startTask(tasks[i])
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
            startTask(tasks[i])
        }
    }

    private func handleTaskCompletion(_ task: Mp3GainTask) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var replacement = self.tasks.filter { $0 !== task }
            if task.failureCount == 1 {
                replacement.append(task)
            }
            self.tasks = replacement
            let total = Double(self.inputList.count - replacement.count)
            self.progress = total

            let filesLeft = replacement.count
            if filesLeft == 0 {
                self.isProcessing = false
                self.tableVersion = UUID()   // force Table to re-read mutated item data
                self.tasks = []
            } else {
                for nextTask in replacement {
                    if !nextTask.inProgress && (filesLeft == 1 || nextTask.files.count == 1) {
                        self.startTask(nextTask)
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Subfolder Accessory View (AppKit helper)

final class SubfolderAccessoryView {
    private var popup: NSPopUpButton!

    var selectedDepth: Int { popup.indexOfSelectedItem }

    func makeView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 356, height: 35))

        let label = NSTextField(
            labelWithString: NSLocalizedString("Include subfolders:", comment: "Include subfolders:")
        )
        label.frame = NSRect(x: 17, y: 10, width: 135, height: 17)
        view.addSubview(label)

        popup = NSPopUpButton(frame: NSRect(x: 154, y: 4, width: 185, height: 26))
        popup.addItem(withTitle: NSLocalizedString("None", comment: "None"))
        popup.addItem(withTitle: NSLocalizedString("1_below", comment: "1 subfolder below"))
        popup.addItem(withTitle: NSLocalizedString("2_below", comment: "2 subfolders below"))
        popup.addItem(withTitle: NSLocalizedString("3_below", comment: "3 subfolders below"))
        popup.addItem(withTitle: NSLocalizedString("4_below", comment: "4 subfolders below"))
        popup.addItem(withTitle: NSLocalizedString("5_below", comment: "5 subfolders below"))
        view.addSubview(popup)

        return view
    }
}