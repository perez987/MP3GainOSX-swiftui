//
//  LanguageSelectorView.swift
//  MP3GainExpress
//

import SwiftUI
import AppKit

private struct Language: Identifiable {
    let code: String
    let name: String
    let flag: String
    var id: String { code }
}

private let supportedLanguages: [Language] = [
    Language(code: "de", name: "Deutsch",   flag: "🇩🇪"),
    Language(code: "en", name: "English",   flag: "🇬🇧"),
    Language(code: "es", name: "Español",   flag: "🇪🇸"),
    Language(code: "fr", name: "Français",  flag: "🇫🇷"),
    Language(code: "it", name: "Italiano",  flag: "🇮🇹"),
    Language(code: "cs", name: "Česko",     flag: "🇨🇿"),
    Language(code: "el", name: "ελληνική",  flag: "🇬🇷")
]

struct LanguageSelectorView: View {
    @Binding var isPresented: Bool
    @State private var selectedCode: String? = "en"
    @State private var initialCode: String = "en"
    @State private var showRestartAlert: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            List(supportedLanguages, selection: $selectedCode) { lang in
                Text("\(lang.flag)  \(lang.name)")
                    .font(.system(size: 14))
                    .frame(height: 30)
            }
//            .listStyle(.bordered)
            .overlay(
                 RoundedRectangle(cornerRadius: 6)
                     .stroke(.tertiary, lineWidth: 1)
                     .padding(5)
             )
            .frame(width: 222, height: CGFloat(supportedLanguages.count) * 36 + 36)

            HStack {
                Spacer()
                Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button(NSLocalizedString("Accept", comment: "Accept")) {
                    let selected = selectedCode ?? initialCode
                    let changed = selected != initialCode
                    if changed {
                        UserDefaults.standard.set([selected], forKey: "AppleLanguages")
                        showRestartAlert = true
                    } else {
                        isPresented = false
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300, height: 400)
        .onAppear { loadCurrentLanguage() }
        .alert(
            NSLocalizedString("Language changed alert title", comment: "Language Changed"),
            isPresented: $showRestartAlert
        ) {
            Button(NSLocalizedString("OK", comment: "OK")) {
                isPresented = false
            }
        } message: {
            Text(NSLocalizedString("Language changed message", comment: ""))
        }
    }

    private func loadCurrentLanguage() {
        var code = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first ?? ""
        code = code.components(separatedBy: "-").first ?? code
        if code.isEmpty {
            if #available(macOS 13, *) {
                code = Locale.current.language.languageCode?.identifier ?? "en"
            } else {
                code = Locale.current.languageCode ?? "en"
            }
        }
        // Default to "en" if the stored code isn't in our list
        if !supportedLanguages.contains(where: { $0.code == code }) { code = "en" }
        initialCode = code
        selectedCode = code
    }
}
