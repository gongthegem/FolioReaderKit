```mermaid
classDiagram
    %% Book Reading Lifecycle Class Diagram - Improved Architecture
    
    class AppCoordinator {
        <<ObservableObject>>
        @Published currentFlow: AppFlow
        -viewFactory: ViewFactory
        +navigateToLibrary() void
        +navigateToReader(book: Book) void
        +navigateToSettings() void
        +navigateToImport() void
        +handleOpenURL(url: URL) void
        +handleDeepLink(url: URL) void
    }
    
    class ViewModelCoordinator {
        <<ObservableObject>>
        -serviceLocator: ServiceLocator
        -bookViewModel: BookViewModel
        -readingContentVM: ReadingContentViewModel
        -inlineHighlightVM: InlineHighlightViewModel?
        -speedReadingVM: SpeedReadingViewModel?
        +coordinateBookLoading(url: URL) void
        +coordinateChapterNavigation(bookId: String, chapterIndex: Int) void
        +coordinateReadingModeChange(mode: ReadingModeStrategy) void
        +coordinateProgressSaving(bookId: String, position: ReadingPosition) void
        +coordinateReadingFlowCompletion() void
    }
    
    class ServiceLocator {
        <<singleton>>
        +getBookViewModel() BookViewModel
        +getReadingContentViewModel() ReadingContentViewModel
        +getInlineHighlightViewModel() InlineHighlightViewModel
        +getSpeedReadingViewModel() SpeedReadingViewModel
        +getBookStorageService() BookStorageService
        +getProgressManager() ReadingProgressManager
        +getEPUBService() EPUBService
        +getContentProcessor() ContentProcessingService
        +getSettingsManager() SettingsManager
    }

    class BookViewModel {
        <<ObservableObject>>
        -coordinator: ViewModelCoordinator?
        -serviceLocator: ServiceLocator
        @Published currentBook: Book?
        @Published library: [Book]
        @Published currentChapterIndex: Int
        @Published settings: ReaderSettings
        @Published currentChapterContent: ProcessedChapter?
        @Published isLoading: Bool
        @Published loadingError: String?
        +loadEPUB(from: URL) void
        +loadBook(_ book: Book) void
        +loadChapter(at: Int) void
        +navigateToChapter(index: Int) void
        +navigateToNextChapter() void
        +navigateToPreviousChapter() void
        +saveReadingPosition(chapterIndex: Int, sentenceIndex: Int, displayMode: ReadingModeStrategy) void
    }

    class ReadingContentViewModel {
        <<ObservableObject>>
        -coordinator: ViewModelCoordinator?
        -serviceLocator: ServiceLocator
        @Published currentChapter: Chapter?
        @Published processedChapter: ProcessedChapter?
        @Published displayOptions: ContentDisplayOptions
        @Published currentSentenceIndex: Int
        @Published isLoading: Bool
        @Published readingMode: ReadingModeStrategy
        +loadChapter(chapter: Chapter, options: ContentDisplayOptions) void
        +updateDisplayOptions(options: ContentDisplayOptions) void
        +setReadingMode(_ mode: ReadingModeStrategy) void
        +generateHTMLForCurrentSentence(sentenceIndex: Int) String
        +sentenceAtIndex(index: Int) String?
        +moveToNextSentence() Bool
        +moveToPreviousSentence() Bool
        +moveToSentence(index: Int) Bool
        +totalSentences: Int <<computed>>
        +notifyProgressChanged() void
    }
    
    class InlineHighlightViewModel {
        <<ObservableObject>>
        -coordinator: ViewModelCoordinator?
        -serviceLocator: ServiceLocator
        @Published bookId: String?
        @Published currentSentenceIndex: Int
        @Published currentChapterIndex: Int
        +configure(with: String, chapterIndex: Int, initialSentenceIndex: Int) void
        +moveToNextSentence() void
        +moveToPreviousSentence() void
        +notifyProgressChanged() void
    }
    
    class SpeedReadingViewModel {
        <<ObservableObject>>
        -coordinator: ViewModelCoordinator?
        -serviceLocator: ServiceLocator
        @Published bookId: String?
        @Published isPlaying: Bool
        @Published wordsPerMinute: Int
        @Published currentSentenceIndex: Int
        @Published speedReadingMode: SpeedReaderMode
        @Published currentChapterIndex: Int
        -playbackTimer: Timer?
        +configure(with: String, chapterIndex: Int, initialSentenceIndex: Int) void
        +togglePlayback() void
        +goToNextSentence() void
        +goToPreviousSentence() void
        +adjustWPM(by: Int) void
        +notifyProgressChanged() void
    }

    class EPUBProcessingService {
        <<interface>>
        +processEPUB(url: URL, progressCallback: (Double) -> Void) -> Future<Book, Error>
        +extractContents(bookId: String, outputDirectory: URL) -> Future<Bool, Error>
    }
    
    class DefaultEPUBService {
        <<EPUBProcessingService>>
        -serviceFactory: EPUBServiceFactory
        -errorHandler: ErrorHandlingService
        -logger: LoggingService
        +parseEPUB(at: URL, progressCallback: (Double) -> Void) -> Future<Book, Error>
        +unzipToDirectory(from: URL, destination: URL) throws -> Future<Bool, Error>
    }
    
    class EPUBProcessingPipeline {
        <<interface>>
        +extract(epubURL: URL) -> Self
        +parseMetadata() -> Self
        +parseTOC() -> Self
        +parseSpine() -> Self
        +loadChapters() -> Self
        +loadImages() -> Self
        +build() -> Future<Book, Error>
    }

    class StorageCoordinator {
        <<singleton>>
        -bookStorage: BookStorageService
        -progressManager: ReadingProgressManager
        -cacheManager: CacheManagerService
        +saveBook(book: Book, extractSource: URL) -> Future<Void, Error>
        +loadBook(id: String) -> Future<Book?, Error>
        +getAllBooks() -> Future<[Book], Error>
        +saveReadingProgress(bookId: String, position: ReadingPosition) -> Future<Void, Error>
        +loadReadingProgress(bookId: String) -> Future<ReadingPosition?, Error>
        +cleanupUnusedResources() -> Future<Void, Error>
    }
    
    class BookStorageService {
        <<interface>>
        +hasExtractedBook(id: String) -> Future<Bool, Error>
        +getExtractedBookDirectory(id: String) -> URL
        +saveExtractedBook(from: URL, withId: String) -> Future<Void, Error>
        +getBookMetadata(id: String) -> Future<Book?, Error>
        +saveBookMetadata(_ book: Book) -> Future<Void, Error>
        +getAllSavedBooks() -> Future<[Book], Error>
        +deleteBook(id: String) -> Future<Void, Error>
    }

    class ReadingProgressManager {
        <<ObservableObject>>
        -storageService: KeyValueStorageService
        -encoder: DataEncoderService
        -decoder: DataDecoderService
        +saveProgress(bookId: String, position: ReadingPosition) -> Future<Void, Error>
        +loadProgress(bookId: String) -> Future<ReadingPosition?, Error>
        +updateLastReadDate(bookId: String) -> Future<Void, Error>
        +getRecentBooks() -> Future<[String], Error>
        +deleteProgress(bookId: String) -> Future<Void, Error>
    }

    class ContentProcessingService {
        <<interface>>
        +processChapter(chapter: Chapter, options: ContentDisplayOptions) ProcessedChapter
    }
    
    class DefaultContentProcessor {
        <<ContentProcessingService>>
        -sentenceProcessor: SentenceProcessingService
        -htmlProcessor: HTMLProcessingService
        -attributedContentFormatter: AttributedContentService
        +processChapter(chapter: Chapter, options: ContentDisplayOptions) ProcessedChapter
    }

    class ChapterCache {
        <<singleton>>
        -cache: NSCache<NSString, ProcessedChapter>
        -diskCache: DiskCacheService
        +getChapter(cacheKey: String) ProcessedChapter?
        +cacheChapter(_ chapter: ProcessedChapter, forKey: String) void
        +clearCache() void
        +evictLeastRecentlyUsed(count: Int) void
    }
    
    class SettingsManager {
        <<ObservableObject>>
        +settings: ReaderSettings
        +applySettings(to: ContentDisplayOptions) ContentDisplayOptions
        +getSpeedReadingSettings() SpeedReadingSettings
        +getInlineHighlightSettings() InlineHighlightSettings
    }

    class ReadingModeStrategy {
        <<interface>>
        +initializeMode(chapter: Chapter, options: ContentDisplayOptions) void
        +prepareForDisplay() DisplayConfiguration
        +handleNavigation(action: NavigationAction) Bool
        +getDisplayMode() DisplayMode
    }
    
    class StandardReadingStrategy {
        <<ReadingModeStrategy>>
    }
    
    class InlineHighlightStrategy {
        <<ReadingModeStrategy>>
    }
    
    class SpeedReadingStrategy {
        <<ReadingModeStrategy>>
    }

    class Book {
        <<struct>>
        +id: UUID
        +title: String
        +author: String
        +coverImagePath: String?
        +chapters: [Chapter]
        +metadata: BookMetadata
        +filePath: String
        +lastReadPosition: ReadingPosition?
        +tocItems: [TocItem]
    }

    class Chapter {
        <<struct>>
        +id: String
        +title: String
        +htmlContent: String
        +plainTextContent: String
        +blocks: [ChapterBlock]
        +images: [ChapterImage]
    }

    class ReadingPosition {
        <<struct>>
        +chapterIndex: Int
        +sentenceIndex: Int
        +scrollPosition: CGPoint?
        +lastReadDate: Date
        +chapterPositions: [Int: Int]
        +readingModeData: ReadingModeData?
        +updateChapterPosition(chapter: Int, sentence: Int) void
        +sentenceIndexForChapter(_ chapter: Int) Int
    }
    
    class ReadingModeData {
        <<protocol>>
        +modeIdentifier: String
    }

    class ProcessedChapter {
        <<struct>>
        +originalChapter: Chapter
        +processedTextContent: String
        +sentences: [String]
        +sentenceRanges: [Range<String.Index>]
        +attributedSentences: [NSAttributedString]?
        +processedHTMLContent: String
        +cacheKey: String <<computed>>
    }

    class ContentDisplayOptions {
        <<struct>>
        +fontSize: CGFloat
        +lineSpacing: CGFloat
        +horizontalPadding: CGFloat
        +highlightedSentenceIndex: Int?
        +highlightColor: Color?
        +highlightMode: HighlightMode?
        +baseURL: URL?
        +darkMode: Bool
        +withHighlightIndex(_ index: Int?) ContentDisplayOptions
        +withFontSize(_ size: CGFloat) ContentDisplayOptions
    }

    class ReaderSettings {
        <<ObservableObject>>
        @Published fontSize: CGFloat
        @Published lineSpacing: CGFloat
        @Published horizontalPadding: CGFloat
        @Published darkMode: Bool
        +save() void
        +load() void
    }

    %% UI Components
    class ReaderContainerView {
        <<View>>
        @StateObject viewModel: BookViewModel
        @EnvironmentObject coordinator: AppCoordinator
        @StateObject viewModelCoordinator: ViewModelCoordinator
        +body: some View
    }
    
    class UnifiedReaderView {
        <<View>>
        @ObservedObject viewModel: ReadingContentViewModel
        @EnvironmentObject settings: ReaderSettings
        +body: some View
    }
    
    class WebContentView {
        <<View>>
        @ObservedObject viewModel: ReadingContentViewModel
        @EnvironmentObject settings: ReaderSettings
        -htmlContent: String
        +body: some View
    }

    %% Relationships - Core Flow
    AppCoordinator --> ViewModelCoordinator : creates
    AppCoordinator --> ReaderContainerView : shows
    
    ViewModelCoordinator --> ServiceLocator : uses
    ViewModelCoordinator --> BookViewModel : coordinates
    ViewModelCoordinator --> ReadingContentViewModel : coordinates
    ViewModelCoordinator --> InlineHighlightViewModel : coordinates
    ViewModelCoordinator --> SpeedReadingViewModel : coordinates
    
    ServiceLocator --> BookViewModel : provides
    ServiceLocator --> ReadingContentViewModel : provides
    ServiceLocator --> DefaultEPUBService : provides
    ServiceLocator --> DefaultContentProcessor : provides
    ServiceLocator --> BookStorageService : provides
    ServiceLocator --> ReadingProgressManager : provides
    ServiceLocator --> SettingsManager : provides
    
    BookViewModel --> DefaultEPUBService : uses
    BookViewModel --> StorageCoordinator : uses
    BookViewModel --> ReadingProgressManager : uses
    BookViewModel --> Book : manages
    
    ReadingContentViewModel --> DefaultContentProcessor : uses
    ReadingContentViewModel --> ProcessedChapter : manages
    ReadingContentViewModel --> ContentDisplayOptions : configures
    ReadingContentViewModel --> ReadingModeStrategy : uses
    
    DefaultEPUBService --> EPUBProcessingPipeline : creates
    DefaultEPUBService --> StorageCoordinator : saves result via
    
    StorageCoordinator --> BookStorageService : uses
    StorageCoordinator --> ReadingProgressManager : uses
    
    DefaultContentProcessor --> ProcessedChapter : produces
    DefaultContentProcessor --> ChapterCache : uses
    
    ProcessedChapter --> Chapter : references
    
    ReaderContainerView --> BookViewModel : uses
    ReaderContainerView --> UnifiedReaderView : shows
    
    UnifiedReaderView --> ReadingContentViewModel : uses
    UnifiedReaderView --> WebContentView : contains
    
    WebContentView --> ProcessedChapter : displays
    
    ReadingModeStrategy <|.. StandardReadingStrategy
    ReadingModeStrategy <|.. InlineHighlightStrategy
    ReadingModeStrategy <|.. SpeedReadingStrategy