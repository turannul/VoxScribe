
//
//  ContentViewModel.swift
//  VoxScribe
//
//  Created by Turann_ on 03.09.2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ContentViewModel: ObservableObject {
    @Published var audioManager = AudioManager()
    @Published var languageManager = LanguageManager()
    
    @Published var transcribedText = ""
    @Published var displayText = ""
    @Published var savedRecordings: [RecordingFile] = []
    @Published var audioLevels: [CGFloat] = Array(repeating: 0, count: 30)
    
    private var animationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadSavedRecordings()
        setupBindings()
    }
    
    private func setupBindings() {
        // Using Combine to listen for changes from AudioManager
        audioManager.transcriptionUpdate
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                self?.updateTranscription(text: text)
            }
            .store(in: &cancellables)
            
        audioManager.audioLevelUpdate
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.updateAudioLevel(level: level)
            }
            .store(in: &cancellables)
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
    
    func copyToClipboard() {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(transcribedText, forType: .string)
        #else
            UIPasteboard.general.string = transcribedText
        #endif
    }
    
    func resetTranscription() {
        transcribedText = ""
        displayText = ""
    }
    
    // MARK: - Recording Management
    func toggleRecording() {
        if audioManager.isRecording {
            audioManager.stopRecording()
            stopTextAnimation()
            if !transcribedText.isEmpty { saveCurrentRecording() }
        } else {
            resetTranscription()
            audioManager.startRecording()
            startTextAnimation()
        }
    }
    
    private func startTextAnimation() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let targetText = self.transcribedText
            if self.displayText.count < targetText.count {
                let newCharacter = targetText[targetText.index(targetText.startIndex, offsetBy: self.displayText.count)]
                withAnimation(.linear(duration: 0.02)) { self.displayText.append(newCharacter) }
            }
        }
    }
    
    private func stopTextAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        displayText = transcribedText
    }
    
    // MARK: - Star & Export Functionality
    func toggleStar(for recording: RecordingFile) {
        guard let index = savedRecordings.firstIndex(where: { $0.id == recording.id }) else { return }
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
                    // Consider showing an alert to the user
                    print("Export failed: \(error)")
                }
            }
        }
        #else
        exportRecordingIOS(recording)
        #endif
    }
    
    #if os(iOS)
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
    
    func deleteRecording(_ recording: RecordingFile) {
        savedRecordings.removeAll { $0.id == recording.id }
        saveRecordingsToStorage()
    }
    
    #if os(iOS)
    func deleteRecordings(at offsets: IndexSet) {
        savedRecordings.remove(atOffsets: offsets)
        saveRecordingsToStorage()
    }
    #endif
    
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
    private func updateAudioLevel(level: Float) {
        let normalizedLevel = CGFloat(min(max(level, 0), 1))
        audioLevels.removeFirst()
        audioLevels.append(normalizedLevel)
    }
}
