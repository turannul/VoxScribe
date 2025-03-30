import AVFoundation
import AudioKit

class AudioManager: NSObject, ObservableObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    @Published var isRecording = false
    @Published var availableMicrophones: [AVCaptureDevice] = []
    @Published var selectedMicrophone: AVCaptureDevice?
    @Published var audioPermissionGranted = false
    
    private var captureSession: AVCaptureSession?
    private var audioOutput: AVCaptureAudioDataOutput?
    // Use AudioKit’s AudioEngine in place of AVAudioEngine.
    private var audioEngine: AudioEngine?
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
        cleanup() // Invalidate timer and remove observers
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
        let allDevices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices
        
        self.availableMicrophones = allDevices.filter { device in
            !device.localizedName.contains("CADefaultDeviceAggregate") &&
            !device.localizedName.contains("NULL") &&
            !device.localizedName.contains("Default Audio Device") &&
            !device.localizedName.contains("System")
        }
        
        if let firstValidMic = availableMicrophones.first {
            self.selectedMicrophone = firstValidMic
        }
    }
    
    func setupMicrophoneMonitoring() {
        microphoneUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshMicrophoneList()
        }
    }
    
    private func isValidMicrophone(_ device: AVCaptureDevice) -> Bool {
        let invalidNames = ["CADefaultDeviceAggregate", "NULL", "Default Audio Device", "System"]
        return !invalidNames.contains { device.localizedName.contains($0) }
    }
    
    func refreshMicrophoneList() {
        let currentDeviceID = selectedMicrophone?.uniqueID
        let allDevices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices
        
        self.availableMicrophones = allDevices.filter(isValidMicrophone)
        
        // Restore selection if still valid
        if let currentID = currentDeviceID,
           let sameDevice = availableMicrophones.first(where: { $0.uniqueID == currentID }) {
            self.selectedMicrophone = sameDevice
        } else {
            self.selectedMicrophone = availableMicrophones.first
        }
    }
    
    func setupTranscriber() {
        self.transcriber = Transcriber()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(transcriptionDidUpdate),
            name: Notification.Name("TranscriptionUpdated"),
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
        guard audioPermissionGranted, selectedMicrophone != nil else { return }
        
        // Use AVCaptureSession to select the microphone device for recording meeting audio.
        let session = AVCaptureSession()
        do {
            let audioInput = try AVCaptureDeviceInput(device: selectedMicrophone!)
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
            
            // Setup AudioKit engine for processing the microphone signal.
            setupAudioEngine()
            
            session.startRunning()
            self.isRecording = true
        } catch {
            print("Error setting up audio capture: \(error)")
        }
    }
    
    func setupAudioEngine() {
        // Initialize AudioKit engine.
        let engine = AudioEngine()
        // Use the input node provided by AudioKit.
        guard let input = engine.input else {
            print("Audio input not available")
            return
        }
        
        // Configure format to 16kHz mono for WhisperKit compatibility.
        let desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!
        
        // Install a tap on the AudioKit input node.
        input.avAudioNode.installTap(onBus: 0, bufferSize: 1024, format: desiredFormat) { [weak self] buffer, _ in
            self?.transcriber?.processAudio(buffer: buffer)
        }
        
        do {
            try engine.start()
            self.audioEngine = engine
        } catch {
            print("Audio engine error: \(error)")
        }
    }
    
    func stopRecording() {
        captureSession?.stopRunning()
        // Stop AudioKit engine and remove tap.
        if let engine = audioEngine, let input = engine.input {
            engine.stop()
            input.avAudioNode.removeTap(onBus: 0)
        }
        self.isRecording = false
        
        // Finish any remaining transcription processing.
        transcriber?.finishProcessing()
    }
    
    // For AVCaptureAudioDataOutputSampleBufferDelegate – forward sample buffers to transcriber.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        transcriber?.processAudio(sampleBuffer: sampleBuffer)
    }
    
    func cleanup() {
        microphoneUpdateTimer?.invalidate()
        microphoneUpdateTimer = nil
        NotificationCenter.default.removeObserver(self)
    }
}
