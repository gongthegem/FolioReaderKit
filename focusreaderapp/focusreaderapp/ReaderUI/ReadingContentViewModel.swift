import Foundation
import SwiftUI
import Combine

class ReadingContentViewModel: ObservableObject {
    private let contentProcessor = ContentProcessor.shared
    
    @Published var currentChapter: Chapter?
    @Published var processedChapter: ProcessedChapter?
    @Published var displayOptions: ContentDisplayOptions
    @Published var isLoading: Bool = false
    @Published var contentError: String? = nil
    @Published var currentSentenceIndex: Int = 0
    @Published var currentDisplayMode: ReaderDisplayMode = .standard
    @Published var totalSentences: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init(displayOptions: ContentDisplayOptions = ContentDisplayOptions()) {
        self.displayOptions = displayOptions
        LoggingService.shared.debug("Initializing ReadingContentViewModel with fontSize: \(displayOptions.fontSize)", category: .ui)
    }
    
    func loadChapter(chapter: Chapter, options: ContentDisplayOptions) {
        LoggingService.shared.debug("Loading chapter: \(chapter.title)", category: .ui)
        
        isLoading = true
        contentError = nil
        currentChapter = chapter
        displayOptions = options
        
        // Verify chapter content
        if chapter.htmlContent.isEmpty {
            LoggingService.shared.error("Chapter HTML content is empty: \(chapter.title)", category: .contentProcessing)
            contentError = "Chapter content is missing. Please try another chapter or reload the book."
            
            // Create a dummy HTML with an error message
            let errorHTML = "<div style='padding: 20px; text-align: center;'><h3>Content appears to be missing</h3><p>Please try reloading the book or selecting another chapter.</p></div>"
            
            let processedContent = HTMLRenderer.shared.wrapContentInHTML(
                content: errorHTML, 
                options: options
            )
            
            let emptyChapter = ProcessedChapter(
                originalChapter: chapter,
                processedTextContent: chapter.plainTextContent,
                processedHTMLContent: processedContent
            )
            
            processedChapter = emptyChapter
            isLoading = false
            return
        }
        
        // Process the chapter asynchronously to avoid UI freezes
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            LoggingService.shared.debug("Processing chapter: \(chapter.title)", category: .contentProcessing)
            LoggingService.shared.debug("HTML content length: \(chapter.htmlContent.count)", category: .contentProcessing)
            LoggingService.shared.debug("Plain text content length: \(chapter.plainTextContent.count)", category: .contentProcessing)
            
            // Start performance measurement
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Process the chapter
            let processor = ContentProcessor.shared
            let processedChapter = processor.processChapter(
                chapter: chapter,
                fontSize: options.fontSize
            )
            
            // Calculate processing time
            let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            LoggingService.shared.logPerformance(
                operation: "Chapter processing",
                timeInMilliseconds: processingTime,
                metadata: ["chapterTitle": chapter.title, "contentLength": chapter.htmlContent.count]
            )
            
            // Simulate total sentences calculation
            // In a real app, this would be calculated based on the actual text
            let estimatedSentences = max(1, chapter.plainTextContent.count / 100)
            
            DispatchQueue.main.async {
                LoggingService.shared.debug("Chapter loaded: \(chapter.title) - HTML length: \(processedChapter.processedHTMLContent.count)", category: .contentProcessing)
                self.processedChapter = processedChapter
                self.totalSentences = estimatedSentences
                self.isLoading = false
                self.objectWillChange.send()
            }
        }
    }
    
    func updateDisplayOptions(options: ContentDisplayOptions) {
        LoggingService.shared.debug("Updating display options - fontSize: \(options.fontSize)", category: .ui)
        displayOptions = options
        
        // Regenerate HTML content if needed
        if let chapter = currentChapter {
            isLoading = true
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                let processed = self.contentProcessor.processChapter(
                    chapter: chapter,
                    fontSize: options.fontSize
                )
                
                DispatchQueue.main.async {
                    self.processedChapter = processed
                    self.isLoading = false
                }
            }
        }
    }
    
    func setDisplayMode(_ mode: ReaderDisplayMode) {
        LoggingService.shared.debug("Setting display mode to: \(mode.rawValue)", category: .ui)
        currentDisplayMode = mode
        objectWillChange.send()
    }
    
    func moveToSentence(index: Int) {
        LoggingService.shared.debug("Moving to sentence at index: \(index)", category: .ui)
        currentSentenceIndex = index
        objectWillChange.send()
    }
    
    func moveToPreviousSentence() {
        if currentSentenceIndex > 0 {
            currentSentenceIndex -= 1
            LoggingService.shared.debug("Moving to previous sentence: \(self.currentSentenceIndex)", category: .ui)
            objectWillChange.send()
        }
    }
    
    func moveToNextSentence() {
        if currentSentenceIndex < totalSentences - 1 {
            currentSentenceIndex += 1
            LoggingService.shared.debug("Moving to next sentence: \(self.currentSentenceIndex)", category: .ui)
            objectWillChange.send()
        }
    }
    
    func generateHTMLForCurrentSentence(sentenceIndex: Int) -> String {
        guard let processedChapter = processedChapter else {
            LoggingService.shared.warning("Cannot generate HTML for sentence; no processed chapter available", category: .contentProcessing)
            return ""
        }
        
        // TODO: Implement sentence extraction logic here
        
        // For now, just return the full HTML content
        return processedChapter.processedHTMLContent
    }
    
    func reloadCurrentChapter() {
        if let chapter = currentChapter {
            loadChapter(chapter: chapter, options: displayOptions)
        }
    }
    
    func sentenceAtIndex(index: Int) -> String? {
        guard processedChapter != nil else {
            LoggingService.shared.warning("Cannot get sentence; no processed chapter available", category: .contentProcessing)
            return nil
        }
        
        // For simplicity, we'll just return a placeholder string
        // In a real implementation, you'd extract the actual sentence
        // from the processed chapter's text content
        return "Sentence at index \(index)"
    }
} 