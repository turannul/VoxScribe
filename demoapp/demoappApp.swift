import SwiftUI
import AVFoundation
import Speech
import WhisperKit
import CoreAudio

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
            AVCaptureDevice.requestAccess(for: .audio) { granted in DispatchQueue.main.async {self.audioPermissionGranted = granted} }
        default:
            self.audioPermissionGranted = false
        }
    }
    
    func fetchAvailableMicrophones() {
        self.availableMicrophones = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .unspecified).devices
        
        if let firstMic = availableMicrophones.first {self.selectedMicrophone = firstMic}
    }
    
    func setupMicrophoneMonitoring() {
        microphoneUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.refreshMicrophoneList() }
    }
    
    func refreshMicrophoneList() {
        let currentDeviceID = selectedMicrophone?.uniqueID
        let updatedMicrophones = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .unspecified).devices
        
        if !compareDeviceLists(oldList: availableMicrophones, newList: updatedMicrophones) {
            self.availableMicrophones = updatedMicrophones
            
            if let currentID = currentDeviceID,
               let sameDevice = updatedMicrophones.first(where: { $0.uniqueID == currentID }) {self.selectedMicrophone = sameDevice
            } else if let firstMic = updatedMicrophones.first { self.selectedMicrophone = firstMic }
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
        NotificationCenter.default.addObserver(self, selector: #selector(transcriptionDidUpdate), name: NSNotification.Name("TranscriberTextChanged"), object: nil)
    }
    
    @objc func transcriptionDidUpdate(_ notification: Notification) {
        if let text = notification.object as? String {NotificationCenter.default.post(name: Notification.Name("TranscriptionUpdated"), object: text)}
    }
    
    func startRecording() {
        guard audioPermissionGranted, let selectedMic = selectedMicrophone else { return }
        
        let session = AVCaptureSession()
        do {
            let audioInput = try AVCaptureDeviceInput(device: selectedMic)
            if session.canAddInput(audioInput) {session.addInput(audioInput)}
            
            let output = AVCaptureAudioDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "audioQueue"))
            if session.canAddOutput(output) {session.addOutput(output)}

            self.captureSession = session
            self.audioOutput = output
            
            setupAudioEngine()
            
            session.startRunning()
            try audioEngine?.start()
            self.isRecording = true
        } catch {
            print("Error setting up audio capture: \(error)")
            // TODO: A Error message box
        }
    }
    
    func setupAudioEngine() {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, time in self.transcriber?.processAudio(buffer: buffer) }
        
        do {
            try engine.start()
            self.audioEngine = engine
        } catch {
            print("Error starting audio engine: \(error)")
            // TODO: A Error message box
        }
    }
    
    func stopRecording() {
        captureSession?.stopRunning()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        self.isRecording = false
        
        transcriber?.finishProcessing()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {transcriber?.processAudio(sampleBuffer: sampleBuffer)}
    
    func cleanup() {
        microphoneUpdateTimer?.invalidate()
        microphoneUpdateTimer = nil
        NotificationCenter.default.removeObserver(self)
    }
}

class Transcriber: NSObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var whisperKit: WhisperKit?
    private var WhisperKitAvailable: Bool = false
    
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
        if WhisperKitAvailable {setupWhisperKit()}
    }
    
    func setupRecognition() {
        // Native Speech Recognition
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("Speech recognition authorization denied")
                // TODO: A Error message box
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
                // TODO: A Error message box
                WhisperKitAvailable = false
            }
        }
    }
    
    func processAudio(buffer: AVAudioPCMBuffer) {
        if WhisperKitAvailable {
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
                    DispatchQueue.main.async {self.transcribedText = result.bestTranscription.formattedString}
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
        return TranscriptionResult(text: "Test transcription placeholder")
    }
}

struct TranscriptionResult {
    let text: String
}

@main
struct MeetingTranscriberApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
