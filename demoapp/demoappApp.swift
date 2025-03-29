//
//  demoappApp.swift
//  demoapp
//
//  Created by Turann_ on 29.03.2025.
//

import SwiftUI
import AVFoundation
import Speech
import WhisperKit
import CoreAudio

@main
struct MeetingTranscriberApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AudioManager: NSObject, ObservableObject, AVCaptureAudioDataOutputSampleBufferDelegate {  
    @Published var isRecording = false
    @Published var availableMicrophones: [AVCaptureDevice] = []
    @Published var selectedMicrophone: AVCaptureDevice?
    @Published var audioPermissionGranted = false
    
    private var captureSession: AVCaptureSession?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var audioFileOutput: AVCaptureMovieFileOutput?
    private var audioRecorder: AVAudioRecorder?
    private var audioEngine: AVAudioEngine?
    private var audioData = Data()
    private var microphoneUpdateTimer: Timer?
    private var transcriber: Transcriber?
    
    override init() {
        super.init()
        checkPermissions()
        fetchAvailableMicrophones()
        setupTranscriber()
        setupMicrophoneMonitoring()
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

    func setupMicrophoneMonitoring() {
        microphoneUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshMicrophoneList()
        }
    }
    
    func cleanup() {
        microphoneUpdateTimer?.invalidate()
        microphoneUpdateTimer = nil
    }
    
    // Helper to compare device lists to detect changes
    private func compareDeviceLists(oldList: [AVCaptureDevice], newList: [AVCaptureDevice]) -> Bool {
        guard oldList.count == newList.count else { return false }
        
        let oldIDs = Set(oldList.map { $0.uniqueID })
        let newIDs = Set(newList.map { $0.uniqueID })
        
        return oldIDs == newIDs
    }
    
    func refreshMicrophoneList() {
        let currentDeviceID = selectedMicrophone?.uniqueID
        
        // Get updated list of microphones
        let updatedMicrophones = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone],mediaType: .audio,position: .unspecified).devices
        
        // Only update if the list has actually changed
        if !compareDeviceLists(oldList: availableMicrophones, newList: updatedMicrophones) {
            self.availableMicrophones = updatedMicrophones
            
            // Try to keep the same device selected if it still exists
            if let currentID = currentDeviceID,
            let sameDevice = updatedMicrophones.first(where: { $0.uniqueID == currentID }) {
                self.selectedMicrophone = sameDevice
            } else if let firstMic = updatedMicrophones.first {
                self.selectedMicrophone = firstMic
            }
        }
    }

    func fetchAvailableMicrophones() {
        self.availableMicrophones = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .unspecified).devices
        if let firstMic = availableMicrophones.first {self.selectedMicrophone = firstMic}
    }
    
    func setupTranscriber() {
        self.transcriber = Transcriber()
    }
    
    func startRecording() {
        guard audioPermissionGranted, let selectedMic = selectedMicrophone else { return }
        
        // Setup capture session
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
            
            // Also setup AVAudioEngine for system audio capture
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
        
        // Process any remaining audio for transcription
        transcriber?.finishProcessing()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Handle microphone audio
        transcriber?.processAudio(sampleBuffer: sampleBuffer)
    }

    deinit {
        cleanup()
    }

}

class Transcriber: NSObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var whisperKit: WhisperKit?
    private var useWhisperKit = true
    
    @Published var transcribedText = ""
    
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
        // Initialize WhisperKit
        // Note: This is a placeholder for the actual WhisperKit setup
        // You would need to follow the WhisperKit documentation for proper initialization
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
        // Convert CMSampleBuffer to format needed for transcription
        // Implementation depends on whether using WhisperKit or native Speech framework
    }
    
    func processWithWhisperKit(buffer: AVAudioPCMBuffer) {
        // This is a placeholder for WhisperKit transcription
        // Actual implementation would follow WhisperKit documentation
        Task {
            guard whisperKit != nil else { return }
            
            // Convert buffer to appropriate format for WhisperKit
            // Then run transcription
            
            // Example (pseudo-code based on WhisperKit API):
            // let result = try await whisperKit.transcribe(buffer)
            // DispatchQueue.main.async {
            //     self.transcribedText += result.text + " "
            // }
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

extension WhisperKit {
    static func setup() async throws -> WhisperKit {
        return try await WhisperKit()
    }
    
    func transcribe(_ buffer: AVAudioPCMBuffer) async throws -> TranscriptionResult {
        return TranscriptionResult(text: "Transcription placeholder")
    }
}

struct TranscriptionResult {
    let text: String
}
