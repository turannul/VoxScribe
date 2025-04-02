//
//  Transcriber.swift
//  Transcriber
//
//  Created by Turann_ on 30.03.2025.
//

import AVFoundation
import Speech

class Transcriber: NSObject {
    private var speechRecognizer: SFSpeechRecognizer?
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
    
    private var currentLocale: Locale
    
    init(locale: Locale? = nil) {
        self.currentLocale = locale ?? Locale.current
        super.init()
        setupRecognizer()
        setupRecognition()
    }
    
    private func setupRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: currentLocale)
    }
    
    func setLanguage(identifier: String) {
        let newLocale = Locale(identifier: identifier)
        currentLocale = newLocale
        finishProcessing()
        setupRecognizer()
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
    
    func processAudio(sampleBuffer: CMSampleBuffer) {} // this is somewhat crucial despite being no code in it.
    
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