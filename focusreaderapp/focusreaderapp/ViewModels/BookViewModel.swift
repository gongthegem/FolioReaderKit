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
        
        print("\n======== Starting EPUB loading process ========")
        print("Loading EPUB from: \(url.path)")
        
        do {
            // Check if the file exists
            guard fileManager.fileExists(atPath: url.path) else {
                print("❌ EPUB file does not exist at path: \(url.path)")
                loadingError = "File not found at \(url.path)"
                isLoading = false
                return
            }
            
            // Get file size
            if let fileAttributes = try? fileManager.attributesOfItem(atPath: url.path),
               let fileSize = fileAttributes[.size] as? Int {
                print("EPUB file size: \(fileSize) bytes")
            }
            
            print("Parsing EPUB using epubService...")
            if let book = epubService.parseEPUB(at: url) {
                print("\n======== EPUB parsing success ========")
                print("Successfully parsed EPUB:")
                print("- Title: \(book.title)")
                print("- Author: \(book.author)")
                print("- Chapters: \(book.chapters.count)")
                print("- File path: \(book.filePath)")
                
                if book.chapters.isEmpty {
                    print("⚠️ WARNING: Book has 0 chapters!")
                } else {
                    print("Chapter titles:")
                    for (index, chapter) in book.chapters.enumerated() {
                        print("- Chapter \(index+1): \(chapter.title) (HTML: \(chapter.htmlContent.count) bytes, Plain: \(chapter.plainTextContent.count) bytes)")
                    }
                }
                
                // Save to book storage if not already there
                if !bookStorage.hasExtractedBook(id: book.id.uuidString) {
                    print("Saving book to storage with ID \(book.id.uuidString)")
                    try bookStorage.saveExtractedBook(from: url, withId: book.id.uuidString)
                    try bookStorage.saveBookMetadata(book)
                    print("✅ Book saved to storage successfully")
                } else {
                    print("Book already exists in storage with ID \(book.id.uuidString)")
                }
                
                // Add to library if not already there
                if !library.contains(where: { $0.id == book.id }) {
                    library.append(book)
                    print("✅ Added book to library (library now has \(library.count) books)")
                } else {
                    print("Book already in library")
                }
                
                // Load the book
                print("Loading book into reader...")
                loadBook(book)
            } else {
                print("❌ Failed to parse EPUB file")
                loadingError = "Failed to parse EPUB file"
                isLoading = false
            }
        } catch {
            print("❌ Error loading EPUB: \(error.localizedDescription)")
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
        guard let book = currentBook else {
            print("❌ Cannot load chapter: No current book")
            return
        }
        
        guard index >= 0 else {
            print("❌ Cannot load chapter: Invalid index \(index) (less than 0)")
            return
        }
        
        guard index < book.chapters.count else {
            print("❌ Cannot load chapter: Invalid index \(index) (book has \(book.chapters.count) chapters)")
            return
        }
        
        print("\n======== Loading chapter at index \(index) ========")
        print("Book: \(book.title)")
        print("Total chapters: \(book.chapters.count)")
        print("Current chapter index: \(index)")
        
        // Save current chapter position before switching
        if let currentSentenceIndex = currentChapterContent?.sentences.count ?? 0 > 0 ? 
            getCurrentSentenceIndex() : nil {
            print("Saving current reading position at chapter \(currentChapterIndex), sentence \(currentSentenceIndex)")
            updateChapterPosition(currentChapterIndex, sentenceIndex: currentSentenceIndex)
        }
        
        currentChapterIndex = index
        let chapter = book.chapters[index]
        
        print("\nProcessing chapter:")
        print("- Title: \(chapter.title)")
        print("- ID: \(chapter.id)")
        print("- HTML content length: \(chapter.htmlContent.count) bytes")
        print("- Plain text length: \(chapter.plainTextContent.count) bytes")
        print("- Images: \(chapter.images.count)")
        
        if chapter.htmlContent.isEmpty {
            print("⚠️ WARNING: Chapter has empty HTML content!")
            print("First 100 characters of HTML: \(chapter.htmlContent.prefix(100))")
        }
        
        // Process the chapter
        print("\nProcessing chapter with ContentProcessor...")
        let processedChapter = ContentProcessor.shared.processChapter(
            chapter: chapter,
            fontSize: settings.fontSize
        )
        
        print("Chapter processed:")
        print("- Sentences: \(processedChapter.sentences.count)")
        print("- Processed HTML length: \(processedChapter.processedHTMLContent.count) bytes")
        
        if processedChapter.sentences.isEmpty {
            print("⚠️ WARNING: Processed chapter has 0 sentences!")
        } else {
            print("First sentence: \(processedChapter.sentences.first?.prefix(50) ?? "")")
        }
        
        currentChapterContent = processedChapter
        
        // If there's a saved position for this chapter, restore it
        if let position = book.lastReadPosition {
            let sentenceIndex = position.sentenceIndexForChapter(index)
            print("Restoring reading position to sentence \(sentenceIndex)")
            
            // Update the reading content view
            NotificationCenter.default.post(
                name: Notification.Name("RestoreSentencePosition"),
                object: nil,
                userInfo: ["sentenceIndex": sentenceIndex]
            )
        }
        
        print("✅ Chapter loading complete")
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
        print("\n======== Loading sample book ========")
        
        // Check if the sample book is already in the library
        if library.contains(where: { $0.title.contains("Sample") }) {
            print("Sample book already in library, loading it")
            // Sample is already loaded, just find and open it
            if let sampleBook = library.first(where: { $0.title.contains("Sample") }) {
                loadBook(sampleBook)
            }
            return
        }
        
        // First try to get the URL to the embedded sample.epub in the main bundle
        if let sampleURL = Bundle.main.url(forResource: "sample", withExtension: "epub") {
            print("Found sample.epub in main bundle at \(sampleURL.path)")
            // Load the EPUB file
            loadEPUB(from: sampleURL)
            return
        } else {
            print("sample.epub not found in main bundle resources")
        }
        
        // Try looking in the app's Resources directory
        let resourcesURL = Bundle.main.resourceURL?.appendingPathComponent("Resources/sample.epub")
        if let resourcesURL = resourcesURL, fileManager.fileExists(atPath: resourcesURL.path) {
            print("Found sample.epub in Resources directory at \(resourcesURL.path)")
            loadEPUB(from: resourcesURL)
            return
        } else if let resourcesURL = resourcesURL {
            print("sample.epub not found at expected Resources path: \(resourcesURL.path)")
        }
        
        // Look for the file in the project directory
        let sourceURL = URL(fileURLWithPath: Bundle.main.bundlePath)
            .deletingLastPathComponent()
            .appendingPathComponent("focusreaderapp/Resources/sample.epub")
        
        print("Checking for sample.epub at \(sourceURL.path)")
        if fileManager.fileExists(atPath: sourceURL.path) {
            print("Found sample.epub in project directory")
            loadEPUB(from: sourceURL)
            return
        }
        
        // Last resort: Search for the file in common locations
        print("Searching for sample.epub file...")
        
        let possibleLocations = [
            Bundle.main.bundlePath,
            Bundle.main.resourcePath,
            Bundle.main.bundlePath + "/Resources",
            Bundle.main.bundlePath + "/focusreaderapp/Resources",
            Bundle.main.bundlePath + "/../focusreaderapp/Resources",
            FileManager.default.currentDirectoryPath,
            FileManager.default.currentDirectoryPath + "/focusreaderapp/Resources"
        ].compactMap { $0 } // Filter out any nil paths
        
        for location in possibleLocations {
            let testPath = location + "/sample.epub"
            print("Testing path: \(testPath)")
            if fileManager.fileExists(atPath: testPath) {
                print("✅ Found sample.epub at: \(testPath)")
                loadEPUB(from: URL(fileURLWithPath: testPath))
                return
            }
        }
        
        print("❌ Could not find sample.epub file in any expected location")
        loadingError = "Could not find sample book file"
    }
} 