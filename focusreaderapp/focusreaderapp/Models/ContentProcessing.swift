import Foundation
import SwiftUI

struct ContentDisplayOptions {
    var fontSize: CGFloat
    var lineSpacing: CGFloat
    var horizontalPadding: CGFloat
    var highlightedSentenceIndex: Int?
    var highlightColor: Color?
    var highlightMode: HighlightMode?
    var baseURL: URL?
    var darkMode: Bool
    
    init(
        fontSize: CGFloat = 16,
        lineSpacing: CGFloat = 1.5,
        horizontalPadding: CGFloat = 20,
        highlightedSentenceIndex: Int? = nil,
        highlightColor: Color? = .yellow,
        highlightMode: HighlightMode? = HighlightMode.none,
        baseURL: URL? = nil,
        darkMode: Bool = false
    ) {
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.horizontalPadding = horizontalPadding
        self.highlightedSentenceIndex = highlightedSentenceIndex
        self.highlightColor = highlightColor
        self.highlightMode = highlightMode
        self.baseURL = baseURL
        self.darkMode = darkMode
    }
}

struct ProcessedChapter {
    var originalChapter: Chapter
    var processedTextContent: String
    var sentences: [String]
    var sentenceRanges: [Range<String.Index>]
    var attributedSentences: [NSAttributedString]?
    var processedHTMLContent: String
    
    init(
        originalChapter: Chapter,
        processedTextContent: String,
        sentences: [String] = [],
        sentenceRanges: [Range<String.Index>] = [],
        attributedSentences: [NSAttributedString]? = nil,
        processedHTMLContent: String = ""
    ) {
        self.originalChapter = originalChapter
        self.processedTextContent = processedTextContent
        self.sentences = sentences
        self.sentenceRanges = sentenceRanges
        self.attributedSentences = attributedSentences
        self.processedHTMLContent = processedHTMLContent
    }
} 