//
//  Transcriber.swift
//  Transcriber
//
//  Created by Turann_ on 30.03.2025.
//

import AVFoundation
import Speech

class Transcriber: NSObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "tr-TR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
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
    }
    
    func setupRecognition() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("Speech recognition authorization denied")
                // TODO: Handle authorization error
            }
        }
    }
    
    func processAudio(buffer: AVAudioPCMBuffer) {
        processWithSpeechRecognition(buffer: buffer)
    }
    
    func processAudio(sampleBuffer: CMSampleBuffer) {
        // TODO: Implement Speech framework processing.
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
