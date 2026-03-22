//
//  M3GWindow.swift
//  MP3GainExpress
//

import AppKit

class M3GWindow: NSWindow, NSWindowDelegate {
    private var originalView: NSView?

    override func awakeFromNib() {
        super.awakeFromNib()
            originalView = contentView
            let contentFrame = contentView!.frame
            let windowFrame = frame
            titlebarAppearsTransparent = true

            let vev = NSVisualEffectView()
            vev.frame = contentFrame
            vev.blendingMode = .behindWindow
            vev.state = .active
            vev.material = .underWindowBackground
            contentView = vev

            if let origView = originalView {
                vev.addSubview(origView)
                origView.frame = contentLayoutRect
            setFrame(windowFrame, display: true)
            delegate = self
            addObserver(self, forKeyPath: "contentLayoutRect", options: .new, context: nil)
        }
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "contentLayoutRect" {
            originalView?.frame = contentLayoutRect
        }
    }

    func window(_ window: NSWindow, willPositionSheet sheet: NSWindow, using rect: NSRect) -> NSRect {
        var region = contentLayoutRect
        region.origin.y += region.size.height
        region.size.height = 0
        return region
    }
}
