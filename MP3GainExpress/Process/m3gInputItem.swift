//
//  m3gInputItem.swift
//  MP3GainExpress
//

import Foundation

class m3gInputItem: NSObject {
    var filePath: URL?
    var volume: Double = 0
    var clipping: Bool = false
    var track_gain: Double = 0
    /*
     State values:
     0 - Normal
     1 - Cannot undo
     2 - Unsupported file
     3 - Not MP3 file
     */
    var state: UInt16 = 0

    func getFilename() -> String {
        return filePath?.lastPathComponent ?? ""
    }
}
