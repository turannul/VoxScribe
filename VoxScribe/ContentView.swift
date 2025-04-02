//
//  ContentView.swift
//  Transcriber
//
//  Updated with features from VoxScribe
//

import SwiftUI
import AVFoundation
import Foundation

// MARK: - Language Model
struct SupportedLanguage: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let code: String
    
    static let systemLanguage = SupportedLanguage(
        name: "System Language",
        code: Locale.current.identifier
    )
}

// MARK: - Updated Data Model
struct RecordingFile: Identifiable, Codable {
    var id: UUID
    var date: String
    var preview: String
    var fullText: String
    var isStarred: Bool = false
    var languageCode: String? // Added language code to store with recording
}

// MARK: - Recording Card View
struct RecordingCard: View {
    @Binding var recording: RecordingFile
    let onDelete: () -> Void
    let onToggleStar: () -> Void
    let onExport: () -> Void
    
    @State private var isExpanded = false
    @State private var isHovered = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(recording.date)
                        .font(.headline)
                    Text(isExpanded ? recording.fullText : recording.preview)
                        .font(.subheadline)
                        .lineLimit(isExpanded ? nil : 2)
                }
                
                Spacer()
                
                // All buttons only show on hover
                if isHovered {
                    HStack(spacing: 12) {
                        Button(action: onToggleStar) {
                            Image(systemName: recording.isStarred ? "star.fill" : "star")
                                .foregroundColor(recording.isStarred ? .yellow : .gray)
                        }
                        
                        Button(action: onExport) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .transition(.opacity)
                }
            }
            
            if recording.fullText.count > 100 {
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(isExpanded ? "Show Less" : "Show More")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(recording.isStarred ? Color.yellow.opacity(0.1) : Color(.darkGray))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var languageManager = LanguageManager()

    @State private var transcribedText = ""
    @State private var displayText = ""
    @State private var savedRecordings: [RecordingFile] = []
    @State private var audioLevels: [CGFloat] = Array(repeating: 0, count: 30)
    @State private var animationTimer: Timer?
    
    var body: some View {
        HStack(spacing: 0) {
            // Control Panel
            VStack {
                if !audioManager.audioPermissionGranted {
                    permissionView
                } else {
                    recordingControls
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
            
            // Main Content
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
                updateTranscription(text: text)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AudioLevelUpdated"))) { notification in
            updateAudioLevel(notification: notification)
        }
        .onAppear {
            loadSavedRecordings()
        }
    }
    
    // MARK: - View Components
    private var permissionView: some View {
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
    }
    
    private var recordingControls: some View {
        VStack {
            Picker("Select Source", selection: $audioManager.selectedMicrophone) {
                ForEach(audioManager.availableMicrophones, id: \.uniqueID) { device in
                    Text(device.localizedName).tag(device as AVCaptureDevice?)
                }
            }
            .padding()
            
            // Language selection
             Picker("Language", selection: $languageManager.selectedLanguage) {
                 ForEach(languageManager.availableLanguages, id: \.id) { language in
                     Text(language.name).tag(language)
                 }
             }
             .onChange(of: languageManager.selectedLanguage) { newValue in
                 audioManager.setTranscriberLanguage(languageCode: newValue.code)
             }.disabled(audioManager.isRecording)
            .padding()
            
            Button(audioManager.isRecording ? "Stop Recording" : "Start Recording") {
                toggleRecording()
            }
            .buttonStyle(.borderedProminent)
            .tint(audioManager.isRecording ? .red : .green)
            .foregroundColor(.white)
            .padding()
        }
    }
    
    private var liveTranscriptionView: some View {
        VStack {
            Text("Live Transcription")
                .font(.title)
                .padding()
            
            Text("Language: \(languageManager.selectedLanguage.name)")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.bottom)
            
            ScrollView {
                Text(displayText.isEmpty ? "Start speaking..." : displayText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .typingCursor()
                    .animation(.easeInOut, value: displayText)
            }
            
            HStack {
                Button("Copy") {
                    copyToClipboard()
                }
                .disabled(transcribedText.isEmpty)
                
                Button("Clear") {
                    resetTranscription()
                }
                .disabled(transcribedText.isEmpty)
            }
            .buttonStyle(.bordered)
            .padding()
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
                ForEach($savedRecordings) { $recording in
                    RecordingCard(
                        recording: $recording,
                        onDelete: { deleteRecording(recording) },
                        onToggleStar: { toggleStar(for: recording) },
                        onExport: { exportRecording(recording) }
                    )
                }
            }
        }
        .background(Color.black)
    }
    
    // MARK: - Transcription Logic
    private func updateTranscription(text: String) {
        transcribedText = text
        updateDisplayText()
    }
    
    private func updateDisplayText() {
        if displayText.count < transcribedText.count {
            let index = transcribedText.index(
                transcribedText.startIndex, offsetBy: displayText.count)
            displayText.append(transcribedText[index])
        }
    }
    
    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcribedText, forType: .string)
        #else
        UIPasteboard.general.string = transcribedText
        #endif
    }
    
    private func resetTranscription() {
        transcribedText = ""
        displayText = ""
    }
    
    // MARK: - Recording Management
    private func toggleRecording() {
        if audioManager.isRecording {
            audioManager.stopRecording()
            stopTextAnimation()
            if !transcribedText.isEmpty {
                saveCurrentRecording()
            }
        } else {
            resetTranscription()
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
    
    private func stopTextAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        displayText = transcribedText
    }
    
    // MARK: - Star & Export Functionality
    private func toggleStar(for recording: RecordingFile) {
        guard let index = savedRecordings.firstIndex(where: { $0.id == recording.id }) else { return }
        savedRecordings[index].isStarred.toggle()
        saveRecordingsToStorage()
    }
    
    private func exportRecording(_ recording: RecordingFile) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.text]
        savePanel.nameFieldStringValue = "Transcription_\(recording.date).txt"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try recording.fullText.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Export failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Persistence
    private func saveCurrentRecording() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateString = formatter.string(from: Date())
        
        let newRecording = RecordingFile(
            id: UUID(),
            date: dateString,
            preview: String(transcribedText.prefix(100)) + (transcribedText.count > 100 ? "..." : ""),
            fullText: transcribedText,
            languageCode: languageManager.selectedLanguage.code
        )
        
        savedRecordings.insert(newRecording, at: 0)
        saveRecordingsToStorage()
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
    
    private func loadSavedRecordings() {
        if let savedData = UserDefaults.standard.data(forKey: "savedRecordings"),
            let decoded = try? JSONDecoder().decode([RecordingFile].self, from: savedData) {
            savedRecordings = decoded
        }
    }
    
    // MARK: - Audio Visualization
    private func updateAudioLevel(notification: Notification) {
        if let level = notification.object as? Float {
            let normalizedLevel = CGFloat(min(max(level, 0), 1))
            audioLevels.removeFirst()
            audioLevels.append(normalizedLevel)
        }
    }
}

// MARK: - UI Components
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

// MARK: - Cursor Animation
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

#Preview {
    ContentView()
}
