//
//  ContentView.swift
//  VoxScribe
//
//  Created by Turann_ on 30.03.2025.
//

import SwiftUI
import AVFoundation
import Foundation



// MARK: - Updated Data Model
struct RecordingFile: Identifiable, Codable {
    var id: UUID
    var date: String
    var preview: String
    var fullText: String
    var isStarred: Bool = false
    var languageCode: String?
}

// MARK: - Recording Card View
struct RecordingCard: View {
    @Binding var recording: RecordingFile
    let onDelete: () -> Void
    let onToggleStar: () -> Void
    let onExport: () -> Void
    
    @State private var isExpanded: Bool = false
    @State private var isHovered: Bool = false
    
    private var dateFormatter: DateFormatter {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(recording.date).font(.headline)
                    Text(isExpanded ? recording.fullText : recording.preview).font(.subheadline).lineLimit(isExpanded ? nil : 2)
                }
                
                Spacer()
                
                if isHovered {
                    HStack(spacing: 12) {
                        Button(action: onToggleStar) {Image(systemName: recording.isStarred ? "star.fill" : "star").foregroundColor(recording.isStarred ? .yellow : .gray)}
                        Button(action: onExport) {Image(systemName: "square.and.arrow.up").foregroundColor(.blue)}
                        Button(action: onDelete) {Image(systemName: "trash").foregroundColor(.red)}
                        if recording.fullText.count > 100 {Button(action: {withAnimation {isExpanded.toggle()}}) {Image(systemName: isExpanded ? "chevron.up" : "chevron.down").foregroundColor(.white)}}
                    }.transition(.opacity)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(recording.isStarred ? Color.yellow.opacity(0.1) : Color(.darkGray)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1)))
        .onHover { hovering in withAnimation(.easeInOut(duration: 0.1)) {isHovered = hovering}}
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
        #if os(macOS)
        HStack(spacing: 0) {
            // Control Panel
            VStack {
                if !audioManager.audioPermissionGranted {
                    permissionView
                } else {
                    recordingControls
                    if audioManager.isRecording {
                        AudioWaveformView(audioLevels: audioLevels).frame(height: 60).padding()
                    }
                }
                Spacer()
            }.frame(width: 300).background(Color(.darkGray))
            
            // Main Content
            Group {
                if audioManager.isRecording {
                    liveTranscriptionView
                } else {
                    recordingsListView
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TranscriptionUpdated"))) { notification in if let text = notification.object as? String {updateTranscription(text: text)}}
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AudioLevelUpdated"))) { notification in updateAudioLevel(notification: notification)}
        .onAppear {loadSavedRecordings()}
        #else
        iPadLayout
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
        #endif
    }
    
    // MARK: - View Components
    private var permissionView: some View {
        VStack {
            Text("Microphone access is required").foregroundColor(.red).padding()
            Button("Request Permission") {audioManager.checkPermissions()}.buttonStyle(.borderedProminent).padding()
        }
    }
    
    private var recordingControls: some View {
        VStack {
            // Microphone selection
            Picker("Select Source", selection: $audioManager.selectedMicrophone) {ForEach(audioManager.availableMicrophones, id: \.uniqueID) { device in Text(device.localizedName).tag(device as AVCaptureDevice?)}}.padding()
            // Language selection
            Picker("Language", selection: $languageManager.selectedLanguage) {ForEach(languageManager.availableLanguages, id: \.id) { language in Text(language.name).tag(language)}}.onChange(of: languageManager.selectedLanguage) {newValue in audioManager.setTranscriberLanguage(languageCode: newValue.code)}.disabled(audioManager.isRecording).padding()
            Button(audioManager.isRecording ? "Stop Recording" : "Start Recording") {toggleRecording()}.buttonStyle(.borderedProminent).tint(audioManager.isRecording ? .red : .green).foregroundColor(.white).padding()
        }
    }
    
    private var liveTranscriptionView: some View {
            VStack {
                Text("Live Transcription").font(.title).padding()
                Text("Language: \(languageManager.selectedLanguage.name)").font(.subheadline).foregroundColor(.gray).padding(.bottom)
                
                ScrollView {
                    VStack(alignment: .leading) {
                        HStack(spacing: 0) {
                            Text(displayText.isEmpty ? "Start speaking..." : displayText).animation(.easeInOut, value: displayText)
                            // Cursor animation
                            if audioManager.isRecording {
                                Rectangle().frame(width: 2, height: 20).foregroundColor(.white).opacity(1).animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: true)
                            }}.frame(maxWidth: .infinity, alignment: .leading)
                    }.padding()
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                
                HStack {
                    Button("Copy") {copyToClipboard()}.disabled(transcribedText.isEmpty)
                    Button("Clear") {resetTranscription()}.disabled(transcribedText.isEmpty)
                }.buttonStyle(.bordered).padding()
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black)
        }
    
    private var recordingsListView: some View {
        VStack {
            Text("Saved Recordings").font(.title).padding()
            
            List {
                if savedRecordings.isEmpty {
                    Text("Nothing recorded yet.").frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center).listRowInsets(EdgeInsets()).listRowBackground(Color.clear).padding()
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
        }.background(Color.black)
    }
    
    // MARK: - Transcription Logic
    private func updateTranscription(text: String) {
        transcribedText = text
        updateDisplayText()
    }
    
    private func updateDisplayText() {
        if displayText.count < transcribedText.count {
            let index = transcribedText.index(transcribedText.startIndex, offsetBy: displayText.count)
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
            if !transcribedText.isEmpty {saveCurrentRecording()}
        } else {
            resetTranscription()
            audioManager.startRecording()
            startTextAnimation()
        }
    }
    
    private func startTextAnimation() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            let targetText: String = transcribedText
            if displayText.count < targetText.count {
                let newCharacter: Character = targetText[targetText.index(targetText.startIndex, offsetBy: displayText.count)]
                withAnimation(.linear(duration: 0.02)) {displayText.append(newCharacter)}
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
        guard let index: Array<RecordingFile>.Index = savedRecordings.firstIndex(where: { $0.id == recording.id }) else { return }
        savedRecordings[index].isStarred.toggle()
        saveRecordingsToStorage()
    }
    
    func exportRecording(_ recording: RecordingFile) {
        #if os(macOS)
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
        #else
        exportRecordingIOS(recording)
        #endif
    }
    
    // MARK: - Persistence
    private func saveCurrentRecording() {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateString: String = formatter.string(from: Date())
        
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
        if let encoded: Data = try? JSONEncoder().encode(savedRecordings) {UserDefaults.standard.set(encoded, forKey: "savedRecordings")}
    }
    
    private func loadSavedRecordings() {
        if let savedData: Data = UserDefaults.standard.data(forKey: "savedRecordings"),
            let decoded: [RecordingFile] = try? JSONDecoder().decode([RecordingFile].self, from: savedData) {
            savedRecordings = decoded
        }
    }
    
    // MARK: - Audio Visualization
    private func updateAudioLevel(notification: Notification) {
        if let level: Float = notification.object as? Float {
            let normalizedLevel: CGFloat = CGFloat(min(max(level, 0), 1))
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
            ForEach(0..<audioLevels.count, id: \.self) { index in RoundedRectangle(cornerRadius: 2).fill(Color.accentColor.opacity(0.65)).frame(width: 4, height: 6 + audioLevels[index] * 54).animation(.interactiveSpring(response: 0.15, dampingFraction: 0.5), value: audioLevels[index])}
        }
    }
}

// MARK: - Cursor Animation
struct TypingCursorModifier: ViewModifier {
    @State private var isVisible: Bool = false
    
    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            content
            Rectangle().frame(width: 1, height: 20).foregroundColor(.white).opacity(isVisible ? 1 : 0).animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isVisible)
        }.onAppear { isVisible = true }
    }
}

// MARK: - Recording Detail View for iPad
struct RecordingDetailView: View {
    @Binding var recording: RecordingFile
    let onExport: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(recording.date)
                        .font(.title)
                    
                    Spacer()
                    
                    Button(action: {
                        recording.isStarred.toggle()
                    }) {
                        Image(systemName: recording.isStarred ? "star.fill" : "star")
                            .foregroundColor(recording.isStarred ? .yellow : .gray)
                    }
                    
                    Button(action: onExport) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                
                Divider()
                
                Text(recording.fullText)
                    .font(.body)
                    .padding()
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("Transcription")
    }
}

// MARK: - iOS/iPadOS ContentView Adaptation
extension ContentView {
    #if os(iOS)
    private var recordingControlsIOS: some View {
        VStack {
            Text("Input: \(audioManager.selectedMicrophone?.localizedName ?? "Default Microphone")").foregroundColor(.gray).padding()
            Picker("Language", selection: $languageManager.selectedLanguage) {ForEach(languageManager.availableLanguages, id: \.id) { language in Text(language.name).tag(language) }}
            .pickerStyle(MenuPickerStyle())
            .onChange(of: languageManager.selectedLanguage) { newValue in audioManager.setTranscriberLanguage(languageCode: newValue.code) }
            .disabled(audioManager.isRecording)
            .padding()
            
            Button(audioManager.isRecording ? "Stop Recording" : "Start Recording") { toggleRecording() }
            .buttonStyle(.borderedProminent)
            .tint(audioManager.isRecording ? .red : .green)
            .foregroundColor(.white)
            .padding()
        }
    }
    
    private var iPadLayout: some View {
        NavigationView {
            VStack {
                if !audioManager.audioPermissionGranted {
                    permissionViewIOS
                } else {
                    recordingControlsIOS
                    if audioManager.isRecording {
                        AudioWaveformView(audioLevels: audioLevels)
                            .frame(height: 60)
                            .padding()
                    }
                }
                Spacer()
                
                if !audioManager.isRecording {
                    List {
                        ForEach($savedRecordings) { $recording in
                            NavigationLink(destination: RecordingDetailView(recording: $recording, onExport: { exportRecording(recording) })) {
                                Text(recording.date)
                                    .font(.headline)
                            }
                        }
                        .onDelete(perform: deleteRecordings)
                    }
                    .listStyle(SidebarListStyle())
                }
            }
            .frame(width: 300)
            .background(Color(.darkGray))
            
            Group {
                if audioManager.isRecording {
                    liveTranscriptionViewIOS
                } else if let firstRecording = savedRecordings.first {
                    RecordingDetailView(
                        recording: .constant(firstRecording),
                        onExport: { exportRecording(firstRecording) }
                    )
                } else {
                    Text("Select a recording or start a new one")
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private var permissionViewIOS: some View {
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
    
    private var liveTranscriptionViewIOS: some View {
        VStack {
            Text("Live Transcription")
                .font(.title)
                .padding()
            
            Text("Language: \(languageManager.selectedLanguage.name)")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.bottom)
            
            ScrollView {
                VStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Text(displayText.isEmpty ? "Start speaking..." : displayText)
                            .animation(.easeInOut, value: displayText)
                        
                        // Cursor animation
                        if audioManager.isRecording {
                            Rectangle()
                                .frame(width: 2, height: 20)
                                .foregroundColor(.white)
                                .opacity(1)
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            HStack {
                Button("Copy") {
                    copyToClipboard()
                }
                .disabled(transcribedText.isEmpty)
                
                Button("Save") {
                    audioManager.stopRecording()
                    stopTextAnimation()
                    if !transcribedText.isEmpty {
                        saveCurrentRecording()
                    }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    private func deleteRecordings(at offsets: IndexSet) {
        savedRecordings.remove(atOffsets: offsets)
        saveRecordingsToStorage()
    }
    
    private func exportRecordingIOS(_ recording: RecordingFile) {
        let fileName = "Transcription_\(recording.date).txt"
        let activityVC = UIActivityViewController(
            activityItems: [recording.fullText],
            applicationActivities: nil
        )
        
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        window?.rootViewController?.present(activityVC, animated: true)
    }
    #endif
}

extension View {func typingCursor() -> some View {self.modifier(TypingCursorModifier())}}
#Preview {ContentView()}
