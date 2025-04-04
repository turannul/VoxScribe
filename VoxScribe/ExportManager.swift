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
            } else {
                completion(false)
            }
        }
        #else
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            let activityVC = UIActivityViewController(
                activityItems: [text],
                applicationActivities: nil
            )
            
            if let popoverController = activityVC.popoverPresentationController {
                popoverController.sourceView = rootViewController.view
                popoverController.sourceRect = CGRect(x: rootViewController.view.bounds.midX,
                                                     y: rootViewController.view.bounds.midY,
                                                     width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            rootViewController.present(activityVC, animated: true) {
                completion(true)
            }
        } else {
            completion(false)
        }
        #endif
    }
}
