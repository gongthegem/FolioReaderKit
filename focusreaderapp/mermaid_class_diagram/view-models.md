```mermaid
classDiagram
    %% ViewModels Layer - Improved Design with Reduced Coupling
    
    %% Base ViewModel Coordinator
    class ViewModelCoordinator {
        "Interface for coordinating view model interactions"
        <<interface>>
        +coordinateBookLoading(url: URL) void
        +coordinateChapterNavigation(bookId: String, chapterIndex: Int) void
        +coordinateReadingModeChange(mode: ReadingModeStrategy) void
        +coordinateProgressSaving(bookId: String, position: ReadingPosition) void
        +coordinateReadingFlowCompletion() void
    }
    
    class DefaultViewModelCoordinator {
        "Default implementation of view model coordination"
        <<ViewModelCoordinator>>
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
        "Service dependency provider"
        <<singleton>>
        +getEPUBService() EPUBService
        +getBookStorageService() BookStorageService
        +getProgressManager() ReadingProgressManager
        +getContentProcessor() ContentProcessingService
        +getSettingsManager() SettingsManager
    }
    
    class BookViewModel {
        "Manages books and library data"
        <<ObservableObject>>
        -coordinator: ViewModelCoordinator?
        -serviceLocator: ServiceLocator
        -epubService: EPUBService
        -progressManager: ReadingProgressManager
        -bookStorage: BookStorageService
        -fileManager: FileManager
        @Published currentBook: Book?
        @Published library: [Book]
        @Published currentChapterIndex: Int
        @Published settings: ReaderSettings
        @Published currentChapterContent: ProcessedChapter?
        @Published isLoading: Bool
        @Published loadingError: String?
        +init(serviceLocator: ServiceLocator, coordinator: ViewModelCoordinator?)
        +loadEPUB(from: URL) void
        +loadBook(_ book: Book) void
        +loadChapter(at: Int) void
        +navigateToChapter(index: Int) void
        +navigateToNextChapter() void
        +navigateToPreviousChapter() void
        +saveReadingPosition(chapterIndex: Int, sentenceIndex: Int, displayMode: ReadingModeStrategy) void
        -refreshCurrentChapter() void
        -updateChapterPosition(_ chapter: Int, sentenceIndex: Int, displayMode: ReadingModeStrategy?) void
        -getCurrentSentenceIndex() Int
    }

    class ReadingContentViewModel {
        "Manages current reading content and navigation"
        <<ObservableObject>>
        -coordinator: ViewModelCoordinator?
        -serviceLocator: ServiceLocator
        -contentProcessor: ContentProcessor
        @Published currentChapter: Chapter?
        @Published processedChapter: ProcessedChapter?
        @Published displayOptions: ContentDisplayOptions
        @Published currentSentenceIndex: Int
        @Published isLoading: Bool
        @Published readingMode: ReadingModeStrategy
        +init(serviceLocator: ServiceLocator, coordinator: ViewModelCoordinator?)
        +loadChapter(chapter: Chapter, options: ContentDisplayOptions) void
        +updateDisplayOptions(options: ContentDisplayOptions) void
        +setReadingMode(_ mode: ReadingModeStrategy) void
        +generateHTMLForCurrentSentence(sentenceIndex: Int) String
        +sentenceAtIndex(index: Int) String?
        +blockForSentence(at index: Int) ChapterBlock?
        +moveToNextSentence() Bool
        +moveToPreviousSentence() Bool
        +moveToSentence(index: Int) Bool
        +totalSentences: Int <<computed>>
        +notifyProgressChanged() void
        -handleRestoreSentencePosition(_ notification: Notification) @objc
    }
    
    class InlineHighlightViewModel {
        "Manages inline highlighting reading mode"
        <<ObservableObject>>
        -coordinator: ViewModelCoordinator?
        -serviceLocator: ServiceLocator
        -progressManager: ReadingProgressManager?
        -readingContentVM: ReadingContentViewModel
        @Published bookId: String?
        @Published currentSentenceIndex: Int
        @Published currentChapterIndex: Int
        +init(serviceLocator: ServiceLocator, coordinator: ViewModelCoordinator?)
        +configure(with: String, chapterIndex: Int, initialSentenceIndex: Int) void
        +moveToNextSentence() void
        +moveToPreviousSentence() void
        +notifyProgressChanged() void
    }
    
    class SpeedReadingViewModel {
        "Manages speed reading display and control"
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
        +init(serviceLocator: ServiceLocator, coordinator: ViewModelCoordinator?)
        +configure(with: String, chapterIndex: Int, initialSentenceIndex: Int) void
        +togglePlayback() void
        +goToNextSentence() void
        +goToPreviousSentence() void
        +adjustWPM(by: Int) void
        +notifyProgressChanged() void
        -startPlaybackTimer() void
        -stopPlaybackTimer() void
        -calculateTimeInterval() TimeInterval
    }
    
    class ReadingModeStrategy {
        "Strategy for reading mode behavior"
        <<interface>>
        +initializeMode(chapter: Chapter, options: ContentDisplayOptions) void
        +prepareForDisplay() DisplayConfiguration
        +handleNavigation(action: NavigationAction) Bool
        +getDisplayMode() DisplayMode
    }
    
    class StandardReadingStrategy {
        "Standard continuous reading mode"
        <<ReadingModeStrategy>>
    }
    
    class InlineHighlightStrategy {
        "Sentence-by-sentence highlighting mode"
        <<ReadingModeStrategy>>
    }
    
    class SpeedReadingStrategy {
        "Rapid word or sentence display mode"
        <<ReadingModeStrategy>>
    }
    
    class NavigationAction {
        "Reading navigation action type"
        <<enum>>
        next
        previous
        specificIndex(Int)
    }
    
    class DisplayMode {
        "UI display mode for reading"
        <<enum>>
        standard
        inlineHighlight
        speedReading
    }
    
    class SettingsManager {
        "Manages all application settings"
        <<ObservableObject>>
        +settings: ReaderSettings
        +applySettings(to: ContentDisplayOptions) ContentDisplayOptions
        +getSpeedReadingSettings() SpeedReadingSettings
        +getInlineHighlightSettings() InlineHighlightSettings
    }
    
    class ReaderSettings { <<ObservableObject>> } %% Defined elsewhere
    class ReadingProgressManager { <<ObservableObject>> } %% Defined elsewhere
    class BookStorageService { <<protocol>> } %% Defined elsewhere
    class EPUBService { <<protocol>> } %% Defined elsewhere
    class ContentProcessor { <<singleton>> } %% Defined elsewhere
    class ContentDisplayOptions { <<struct>> } %% Defined elsewhere
    class Chapter { <<struct>> } %% Defined elsewhere
    class ProcessedChapter { <<struct>> } %% Defined elsewhere
    class Book { <<struct>> } %% Defined elsewhere
    class ReadingPosition { <<struct>> } %% Defined elsewhere
    class SpeedReaderMode { <<enum>> } %% Defined elsewhere
    class ChapterBlock { <<enum>> } %% Defined elsewhere
    class SpeedReadingSettings { <<struct>> } %% Defined elsewhere
    class InlineHighlightSettings { <<struct>> } %% Defined elsewhere
    class DisplayConfiguration { <<struct>> } %% Defined elsewhere
    
    %% Relationships
    ViewModelCoordinator <|.. DefaultViewModelCoordinator
    ReadingModeStrategy <|.. StandardReadingStrategy
    ReadingModeStrategy <|.. InlineHighlightStrategy
    ReadingModeStrategy <|.. SpeedReadingStrategy
    
    DefaultViewModelCoordinator --> BookViewModel : coordinates
    DefaultViewModelCoordinator --> ReadingContentViewModel : coordinates
    DefaultViewModelCoordinator --> InlineHighlightViewModel : coordinates
    DefaultViewModelCoordinator --> SpeedReadingViewModel : coordinates
    DefaultViewModelCoordinator --> ServiceLocator : uses
    
    BookViewModel --> ServiceLocator : gets-services
    ReadingContentViewModel --> ServiceLocator : gets-services
    InlineHighlightViewModel --> ServiceLocator : gets-services
    SpeedReadingViewModel --> ServiceLocator : gets-services
    
    BookViewModel --> ViewModelCoordinator : notifies
    ReadingContentViewModel --> ViewModelCoordinator : notifies
    InlineHighlightViewModel --> ViewModelCoordinator : notifies
    SpeedReadingViewModel --> ViewModelCoordinator : notifies
    
    ReadingContentViewModel --> ReadingModeStrategy : uses
    BookViewModel --> Book : manages
    ReadingContentViewModel --> ProcessedChapter : manages
    ReadingContentViewModel --> Chapter : processes
```