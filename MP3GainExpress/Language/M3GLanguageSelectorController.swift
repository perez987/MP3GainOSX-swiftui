//
//  M3GLanguageSelectorController.swift
//  MP3Gain Express
//

import AppKit

// Layout constants — window height is derived from these so changes stay consistent
private let kRowHeight: CGFloat = 36.0      // height of each language row
private let kTableWidth: CGFloat = 222.0    // scroll view / table width
private let kScrollViewX: CGFloat = 39.0    // scroll view left inset
private let kScrollViewY: CGFloat = 68.0    // scroll view bottom edge (above buttons)
private let kTopPadding: CGFloat = 42.0     // space above scroll view (below title bar)
private let kWindowWidth: CGFloat = 300.0

class M3GLanguageSelectorController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {
    private var tableView: NSTableView!
    private static let supportedLanguages: [[String: String]] = [
        ["code": "de", "name": "Deutsch",    "flag": "🇩🇪"],
        ["code": "en", "name": "English",    "flag": "🇬🇧"],
        ["code": "es", "name": "Español",    "flag": "🇪🇸"],
        ["code": "fr", "name": "Français",   "flag": "🇫🇷"],
        ["code": "it", "name": "Italiano",   "flag": "🇮🇹"],
        ["code": "cs", "name": "Česko",      "flag": "🇨🇿"],
        ["code": "el", "name": "ελληνική",   "flag": "🇬🇷"]
    ]
    private var languages: [[String: String]] { M3GLanguageSelectorController.supportedLanguages }
    private var initialLanguageCode: String = "en"

    static let sharedController: M3GLanguageSelectorController = {
        return M3GLanguageSelectorController()
    }()

    init() {
        // Panel height = rows below title bar: top padding + table + scroll-view Y offset
        // Derived from supportedLanguages.count so it stays in sync automatically
        let windowHeight = kTopPadding + CGFloat(M3GLanguageSelectorController.supportedLanguages.count) * kRowHeight + kScrollViewY
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: kWindowWidth, height: windowHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init(window: panel)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        // Scroll view height = one row per language so all entries are visible without scrolling
        let tableHeight = CGFloat(languages.count) * kRowHeight + 6
        let scrollView = NSScrollView(frame: NSRect(x: kScrollViewX, y: kScrollViewY, width: kTableWidth, height: tableHeight))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true

        tableView = NSTableView(frame: NSRect(x: 0, y: 0, width: kTableWidth, height: tableHeight))
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("language"))
        column.width = 204
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = kRowHeight
        tableView.gridStyleMask = []
        tableView.allowsEmptySelection = false

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        // Cancel button
        let cancelButton = NSButton(
            title: NSLocalizedString("Cancel", comment: "Cancel"),
            target: self,
            action: #selector(cancelAction(_:))
        )
        cancelButton.frame = NSRect(x: 90, y: 20, width: 90, height: 28)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1B}"
        contentView.addSubview(cancelButton)

        // Accept button
        let acceptButton = NSButton(
            title: NSLocalizedString("Accept", comment: "Accept"),
            target: self,
            action: #selector(acceptAction(_:))
        )
        acceptButton.frame = NSRect(x: 192, y: 20, width: 90, height: 28)
        acceptButton.bezelStyle = .rounded
        acceptButton.keyEquivalent = "\r"
        contentView.addSubview(acceptButton)
    }

    func showForWindow(_ parentWindow: NSWindow) {
        // Determine current language
        var currentLang = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first ?? ""
        currentLang = currentLang.components(separatedBy: "-").first ?? currentLang
        if currentLang.isEmpty {
            if #available(macOS 13, *) {
                currentLang = Locale.current.language.languageCode?.identifier ?? "en"
            } else {
                currentLang = Locale.current.languageCode ?? "en"
            }
        }
        initialLanguageCode = currentLang

        window?.title = NSLocalizedString("Language selector title", comment: "Select Language")
        tableView.reloadData()
        selectLanguageCode(currentLang)

        window?.center()
        parentWindow.beginSheet(window!, completionHandler: nil)
    }

    private func selectLanguageCode(_ code: String) {
        if let idx = languages.firstIndex(where: { $0["code"] == code }) {
            tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            tableView.scrollRowToVisible(idx)
        }
    }

    private var selectedLanguageCode: String {
        let row = tableView.selectedRow
        if row >= 0 && row < languages.count {
            return languages[row]["code"] ?? "en"
        }
        return "en"
    }

    @objc private func cancelAction(_ sender: Any) {
        window?.sheetParent?.endSheet(window!)
        window?.orderOut(self)
    }

    @objc private func acceptAction(_ sender: Any) {
        let selected = selectedLanguageCode
        let changed = selected != initialLanguageCode

        window?.sheetParent?.endSheet(window!)
        window?.orderOut(self)

        if changed {
            UserDefaults.standard.set([selected], forKey: "AppleLanguages")

            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Language changed alert title", comment: "Language Changed")
            alert.informativeText = NSLocalizedString("Language changed message", comment: "Please restart the application to apply the new language.")
            alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK"))
            alert.runModal()
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return languages.count
    }

    private func makeCellView() -> NSTableCellView {
        let cellView = NSTableCellView()
        cellView.identifier = NSUserInterfaceItemIdentifier("LanguageCell")

        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = NSFont.systemFont(ofSize: 14)
        cellView.addSubview(textField)
        cellView.textField = textField

        NSLayoutConstraint.activate([
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8)
        ])
        return cellView
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var cellView = tableView.makeView(
            withIdentifier: NSUserInterfaceItemIdentifier("LanguageCell"),
            owner: self
        ) as? NSTableCellView
        if cellView == nil {
            cellView = makeCellView()
        }
        let lang = languages[row]
        cellView?.textField?.stringValue = "\(lang["flag"] ?? "")  \(lang["name"] ?? "")"
        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return kRowHeight
    }
}
