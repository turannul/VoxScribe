//
//  AudioManager.swift
//  VoxScribe
//
//  Created by Turann_ on 30.03.2025.
//


import AVFoundation
import SwiftUI

class AudioManager: NSObject, ObservableObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    @Published var isRecording: Bool = false
    @Published var availableMicrophones: [AVCaptureDevice] = []
    @Published var selectedMicrophone: AVCaptureDevice?
    @Published var audioPermissionGranted: Bool = false
    
    private var captureSession: AVCaptureSession?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var audioEngine: AVAudioEngine?
    private var transcriber: Transcriber?
    private var microphoneUpdateTimer: Timer?
    private var currentLanguageCode: String = Locale.current.identifier
    
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
        if let firstMic: AVCaptureDevice = availableMicrophones.first {self.selectedMicrophone = firstMic}
    }
    
    func setupMicrophoneMonitoring() {
        microphoneUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.refreshMicrophoneList() }
    }
    
    func refreshMicrophoneList() {
        let currentDeviceID: String? = selectedMicrophone?.uniqueID
        let updatedMicrophones: [AVCaptureDevice] = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .unspecified).devices
        
        if !compareDeviceLists(oldList: availableMicrophones, newList: updatedMicrophones) {
            self.availableMicrophones = updatedMicrophones
            
            if let currentID: String = currentDeviceID,
                let sameDevice: AVCaptureDevice = updatedMicrophones.first(where: { $0.uniqueID == currentID }) {self.selectedMicrophone = sameDevice
            } else if 
                let firstMic: AVCaptureDevice = updatedMicrophones.first { self.selectedMicrophone = firstMic }
        }
    }
    
    private func compareDeviceLists(oldList: [AVCaptureDevice], newList: [AVCaptureDevice]) -> Bool {
        guard oldList.count == newList.count else { return false }
        let oldIDs: Set<String> = Set(oldList.map { $0.uniqueID })
        let newIDs: Set<String> = Set(newList.map { $0.uniqueID })
        return oldIDs == newIDs
    }
    
    func setupTranscriber() {
        let locale: Locale = Locale(identifier: currentLanguageCode)
        self.transcriber = Transcriber(locale: locale)
        NotificationCenter.default.addObserver(self, selector: #selector(transcriptionDidUpdate), name: NSNotification.Name("TranscriberTextChanged"), object: nil)
    }
    
    func setTranscriberLanguage(languageCode: String) {
        currentLanguageCode = languageCode
        let wasRecording: Bool = isRecording
        if wasRecording {stopRecording()}
        transcriber?.setLanguage(identifier: languageCode)
        if wasRecording {startRecording()}
    }
    
    @objc func transcriptionDidUpdate(_ notification: Notification) {
        if let text: String = notification.object as? String {NotificationCenter.default.post(name: Notification.Name("TranscriptionUpdated"), object: text)}
    }
    
    func startRecording() {
        guard audioPermissionGranted else { return }
        
        #if os(macOS)
        guard let selectedMic = selectedMicrophone else { return }
        
        let session = AVCaptureSession()
        do {
            let audioInput = try AVCaptureDeviceInput(device: selectedMic)
            if session.canAddInput(audioInput) { session.addInput(audioInput) }
            
            let output = AVCaptureAudioDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "audioQueue"))
            if session.canAddOutput(output) { session.addOutput(output) }
            
            self.captureSession = session
            self.audioOutput = output
            
            setupAudioEngine()
            
            session.startRunning()
            try audioEngine?.start()
            self.isRecording = true
        } catch {
            print("Error setting up audio capture: \(error)")
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Error setting up audio capture"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        #else
        setupAudioEngineIOS()
        #endif
    }
    
    func setupAudioEngine() {
        let engine: AVAudioEngine = AVAudioEngine()
        let inputNode: AVAudioInputNode = engine.inputNode
        let recordingFormat: AVAudioFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, time in 
            self.processAudioSamples(buffer)
            self.transcriber?.processAudio(buffer: buffer)
        }
        
        do {
            try engine.start()
            self.audioEngine = engine
        } catch {
            #if os(macOS)
            let alert: NSAlert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Error starting audio engine"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            #endif
        }
    }
    
    func stopRecording() {
        #if os(macOS)
        captureSession?.stopRunning()
        #endif
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Error deactivating audio session: \(error)")
        }
        #endif
        
        self.isRecording = false
        transcriber?.finishProcessing()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        transcriber?.processAudio(sampleBuffer: sampleBuffer)
    }
    
    func processAudioSamples(_ buffer: AVAudioPCMBuffer) {
        guard let channelData: UnsafePointer<UnsafeMutablePointer<Float>> = buffer.floatChannelData else { return }
        let samples: [Float] = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelData[0][$0] }
        let rms: Float = sqrt(samples.reduce(0) { $0 + pow($1, 2) } / Float(buffer.frameLength))
        let dB: Float = 20 * log10(rms)
        let normalizedLevel: Float = max(0, min(1, (dB + 60) / 60))
        DispatchQueue.main.async {NotificationCenter.default.post(name: Notification.Name("AudioLevelUpdated"), object: normalizedLevel)}
    }

    func cleanup() {
        microphoneUpdateTimer?.invalidate()
        microphoneUpdateTimer = nil
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Audio Manager iOS Implementation
extension AudioManager {
#if os(iOS)
    func setupAudioEngineIOS() {
        let engine = AVAudioEngine()
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { buffer, time in
                self.processAudioSamples(buffer)
                self.transcriber?.processAudio(buffer: buffer)
            }
            
            engine.prepare()
            try engine.start()
            self.audioEngine = engine
            
            // Set isRecording flag after successful setup
            self.isRecording = true
        } catch {
            print("Error setting up audio engine: \(error.localizedDescription)")
            #if os(iOS)
            // Show an alert on iOS
            DispatchQueue.main.async {
                let alertController = UIAlertController(
                    title: "Audio Error",
                    message: "Failed to start recording: \(error.localizedDescription)",
                    preferredStyle: .alert
                )
                alertController.addAction(UIAlertAction(title: "OK", style: .default))
                
                // Get the key window to present the alert
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                    let window = windowScene.windows.first {
                    window.rootViewController?.present(alertController, animated: true)
                }
            }
            #endif
        }
    }
#endif
}