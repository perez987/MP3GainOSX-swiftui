//
//  m3gInputList.swift
//  MP3GainExpress
//

import AppKit

class m3gInputList: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private var list: [m3gInputItem] = []

    var count: Int { list.count }

    func addObject(_ item: m3gInputItem) {
        let hasAlready = list.contains { $0.filePath?.path == item.filePath?.path }
        if !hasAlready {
            list.append(item)
        }
    }

    func object(at idx: Int) -> m3gInputItem {
        return list[idx]
    }

    func allObjects() -> [m3gInputItem] {
        return list
    }

    func clear() {
        list.removeAll()
    }

    func remove(at idx: Int) {
        list.remove(at: idx)
    }

    func addFile(_ filePath: String) {
        let lower = filePath.lowercased()
        guard lower.hasSuffix(".mp3") || lower.hasSuffix(".mp4") || lower.hasSuffix(".m4a") else { return }
        let item = m3gInputItem()
        item.filePath = URL(fileURLWithPath: filePath)
        addObject(item)
    }

    func addDirectory(_ folderPath: String, subFoldersRemaining depth: Int) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: folderPath) else { return }
        var normalizedPath = folderPath
        if !normalizedPath.hasSuffix("/") { normalizedPath += "/" }
        for fileName in files {
            let filePath = normalizedPath + fileName
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: filePath, isDirectory: &isDir) {
                if isDir.boolValue {
                    if depth > 0 { addDirectory(filePath, subFoldersRemaining: depth - 1) }
                } else {
                    addFile(filePath)
                }
            }
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return list.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = list[row]
        guard let identity = tableColumn?.identifier.rawValue else { return nil }

        var cellView = tableView.makeView(
            withIdentifier: NSUserInterfaceItemIdentifier(identity),
            owner: self
        ) as? NSTableCellView

        if cellView == nil {
            cellView = NSTableCellView(frame: .zero)
            cellView!.identifier = NSUserInterfaceItemIdentifier(identity)

            let textField = NSTextField(frame: .zero)
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = false
            textField.isSelectable = false
            textField.lineBreakMode = .byTruncatingTail
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.alignment = identity == "File" ? .left : .right

            cellView!.addSubview(textField)
            cellView!.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 2),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -2),
                textField.topAnchor.constraint(equalTo: cellView!.topAnchor),
                textField.bottomAnchor.constraint(equalTo: cellView!.bottomAnchor)
            ])
        }

        switch identity {
        case "File":
            cellView!.textField!.stringValue = item.getFilename()
        case "Volume":
            if item.volume > 0 {
                cellView!.textField!.stringValue = String(format: "%.2f dB", item.volume)
            } else if item.state == 1 {
                cellView!.textField!.stringValue = NSLocalizedString("NoUndo", comment: "Can't Undo")
            } else if item.state == 2 {
                cellView!.textField!.stringValue = NSLocalizedString("UnsupportedFile", comment: "Unsupported File")
            } else if item.state == 3 {
                cellView!.textField!.stringValue = NSLocalizedString("Not_MP3_file", comment: "Not MP3 file")
            } else {
                cellView!.textField!.stringValue = ""
            }
        case "Clipping":
            cellView!.textField!.stringValue = item.clipping
                ? NSLocalizedString("Yes", comment: "Yes")
                : NSLocalizedString("No", comment: "No")
        case "TrackGain":
            cellView!.textField!.stringValue = item.volume > 0
                ? String(format: "%.2f dB", item.track_gain)
                : ""
        default:
            break
        }

        return cellView
    }

    // MARK: - Drag and Drop

    func tableView(
        _ tableView: NSTableView,
        validateDrop info: NSDraggingInfo,
        proposedRow row: Int,
        proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
        tableView.setDropRow(-1, dropOperation: .on)
        let fileList = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
        if fileList.contains(where: { $0.isFileURL }) {
            return .copy
        }
        return []
    }

    func tableView(
        _ tableView: NSTableView,
        acceptDrop info: NSDraggingInfo,
        row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        let fileList = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
        let fileManager = FileManager.default
        for url in fileList where url.isFileURL {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    addDirectory(url.path, subFoldersRemaining: 5)
                } else {
                    addFile(url.path)
                }
            }
        }
        tableView.reloadData()
        return false
    }
}
