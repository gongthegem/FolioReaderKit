classDiagram
    %% Core Services Layer
    class EPUBService {
        <<protocol>>
        +parseEPUB(at: URL) Book?
        +unzipToDirectory(from: URL, destination: URL) Bool throws
    }

    class DefaultEPUBService {
        <<EPUBService>>
        -extractor: EPUBExtractorService
        -metadataParser: EPUBMetadataParserService
        -tocParser: TOCParsingService
        -pathResolver: PathResolverService
        -spineService: EPUBSpineService
        -zipService: EPUBZipService
        +parseEPUB(at: URL) Book?
        +unzipToDirectory(from: URL, destination: URL) Bool throws
    }

    DefaultEPUBService ..|> EPUBService
    DefaultEPUBService --> EPUBExtractorService : uses
    DefaultEPUBService --> EPUBMetadataParserService : uses
    DefaultEPUBService --> TOCParsingService : uses
    DefaultEPUBService --> PathResolverService : uses
    DefaultEPUBService --> EPUBSpineService : uses
    DefaultEPUBService --> EPUBZipService : uses

    %% Sub-services with consistent interfaces
    class EPUBExtractorService {<<protocol>>}
    class EPUBMetadataParserService {<<protocol>>}
    class TOCParsingService {<<protocol>>}
    class PathResolverService {<<protocol>>}
    class EPUBSpineService {<<protocol>>}
    class EPUBZipService {<<protocol>>}

    %% Core Models Layer - Simplified, removes duplication
    class Book {
        <<struct>>
        +id: UUID
        +title: String
        +author: String
        +coverImage: UIImage?
        +chapters: [Chapter]
        +metadata: BookMetadata
        +filePath: String
        +lastReadPosition: ReadingPosition?
    }

    class BookMetadata {
        <<struct>>
        +publisher: String?
        +language: String?
        +identifier: String?
        +description: String?
        +subjects: [String]
        +rights: String?
        +source: String?
        +modified: String?
        +extraMetadata: [String: String]
    }

    class ReadingPosition {
        <<struct>>
        +chapterIndex: Int
        +sentenceIndex: Int
        +scrollPosition: CGPoint?
        +lastReadDate: Date
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

    class ChapterBlock {
        <<enum>>
        case text(String, TextBlockType)
        case image(ChapterImage)
        +isImageBlock: Bool
        +textContent: String?
        +image: ChapterImage?
        +blockType: TextBlockType?
    }

    class ChapterImage {
        <<struct>>
        +id: String
        +name: String
        +caption: String?
        +image: UIImage
        +altText: String?
        +sourceURL: URL?
    }

    class TextBlockType {
        <<enum>>
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

    class TocItem {
        <<struct>>
        +id: String
        +title: String
        +href: String?
        +level: Int
        +children: [TocItem]
        +chapterIndex: Int?
    }

    Book *-- "1" BookMetadata : has
    Book *-- "0..1" ReadingPosition : has
    Book *-- "*" Chapter : contains
    Chapter *-- "*" ChapterBlock : composed of
    Chapter *-- "*" ChapterImage : references
    ChapterBlock ..> ChapterImage : may contain
    ChapterBlock ..> TextBlockType : may have
    TocItem *-- "*" TocItem : contains

    %% Content Processing/Display Layer - Unified utilities
    class ContentProcessor {
        <<singleton>>
        +processChapter(chapter: Chapter, fontSize: CGFloat) ProcessedChapter
        +extractSentences(from: String) [String]
        +generateHTMLContent(chapter: Chapter, options: ContentDisplayOptions) String
        +convertToAttributedString(html: String, fontSize: CGFloat) NSAttributedString
        -computeSentenceRanges(text: String) [Range<String.Index>]
        -handleSpecialElements(doc: SwiftSoup.Document)
    }

    class ContentDisplayOptions {
        <<struct>>
        +fontSize: CGFloat
        +lineSpacing: CGFloat
        +horizontalPadding: CGFloat
        +highlightedSentenceIndex: Int?
        +highlightColor: Color?
        +speedReadingMode: SpeedReaderMode?
        +baseURL: URL?
        +darkMode: Bool
    }

    class ProcessedChapter {
        <<struct>>
        +originalChapter: Chapter
        +processedTextContent: String
        +sentences: [String]
        +sentenceRanges: [Range<String.Index>]
        +attributedSentences: [NSAttributedString]?
        +processedHTMLContent: String
    }

    class HTMLRenderer {
        <<singleton>>
        +wrapContentInHTML(content: String, options: ContentDisplayOptions) String
        +highlightSentenceInHTML(html: String, sentenceIndex: Int, sentences: [String], options: ContentDisplayOptions) String
        +getHighlightStyles() String
        +getHighlightJavaScript() String
    }

    class PathResolver {
        <<singleton>>
        +resolveRelativePath(path: String, basePath: String) String
        +resolveURL(for: String, baseURL: URL) URL?
        +directoryFromPath(path: String) String
    }

    ContentProcessor --> ProcessedChapter : produces
    ContentProcessor --> ContentDisplayOptions : uses
    ContentProcessor --> HTMLRenderer : uses
    ContentProcessor --> PathResolver : uses
    HTMLRenderer --> ContentDisplayOptions : uses

    %% ViewModels Layer - Simplified with clearer responsibilities
    class BookViewModel {
        <<ObservableObject>>
        -epubService: EPUBService
        -progressManager: ReadingProgressManager
        #currentBook: Book?
        #library: [Book]
        #currentChapterIndex: Int
        #settings: ReaderSettings
        #speedReadingMode: SpeedReaderMode?
        +currentChapterContent: ProcessedChapter?
        +loadEPUB(from: URL) void
        +navigateToChapter(index: Int) void
        +navigateToNextChapter() void
        +navigateToPreviousChapter() void
        +saveReadingPosition(chapterIndex: Int, sentenceIndex: Int) void
        +loadLibrary() void
        +saveLibrary() void
    }

    class ReadingContentViewModel {
        <<ObservableObject>>
        -contentProcessor: ContentProcessor
        #currentChapter: Chapter?
        #processedChapter: ProcessedChapter?
        #displayOptions: ContentDisplayOptions
        +loadChapter(chapter: Chapter, options: ContentDisplayOptions) void
        +updateDisplayOptions(options: ContentDisplayOptions) void
        +generateHTMLForCurrentSentence(sentenceIndex: Int) String
        +sentenceAtIndex(index: Int) String?
        +blockForSentence(at: Int) ChapterBlock?
    }

    class SpeedReadingViewModel {
        <<ObservableObject>>
        -progressManager: ReadingProgressManager
        -readingContentVM: ReadingContentViewModel
        #bookId: String
        #isPlaying: Bool
        #wordsPerMinute: Int
        #currentSentenceIndex: Int
        -playbackTimer: Timer?
        +togglePlayback() void
        +goToNextSentence() void
        +goToPreviousSentence() void
        +adjustWPM(by: Int) void
        +saveProgress() void
        -startPlaybackTimer() void
        -stopPlaybackTimer() void
    }

    class ReaderSettings {
        <<ObservableObject>>
        +fontSize: CGFloat
        +lineSpacing: CGFloat
        +horizontalPadding: CGFloat
        +darkMode: Bool
        +save() void
        +load() void
    }

    class ReadingProgressManager {
        <<ObservableObject>>
        +saveProgress(bookId: String, position: ReadingPosition) void
        +loadProgress(bookId: String) ReadingPosition?
        +updateLastReadDate(bookId: String) void
    }

    BookViewModel --> EPUBService : uses
    BookViewModel --> ReadingProgressManager : uses
    BookViewModel --> ReaderSettings : manages
    BookViewModel --> Book : manages
    BookViewModel --> ProcessedChapter : provides
    
    ReadingContentViewModel --> ContentProcessor : uses
    ReadingContentViewModel --> ProcessedChapter : manages
    ReadingContentViewModel --> ContentDisplayOptions : manages
    ReadingContentViewModel --> Chapter : processes
    
    SpeedReadingViewModel --> ReadingProgressManager : uses
    SpeedReadingViewModel --> ReadingContentViewModel : uses

    %% Views Layer - Maintains UI components with clearer responsibilities
    class ReaderContainerView {
        <<View>>
        +bookViewModel: BookViewModel
        +readingContentVM: ReadingContentViewModel
        +speedReadingVM: SpeedReadingViewModel?
        -readerMode: ReaderMode
        -showSettings: Bool
        -showTOC: Bool
        +body: View
    }

    class StandardReaderView {
        <<View>>
        +bookViewModel: BookViewModel
        +readingContentVM: ReadingContentViewModel
        +onShowSettings: () -> Void
        +onShowTOC: () -> Void
        +onModeChange: (ReaderMode) -> Void
        +body: View
    }

    class SpeedReaderView {
        <<View>>
        +speedReadingVM: SpeedReadingViewModel
        +readingContentVM: ReadingContentViewModel
        +onShowSettings: () -> Void
        +onExit: () -> Void
        +body: View
    }

    class BookWebView {
        <<UIViewRepresentable>>
        +htmlContent: String
        +baseURL: URL?
        +displayOptions: ContentDisplayOptions
        +onSentenceTap: (Int) -> Void
        +onImageTap: (ChapterImage) -> Void
        +onMarginTap: (MarginSide) -> Void
        +body: View
    }

    class SettingsView {
        <<View>>
        +settings: ReaderSettings
        +onDismiss: () -> Void
        +body: View
    }

    class TOCView {
        <<View>>
        +tocItems: [TocItem]
        +currentChapterIndex: Int
        +onChapterSelected: (Int) -> Void
        +onDismiss: () -> Void
        +body: View
    }

    class BaseNavigationControls {
        <<View>>
        +onPrevious: () -> Void
        +onNext: () -> Void
        +body: View
    }

    class StandardNavigationControls {
        <<View>>
        +currentIndex: Int
        +totalCount: Int
        +body: View
    }

    class InlineHighlightControls {
        <<View>>
        +currentSentenceIndex: Int
        +totalSentences: Int
        +onExitHighlightMode: () -> Void
        +body: View
    }

    ReaderContainerView --> BookViewModel : uses
    ReaderContainerView --> ReadingContentViewModel : uses
    ReaderContainerView --> SpeedReadingViewModel : uses
    ReaderContainerView --> StandardReaderView : displays
    ReaderContainerView --> SpeedReaderView : displays
    ReaderContainerView --> SettingsView : displays
    ReaderContainerView --> TOCView : displays
    
    StandardReaderView --> BookWebView : displays
    StandardReaderView --> StandardNavigationControls : displays
    
    SpeedReaderView --> BookWebView : displays
    SpeedReaderView --> InlineHighlightControls : displays
    
    BaseNavigationControls <|-- StandardNavigationControls : extends
    BaseNavigationControls <|-- InlineHighlightControls : extends