import Foundation
import SwiftUI

struct Book: Identifiable, Codable {
    var id: UUID
    var title: String
    var author: String
    var coverImagePath: String?
    var chapters: [Chapter] = []
    var metadata: BookMetadata
    var filePath: String
    var lastReadPosition: ReadingPosition?
    var tocItems: [TocItem] = []
    
    enum CodingKeys: String, CodingKey {
        case id, title, author, coverImagePath, metadata, filePath, lastReadPosition, tocItems
    }
    
    var coverImage: UIImage? {
        guard let coverPath = coverImagePath else { return nil }
        return UIImage(contentsOfFile: coverPath)
    }
}

struct BookMetadata: Codable {
    var publisher: String?
    var language: String?
    var identifier: String?
    var description: String?
    var subjects: [String]
    var rights: String?
    var source: String?
    var modified: String?
    var extraMetadata: [String: String]
    
    init(
        publisher: String? = nil,
        language: String? = nil,
        identifier: String? = nil,
        description: String? = nil,
        subjects: [String] = [],
        rights: String? = nil,
        source: String? = nil,
        modified: String? = nil,
        extraMetadata: [String: String] = [:]
    ) {
        self.publisher = publisher
        self.language = language
        self.identifier = identifier
        self.description = description
        self.subjects = subjects
        self.rights = rights
        self.source = source
        self.modified = modified
        self.extraMetadata = extraMetadata
    }
}

struct ReadingPosition: Codable {
    var chapterIndex: Int
    var sentenceIndex: Int
    var scrollPosition: CGPoint?
    var lastReadDate: Date
    var chapterPositions: [Int: Int] // [chapterIndex: sentenceIndex]
    var displayMode: ReaderDisplayMode?
    
    enum CodingKeys: String, CodingKey {
        case chapterIndex, sentenceIndex, scrollPositionX, scrollPositionY, lastReadDate, chapterPositions, displayMode
    }
    
    init(chapterIndex: Int, sentenceIndex: Int, scrollPosition: CGPoint? = nil, lastReadDate: Date = Date(), chapterPositions: [Int: Int] = [:], displayMode: ReaderDisplayMode? = nil) {
        self.chapterIndex = chapterIndex
        self.sentenceIndex = sentenceIndex
        self.scrollPosition = scrollPosition
        self.lastReadDate = lastReadDate
        self.chapterPositions = chapterPositions
        self.displayMode = displayMode
        
        // Store current position in the map as well
        var positions = chapterPositions
        positions[chapterIndex] = sentenceIndex
        self.chapterPositions = positions
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chapterIndex = try container.decode(Int.self, forKey: .chapterIndex)
        sentenceIndex = try container.decode(Int.self, forKey: .sentenceIndex)
        lastReadDate = try container.decode(Date.self, forKey: .lastReadDate)
        chapterPositions = try container.decodeIfPresent([Int: Int].self, forKey: .chapterPositions) ?? [:]
        displayMode = try container.decodeIfPresent(ReaderDisplayMode.self, forKey: .displayMode)
        
        if let x = try container.decodeIfPresent(CGFloat.self, forKey: .scrollPositionX),
           let y = try container.decodeIfPresent(CGFloat.self, forKey: .scrollPositionY) {
            scrollPosition = CGPoint(x: x, y: y)
        } else {
            scrollPosition = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(chapterIndex, forKey: .chapterIndex)
        try container.encode(sentenceIndex, forKey: .sentenceIndex)
        try container.encode(lastReadDate, forKey: .lastReadDate)
        try container.encode(chapterPositions, forKey: .chapterPositions)
        try container.encodeIfPresent(displayMode, forKey: .displayMode)
        
        if let position = scrollPosition {
            try container.encode(position.x, forKey: .scrollPositionX)
            try container.encode(position.y, forKey: .scrollPositionY)
        }
    }
    
    // Helper to update a specific chapter position
    mutating func updateChapterPosition(chapter: Int, sentence: Int) {
        chapterPositions[chapter] = sentence
        
        // If this is the current chapter, also update main position
        if chapter == chapterIndex {
            sentenceIndex = sentence
        }
        
        // Always update the date
        lastReadDate = Date()
    }
    
    // Helper to get a chapter's saved position
    func sentenceIndexForChapter(_ chapter: Int) -> Int {
        return chapterPositions[chapter] ?? 0
    }
}

enum ReaderMode: String, Codable {
    case standard
    case speedReading
}

enum SpeedReaderMode: String, Codable {
    case word
    case sentence
} 