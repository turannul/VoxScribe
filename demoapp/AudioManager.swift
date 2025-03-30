import SwiftUI
import AVFoundation
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
        cleanup() // Invalidate timer
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            self.audioPermissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in DispatchQueue.main.async { self.audioPermissionGranted = granted } }
        default:
            self.audioPermissionGranted = false
        }
    }
    
    func fetchAvailableMicrophones() {
        let allDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .unspecified).devices
        
        // Filter out system-created devices
        self.availableMicrophones = allDevices.filter {device in !device.localizedName.contains("CADefaultDeviceAggregate") && !device.localizedName.contains("NULL") && !device.localizedName.contains("Default Audio Device") && !device.localizedName.contains("System") }
        
        if let firstValidMic = availableMicrophones.first { self.selectedMicrophone = firstValidMic }
    }
    
    func setupMicrophoneMonitoring() {
        microphoneUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.refreshMicrophoneList() }
    }
    
    private func isValidMicrophone(_ device: AVCaptureDevice) -> Bool {
        let invalidNames = ["CADefaultDeviceAggregate", "NULL", "Default Audio Device", "System"]
        return !invalidNames.contains { device.localizedName.contains($0) }
    }
    
    func refreshMicrophoneList() {
        let currentDeviceID = selectedMicrophone?.uniqueID
        let allDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .unspecified ).devices
        
        self.availableMicrophones = allDevices.filter(isValidMicrophone)
        
        // Restore selection if still valid
        if let currentID = currentDeviceID,
            let sameDevice = availableMicrophones.first(where: { $0.uniqueID == currentID }) {
            self.selectedMicrophone = sameDevice
        } else {
            self.selectedMicrophone = availableMicrophones.first
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(transcriptionDidUpdate),
            name: NSNotification.Name("TranscriberTextChanged"),
            object: nil
        )
    }
    
    @objc func transcriptionDidUpdate(_ notification: Notification) {
        if let text = notification.object as? String {
            NotificationCenter.default.post(
                name: Notification.Name("TranscriptionUpdated"),
                object: text
            )
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
            self.processAudioSamples(buffer)
            self.transcriber?.processAudio(buffer: buffer)
        }
        
        do {
            try engine.start()
            self.audioEngine = engine
        } catch {
            print("Error starting audio engine: \(error)")
        }
    }
    
    func processAudioSamples(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let samples = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride)
            .map { channelData[0][$0] }
        
        let rms = sqrt(samples.reduce(0) { $0 + pow($1, 2) } / Float(buffer.frameLength))
        let dB = 20 * log10(rms)
        let normalizedLevel = max(0, min(1, (dB + 60) / 60))
        
        DispatchQueue.main.async {
            self.updateAudioLevels(normalizedLevel)
        }
    }
    
    func updateAudioLevels(_ level: Float) {
        NotificationCenter.default.post(
            name: Notification.Name("AudioLevelUpdated"),
            object: level
        )
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
