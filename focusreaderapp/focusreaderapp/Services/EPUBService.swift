import Foundation
import ZIPFoundation

// MARK: - Main EPUB Service Protocol
protocol EPUBService {
    func parseEPUB(at url: URL) -> Book?
    func unzipToDirectory(from: URL, destination: URL) throws -> Bool
}

// MARK: - Sub-Service Protocols
protocol EPUBExtractorService {
    func extractEPUB(at url: URL, to destinationURL: URL) throws -> URL
}

protocol EPUBMetadataParserService {
    func parseMetadata(from opfPath: URL) -> (title: String, author: String, metadata: BookMetadata, coverPath: String?)
}

protocol TOCParsingService {
    func parseTOC(from opfURL: URL, ncxURL: URL?) -> [TocItem]
}

protocol PathResolverService {
    func resolveContainerPath(in epubDirectory: URL) -> URL?
    func resolveOPFPath(from containerXML: URL) -> URL?
    func resolveNCXPath(from opfURL: URL) -> URL?
    func resolveChapterPaths(from opfURL: URL) -> [URL]
    func resolveBaseDirectory(from opfURL: URL) -> URL
}

protocol EPUBSpineService {
    func getSpineItems(from opfURL: URL) -> [URL]
}

protocol EPUBZipService {
    func unzip(from sourceURL: URL, to destinationURL: URL) throws -> Bool
}

// MARK: - Default Implementation
class DefaultEPUBService: EPUBService {
    private let extractor: EPUBExtractorService
    private let metadataParser: EPUBMetadataParserService
    private let tocParser: TOCParsingService
    private let pathResolver: PathResolverService
    private let spineService: EPUBSpineService
    private let zipService: EPUBZipService
    private let fileManager = FileManager.default
    
    init(
        extractor: EPUBExtractorService,
        metadataParser: EPUBMetadataParserService,
        tocParser: TOCParsingService,
        pathResolver: PathResolverService,
        spineService: EPUBSpineService,
        zipService: EPUBZipService
    ) {
        self.extractor = extractor
        self.metadataParser = metadataParser
        self.tocParser = tocParser
        self.pathResolver = pathResolver
        self.spineService = spineService
        self.zipService = zipService
    }
    
    func parseEPUB(at url: URL) -> Book? {
        do {
            // Create a temporary directory
            let tempDir = try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent(UUID().uuidString)
            
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // Extract the EPUB to the temporary directory
            let epubDirectory = try extractor.extractEPUB(at: url, to: tempDir)
            
            // Resolve paths for necessary files
            guard let containerPath = pathResolver.resolveContainerPath(in: epubDirectory),
                  let opfPath = pathResolver.resolveOPFPath(from: containerPath) else {
                throw NSError(domain: "EPUBParsingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to resolve OPF path"])
            }
            
            // Parse metadata
            let (title, author, metadata, coverImagePath) = metadataParser.parseMetadata(from: opfPath)
            
            // Resolve NCX path for TOC
            let ncxPath = pathResolver.resolveNCXPath(from: opfPath)
            
            // Parse TOC
            let tocItems = tocParser.parseTOC(from: opfPath, ncxURL: ncxPath)
            
            // Get spine items (chapter paths)
            let chapterPaths = spineService.getSpineItems(from: opfPath)
            
            // Load chapters
            var chapters: [Chapter] = []
            
            for (index, chapterPath) in chapterPaths.enumerated() {
                do {
                    let htmlContent = try String(contentsOf: chapterPath)
                    let chapterId = "chapter-\(index)"
                    
                    // Use chapter title from TOC if available
                    let chapterTitle = tocItems.first(where: { $0.chapterIndex == index })?.title ?? "Chapter \(index + 1)"
                    
                    // TODO: Implement proper HTML to plain text conversion
                    let plainTextContent = htmlContent.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    
                    let chapter = Chapter(
                        id: chapterId,
                        title: chapterTitle,
                        htmlContent: htmlContent,
                        plainTextContent: plainTextContent
                    )
                    
                    chapters.append(chapter)
                } catch {
                    print("Error parsing chapter at \(chapterPath): \(error)")
                }
            }
            
            // Create the book
            let book = Book(
                id: UUID(),
                title: title,
                author: author,
                coverImagePath: coverImagePath,
                chapters: chapters,
                metadata: metadata,
                filePath: url.path
            )
            
            return book
        } catch {
            print("Error parsing EPUB: \(error)")
            return nil
        }
    }
    
    func unzipToDirectory(from sourceURL: URL, destination: URL) throws -> Bool {
        return try zipService.unzip(from: sourceURL, to: destination)
    }
}

// MARK: - Default Implementations for Sub-Services

class DefaultEPUBExtractorService: EPUBExtractorService {
    private let zipService: EPUBZipService
    
    init(zipService: EPUBZipService) {
        self.zipService = zipService
    }
    
    func extractEPUB(at url: URL, to destinationURL: URL) throws -> URL {
        let extractedSuccess = try zipService.unzip(from: url, to: destinationURL)
        if extractedSuccess {
            return destinationURL
        } else {
            throw NSError(domain: "EPUBExtractorError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract EPUB"])
        }
    }
}

class DefaultEPUBZipService: EPUBZipService {
    func unzip(from sourceURL: URL, to destinationURL: URL) throws -> Bool {
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        
        // Use ZIPFoundation to extract the archive
        guard let archive = Archive(url: sourceURL, accessMode: .read) else {
            throw NSError(domain: "ZipError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open archive"])
        }
        
        for entry in archive {
            let entryURL = destinationURL.appendingPathComponent(entry.path)
            
            // Create directory if needed
            if entry.type == .directory {
                try FileManager.default.createDirectory(at: entryURL, withIntermediateDirectories: true)
            } else {
                // Extract file
                do {
                    // Create parent directory if needed
                    let parentDir = entryURL.deletingLastPathComponent()
                    try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
                    
                    // Extract the file
                    _ = try archive.extract(entry, to: entryURL)
                } catch {
                    print("Error extracting \(entry.path): \(error)")
                }
            }
        }
        
        return true
    }
} 
