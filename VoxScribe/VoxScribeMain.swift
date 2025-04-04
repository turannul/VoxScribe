//
//  TranscriberMain.swift
//  Transcriber
//
//  Created by Turann_ on 30.03.2025.
//

import SwiftUI
import AVFoundation
import Speech

@main
struct VoxScribeApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    var body: some Scene {
        WindowGroup {
            ContentView()
            #if os(macOS)
                .frame(minWidth: 800, minHeight: 600)
            #else
                .edgesIgnoringSafeArea(.all)
            #endif
        }
    }
}

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("Speech recognition authorization denied")
            }
        }
        
        AVAudioApplication.requestRecordPermission { granted in
            if !granted {
                print("Microphone permission denied")
            }
        }
        
        return true
    }
}
#endif
