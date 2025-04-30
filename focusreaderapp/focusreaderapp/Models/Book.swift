import Foundation
import SwiftUI

struct Book: Identifiable, Codable {
    var id: UUID
    var title: String
    var author: String
    var coverImagePath: String?
    var chapters: [Chapter]
    var metadata: BookMetadata
    var filePath: String
    var lastReadPosition: ReadingPosition?
    
    enum CodingKeys: String, CodingKey {
        case id, title, author, coverImagePath, metadata, filePath, lastReadPosition
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
    
    enum CodingKeys: String, CodingKey {
        case chapterIndex, sentenceIndex, scrollPositionX, scrollPositionY, lastReadDate
    }
    
    init(chapterIndex: Int, sentenceIndex: Int, scrollPosition: CGPoint? = nil, lastReadDate: Date = Date()) {
        self.chapterIndex = chapterIndex
        self.sentenceIndex = sentenceIndex
        self.scrollPosition = scrollPosition
        self.lastReadDate = lastReadDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chapterIndex = try container.decode(Int.self, forKey: .chapterIndex)
        sentenceIndex = try container.decode(Int.self, forKey: .sentenceIndex)
        lastReadDate = try container.decode(Date.self, forKey: .lastReadDate)
        
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
        
        if let position = scrollPosition {
            try container.encode(position.x, forKey: .scrollPositionX)
            try container.encode(position.y, forKey: .scrollPositionY)
        }
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