//
//  m3gInputList.swift
//  MP3GainExpress
//

import Foundation

class m3gInputList: NSObject {
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
}
