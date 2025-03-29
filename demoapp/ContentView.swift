//
//  ContentView.swift
//  demoapp
//
//  Created by Turann_ on 29.03.2025.
//

import SwiftUI
import AVFoundation
import Speech
import WhisperKit
import CoreAudio

/*
struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var transcribedText = ""
    
    var body: some View {
        HStack(spacing: 0) {
            // Left panel - Controls
            VStack {
                Text("Hello World!")
                    .font(.title)
                    .padding()
                
                if !audioManager.audioPermissionGranted {
                    Text("Microphone access is required")
                        .foregroundColor(.red)
                        .padding()
                    
                    Button("Request Permission") {
                        audioManager.checkPermissions()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                } else {
                    // Microphone selection
                    Picker("Select Microphone", selection: $audioManager.selectedMicrophone) {
                        ForEach(audioManager.availableMicrophones, id: \.uniqueID) { device in Text(device.localizedName).tag(device as AVCaptureDevice?)
                        }
                    }
                    .padding()
                    
                    Button(audioManager.isRecording ? "Stop Meeting" : "Start Meeting") {
                        if audioManager.isRecording {
                            // while recording - show right panel - Live transcription
                            audioManager.stopRecording()
                        } else {
                            // when recording stopped - show previously recorded audio files
                            audioManager.startRecording()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundColor(.white)
                    .background(audioManager.isRecording ? Color.red : Color.green)
                    .cornerRadius(8)
                    .padding()
                }
                
                Spacer()
            }
            .frame(width: 300)
            .background(Color(.darkGray))
            
            // Right panel - Transcription
            VStack {
                Text("Transcription")
                    .font(.title)
                    .padding()
                
                ScrollView {
                    Text(transcribedText.isEmpty ? "Meeting transcription will appear here..." : transcribedText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TranscriptionUpdated"))) { notification in
            if let text = notification.object as? String {
                self.transcribedText = text
            }
        }
    }
    
    func saveTranscription() {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.text]
        savePanel.nameFieldStringValue = "Meeting Transcription.txt"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try transcribedText.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to save transcription: \(error)")
                }
            }
        }
        #else
        // iOS implementation would use UIDocumentPickerViewController
        #endif
    }
}
*/

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var transcribedText = ""
    @State private var showRecordedFiles = false
    @State private var savedRecordings: [RecordingFile] = []
    
    var body: some View {
        HStack(spacing: 0) {
            // Left panel - Controls
            VStack {
                Text("Meeting Transcriber")
                    .font(.title)
                    .padding()
                
                if !audioManager.audioPermissionGranted {
                    Text("Microphone access is required")
                        .foregroundColor(.red)
                        .padding()
                    
                    Button("Request Permission") {
                        audioManager.checkPermissions()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                } else {
                    // Microphone selection
                    Picker("Select Microphone", selection: $audioManager.selectedMicrophone) {
                        ForEach(audioManager.availableMicrophones, id: \.uniqueID) { device in 
                            Text(device.localizedName).tag(device as AVCaptureDevice?)
                        }
                    }
                    .padding()
                    
                    // Toggle between recording and viewing saved files
                    Button(audioManager.isRecording ? "Stop Meeting" : "Start Meeting") {
                        if audioManager.isRecording {
                            audioManager.stopRecording()
                            // Save current recording when stopping
                            if !transcribedText.isEmpty {
                                saveCurrentRecording()
                            }
                        } else {
                            showRecordedFiles = false
                            transcribedText = ""
                            audioManager.startRecording()
                        }
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
                
                Spacer()
            }
            .frame(width: 300)
            .background(Color(.darkGray))
            
            // Right panel - Transcription or Saved Files
            if showRecordedFiles {
                // Show saved recordings
                VStack {
                    Text("Saved Recordings")
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
                                showRecordedFiles = false
                            }
                        }
                    }
                }
                .background(Color.white)
            } else {
                // Show live transcription
                VStack {
                    Text("Transcription")
                        .font(.title)
                        .padding()
                    
                    ScrollView {
                        Text(transcribedText.isEmpty ? "Meeting transcription will appear here..." : transcribedText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TranscriptionUpdated"))) { notification in
            if let text = notification.object as? String {
                self.transcribedText = text
            }
        }
    }
    
    func saveTranscription() {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.text]
        savePanel.nameFieldStringValue = "Meeting Transcription.txt"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try transcribedText.write(to: url, atomically: true, encoding: .utf8)
                    saveCurrentRecording()
                } catch {
                    print("Failed to save transcription: \(error)")
                }
            }
        }
        #else
        // iOS implementation would use UIDocumentPickerViewController
        #endif
    }
    
    func saveCurrentRecording() {
        // Get the Documents directory
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateString = formatter.string(from: Date())
        
        // Create a recording object
        let recording = RecordingFile(
            id: UUID(),
            date: dateString,
            preview: String(transcribedText.prefix(100)) + (transcribedText.count > 100 ? "..." : ""),
            fullText: transcribedText
        )
        
        // Save to UserDefaults for simplicity
        // In a real app, consider using Core Data or files
        var recordings = getSavedRecordings()
        recordings.append(recording)
        if let encoded = try? JSONEncoder().encode(recordings) {
            UserDefaults.standard.set(encoded, forKey: "savedRecordings")
        }
    }
    
    func loadSavedRecordings() {
        savedRecordings = getSavedRecordings()
    }
    
    func getSavedRecordings() -> [RecordingFile] {
        if let savedData = UserDefaults.standard.data(forKey: "savedRecordings"),
           let recordings = try? JSONDecoder().decode([RecordingFile].self, from: savedData) {
            return recordings
        }
        return []
    }
}

// Model for saved recordings
struct RecordingFile: Identifiable, Codable {
    var id: UUID
    var date: String
    var preview: String
    var fullText: String
}

// Updates to AudioManager class
class AudioManager: NSObject, ObservableObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    @Published var isRecording = false
    @Published var availableMicrophones: [AVCaptureDevice] = []
    @Published var selectedMicrophone: AVCaptureDevice?
    @Published var audioPermissionGranted = false
    
    private var captureSession: AVCaptureSession?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var audioEngine: AVAudioEngine?
    private var transcriber: Transcriber?
    private var microphoneUpdateTimer: Timer?
    
    override init() {
        super.init()
        checkPermissions()
        fetchAvailableMicrophones()
        setupTranscriber()
        setupMicrophoneMonitoring()
    }
    
    deinit {
        cleanup()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            self.audioPermissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.audioPermissionGranted = granted
                }
            }
        default:
            self.audioPermissionGranted = false
        }
    }
    
    func fetchAvailableMicrophones() {
        self.availableMicrophones = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone], 
            mediaType: .audio, 
            position: .unspecified
        ).devices
        
        if let firstMic = availableMicrophones.first {
            self.selectedMicrophone = firstMic
        }
    }
    
    func setupMicrophoneMonitoring() {
        microphoneUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshMicrophoneList()
        }
    }
    
    func refreshMicrophoneList() {
        let currentDeviceID = selectedMicrophone?.uniqueID
        
        let updatedMicrophones = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone], 
            mediaType: .audio, 
            position: .unspecified
        ).devices
        
        if !compareDeviceLists(oldList: availableMicrophones, newList: updatedMicrophones) {
            self.availableMicrophones = updatedMicrophones
            
            if let currentID = currentDeviceID, 
               let sameDevice = updatedMicrophones.first(where: { $0.uniqueID == currentID }) {
                self.selectedMicrophone = sameDevice
            } else if let firstMic = updatedMicrophones.first {
                self.selectedMicrophone = firstMic
            }
        }
    }
    
    private func compareDeviceLists(oldList: [AVCaptureDevice], newList: [AVCaptureDevice]) -> Bool {
        guard oldList.count == newList.count else { return false }
        
        let oldIDs = Set(oldList.map { $0.uniqueID })
        let newIDs = Set(newList.map { $0.uniqueID })
        
        return oldIDs == newIDs
    }
    
    func setupTranscriber() {
        self.transcriber = Transcriber()
        
        // Add notification observer to handle transcription updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(transcriptionDidUpdate),
            name: NSNotification.Name("TranscriberTextChanged"),
            object: nil
        )
    }
    
    @objc func transcriptionDidUpdate(_ notification: Notification) {
        if let text = notification.object as? String {
            NotificationCenter.default.post(name: Notification.Name("TranscriptionUpdated"), object: text)
        }
    }
    
    func startRecording() {
        guard audioPermissionGranted, let selectedMic = selectedMicrophone else { return }
        
        let session = AVCaptureSession()
        do {
            let audioInput = try AVCaptureDeviceInput(device: selectedMic)
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
            
            let output = AVCaptureAudioDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "audioQueue"))
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            self.captureSession = session
            self.audioOutput = output
            
            setupAudioEngine()
            
            session.startRunning()
            try audioEngine?.start()
            self.isRecording = true
        } catch {
            print("Error setting up audio capture: \(error)")
        }
    }
    
    func setupAudioEngine() {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, time in
            self.transcriber?.processAudio(buffer: buffer)
        }
        
        do {
            try engine.start()
            self.audioEngine = engine
        } catch {
            print("Error starting audio engine: \(error)")
        }
    }
    
    func stopRecording() {
        captureSession?.stopRunning()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        self.isRecording = false
        
        transcriber?.finishProcessing()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        transcriber?.processAudio(sampleBuffer: sampleBuffer)
    }
    
    func cleanup() {
        microphoneUpdateTimer?.invalidate()
        microphoneUpdateTimer = nil
        NotificationCenter.default.removeObserver(self)
    }
}

// Updated Transcriber class with improved notification
class Transcriber: NSObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var whisperKit: WhisperKit?
    private var useWhisperKit = true
    
    private var _transcribedText = ""
    var transcribedText: String {
        get { return _transcribedText }
        set {
            _transcribedText = newValue
            NotificationCenter.default.post(
                name: NSNotification.Name("TranscriberTextChanged"),
                object: newValue
            )
        }
    }
    
    override init() {
        super.init()
        setupRecognition()
        if useWhisperKit {
            setupWhisperKit()
        }
    }
    
    func setupRecognition() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("Speech recognition authorization denied")
            }
        }
    }
    
    func setupWhisperKit() {
        Task {
            do {
                whisperKit = try await WhisperKit.setup()
                print("WhisperKit initialized successfully")
            } catch {
                print("Failed to initialize WhisperKit: \(error)")
                useWhisperKit = false
            }
        }
    }
    
    func processAudio(buffer: AVAudioPCMBuffer) {
        if useWhisperKit {
            processWithWhisperKit(buffer: buffer)
        } else {
            processWithSpeechRecognition(buffer: buffer)
        }
    }
    
    func processAudio(sampleBuffer: CMSampleBuffer) {
        // Implementation would depend on WhisperKit or Speech framework requirements
    }
    
    func processWithWhisperKit(buffer: AVAudioPCMBuffer) {
        Task {
            guard let whisperKit = whisperKit else { return }
            
            do {
                let result = try await whisperKit.transcribe(buffer)
                DispatchQueue.main.async {
                    if !result.text.isEmpty {
                        self.transcribedText += result.text + " "
                    }
                }
            } catch {
                print("WhisperKit transcription error: \(error)")
            }
        }
    }
    
    func processWithSpeechRecognition(buffer: AVAudioPCMBuffer) {
        if recognitionRequest == nil {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest = recognitionRequest else { return }
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                if let result = result {
                    DispatchQueue.main.async {
                        self.transcribedText = result.bestTranscription.formattedString
                    }
                }
            }
        }
        
        recognitionRequest?.append(buffer)
    }
    
    func finishProcessing() {
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

// WhisperKit extension - this would be replaced by actual implementation
extension WhisperKit {
    static func setup() async throws -> WhisperKit {
        return WhisperKit()
    }
    
    func transcribe(_ buffer: AVAudioPCMBuffer) async throws -> TranscriptionResult {
        // In real implementation, this would process audio and return actual transcription
        return TranscriptionResult(text: "Test transcription placeholder")
    }
}

struct TranscriptionResult {
    let text: String
}

// App entry point
@main
struct MeetingTranscriberApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

#Preview {
    ContentView()
}
