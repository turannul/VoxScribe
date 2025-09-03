//
//  RecordingFile.swift
//  VoxScribe
//
//  Created by Turann_ on 03.09.2025.
//

import Foundation

struct RecordingFile: Identifiable, Codable, Hashable {
    var id: UUID
    var date: String
    var preview: String
    var fullText: String
    var isStarred: Bool = false
    var languageCode: String?
    var audioURL: URL?
}
