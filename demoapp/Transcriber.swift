import WhisperKit
import AudioKit
import AVFoundation

class Transcriber: NSObject {
    private var whisperKit: WhisperKit?
    private var processingQueue = DispatchQueue(label: "transcriber.queue", qos: .userInitiated)
    private var buffers: [AVAudioPCMBuffer] = []
    private var isProcessing = false
    
    override init() {
        super.init()
        // Initialize WhisperKit asynchronously.
        Task {
            await setup()
        }
    }
    
    @MainActor
    func setup() async {
        do {
            whisperKit = try await WhisperKit()
            print("WhisperKit ready")
        } catch {
            print("WhisperKit init failed: \(error)")
        }
    }
    
    /// Receives a buffer either from the AudioKit tap or from the AVCapture delegate.
    func processAudio(buffer: AVAudioPCMBuffer) {
        processingQueue.async { [weak self] in
            self?.buffers.append(buffer)
            self?.processBuffersIfNeeded()
        }
    }
    
    /// Overload to handle CMSampleBuffer from AVCapture output.
    func processAudio(sampleBuffer: CMSampleBuffer) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer),
              let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        if CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer) == noErr,
           let dataPointer = dataPointer {
            let audioFormat = AVAudioFormat(cmAudioFormatDescription: format)
            if let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(length) / audioFormat.streamDescription.pointee.mBytesPerFrame) {
                buffer.frameLength = buffer.frameCapacity
                memcpy(buffer.floatChannelData?[0], dataPointer, Int(buffer.frameLength) * Int(audioFormat.streamDescription.pointee.mBytesPerFrame))
                processAudio(buffer: buffer)
            }
        }
    }
    
    private func processBuffersIfNeeded() {
        guard !isProcessing, !buffers.isEmpty else { return }
        isProcessing = true
        
        guard let mergedBuffer = mergeBuffers(buffers) else {
            isProcessing = false
            return
        }
        buffers.removeAll()
        
        Task {
            guard let whisperKit = self.whisperKit else {
                self.isProcessing = false
                return
            }
            
            do {
                let audioArray = self.bufferToFloatArray(mergedBuffer)
                let results = try await whisperKit.transcribe(
                    audioArray: audioArray)

                
                if let text = results.first?.text {
                    self.updateTranscription(text)
                }
            } catch {
                print("Transcription error: \(error)")
            }
            self.isProcessing = false
        }
    }
    
    /// Merge multiple AVAudioPCMBuffer objects into one contiguous buffer.
    private func mergeBuffers(_ buffers: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        guard let firstBuffer = buffers.first else { return nil }
        let format = firstBuffer.format
        
        let totalFrameCount = buffers.reduce(0) { $0 + Int($1.frameLength) }
        guard let mergedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrameCount)) else { return nil }
        
        mergedBuffer.frameLength = mergedBuffer.frameCapacity
        
        var currentFrame: AVAudioFrameCount = 0
        
        if let mergedChannelData = mergedBuffer.floatChannelData {
            for buffer in buffers {
                let frameLength = buffer.frameLength
                if let channelData = buffer.floatChannelData {
                    let destination = mergedChannelData[0] + Int(currentFrame)
                    memcpy(destination, channelData[0], Int(frameLength) * MemoryLayout<Float>.size)
                }
                currentFrame += frameLength
            }
        }
        return mergedBuffer
    }
    
    private func bufferToFloatArray(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let count = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData[0], count: count))
    }
    
    private func updateTranscription(_ text: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("TranscriptionUpdated"),
                object: text
            )
        }
    }
    
    /// Call this if you need to flush any remaining buffers.
    func finishProcessing() {
        processingQueue.async { [weak self] in
            self?.processBuffersIfNeeded()
        }
    }
}
