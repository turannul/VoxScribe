//
//  ContentView.swift
//  VoxScribeWatch Watch App
//
//  Created by Turann_ on 3.09.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var connectivityManager = WatchConnectivityManager()

    var body: some View {
        VStack {
            Button(action: {
                connectivityManager.sendMessage(message: ["action": "toggleRecording"])
            }) {
                Image(systemName: connectivityManager.isRecording ? "stop.fill" : "play.fill")
                    .font(.largeTitle)
                    .foregroundColor(connectivityManager.isRecording ? .red : .green)
            }
            Text(connectivityManager.isRecording ? "Recording..." : "Ready")
                .padding()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}