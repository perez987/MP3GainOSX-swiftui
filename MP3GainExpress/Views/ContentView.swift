//
//  ContentView.swift
//  MP3GainExpress
//

import SwiftUI
import AppKit

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            fakeToolbar
            Divider()
            topBar
            fileTable
            Divider()
            bottomBar
        }
        .frame(minWidth: 700, idealWidth: 700, maxWidth: 700,
               minHeight: 500, idealHeight: 500, maxHeight: 700)
        .background(VisualEffectView().ignoresSafeArea())
        .sheet(isPresented: $viewModel.isProcessing) {
            ProcessingSheetView().environmentObject(viewModel)
        }
        .sheet(isPresented: $viewModel.showWarning) {
            WarningSheetView().environmentObject(viewModel)
        }
        .sheet(isPresented: $viewModel.showLanguageSelector) {
            LanguageSelectorView(isPresented: $viewModel.showLanguageSelector)
        }
        .alert(
            NSLocalizedString("InvalidVolume", comment: "Invalid target volume!"),
            isPresented: $viewModel.showInvalidVolumeAlert
        ) {
            Button(NSLocalizedString("OK", comment: "OK")) {}
        } message: {
            Text(NSLocalizedString("VolumeInfo", comment: ""))
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
        ) { _ in
            viewModel.savePreferences()
        }
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack(spacing: 6) {
            Text(NSLocalizedString("Target \"Normal\" Volume:", comment: ""))
                .font(.system(size: 13))
            TextField("89", text: $viewModel.targetVolumeText)
                .frame(width: 50)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
            Text(NSLocalizedString("dB (Default 89.0)", comment: ""))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var fileTable: some View {
        Table(viewModel.items, selection: $viewModel.selectedRows) {
            TableColumn(NSLocalizedString("File", comment: "File")) { item in
                Text(item.getFilename())
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .width(min: 120, ideal: 300)

            TableColumn(NSLocalizedString("Volume", comment: "Volume")) { item in
                Text(volumeText(for: item))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 90)

            TableColumn(NSLocalizedString("Clipping", comment: "Clipping")) { item in
                Text(clippingText(for: item))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 60, ideal: 70)

            TableColumn(NSLocalizedString("Track Gain", comment: "Track Gain")) { item in
                Text(item.volume > 0 ? String(format: "%.2f dB", item.track_gain) : "")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 90)
        }
        .id(viewModel.tableVersion)
        .dropDestination(for: URL.self) { urls, _ in
            viewModel.addDroppedURLs(urls)
            return true
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button(NSLocalizedString("Analyze Only", comment: "Analyze Only")) {
                viewModel.analyze()
            }
            Button(NSLocalizedString("Apply Gain", comment: "Apply Gain")) {
                viewModel.applyGain()
            }
            Menu(NSLocalizedString("Advanced", comment: "Advanced")) {
                Button(NSLocalizedString("Undo Gain", comment: "Undo Gain")) {
                    viewModel.undoGain()
                }
            }
            .fixedSize()

            Spacer()

            Toggle(NSLocalizedString("Prevent clipping", comment: "Prevent clipping"),
                   isOn: $viewModel.avoidClipping)
            Toggle(NSLocalizedString("Album Mode", comment: "Album Mode"),
                   isOn: $viewModel.albumGain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var fakeToolbar: some View {
        HStack(spacing: 0) {
            Spacer()
            fakeToolbarButton(
                image: "AddSong",
                label: NSLocalizedString("Add File(s)", comment: "Add File(s)"),
                isDisabled: false
            ) {
                viewModel.showAddFilesPanel()
            }
            Spacer()
            fakeToolbarButton(
                image: "AddFolder",
                label: NSLocalizedString("Add Folder", comment: "Add Folder"),
                isDisabled: false
            ) {
                viewModel.showAddFolderPanel()
            }
            Spacer()
            fakeToolbarButton(
                image: "ClearSong",
                label: NSLocalizedString("Clear File", comment: "Clear File"),
                isDisabled: viewModel.selectedRows.isEmpty
            ) {
                viewModel.removeSelected()
            }
            Spacer()
            fakeToolbarButton(
                image: "ClearAll",
                label: NSLocalizedString("Clear All", comment: "Clear All"),
                isDisabled: viewModel.items.isEmpty
            ) {
                viewModel.clearAll()
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func fakeToolbarButton(
        image: String,
        label: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.system(size: 11))
            }
        }
        .buttonStyle(.plain)
        .help(label)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1.0)
        .accessibilityLabel(label)
    }

    // MARK: - Helpers

    private func volumeText(for item: m3gInputItem) -> String {
        if item.volume > 0 {
            return String(format: "%.2f dB", item.volume)
        }
        switch item.state {
        case 1: return NSLocalizedString("NoUndo", comment: "Can't Undo")
        case 2: return NSLocalizedString("UnsupportedFile", comment: "Unsupported File")
        case 3: return NSLocalizedString("Not_MP3_file", comment: "Not MP3 file")
        default: return ""
        }
    }

    private func clippingText(for item: m3gInputItem) -> String {
        guard item.volume > 0 else { return "" }
        return item.clipping
            ? NSLocalizedString("Yes", comment: "Yes")
            : NSLocalizedString("No", comment: "No")
    }
}

// MARK: - Processing Sheet

struct ProcessingSheetView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.statusText)
                .font(.system(size: 13))

            HStack(spacing: 12) {
                ProgressView(value: viewModel.progress, total: max(viewModel.progressMax, 1))
                    .progressViewStyle(.linear)
                    .frame(maxWidth: .infinity)

                Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    viewModel.cancel()
                }
                .disabled(!viewModel.cancelEnabled)
            }
        }
        .padding()
        .frame(width: 430, height: 80)
        .interactiveDismissDisabled(true)
        .onAppear {
            viewModel.runPendingOperation()
        }
    }
}

// MARK: - Warning Sheet

struct WarningSheetView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("WarningText", comment: ""))
                .font(.system(size: 11))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Toggle(
                    NSLocalizedString("DontWarnAgain", comment: "Do not show this warning again"),
                    isOn: Binding(
                        get: { m3gPreferences.shared.hideWarning },
                        set: { m3gPreferences.shared.hideWarning = $0 }
                    )
                )
                .toggleStyle(.checkbox)

                Spacer()

                Button(NSLocalizedString("OK", comment: "OK")) {
                    viewModel.showWarning = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 410)
    }
}

// MARK: - Visual Effect Background

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .underWindowBackground
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
