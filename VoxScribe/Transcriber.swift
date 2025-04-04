//
//  Transcriber.swift
//  VoxScribe
//
//  Created by Turann_ on 30.03.2025.
//

import AVFoundation
import Speech
import SwiftUI

class Transcriber: NSObject {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var _transcribedText: String = ""
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
        let newLocale: Locale = Locale(identifier: identifier)
        currentLocale = newLocale
        finishProcessing()
        setupRecognizer()
    }
    
    func setupRecognition() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("Speech recognition authorization denied")
                #if os(macOS)
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Warning: Speech recognition authorization denied"
                alert.informativeText = "VoxScribe uses speech recognition to transcribe audio. Please enable speech recognition in system settings."
                alert.runModal()
                #endif
            }
        }
    }
    
    func processAudio(buffer: AVAudioPCMBuffer) {
        processWithSpeechRecognition(buffer: buffer)
    }
    
    func processAudio(sampleBuffer: CMSampleBuffer) {}
    
    func processWithSpeechRecognition(buffer: AVAudioPCMBuffer) {
        if recognitionRequest == nil {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest: SFSpeechAudioBufferRecognitionRequest = recognitionRequest else { return }
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                if let result: SFSpeechRecognitionResult = result {
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