import Foundation
import SwiftUI
import Combine

class BookViewModel: ObservableObject {
    private let epubService: EPUBService
    private let progressManager: ReadingProgressManager
    private let bookStorage: BookStorageService
    
    @Published var currentBook: Book?
    @Published var library: [Book] = []
    @Published var currentChapterIndex: Int = 0
    @Published var settings: ReaderSettings
    @Published var currentChapterContent: ProcessedChapter?
    @Published var isLoading: Bool = false
    
    // For loading epub
    @Published var loadingError: String?
    
    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()
    
    init(epubService: EPUBService, progressManager: ReadingProgressManager, bookStorage: BookStorageService, settings: ReaderSettings = ReaderSettings()) {
        self.epubService = epubService
        self.progressManager = progressManager
        self.bookStorage = bookStorage
        self.settings = settings
        
        // Load saved settings
        settings.load()
        
        // Observe settings changes
        settings.$fontSize
            .sink { [weak self] _ in
                self?.refreshCurrentChapter()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - EPUB Loading
    
    func loadEPUB(from url: URL) {
        isLoading = true
        loadingError = nil
        
        do {
            // Parse the book
            if let book = epubService.parseEPUB(at: url) {
                // Save to book storage if not already there
                if !bookStorage.hasExtractedBook(id: book.id.uuidString) {
                    try bookStorage.saveExtractedBook(from: url, withId: book.id.uuidString)
                    try bookStorage.saveBookMetadata(book)
                }
                
                // Add to library if not already there
                if !library.contains(where: { $0.id == book.id }) {
                    library.append(book)
                }
                
                // Load the book
                loadBook(book)
            } else {
                loadingError = "Failed to parse EPUB file"
                isLoading = false
            }
        } catch {
            loadingError = "Error loading EPUB: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func loadBook(_ book: Book) {
        currentBook = book
        
        // Load the last reading position
        if let position = book.lastReadPosition {
            currentChapterIndex = position.chapterIndex
            
            // Update reading progress
            progressManager.updateLastReadDate(bookId: book.id.uuidString)
        } else {
            currentChapterIndex = 0
        }
        
        // Load the current chapter
        loadChapter(at: currentChapterIndex)
    }
    
    // MARK: - Chapter Navigation
    
    func loadChapter(at index: Int) {
        guard let book = currentBook, index >= 0, index < book.chapters.count else {
            return
        }
        
        // Save current chapter position before switching
        if let currentSentenceIndex = currentChapterContent?.sentences.count ?? 0 > 0 ? 
            getCurrentSentenceIndex() : nil {
            updateChapterPosition(currentChapterIndex, sentenceIndex: currentSentenceIndex)
        }
        
        currentChapterIndex = index
        let chapter = book.chapters[index]
        
        // Process the chapter
        let processedChapter = ContentProcessor.shared.processChapter(
            chapter: chapter,
            fontSize: settings.fontSize
        )
        
        currentChapterContent = processedChapter
        
        // If there's a saved position for this chapter, restore it
        if let position = book.lastReadPosition {
            let sentenceIndex = position.sentenceIndexForChapter(index)
            
            // Update the reading content view
            NotificationCenter.default.post(
                name: Notification.Name("RestoreSentencePosition"),
                object: nil,
                userInfo: ["sentenceIndex": sentenceIndex]
            )
        }
        
        isLoading = false
    }
    
    func navigateToChapter(index: Int) {
        loadChapter(at: index)
    }
    
    // Helper to get current sentence index from reader
    private func getCurrentSentenceIndex() -> Int {
        // Try to get from notification center or other means
        // This is a placeholder - implement based on how your app tracks the current sentence
        if let book = currentBook, let position = book.lastReadPosition, 
           position.chapterIndex == currentChapterIndex {
            return position.sentenceIndex
        }
        return 0
    }
    
    // MARK: - Reading Position
    
    func saveReadingPosition(chapterIndex: Int, sentenceIndex: Int, displayMode: ReaderDisplayMode) {
        updateChapterPosition(chapterIndex, sentenceIndex: sentenceIndex, displayMode: displayMode)
    }
    
    private func updateChapterPosition(_ chapter: Int, sentenceIndex: Int, displayMode: ReaderDisplayMode? = nil) {
        guard var book = currentBook else { return }
        
        // If we don't have a position yet, create one
        if book.lastReadPosition == nil {
            book.lastReadPosition = ReadingPosition(
                chapterIndex: chapter,
                sentenceIndex: sentenceIndex,
                displayMode: displayMode
            )
        } else {
            // Update the existing position
            var position = book.lastReadPosition!
            position.updateChapterPosition(chapter: chapter, sentence: sentenceIndex)
            position.displayMode = displayMode
            book.lastReadPosition = position
        }
        
        // Update in memory
        currentBook = book
        
        // Update in library
        if let index = library.firstIndex(where: { $0.id == book.id }) {
            library[index] = book
            
            // Save updated book metadata
            try? bookStorage.saveBookMetadata(book)
        }
        
        // Save to progress manager
        if let position = book.lastReadPosition {
            progressManager.saveProgress(bookId: book.id.uuidString, position: position)
        }
    }
    
    func navigateToNextChapter() {
        guard let book = currentBook else { return }
        let nextIndex = currentChapterIndex + 1
        
        if nextIndex < book.chapters.count {
            navigateToChapter(index: nextIndex)
        }
    }
    
    func navigateToPreviousChapter() {
        let prevIndex = currentChapterIndex - 1
        
        if prevIndex >= 0 {
            navigateToChapter(index: prevIndex)
        }
    }
    
    // MARK: - Library Management
    
    func exitToLibrary() {
        // Save current reading position if needed
        if let currentSentenceIndex = currentChapterContent?.sentences.count ?? 0 > 0 ? 
            getCurrentSentenceIndex() : nil {
            saveReadingPosition(chapterIndex: currentChapterIndex, sentenceIndex: currentSentenceIndex, displayMode: .standard)
        }
        
        // Clear current book to return to library view
        self.currentBook = nil
    }
    
    func loadLibrary() {
        // Load books from storage service
        library = bookStorage.getAllSavedBooks()
        
        // If no books loaded from storage, try legacy method
        if library.isEmpty {
            loadLegacyLibrary()
        }
    }
    
    private func loadLegacyLibrary() {
        guard let libraryData = UserDefaults.standard.data(forKey: "library") else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let loadedLibrary = try decoder.decode([String: Book].self, from: libraryData)
            library = Array(loadedLibrary.values)
            
            // Migrate to new storage
            for book in library {
                try? bookStorage.saveBookMetadata(book)
            }
        } catch {
            print("Error loading legacy library: \(error)")
        }
    }
    
    func saveLibrary() {
        // Save each book to storage
        for book in library {
            try? bookStorage.saveBookMetadata(book)
        }
    }
    
    // MARK: - Other Utilities
    
    private func refreshCurrentChapter() {
        if let currentBook = currentBook {
            loadChapter(at: currentChapterIndex)
        }
    }
    
    func removeBook(at indexSet: IndexSet) {
        for index in indexSet {
            let book = library[index]
            
            // If this book is currently open, close it
            if currentBook?.id == book.id {
                currentBook = nil
            }
            
            // Try to delete the file
            if let url = URL(string: book.filePath) {
                try? fileManager.removeItem(at: url)
            }
        }
        
        // Remove from library
        library.remove(atOffsets: indexSet)
        saveLibrary()
    }
    
    // MARK: - Sample Book Loading
    
    func loadSampleBook() {
        print("Loading sample book...")
        
        // Check if the sample book is already in the library
        if library.contains(where: { $0.title.contains("Sample") }) {
            print("Sample book already in library, loading it")
            // Sample is already loaded, just find and open it
            if let sampleBook = library.first(where: { $0.title.contains("Sample") }) {
                loadBook(sampleBook)
            }
            return
        }
        
        // First try to get the URL to the embedded sample.epub in the bundle
        if let sampleURL = Bundle.main.url(forResource: "sample", withExtension: "epub") {
            print("Found sample.epub in bundle at \(sampleURL.path)")
            // Load the EPUB file
            loadEPUB(from: sampleURL)
            return
        } else {
            print("sample.epub not found in bundle resources")
        }
        
        // If not found in bundle, try the app source directory
        let appSourceURL = URL(fileURLWithPath: Bundle.main.bundlePath)
            .deletingLastPathComponent()
            .appendingPathComponent("focusreaderapp")
            .appendingPathComponent("sample.epub")
        
        print("Checking for sample.epub at \(appSourceURL.path)")
        if FileManager.default.fileExists(atPath: appSourceURL.path) {
            print("Found sample.epub in app source directory")
            // Load the EPUB file from the source directory
            loadEPUB(from: appSourceURL)
            return
        }
        
        // Try one more fallback location - the workspace root
        let workspaceURL = URL(fileURLWithPath: Bundle.main.bundlePath)
            .deletingLastPathComponent()
            .appendingPathComponent("sample.epub")
        
        print("Checking for sample.epub at \(workspaceURL.path)")
        if FileManager.default.fileExists(atPath: workspaceURL.path) {
            print("Found sample.epub in workspace root")
            loadEPUB(from: workspaceURL)
            return
        }
        
        // Try the Resources directory
        let resourcesURL = URL(fileURLWithPath: Bundle.main.bundlePath)
            .deletingLastPathComponent()
            .appendingPathComponent("focusreaderapp")
            .appendingPathComponent("Resources")
            .appendingPathComponent("sample.epub")
        
        print("Checking for sample.epub at \(resourcesURL.path)")
        if FileManager.default.fileExists(atPath: resourcesURL.path) {
            print("Found sample.epub in Resources directory")
            loadEPUB(from: resourcesURL)
        } else {
            print("Could not find sample.epub at any location")
        }
    }
} 