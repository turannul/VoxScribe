//
//  ContentView.swift
//  Transcriber
//
//  Created by Turann_ on 30.03.2025.
//


import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var transcribedText = ""
    @State private var displayText = ""
    @State private var savedRecordings: [RecordingFile] = []
    @State private var audioLevels: [CGFloat] = Array(repeating: 0, count: 30)
    @State private var animationTimer: Timer?
    
    var body: some View {
        HStack(spacing: 0) {
            VStack {
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
                        
                        Button(audioManager.isRecording ? "Stop Recording" : "Start Recording") {
                            toggleRecording()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(audioManager.isRecording ? .red : .green)
                        .foregroundColor(.white)
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
                if audioManager.isRecording {
                    liveTranscriptionView
                } else {
                    recordingsListView
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TranscriptionUpdated"))) { notification in
            if let text = notification.object as? String {
                transcribedText = text
                updateDisplayText()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AudioLevelUpdated"))) { notification in
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
    
    private var liveTranscriptionView: some View {
        VStack {
            Text("Live Transcription")
                .font(.title)
                .padding()
            
            ScrollView {
                Text(displayText.isEmpty ? "Start speaking..." : displayText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .typingCursor()
                    .animation(.easeInOut, value: displayText)
            }
            
            HStack {
                Button("Copy") {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(transcribedText, forType: .string)
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

            }
        }
        .background(Color.black)
    }
    
    private var recordingsListView: some View {
        VStack {
            Text("Saved Recordings")
                .font(.title)
                .padding()
            
            List {
                if savedRecordings.isEmpty {
                    Text("Nothing recorded yet.")
                        .padding()
                }
                ForEach(savedRecordings) { recording in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(recording.date)
                                .font(.headline)
                            Text(recording.preview)
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                        
                        Spacer()
                        
                        Button {
                            deleteRecording(recording)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(isHovering(recording.id) ? 1 : 0)
                        .onHover { hovering in
                            hoveredRecording = hovering ? recording.id : nil
                        }
                    }
                    .padding(.horizontal)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .background(Color.black)
    }

    @State private var hoveredRecording: UUID? = nil

    private func isHovering(_ id: UUID) -> Bool {
        hoveredRecording == id
    }

    private func deleteRecording(_ recording: RecordingFile) {
        savedRecordings.removeAll { $0.id == recording.id }
        saveRecordingsToStorage()
    }

    private func saveRecordingsToStorage() {
        if let encoded = try? JSONEncoder().encode(savedRecordings) {
            UserDefaults.standard.set(encoded, forKey: "savedRecordings")
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
            preview: String(transcribedText.prefix(100)) + (transcribedText.count > 256 ? "..." : ""),
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
                    .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.5), value: audioLevels[index])
            }
        }
    }
}

struct TypingCursorModifier: ViewModifier {
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            content
            Rectangle()
                .frame(width: 2, height: 20)
                .foregroundColor(.blue)
                .opacity(isVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isVisible)
        }
        .onAppear { isVisible = true }
    }
}

extension View {
    func typingCursor() -> some View {
        self.modifier(TypingCursorModifier())
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
