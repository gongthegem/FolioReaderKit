classDiagram
    %% Core Services Layer - Improved Design

    %% Main Application Service Interface
    class EPUBProcessingService {
        "Main interface for processing EPUB files"
        <<interface>>
        +processEPUB(url: URL, progressCallback: (Double) -> Void) -> Future<Book, Error>
        +extractContents(bookId: String, outputDirectory: URL) -> Future<Bool, Error>
    }

    %% EPUB Service
    class EPUBService {
        "Handles EPUB file parsing and extraction"
        <<interface>>
        +parseEPUB(at: URL, progressCallback: (Double) -> Void) -> Future<Book, Error>
        +unzipToDirectory(from: URL, destination: URL) throws -> Future<Bool, Error>
    }

    class DefaultEPUBService {
        "Default implementation of EPUBService"
        <<EPUBService>>
        -serviceFactory: EPUBServiceFactory
        -errorHandler: ErrorHandlingService
        -logger: LoggingService
        +init(serviceFactory: EPUBServiceFactory)
        +parseEPUB(at: URL, progressCallback: (Double) -> Void) -> Future<Book, Error>
        +unzipToDirectory(from: URL, destination: URL) throws -> Future<Bool, Error>
        -reportProgress(progress: Double, callback: (Double) -> Void) void
    }
    
    class EPUBServiceFactory {
        "Factory for creating EPUB service components"
        <<interface>>
        +makeExtractorService() EPUBExtractorService
        +makeMetadataParserService() EPUBMetadataParserService
        +makeTOCParsingService() TOCParsingService
        +makePathResolverService() PathResolverService
        +makeSpineService() EPUBSpineService
        +makeZipService() EPUBZipService
        +makeResourceManager() EPUBResourceManager
    }
    
    class DefaultEPUBServiceFactory {
        "Default implementation of EPUBServiceFactory"
        <<EPUBServiceFactory>>
        +makeExtractorService() EPUBExtractorService
        +makeMetadataParserService() EPUBMetadataParserService
        +makeTOCParsingService() TOCParsingService
        +makePathResolverService() PathResolverService
        +makeSpineService() EPUBSpineService
        +makeZipService() EPUBZipService
        +makeResourceManager() EPUBResourceManager
    }

    %% EPUB Processing Pipeline - Builder Pattern
    class EPUBProcessingPipeline {
        "Fluent builder for EPUB processing steps"
        <<interface>>
        +extract(epubURL: URL) -> Self
        +parseMetadata() -> Self
        +parseTOC() -> Self
        +parseSpine() -> Self
        +loadChapters() -> Self
        +loadImages() -> Self
        +build() -> Future<Book, Error>
    }
    
    class DefaultEPUBProcessingPipeline {
        "Pipeline implementation with sequential processing"
        <<EPUBProcessingPipeline>>
        -serviceFactory: EPUBServiceFactory
        -extractedDir: URL?
        -metadata: BookMetadata?
        -tocItems: [TocItem]
        -chapters: [Chapter]
        -progressCallback: (Double) -> Void
        -currentProgress: Double
        +init(serviceFactory: EPUBServiceFactory, progressCallback: (Double) -> Void)
        +extract(epubURL: URL) -> Self
        +parseMetadata() -> Self
        +parseTOC() -> Self
        +parseSpine() -> Self
        +loadChapters() -> Self
        +loadImages() -> Self
        +build() -> Future<Book, Error>
    }

    %% EPUB Sub-Services
    class EPUBExtractorService {
        "Extracts EPUB files to filesystem"
        <<interface>>
        +extractEPUB(at: URL, to: URL) -> Future<URL, Error>
    }
    
    class EPUBMetadataParserService {
        "Parses EPUB metadata from OPF files"
        <<interface>>
        +parseMetadata(from: URL) -> Future<BookMetadata, Error>
    }
    
    class TOCParsingService {
        "Parses table of contents from NCX/OPF"
        <<interface>>
        +parseTOC(from: URL, ncxURL: URL?) -> Future<[TocItem], Error>
    }
    
    class PathResolverService {
        "Resolves paths within EPUB structure"
        <<interface>>
        +resolveContainerPath(in: URL) -> Future<URL?, Error>
        +resolveOPFPath(from: URL) -> Future<URL?, Error>
        +resolveNCXPath(from: URL) -> Future<URL?, Error>
        +resolveChapterPaths(from: URL) -> Future<[URL], Error>
        +resolveBaseDirectory(from: URL) -> URL
    }
    
    class EPUBSpineService {
        "Retrieves spine items from OPF"
        <<interface>>
        +getSpineItems(from: URL) -> Future<[URL], Error>
    }
    
    class EPUBZipService {
        "Handles ZIP operations for EPUB files"
        <<interface>>
        +unzip(from: URL, to: URL) -> Future<Bool, Error>
    }
    
    class EPUBResourceManager {
        "Manages resources within EPUB package"
        <<interface>>
        +registerResource(id: String, url: URL, mediaType: String) void
        +getResourceURL(id: String) URL?
        +getResourceURL(href: String, relativeTo: URL) URL?
        +resolveManifestResources(from: URL) Future<[String: URL], Error>
    }
    
    class ErrorHandlingService {
        "Centralizes error handling and reporting"
        <<interface>>
        +handleError(error: Error, context: String) void
        +createError(domain: String, code: Int, message: String) Error
        +logError(error: Error) void
    }
    
    class LoggingService {
        "Provides structured logging capabilities"
        <<interface>>
        +info(message: String, context: String) void
        +warning(message: String, context: String) void
        +error(message: String, context: String) void
        +debug(message: String, context: String) void
    }

    %% Storage Services
    class BookStorageService {
        "Manages book storage and retrieval"
        <<interface>>
        +hasExtractedBook(id: String) -> Future<Bool, Error>
        +getExtractedBookDirectory(id: String) -> URL
        +saveExtractedBook(from: URL, withId: String) -> Future<Void, Error>
        +getBookMetadata(id: String) -> Future<Book?, Error>
        +saveBookMetadata(_ book: Book) -> Future<Void, Error>
        +getAllSavedBooks() -> Future<[Book], Error>
    }
    
    class FileSystemBookStorageService {
        "Filesystem-based implementation of BookStorageService"
        <<BookStorageService>>
        -fileAccessor: FileSystemAccessService
        -directoryManager: DirectoryManagementService
        -cacheManager: CacheManagementService
        +init(fileAccessor: FileSystemAccessService, directoryManager: DirectoryManagementService, cacheManager: CacheManagementService)
        +hasExtractedBook(id: String) -> Future<Bool, Error>
        +getExtractedBookDirectory(id: String) -> URL
        +saveExtractedBook(from: URL, withId: String) -> Future<Void, Error>
        +getBookMetadata(id: String) -> Future<Book?, Error>
        +saveBookMetadata(_ book: Book) -> Future<Void, Error>
        +getAllSavedBooks() -> Future<[Book], Error>
    }
    
    class FileSystemAccessService {
        "Abstracts filesystem operations"
        <<interface>>
        +fileExists(atPath: String) Bool
        +directoryExists(atPath: String) Bool
        +createDirectory(at: URL) -> Future<Void, Error>
        +copyItem(at: URL, to: URL) -> Future<Void, Error>
        +contentsOfDirectory(at: URL) -> Future<[URL], Error>
    }
    
    class DirectoryManagementService {
        "Manages application directory structure"
        <<interface>>
        +getBooksDirectory() -> URL
        +getBookDirectory(id: String) -> URL
        +ensureDirectoryExists(url: URL) -> Future<Void, Error>
        +clearTemporaryDirectories() -> Future<Void, Error>
    }
    
    class CacheManagementService {
        "Manages caching of resources"
        <<interface>>
        +cacheData(data: Data, forKey: String) -> Future<Void, Error>
        +getCachedData(forKey: String) -> Future<Data?, Error>
        +clearCache() -> Future<Void, Error>
    }

    %% Relationships
    EPUBProcessingService <|.. DefaultEPUBService : implements
    EPUBService <|.. DefaultEPUBService : implements
    EPUBServiceFactory <|.. DefaultEPUBServiceFactory : implements
    EPUBProcessingPipeline <|.. DefaultEPUBProcessingPipeline : implements
    
    BookStorageService <|.. FileSystemBookStorageService : implements
    
    DefaultEPUBService --> EPUBServiceFactory : uses
    DefaultEPUBService --> ErrorHandlingService : uses
    DefaultEPUBService --> LoggingService : uses
    DefaultEPUBService --> EPUBProcessingPipeline : creates
    
    DefaultEPUBProcessingPipeline --> EPUBServiceFactory : uses
    DefaultEPUBProcessingPipeline --> EPUBExtractorService : gets via factory
    DefaultEPUBProcessingPipeline --> EPUBMetadataParserService : gets via factory
    DefaultEPUBProcessingPipeline --> TOCParsingService : gets via factory
    DefaultEPUBProcessingPipeline --> PathResolverService : gets via factory
    DefaultEPUBProcessingPipeline --> EPUBSpineService : gets via factory
    DefaultEPUBProcessingPipeline --> EPUBResourceManager : gets via factory
    
    FileSystemBookStorageService --> FileSystemAccessService : uses
    FileSystemBookStorageService --> DirectoryManagementService : uses
    FileSystemBookStorageService --> CacheManagementService : uses