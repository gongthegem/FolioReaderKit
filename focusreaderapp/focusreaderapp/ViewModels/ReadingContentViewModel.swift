import Foundation
import SwiftUI
import Combine

class ReadingContentViewModel: ObservableObject {
    private let contentProcessor = ContentProcessor.shared
    
    @Published var currentChapter: Chapter?
    @Published var processedChapter: ProcessedChapter?
    @Published var displayOptions: ContentDisplayOptions
    @Published var currentSentenceIndex: Int = 0
    @Published var isLoading: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init(displayOptions: ContentDisplayOptions = ContentDisplayOptions()) {
        self.displayOptions = displayOptions
    }
    
    func loadChapter(chapter: Chapter, options: ContentDisplayOptions) {
        isLoading = true
        currentChapter = chapter
        displayOptions = options
        
        // Process the chapter
        let processed = contentProcessor.processChapter(
            chapter: chapter,
            fontSize: options.fontSize
        )
        
        processedChapter = processed
        isLoading = false
    }
    
    func updateDisplayOptions(options: ContentDisplayOptions) {
        displayOptions = options
        
        // Regenerate HTML content if needed
        if let chapter = currentChapter {
            let processed = contentProcessor.processChapter(
                chapter: chapter,
                fontSize: options.fontSize
            )
            processedChapter = processed
        }
    }
    
    func generateHTMLForCurrentSentence(sentenceIndex: Int) -> String {
        guard let processedChapter = processedChapter else {
            return ""
        }
        
        currentSentenceIndex = sentenceIndex
        
        var options = displayOptions
        options.highlightedSentenceIndex = sentenceIndex
        
        // Generate HTML with highlighted sentence
        var html = processedChapter.processedHTMLContent
        html = HTMLRenderer.shared.highlightSentenceInHTML(
            html: html,
            sentenceIndex: sentenceIndex,
            sentences: processedChapter.sentences,
            options: options
        )
        
        return html
    }
    
    func sentenceAtIndex(index: Int) -> String? {
        return processedChapter?.sentences[safe: index]
    }
    
    func blockForSentence(at index: Int) -> ChapterBlock? {
        guard let processedChapter = processedChapter,
              index >= 0, index < processedChapter.sentences.count else {
            return nil
        }
        
        let sentence = processedChapter.sentences[index]
        
        // Find the block that contains this sentence
        for block in processedChapter.originalChapter.blocks {
            if let textContent = block.textContent, textContent.contains(sentence) {
                return block
            }
        }
        
        return nil
    }
    
    func moveToNextSentence() -> Bool {
        guard let processedChapter = processedChapter else { return false }
        
        let nextIndex = currentSentenceIndex + 1
        if nextIndex < processedChapter.sentences.count {
            currentSentenceIndex = nextIndex
            return true
        }
        return false
    }
    
    func moveToPreviousSentence() -> Bool {
        let prevIndex = currentSentenceIndex - 1
        if prevIndex >= 0 {
            currentSentenceIndex = prevIndex
            return true
        }
        return false
    }
    
    func moveToSentence(index: Int) -> Bool {
        guard let processedChapter = processedChapter,
              index >= 0, index < processedChapter.sentences.count else {
            return false
        }
        
        currentSentenceIndex = index
        return true
    }
    
    // Helper method to get the total number of sentences in the current chapter
    var totalSentences: Int {
        return processedChapter?.sentences.count ?? 0
    }
} 