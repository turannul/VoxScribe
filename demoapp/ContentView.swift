//
//  ContentView.swift
//  demoapp
//
//  Created by Turann_ on 30.03.2025.
//


import SwiftUI
import AVFoundation
import Speech
import WhisperKit
import CoreAudio

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var transcribedText = ""
    @State private var displayText = ""
    @State private var showRecordedFiles = false
    @State private var savedRecordings: [RecordingFile] = []
    @State private var audioLevels: [CGFloat] = Array(repeating: 0, count: 30)
    @State private var animationTimer: Timer?
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Control Panel
            VStack {
                Text("Meeting Transcriber")
                    .font(.title)
                    .padding()
                
                if !audioManager.audioPermissionGranted {
                    VStack {
                        Text("Microphone access is required")
                            .foregroundColor(.red)
                            .padding()
                        Button("Request Permission") {
                            audioManager.checkPermissions()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                } else {
                    VStack {
                        Picker("Select Source", selection: $audioManager.selectedMicrophone) {
                            ForEach(audioManager.availableMicrophones, id: \.uniqueID) { device in
                                Text(device.localizedName)
                                    .tag(device as AVCaptureDevice?)
                            }
                        }
                        .padding()
                        
                        Button(audioManager.isRecording ? "Stop Meeting" : "Start Meeting") {
                            toggleRecording()
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundColor(.white)
                        .background(audioManager.isRecording ? Color.red : Color.green)
                        .cornerRadius(8)
                        .padding()
                        
                        Button(showRecordedFiles ? "Show Live Transcription" : "Show Saved Recordings") {
                            showRecordedFiles.toggle()
                            if showRecordedFiles {
                                loadSavedRecordings()
                            }
                        }
                        .buttonStyle(.bordered)
                        .padding()
                    }
                    
                    if audioManager.isRecording {
                        AudioWaveformView(audioLevels: audioLevels)
                            .frame(height: 60)
                            .padding()
                    }
                }
                
                Spacer()
            }
            .frame(width: 300)
            .background(Color(.darkGray))
            
            // Main Content Area
            Group {
                if showRecordedFiles {
                    VStack {
                        Text("Recorded Transcriptions")
                            .font(.title)
                            .padding()
                        
                        List {
                            ForEach(savedRecordings) { recording in
                                VStack(alignment: .leading) {
                                    Text(recording.date)
                                        .font(.headline)
                                    Text(recording.preview)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 4)
                                .onTapGesture {
                                    transcribedText = recording.fullText
                                    displayText = recording.fullText
                                    showRecordedFiles = false
                                }
                            }
                        }
                    }
                    .background(Color.black)
                } else {
                    VStack {
                        Text("Transcription")
                            .font(.title)
                            .padding()
                        
                        ScrollView {
                            Text(
                                displayText.isEmpty
                                    ? "Start speaking to begin transcription..." : displayText
                            )
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animation(.easeInOut, value: displayText)
                        }
                        
                        HStack {
                            Button("Copy") {
                                #if os(macOS)
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(
                                        transcribedText, forType: .string)
                                #else
                                    UIPasteboard.general.string = transcribedText
                                #endif
                            }
                            .disabled(transcribedText.isEmpty)
                            .buttonStyle(.bordered)
                            .padding()
                            
                            Button("Clear") {
                                transcribedText = ""
                                displayText = ""
                            }
                            .disabled(transcribedText.isEmpty)
                            .buttonStyle(.bordered)
                            .padding()
                            
                            Button("Save") {
                                saveTranscription()
                            }
                            .disabled(transcribedText.isEmpty)
                            .buttonStyle(.bordered)
                            .padding()
                        }
                    }
                    .background(Color.white)
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name("TranscriptionUpdated"))
        ) { notification in
            if let text = notification.object as? String {
                transcribedText = text
                if audioManager.isRecording {
                    updateDisplayText()
                } else {
                    displayText = text
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name("AudioLevelUpdated"))
        ) { notification in
            if let level = notification.object as? Float {
                let normalizedLevel = CGFloat(min(max(level, 0), 1))
                audioLevels.removeFirst()
                audioLevels.append(normalizedLevel)
            }
        }
        .onAppear {
            loadSavedRecordings()
        }
    }
    
    private func toggleRecording() {
        if audioManager.isRecording {
            audioManager.stopRecording()
            stopTextAnimation()
            if !transcribedText.isEmpty {
                saveCurrentRecording()
                loadSavedRecordings()
            }
        } else {
            showRecordedFiles = false
            transcribedText = ""
            displayText = ""
            audioManager.startRecording()
            startTextAnimation()
        }
    }
    
    private func startTextAnimation() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            let targetText = transcribedText
            if displayText.count < targetText.count {
                let newCharacter = targetText[targetText.index(targetText.startIndex, offsetBy: displayText.count)]
                withAnimation(.linear(duration: 0.02)) {
                    displayText.append(newCharacter)
                }
            }
        }
    }
    
    private func updateDisplayText() {
        if displayText.count < transcribedText.count {
            let index = transcribedText.index(
                transcribedText.startIndex, offsetBy: displayText.count)
            displayText.append(transcribedText[index])
        }
    }
    
    private func stopTextAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        displayText = transcribedText
    }
    
    private func saveTranscription() {
        #if os(macOS)
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.text]
            savePanel.nameFieldStringValue = "Meeting Transcription.txt"
            
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    do {
                        try self.transcribedText.write(to: url, atomically: true, encoding: .utf8)
                        self.saveCurrentRecording()
                        self.loadSavedRecordings()
                    } catch {
                        print("Failed to save transcription: \(error)")
                    }
                }
            }
        #else
            // iOS/iPadOS implementation would use UIDocumentPickerViewController
        #endif
    }
    
    private func saveCurrentRecording() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateString = formatter.string(from: Date())
        
        let recording = RecordingFile(
            id: UUID(),
            date: dateString,
            preview: String(transcribedText.prefix(100)) + (transcribedText.count > 100 ? "..." : ""),
            fullText: transcribedText
        )
        
        var recordings = getSavedRecordings()
        recordings.append(recording)
        if let encoded = try? JSONEncoder().encode(recordings) {
            UserDefaults.standard.set(encoded, forKey: "savedRecordings")
        }
    }
    
    private func loadSavedRecordings() {
        savedRecordings = getSavedRecordings()
    }
    
    private func getSavedRecordings() -> [RecordingFile] {
        if let savedData = UserDefaults.standard.data(forKey: "savedRecordings"),
           let recordings = try? JSONDecoder().decode([RecordingFile].self, from: savedData) {
            return recordings
        }
        return []
    }
}

struct AudioWaveformView: View {
    var audioLevels: [CGFloat]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<audioLevels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.5))
                    .frame(width: 4, height: 6 + audioLevels[index] * 54)
                    .animation(
                        .interactiveSpring(response: 0.15, dampingFraction: 0.5),
                        value: audioLevels[index])
            }
        }
    }
}

struct RecordingFile: Identifiable, Codable {
    var id: UUID
    var date: String
    var preview: String
    var fullText: String
}

#Preview {
    ContentView()
}
