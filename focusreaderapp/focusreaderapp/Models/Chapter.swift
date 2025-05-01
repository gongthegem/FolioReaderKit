import Foundation
import SwiftUI

struct Chapter: Identifiable, Codable {
    var id: String
    var title: String
    var htmlContent: String
    var plainTextContent: String
    var blocks: [ChapterBlock]
    var images: [ChapterImage]
    
    init(id: String, title: String, htmlContent: String, plainTextContent: String, blocks: [ChapterBlock] = [], images: [ChapterImage] = []) {
        self.id = id
        self.title = title
        self.htmlContent = htmlContent
        self.plainTextContent = plainTextContent
        self.blocks = blocks
        self.images = images
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, htmlContent, plainTextContent
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        htmlContent = try container.decode(String.self, forKey: .htmlContent)
        plainTextContent = try container.decode(String.self, forKey: .plainTextContent)
        blocks = []
        images = []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(htmlContent, forKey: .htmlContent)
        try container.encode(plainTextContent, forKey: .plainTextContent)
    }
}

enum ChapterBlock: Equatable {
    case text(String, TextBlockType)
    case image(ChapterImage)
    
    var isImageBlock: Bool {
        switch self {
        case .image: return true
        case .text: return false
        }
    }
    
    var textContent: String? {
        switch self {
        case .text(let content, _): return content
        case .image: return nil
        }
    }
    
    var image: ChapterImage? {
        switch self {
        case .image(let image): return image
        case .text: return nil
        }
    }
    
    var blockType: TextBlockType? {
        switch self {
        case .text(_, let type): return type
        case .image: return nil
        }
    }
}

struct ChapterImage: Equatable, Identifiable {
    var id: String
    var name: String
    var caption: String?
    var imagePath: String
    var altText: String?
    var sourceURL: URL?
    
    var image: UIImage? {
        return UIImage(contentsOfFile: imagePath)
    }
}

enum TextBlockType: String, Codable {
    case paragraph
    case heading1
    case heading2
    case heading3
    case heading4
    case heading5
    case heading6
    case blockquote
    case code
    case list
    case listItem
}

struct TocItem: Identifiable, Codable {
    var id: String
    var title: String
    var href: String?
    var level: Int
    var children: [TocItem]
    var chapterIndex: Int?
    
    init(id: String, title: String, href: String? = nil, level: Int = 0, children: [TocItem] = [], chapterIndex: Int? = nil) {
        self.id = id
        self.title = title
        self.href = href
        self.level = level
        self.children = children
        self.chapterIndex = chapterIndex
    }
}

enum MarginSide {
    case left
    case right
} 