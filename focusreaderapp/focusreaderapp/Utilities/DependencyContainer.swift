import Foundation

class DependencyContainer {
    static let shared = DependencyContainer()
    
    private init() {}
    
    // MARK: - Services
    
    lazy var epubResourceManager: EPUBResourceManager = {
        return DefaultEPUBResourceManager()
    }()
    
    lazy var epubService: EPUBService = {
        let zipService = DefaultEPUBZipService()
        let extractorService = DefaultEPUBExtractorService(zipService: zipService)
        let pathResolverService = DefaultPathResolverService()
        let metadataParserService = DefaultEPUBMetadataParserService()
        let tocParserService = DefaultTOCParsingService()
        let spineService = DefaultEPUBSpineService()
        let resourceManager = epubResourceManager
        
        LoggingService.shared.info("Creating EPUBService with all dependencies initialized", category: .general)
        LoggingService.shared.debug("- zipService: \(zipService)", category: .general)
        LoggingService.shared.debug("- extractorService: \(extractorService)", category: .general)
        LoggingService.shared.debug("- pathResolverService: \(pathResolverService)", category: .general)
        LoggingService.shared.debug("- metadataParserService: \(metadataParserService)", category: .general)
        LoggingService.shared.debug("- tocParserService: \(tocParserService)", category: .general)
        LoggingService.shared.debug("- spineService: \(spineService)", category: .general)
        LoggingService.shared.debug("- resourceManager: \(resourceManager)", category: .general)
        
        return DefaultEPUBService(
            extractor: extractorService,
            metadataParser: metadataParserService,
            tocParser: tocParserService,
            pathResolver: pathResolverService,
            spineService: spineService,
            zipService: zipService,
            resourceManager: resourceManager
        )
    }()
    
    lazy var bookStorage: BookStorageService = {
        return FileSystemBookStorageService()
    }()
    
    // MARK: - Settings
    
    lazy var readerSettings: ReaderSettings = {
        let settings = ReaderSettings()
        settings.load()
        return settings
    }()
    
    // MARK: - ViewModels
    
    func makeBookViewModel() -> BookViewModel {
        // Log information about the app bundle and resource paths
        logResourcePaths()
        
        LoggingService.shared.debug("Creating BookViewModel with epubService, bookStorage, and settings", category: .general)
        
        return BookViewModel(
            epubService: epubService,
            bookStorage: bookStorage,
            settings: readerSettings
        )
    }
    
    private func logResourcePaths() {
        LoggingService.shared.info("======== APP RESOURCE PATHS ========", category: .fileSystem)
        let fileManager = FileManager.default
        
        // Log the main bundle path
        let bundlePath = Bundle.main.bundlePath
        LoggingService.shared.info("Main bundle path: \(bundlePath)", category: .fileSystem)
        
        // Log if the Resources directory exists in the bundle
        let resourcesPath = bundlePath + "/Resources"
        let resourcesExists = fileManager.fileExists(atPath: resourcesPath)
        LoggingService.shared.info("Resources directory exists in bundle: \(resourcesExists)", category: .fileSystem)
        
        // Log if the sample.epub exists in various locations
        let sampleInResources = fileManager.fileExists(atPath: resourcesPath + "/sample.epub")
        LoggingService.shared.info("sample.epub exists in bundle Resources: \(sampleInResources)", category: .fileSystem)
        
        let sampleInBundle = Bundle.main.path(forResource: "sample", ofType: "epub") != nil
        LoggingService.shared.info("sample.epub exists via Bundle lookup: \(sampleInBundle)", category: .fileSystem)
        
        let sampleInResourcesDir = Bundle.main.path(forResource: "sample", ofType: "epub", inDirectory: "Resources") != nil
        LoggingService.shared.info("sample.epub exists via Bundle lookup in Resources dir: \(sampleInResourcesDir)", category: .fileSystem)
        
        // Log the contents of the Resources directory if it exists
        if resourcesExists {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: resourcesPath)
                LoggingService.shared.info("Contents of Resources directory:", category: .fileSystem)
                for item in contents {
                    LoggingService.shared.info("- \(item)", category: .fileSystem)
                }
            } catch {
                LoggingService.shared.error("Error listing Resources directory: \(error.localizedDescription)", category: .fileSystem)
            }
        }
        
        // Try to find the sample.epub file in the project directory structure
        let workspacePaths = [
            bundlePath + "/../Resources/sample.epub",
            bundlePath + "/../../Resources/sample.epub",
            bundlePath + "/../../../Resources/sample.epub",
            "/Users/gongchunyan/Desktop/SwiftProjects/focusreaderapp/focusreaderapp/Resources/sample.epub"
        ]
        
        LoggingService.shared.info("Checking for sample.epub in workspace:", category: .fileSystem)
        for path in workspacePaths {
            let exists = fileManager.fileExists(atPath: path)
            LoggingService.shared.info("- \(path): \(exists)", category: .fileSystem)
        }
        
        LoggingService.shared.info("======== END RESOURCE PATHS ========", category: .fileSystem)
    }
    
    func makeReadingContentViewModel() -> ReadingContentViewModel {
        let displayOptions = ContentDisplayOptions(
            fontSize: readerSettings.fontSize,
            lineSpacing: readerSettings.lineSpacing,
            horizontalPadding: readerSettings.horizontalPadding,
            darkMode: readerSettings.darkMode
        )
        
        LoggingService.shared.debug("Creating ReadingContentViewModel with display options: fontSize=\(displayOptions.fontSize), darkMode=\(displayOptions.darkMode)", category: .ui)
        
        return ReadingContentViewModel(displayOptions: displayOptions)
    }
} 