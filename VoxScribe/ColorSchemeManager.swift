//
//  ColorSchemeManager.swift
//  VoxScribe
//
//  Created by Turann_ on 03.09.2025.
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

enum ColorSchemeOption: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

class ColorSchemeManager: ObservableObject {
    @AppStorage("colorScheme") var colorSchemeOption: ColorSchemeOption = .system

    func applyColorScheme() {
        #if os(iOS)
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        window?.overrideUserInterfaceStyle = UIUserInterfaceStyle(rawValue: colorSchemeOption.colorScheme == .dark ? 2 : 1) ?? .unspecified
        #elseif os(macOS)
        let window = NSApplication.shared.windows.first
        window?.appearance = colorSchemeOption.colorScheme == .dark ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
        #endif
    }
}
