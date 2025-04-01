//
//  ExportManager.swift
//  Transcriber
//
//  Created by Turann_ on 1.04.2025.
//


import SwiftUI

struct ExportManager {
    static func export(text: String, fileName: String, completion: @escaping (Bool) -> Void) {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.text]
        savePanel.nameFieldStringValue = fileName
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try text.write(to: url, atomically: true, encoding: .utf8)
                    completion(true)
                } catch {
                    print("Export failed: \(error)")
                    completion(false)
                }
            }
        }
        #else
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(activityVC, animated: true)
        completion(true)
        #endif
    }
}