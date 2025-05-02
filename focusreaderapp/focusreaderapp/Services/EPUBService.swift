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
            print("Starting to parse EPUB file at \(url.path)")
            
            // Create a temporary directory
            let tempDir = try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent(UUID().uuidString)
            
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            print("Created temporary directory at \(tempDir.path)")
            
            // Extract the EPUB to the temporary directory
            let epubDirectory = try extractor.extractEPUB(at: url, to: tempDir)
            print("Extracted EPUB to \(epubDirectory.path)")
            
            // Resolve paths for necessary files
            guard let containerPath = pathResolver.resolveContainerPath(in: epubDirectory) else {
                print("Failed to find container.xml in EPUB")
                throw NSError(domain: "EPUBParsingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to resolve container.xml path"])
            }
            print("Found container.xml at \(containerPath.path)")
            
            guard let opfPath = pathResolver.resolveOPFPath(from: containerPath) else {
                print("Failed to resolve OPF path from container.xml")
                throw NSError(domain: "EPUBParsingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to resolve OPF path"])
            }
            print("Found OPF file at \(opfPath.path)")
            
            // Parse metadata
            print("Parsing metadata from OPF")
            let (title, author, metadata, coverImagePath) = metadataParser.parseMetadata(from: opfPath)
            print("Parsed metadata - Title: \(title), Author: \(author)")
            
            // Resolve NCX path for TOC
            print("Resolving NCX path for TOC")
            let ncxPath = pathResolver.resolveNCXPath(from: opfPath)
            if let ncxPath = ncxPath {
                print("Found NCX file at \(ncxPath.path)")
            } else {
                print("No NCX file found")
            }
            
            // Parse TOC
            print("Parsing TOC")
            let tocItems = tocParser.parseTOC(from: opfPath, ncxURL: ncxPath)
            print("Parsed \(tocItems.count) TOC items")
            
            // Get spine items (chapter paths)
            print("Getting spine items (chapter paths)")
            let chapterPaths = spineService.getSpineItems(from: opfPath)
            print("Found \(chapterPaths.count) spine items")
            
            // Load chapters
            var chapters: [Chapter] = []
            
            for (index, chapterPath) in chapterPaths.enumerated() {
                do {
                    print("Loading chapter \(index + 1) from \(chapterPath.path)")
                    
                    guard fileManager.fileExists(atPath: chapterPath.path) else {
                        print("Chapter file does not exist: \(chapterPath.path)")
                        continue
                    }
                    
                    let htmlContent = try String(contentsOf: chapterPath, encoding: .utf8)
                    let chapterId = "chapter-\(index)"
                    
                    // Use chapter title from TOC if available
                    let chapterTitle: String
                    if let tocItem = tocItems.first(where: { $0.chapterIndex == index }) {
                        chapterTitle = tocItem.title
                    } else if let tocItem = tocItems.first(where: { 
                        guard let href = $0.href else { return false }
                        return chapterPath.lastPathComponent.contains(href) 
                    }) {
                        chapterTitle = tocItem.title
                    } else {
                        chapterTitle = "Chapter \(index + 1)"
                    }
                    print("Chapter \(index + 1) title: \(chapterTitle)")
                    
                    // Process HTML content to extract blocks and plain text
                    let plainTextContent = htmlContent.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    
                    // Extract images from the chapter
                    var chapterImages: [ChapterImage] = []
                    do {
                        let pattern = #"<img[^>]*src="([^"]+)"[^>]*>"#
                        let regex = try NSRegularExpression(pattern: pattern, options: [])
                        let matches = regex.matches(in: htmlContent, options: [], range: NSRange(htmlContent.startIndex..., in: htmlContent))
                        
                        for (imgIndex, match) in matches.enumerated() {
                            if let srcRange = Range(match.range(at: 1), in: htmlContent) {
                                let src = String(htmlContent[srcRange])
                                let imagePath = chapterPath.deletingLastPathComponent().appendingPathComponent(src).path
                                
                                if fileManager.fileExists(atPath: imagePath) {
                                    let image = ChapterImage(
                                        id: "img-\(index)-\(imgIndex)",
                                        name: src,
                                        caption: nil,
                                        imagePath: imagePath,
                                        altText: nil,
                                        sourceURL: nil
                                    )
                                    chapterImages.append(image)
                                }
                            }
                        }
                    } catch {
                        print("Error extracting images: \(error)")
                    }
                    
                    let chapter = Chapter(
                        id: chapterId,
                        title: chapterTitle,
                        htmlContent: htmlContent,
                        plainTextContent: plainTextContent,
                        blocks: [],
                        images: chapterImages
                    )
                    
                    chapters.append(chapter)
                } catch {
                    print("Error parsing chapter at \(chapterPath): \(error)")
                }
            }
            
            // If no chapters were loaded, try using the resolver's chapter paths as a fallback
            if chapters.isEmpty {
                print("No chapters loaded from spine, trying pathResolver as fallback")
                let fallbackChapterPaths = pathResolver.resolveChapterPaths(from: opfPath)
                
                for (index, chapterPath) in fallbackChapterPaths.enumerated() {
                    do {
                        print("Loading fallback chapter \(index + 1) from \(chapterPath.path)")
                        
                        guard fileManager.fileExists(atPath: chapterPath.path) else {
                            print("Fallback chapter file does not exist: \(chapterPath.path)")
                            continue
                        }
                        
                        let htmlContent = try String(contentsOf: chapterPath, encoding: .utf8)
                        let chapterId = "chapter-\(index)"
                        let chapterTitle = "Chapter \(index + 1)"
                        
                        // Process HTML content to extract plain text
                        let plainTextContent = htmlContent.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        
                        let chapter = Chapter(
                            id: chapterId,
                            title: chapterTitle,
                            htmlContent: htmlContent,
                            plainTextContent: plainTextContent
                        )
                        
                        chapters.append(chapter)
                    } catch {
                        print("Error parsing fallback chapter at \(chapterPath): \(error)")
                    }
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
                filePath: url.path,
                tocItems: tocItems
            )
            
            print("Successfully created book with \(chapters.count) chapters and \(tocItems.count) TOC items")
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
        do {
            let archive = try Archive(url: sourceURL, accessMode: .read)
            
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
        } catch {
            print("Error opening archive: \(error)")
            throw error
        }
    }
} 
