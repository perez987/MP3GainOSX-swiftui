//
//  m3gPreferences.swift
//  MP3GainExpress
//

import Foundation
import Darwin

class m3gPreferences: NSObject {
    // Default target volume level used by aacgain
    static let defaultDbLevel: Float = 89.0
    static let shared = m3gPreferences()

    @objc dynamic var maxCores: UInt32 {
        var numCores: UInt32 = 0
        var len = MemoryLayout<UInt32>.size
        sysctlbyname("hw.ncpu", &numCores, &len, nil, 0)
        return numCores
    }

    @objc dynamic var numProcesses: Int {
        get {
            let max = Int(maxCores)
            var retval = max >= 4 ? 4 : 2
            let ud = UserDefaults.standard
            if ud.object(forKey: "m3g_NumProcesses") != nil {
                let userProcesses = ud.integer(forKey: "m3g_NumProcesses")
                if userProcesses <= max {
                    retval = userProcesses
                }
            }
            return retval
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "m3g_NumProcesses")
        }
    }

    @objc dynamic var rememberOptions: Bool {
        get {
            let ud = UserDefaults.standard
            return ud.object(forKey: "m3g_RememberOptions") != nil
                ? ud.bool(forKey: "m3g_RememberOptions")
                : true
        }
        set { UserDefaults.standard.set(newValue, forKey: "m3g_RememberOptions") }
    }

    var volume: Float {
        get {
            let ud = UserDefaults.standard
            return ud.object(forKey: "m3g_Volume") != nil
                ? ud.float(forKey: "m3g_Volume")
                : 89.0
        }
        set { UserDefaults.standard.set(newValue, forKey: "m3g_Volume") }
    }

    var noClipping: Bool {
        get {
            let ud = UserDefaults.standard
            return ud.object(forKey: "m3g_NoClipping") != nil
                ? ud.bool(forKey: "m3g_NoClipping")
                : false
        }
        set { UserDefaults.standard.set(newValue, forKey: "m3g_NoClipping") }
    }

    @objc dynamic var hideWarning: Bool {
        get {
            let ud = UserDefaults.standard
            return ud.object(forKey: "m3g_HideWarning") != nil
                ? ud.bool(forKey: "m3g_HideWarning")
                : false
        }
        set { UserDefaults.standard.set(newValue, forKey: "m3g_HideWarning") }
    }
}
