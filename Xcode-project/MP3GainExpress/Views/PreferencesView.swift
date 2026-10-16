//
//  PreferencesView.swift
//  MP3GainExpress
//

import SwiftUI
import Darwin

struct PreferencesView: View {
    @State private var numProcesses: Int = m3gPreferences.shared.numProcesses

    private var maxCores: Int {
        var n: UInt32 = 0
        var len = MemoryLayout<UInt32>.size
        sysctlbyname("hw.ncpu", &n, &len, nil, 0)
        return max(1, Int(n))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("Number of files to process concurrently:", comment: ""))
                Spacer()
                TextField("", value: $numProcesses, format: .number)
                    .frame(width: 44)
                    .multilineTextAlignment(.center)
                Stepper("", value: $numProcesses, in: 1...maxCores)
                    .labelsHidden()
            }
            Toggle(NSLocalizedString("Remember Volume settings", comment: ""),
                   isOn: Binding(
                    get: { m3gPreferences.shared.rememberOptions },
                    set: { m3gPreferences.shared.rememberOptions = $0 }
                   ))
        }
        .padding()
        .frame(width: 420)
        .onChange(of: numProcesses) { newValue in
            m3gPreferences.shared.numProcesses = newValue
        }
        .onDisappear {
            // Ensure the current value is persisted even if onChange didn't fire
            m3gPreferences.shared.numProcesses = numProcesses
        }
    }
}
