//
//  SettingsView.swift
//  VoxScribe
//
//  Created by Turann_ on 03.09.2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @StateObject private var colorSchemeManager = ColorSchemeManager()

    var body: some View {
        VStack {
            Picker("Appearance", selection: $colorSchemeManager.colorSchemeOption) {
                ForEach(ColorSchemeOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: colorSchemeManager.colorSchemeOption) { _ in
                colorSchemeManager.applyColorScheme()
            }
            .padding()

            Picker("Select Source", selection: $viewModel.audioManager.selectedMicrophone) {
                ForEach(viewModel.audioManager.availableMicrophones, id: \.uniqueID) { device in
                    Text(device.localizedName).tag(device as AVCaptureDevice?)
                }
            }.padding()

            Picker("Language", selection: $viewModel.languageManager.selectedLanguage) {
                ForEach(viewModel.languageManager.availableLanguages, id: \.id) { language in
                    Text(language.name).tag(language)
                }
            }
            .onChange(of: viewModel.languageManager.selectedLanguage) { newValue in
                viewModel.audioManager.setTranscriberLanguage(languageCode: newValue.code)
            }
            .disabled(viewModel.audioManager.isRecording)
            .padding()

            Spacer()
        }
        .frame(width: 400, height: 300)
        .padding()
    }
}

#Preview { SettingsView() }
