//
//  Mp3GainTask.swift
//  MP3GainExpress
//

import Foundation

enum MP3GActionType {
    case analyze
    case apply
    case undo
}

class Mp3GainTask: NSObject {
    private var task: Process?
    private var detailsPipe: Pipe?
    private var statusPipe: Pipe?
    private var statusHandle: FileHandle?

    // The default aacgain reference level; all dB offsets are relative to this baseline
    private static let defaultDbLevel: Double = 89.0

    var files: [m3gInputItem] = []
    var action: MP3GActionType = .analyze
    var desiredDb: Double = Mp3GainTask.defaultDbLevel
    var noClipping: Bool = false
    var inProgress: Bool = false
    var twoPass: Bool = false
    var fatalError: Bool = false
    var failureCount: Int = 0
    var onProcessingComplete: (() -> Void)?
    var onStatusUpdate: ((Double) -> Void)?

    static func task(withFile file: m3gInputItem, action: MP3GActionType) -> Mp3GainTask {
        let t = Mp3GainTask()
        t.files = [file]
        t.action = action
        t.inProgress = false
        t.twoPass = false
        t.failureCount = 0
        t.fatalError = false
        file.state = 0
        return t
    }

    static func task(withFiles files: [m3gInputItem], action: MP3GActionType) -> Mp3GainTask {
        let t = Mp3GainTask()
        t.files = files
        t.action = action
        t.inProgress = false
        t.twoPass = false
        t.failureCount = 0
        t.fatalError = false
        return t
    }

    deinit {
        if let handle = statusHandle {
            NotificationCenter.default.removeObserver(
                self,
                name: .NSFileHandleDataAvailable,
                object: handle
            )
        }
    }

    func process() {
        inProgress = true
        if files.count == 1 {
            for file in files {
                file.clipping = false
            }
        }
        switch action {
        case .analyze:
            analyzeFile()
        case .apply:
            if files.count == 1 && (!noClipping || files[0].volume == 0) {
                //Always need 2 passes if NoClipping is off, because we don't get notified about
                //clipping during the Apply process. Can't trust previous data because they could
                //change the desired volume on us.
                twoPass = true
                analyzeFile()
            } else {
                applyGain()
            }
        case .undo:
            undoGain()
        }
    }

    func getDescription() -> String {
        if files.isEmpty { return "" }
        if files.count > 1 {
            //When in Album mode, we always scan the tracks individually so that multiple tracks
            //can be scanned at the same time. Then we run it again in album mode, which doesn't
            //need to rescan the files because ReplayGain tags were generated during the initial scan.
            return NSLocalizedString("reprocessAlbum", comment: "Process as Album...")
        }
        return files[0].getFilename()
    }

    private func analyzeFile() {
        var arguments = ["-d", String(format: "%f", desiredDb - Mp3GainTask.defaultDbLevel)]
        for file in files {
            if let path = file.filePath?.path { arguments.append(path) }
        }
        doProcessing(arguments: arguments)
    }

    private func applyGain() {
        var arguments: [String]
        if noClipping {
            arguments = ["-r", "-k", "-d", String(format: "%f", desiredDb - Mp3GainTask.defaultDbLevel)]
        } else {
            arguments = ["-r", "-c", "-d", String(format: "%f", desiredDb - Mp3GainTask.defaultDbLevel)]
        }
        if files.count > 1 {
            arguments[0] = "-a"
        }
        for file in files {
            if let path = file.filePath?.path { arguments.append(path) }
        }
        doProcessing(arguments: arguments)
    }

    private func undoGain() {
        guard let path = files.first?.filePath?.path else { return }
        doProcessing(arguments: ["-u", path])
    }

    private func doProcessing(arguments: [String]) {
        let newTask = Process()
        task = newTask
        guard let launchPath = Bundle.main.path(forResource: "aacgain", ofType: nil) else { return }
        newTask.launchPath = launchPath
        newTask.arguments = arguments

        let details = Pipe()
        detailsPipe = details
        newTask.standardInput = Pipe()
        newTask.standardOutput = details

        //Fun fact: Having status on stderr caused file corruption in previous releases when mp3gain was internal
        let status = Pipe()
        statusPipe = status
        newTask.standardError = status

        let handle = status.fileHandleForReading
        statusHandle = handle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleIncomingStatus(_:)),
            name: .NSFileHandleDataAvailable,
            object: handle
        )
        handle.waitForDataInBackgroundAndNotify(forModes: [.default])

        weak var weakSelf = self
        weak var weakDetails = details
        weak var weakStatus = status
        weak var weakHandle = handle
        newTask.terminationHandler = { myself in
            // Remove the notification observer first to prevent dangling pointer issues
            if let s = weakSelf, let h = weakHandle {
                NotificationCenter.default.removeObserver(s, name: .NSFileHandleDataAvailable, object: h)
            }

            let statusData = weakStatus?.fileHandleForReading.readDataToEndOfFile() ?? Data()
            let statusOutput = String(data: statusData, encoding: .utf8) ?? ""
            let detailsData = weakDetails?.fileHandleForReading.readDataToEndOfFile() ?? Data()
            let detailsOutput = String(data: detailsData, encoding: .utf8) ?? ""

            weakSelf?.handleErrorStream(statusOutput)
            if weakSelf?.fatalError == false {
                weakSelf?.parseProcessDetails(detailsOutput)
            }
            if weakSelf?.fatalError == true {
                weakSelf?.failureCount = 2
                weakSelf?.onProcessingComplete?()
            } else if myself.terminationStatus > 0 {
                for file in weakSelf?.files ?? [] {
                    if file.state == 0 { file.state = 2 }
                }
            } else if myself.terminationStatus == 0 && weakSelf?.twoPass == true && weakSelf?.action == .apply {
                weakSelf?.twoPass = false
                weakSelf?.cleanupTaskAndApply()
            } else {
                weakSelf?.onProcessingComplete?()
            }
        }

        do {
            try newTask.run()
        } catch {
            //Failed to launch mp3gain command line tool for some reason.
            //Add this task to the end of the list if this was the first time it failed,
            //otherwise remove it and mark it as failed.
            if failureCount == 1 {
                for file in files { if file.state == 0 { file.state = 2 } }
            }
            failureCount += 1
            if failureCount == 1 { inProgress = false }
            onProcessingComplete?() //Not actually complete, but this will check failureCount and requeue.
        }
    }

    private func cleanupTaskAndApply() {
        // Remove observer as a safety measure (idempotent - safe to call even if already removed)
        if let handle = statusHandle {
            NotificationCenter.default.removeObserver(self, name: .NSFileHandleDataAvailable, object: handle)
            handle.closeFile()
        }
        detailsPipe = nil
        statusPipe = nil
        statusHandle = nil
        task = nil

        DispatchQueue.main.async { [weak self] in
            self?.applyGain()
        }
    }

    private func parseProcessDetails(_ details: String) {
        let lines = details.components(separatedBy: CharacterSet.newlines)
        let numberParse = NumberFormatter()
        numberParse.locale = Locale(identifier: "en_US_POSIX")
        //The strings we search for are copy/pasted from the source of the mp3gain build we're running
        //against, so they should be correct.
        for line in lines {
            if let range = line.range(of: "Recommended \"Track\" dB change: ") {
                if let dbChange = numberParse.number(from: String(line[range.upperBound...])) {
                    for file in files {
                        let gain = dbChange.doubleValue
                        file.volume = desiredDb - gain
                        file.track_gain = gain
                    }
                }
            } else if line.contains("WARNING: some clipping may occur with this gain change!") {
                for file in files { file.clipping = true }
            } else if let range = line.range(of: "Applying auto-clipped mp3 gain change of ") {
                let searchStart = range.upperBound
                if let endRange = line.range(of: " to ", options: .literal, range: searchStart..<line.endIndex) {
                    if let dbChange = numberParse.number(from: String(line[searchStart..<endRange.lowerBound])) {
                        for file in files { file.track_gain = dbChange.doubleValue }
                    }
                }
            } else if let range = line.range(of: "Recommended \"Album\" dB change for all files: ") {
                if let dbChange = numberParse.number(from: String(line[range.upperBound...])) {
                    for file in files {
                        let gain = dbChange.doubleValue
                        file.volume = desiredDb - gain
                        file.track_gain = gain
                    }
                }
            } else if line.contains("Can't find any valid MP3 frames") || line.contains("MPEG Layer I file, not a layer III file") {
                for file in files { file.state = 3 }
            } else if line.contains("is not a valid mp4/m4a file") {
                for file in files { file.state = 2 }
                fatalError = true
            }
        }
    }

    @objc private func handleIncomingStatus(_ notification: Notification) {
        guard let fileHandle = notification.object as? FileHandle else { return }
        let data = fileHandle.availableData
        if data.count > 0 {
            let text = (String(data: data, encoding: .utf8) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            handleErrorStream(text)
            fileHandle.waitForDataInBackgroundAndNotify()
        } else {
            NotificationCenter.default.removeObserver(self, name: .NSFileHandleDataAvailable, object: fileHandle)
        }
    }

    private func handleErrorStream(_ text: String) {
        let albumFilesStr = "/\(files.count)]"
        if text.contains("The file was not modified.") {
            for file in files {
                file.state = 2
                file.volume = 0
            }
            fatalError = true
        } else if text.contains("No changes to undo in") || text.contains("No undo information in") {
            for file in files { file.state = 1 }
        } else if !fatalError && files.count == 1 && text.count > 4 && text.contains("%") {
            if let percentIdx = text.firstIndex(of: "%") {
                let numberStr = String(text[text.startIndex..<percentIdx])
                if let progress = NumberFormatter().number(from: numberStr) {
                    onStatusUpdate?(progress.doubleValue)
                }
            }
        } else if !fatalError && files.count > 1 && text.count > 4 && text.contains(albumFilesStr) {
            if let albumRange = text.range(of: albumFilesStr),
               let bracketIdx = findLeftBracket(in: text, endingBefore: albumRange.lowerBound) {
                let numberStart = text.index(bracketIdx, offsetBy: 1)
                let numberEnd = text.index(albumRange.lowerBound, offsetBy: -1)
                if numberStart <= numberEnd,
                   let progress = NumberFormatter().number(from: String(text[numberStart...numberEnd])) {
                    if progress.intValue == files.count {
                        onStatusUpdate?(100.0)
                    } else {
                        let percent = Double(progress.intValue - 1) * 100.0 / Double(files.count)
                        onStatusUpdate?(percent)
                    }
                }
            }
        }
    }

    private func findLeftBracket(in text: String, endingBefore end: String.Index) -> String.Index? {
        guard end > text.startIndex else { return nil }
        var idx = text.index(before: end)
        while true {
            if text[idx] == "[" { return idx }
            if idx == text.startIndex { break }
            idx = text.index(before: idx)
        }
        return nil
    }
}
