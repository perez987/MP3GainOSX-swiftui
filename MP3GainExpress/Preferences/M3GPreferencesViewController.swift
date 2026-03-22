//
//  M3GPreferencesViewController.swift
//  MP3GainExpress
//

import AppKit

class M3GPreferencesViewController: NSViewController {
    override func loadView() {
        // View is provided externally from the NIB; prevent automatic NIB loading.
    }

    @objc func viewServiceDidTerminateWithError(_ error: Error) {
        // Implementing this method silences the TUINSRemoteViewController console
        // warning that appears when a window containing a remote view service
        // (e.g. an editable text field or a WKWebView) is closed. This handler is
        // installed on the Preferences window directly and injected into any other
        // application window that lacks a content view controller at the time it
        // becomes key (for example Sparkle's update dialog).
    }
}
