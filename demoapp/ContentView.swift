import SwiftUI
import AVFoundation
import Speech
import WhisperKit
import CoreAudio

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var transcribedText = ""
    @State private var showRecordedFiles = false
    @State private var savedRecordings: [RecordingFile] = []
    
    var body: some View {
        HStack(spacing: 0) {
            VStack {
                Text("Meeting Transcriber").font(.title).padding()
                audioManager.audioPermissionGranted {
                    Text("Microphone access is required").foregroundColor(.red).padding()
                    Button("Request Permission") {audioManager.checkPermissions()}.buttonStyle(.borderedProminent).padding()
                } else {
                    Picker("Select Source", selection: $audioManager.selectedMicrophone) {ForEach(audioManager.availableMicrophones, id: \.uniqueID) { device in Text(device.localizedName).tag(device as AVCaptureDevice?)}}.padding()
                    Button(audioManager.isRecording ? "Stop Meeting" : "Start Meeting") {
                        if audioManager.isRecording {
                            audioManager.stopRecording()
                            if !transcribedText.isEmpty {saveCurrentRecording()}
                        } else {
                            showRecordedFiles = false
                            transcribedText = ""
                            audioManager.startRecording()
                        }
                    }.buttonStyle(.borderedProminent).foregroundColor(.white).background(audioManager.isRecording ? Color.red : Color.green).cornerRadius(8).padding()
                    Button(showRecordedFiles ? "Show Live Transcription" : "Show Saved Recordings") {
                        showRecordedFiles.toggle()
                        if showRecordedFiles {
                            loadSavedRecordings()
                        }
                    }.buttonStyle(.bordered).padding()
                }
                Spacer()
            }.frame(width: 300).background(Color(.darkGray))
            if showRecordedFiles {
                VStack {
                    Text("Recorded Transcriptions").font(.title).padding()
                    List {
                        ForEach(savedRecordings) { recording in
                            VStack(alignment: .leading) {
                                Text(recording.date).font(.headline)
                                Text(recording.preview).font(.subheadline).lineLimit(2)
                            }.padding(.vertical, 4).onTapGesture {transcribedText = recording.fullText showRecordedFiles = false}
                        }
                    }
                }.background(Color.black)
            } else {
                VStack {
                    Text("Transcription").font(.title).padding()
                    ScrollView {Text(transcribedText.isEmpty ? "Recorded transcriptions will be here" : transcribedText).padding().frame(maxWidth: .infinity, alignment: .leading)}
                    HStack {
                        Button("Copy") {
                            #if os(macOS)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(transcribedText, forType: .string)
                            #else
                                UIPasteboard.general.string = transcribedText
                            #endif
                        }.disabled(transcribedText.isEmpty).buttonStyle(.bordered).padding()
                        
                        Button("Clear") {transcribedText = ""}.disabled(transcribedText.isEmpty).buttonStyle(.bordered).padding()

                        Button("Save") {saveTranscription()}.disabled(transcribedText.isEmpty).buttonStyle(.bordered).padding()
                    }
                }.background(Color.white)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TranscriptionUpdated"))) { notification in
            if let text = notification.object as? String {self.transcribedText = text}
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
            // TODO: iOS/iPadOS implementation would use UIDocumentPickerViewController
        #endif
    }
    
    func saveCurrentRecording() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateString = formatter.string(from: Date())
        
        let recording = RecordingFile(
            id: UUID(),
            date: dateString,
            preview: String(transcribedText.prefix(100)) + (transcribedText.count > 100 ? "..." : ""),
            fullText: transcribedText
        )

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
        let recordings = try? JSONDecoder().decode([RecordingFile].self, from: savedData) {return recordings}
        return []
    }
}

struct RecordingFile: Identifiable, Codable {
    var id: UUID
    var date: String
    var preview: String
    var fullText: String
}

#Preview {ContentView()}