import Foundation
import SwiftUI
import Combine

class BookViewModel: ObservableObject {
    private let epubService: EPUBService
    private let progressManager: ReadingProgressManager
    
    @Published var currentBook: Book?
    @Published var library: [Book] = []
    @Published var currentChapterIndex: Int = 0
    @Published var settings: ReaderSettings
    @Published var speedReadingMode: SpeedReaderMode?
    @Published var currentChapterContent: ProcessedChapter?
    @Published var isLoading: Bool = false
    
    // For loading epub
    @Published var loadingError: String?
    
    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()
    
    init(epubService: EPUBService, progressManager: ReadingProgressManager, settings: ReaderSettings = ReaderSettings()) {
        self.epubService = epubService
        self.progressManager = progressManager
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
        
        // Create a local copy of the file first
        do {
            let documentsDirectory = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            let destinationURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
            
            // Only copy if it doesn't already exist
            if !fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.copyItem(at: url, to: destinationURL)
            }
            
            // Parse the book
            if let book = epubService.parseEPUB(at: destinationURL) {
                // Add to library if not already there
                if !library.contains(where: { $0.filePath == book.filePath }) {
                    library.append(book)
                    saveLibrary()
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
        isLoading = true  // Set loading state at start of book loading
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
        
        currentChapterIndex = index
        let chapter = book.chapters[index]
        
        // Process the chapter
        let processedChapter = ContentProcessor.shared.processChapter(
            chapter: chapter,
            fontSize: settings.fontSize
        )
        
        currentChapterContent = processedChapter
        
        // If there's a last position, we'll need to highlight that sentence
        if let position = book.lastReadPosition, position.chapterIndex == index {
            // The reading content view will handle highlighting the sentence
        }
        
        isLoading = false
    }
    
    func navigateToChapter(index: Int) {
        loadChapter(at: index)
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
    
    // MARK: - Reading Position
    
    func saveReadingPosition(chapterIndex: Int, sentenceIndex: Int) {
        guard var book = currentBook else { return }
        
        let position = ReadingPosition(
            chapterIndex: chapterIndex,
            sentenceIndex: sentenceIndex,
            lastReadDate: Date()
        )
        
        book.lastReadPosition = position
        currentBook = book
        
        // Update the book in the library
        if let index = library.firstIndex(where: { $0.id == book.id }) {
            library[index] = book
        }
        
        // Save the progress
        progressManager.saveProgress(bookId: book.id.uuidString, position: position)
        
        // Save library
        saveLibrary()
    }
    
    // MARK: - Library Management
    
    func loadLibrary() {
        guard let libraryData = UserDefaults.standard.data(forKey: "library") else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let loadedLibrary = try decoder.decode([String: Book].self, from: libraryData)
            library = Array(loadedLibrary.values)
        } catch {
            print("Error loading library: \(error)")
        }
    }
    
    func saveLibrary() {
        do {
            var libraryDict = [String: Book]()
            
            for book in library {
                libraryDict[book.id.uuidString] = book
            }
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(libraryDict)
            UserDefaults.standard.set(data, forKey: "library")
        } catch {
            print("Error saving library: \(error)")
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
        isLoading = true  // Set loading state at the start of sample book loading
        
        // Check if the sample book is already in the library
        if library.contains(where: { $0.title.contains("Sample") }) {
            print("Sample book already in library, loading it")
            // Sample is already loaded, just find and open it
            if let sampleBook = library.first(where: { $0.title.contains("Sample") }) {
                loadBook(sampleBook)
            } else {
                isLoading = false // Reset loading state if sample book found but couldn't be loaded
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
            isLoading = false // Reset loading state if sample book couldn't be found
        }
    }
} 