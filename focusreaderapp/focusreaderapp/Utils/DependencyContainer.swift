import Foundation

class DependencyContainer {
    static let shared = DependencyContainer()
    
    private init() {}
    
    // MARK: - Services
    
    lazy var epubService: EPUBService = {
        let zipService = DefaultEPUBZipService()
        let extractorService = DefaultEPUBExtractorService(zipService: zipService)
        let pathResolverService = DefaultPathResolverService()
        let metadataParserService = DefaultEPUBMetadataParserService()
        let tocParserService = DefaultTOCParsingService()
        let spineService = DefaultEPUBSpineService()
        
        return DefaultEPUBService(
            extractor: extractorService,
            metadataParser: metadataParserService,
            tocParser: tocParserService,
            pathResolver: pathResolverService,
            spineService: spineService,
            zipService: zipService
        )
    }()
    
    // MARK: - Managers
    
    lazy var readingProgressManager: ReadingProgressManager = {
        return ReadingProgressManager()
    }()
    
    // MARK: - Settings
    
    lazy var readerSettings: ReaderSettings = {
        let settings = ReaderSettings()
        settings.load()
        return settings
    }()
    
    // MARK: - ViewModels
    
    func makeBookViewModel() -> BookViewModel {
        return BookViewModel(
            epubService: epubService,
            progressManager: readingProgressManager,
            settings: readerSettings
        )
    }
    
    func makeReadingContentViewModel() -> ReadingContentViewModel {
        let displayOptions = ContentDisplayOptions(
            fontSize: readerSettings.fontSize,
            lineSpacing: readerSettings.lineSpacing,
            horizontalPadding: readerSettings.horizontalPadding,
            darkMode: readerSettings.darkMode
        )
        
        return ReadingContentViewModel(displayOptions: displayOptions)
    }
    
    func makeSpeedReadingViewModel(readingContentVM: ReadingContentViewModel) -> SpeedReadingViewModel {
        return SpeedReadingViewModel(
            progressManager: readingProgressManager,
            readingContentVM: readingContentVM
        )
    }
} 