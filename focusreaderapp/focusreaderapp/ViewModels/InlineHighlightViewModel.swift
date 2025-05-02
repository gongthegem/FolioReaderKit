import Foundation
import SwiftUI
import Combine

class InlineHighlightViewModel: ObservableObject {
    private let progressManager: ReadingProgressManager?
    private let readingContentVM: ReadingContentViewModel
    
    @Published var bookId: String?
    @Published var currentSentenceIndex: Int = 0
    @Published var currentChapterIndex: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init(progressManager: ReadingProgressManager? = nil, readingContentVM: ReadingContentViewModel) {
        self.progressManager = progressManager
        self.readingContentVM = readingContentVM
        
        // Observe reading content view model changes
        self.readingContentVM.$currentSentenceIndex
            .sink { [weak self] index in
                self?.currentSentenceIndex = index
            }
            .store(in: &cancellables)
    }
    
    func configure(with bookId: String, chapterIndex: Int, initialSentenceIndex: Int = 0) {
        self.bookId = bookId
        self.currentChapterIndex = chapterIndex
        
        // Set the initial sentence index
        readingContentVM.moveToSentence(index: initialSentenceIndex)
    }
    
    func moveToNextSentence() {
        readingContentVM.moveToNextSentence()
    }
    
    func moveToPreviousSentence() {
        readingContentVM.moveToPreviousSentence()
    }
    
    func saveProgress() {
        guard let bookId = bookId else { return }
        
        // Save progress using ReadingProgressManager
        if let progressManager = progressManager {
            // Create a reading position and save it
            let position = ReadingPosition(
                chapterIndex: currentChapterIndex,
                sentenceIndex: currentSentenceIndex
            )
            progressManager.saveProgress(bookId: bookId, position: position)
        }
    }
} 