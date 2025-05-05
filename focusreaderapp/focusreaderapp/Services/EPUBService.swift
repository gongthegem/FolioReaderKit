import Foundation
import ZIPFoundation
import UIKit

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
    private let resourceManager: EPUBResourceManager
    
    init(
        extractor: EPUBExtractorService,
        metadataParser: EPUBMetadataParserService,
        tocParser: TOCParsingService,
        pathResolver: PathResolverService,
        spineService: EPUBSpineService,
        zipService: EPUBZipService,
        resourceManager: EPUBResourceManager = DefaultEPUBResourceManager()
    ) {
        self.extractor = extractor
        self.metadataParser = metadataParser
        self.tocParser = tocParser
        self.pathResolver = pathResolver
        self.spineService = spineService
        self.zipService = zipService
        self.resourceManager = resourceManager
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
            print("\n======== DETAILED SPINE DEBUGGING ========")
            print("Getting spine items (chapter paths) from OPF file: \(opfPath.path)")
            
            // Debug: List files in OPF directory
            let opfDir = opfPath.deletingLastPathComponent()
            print("Files in OPF directory:")
            if let files = try? fileManager.contentsOfDirectory(atPath: opfDir.path) {
                for (index, file) in files.enumerated() {
                    print("  \(index): \(file)")
                }
            } else {
                print("  Failed to list files in OPF directory")
            }
            
            // Debug: Print OPF content
            if let opfContent = try? String(contentsOf: opfPath, encoding: .utf8) {
                print("\nOPF content sample (first 500 chars):")
                print(opfContent.prefix(500))
                
                // Look for spine and manifest elements
                print("\nSearching for spine elements in OPF:")
                if let spineRange = opfContent.range(of: "<spine[^>]*>.*?</spine>", options: .regularExpression) {
                    let spineContent = opfContent[spineRange]
                    print("Found spine content: \(spineContent)")
                } else {
                    print("No spine element found in OPF!")
                }
                
                print("\nSearching for manifest elements in OPF:")
                if let manifestRange = opfContent.range(of: "<manifest[^>]*>.*?</manifest>", options: .regularExpression) {
                    let manifestContent = String(opfContent[manifestRange])
                    print("Found manifest content (first 500 chars): \(manifestContent.prefix(500))")
                    
                    // Count items in manifest
                    let itemMatches = manifestContent.matches(of: /<item[^>]*>/)
                    print("Found \(itemMatches.count) items in manifest")
                } else {
                    print("No manifest element found in OPF!")
                }
            } else {
                print("Failed to read OPF content!")
            }
            
            let chapterPaths = spineService.getSpineItems(from: opfPath)
            print("Got \(chapterPaths.count) spine items from spine service")
            
            // Debug - list all spine items
            for (index, path) in chapterPaths.enumerated() {
                print("  Spine item \(index): \(path.path)")
                print("  - Exists: \(FileManager.default.fileExists(atPath: path.path))")
                print("  - Size: \((try? FileManager.default.attributesOfItem(atPath: path.path)[.size] as? Int) ?? 0) bytes")
                
                // Try to read the start of the file content
                if let fileContent = try? String(contentsOf: path, encoding: .utf8) {
                    print("  - Content preview: \(fileContent.prefix(100))")
                    
                    // Check if it contains basic HTML structure
                    let hasHtmlTag = fileContent.range(of: "<html", options: .caseInsensitive) != nil
                    let hasBodyTag = fileContent.range(of: "<body", options: .caseInsensitive) != nil
                    print("  - Has HTML tag: \(hasHtmlTag), Body tag: \(hasBodyTag)")
                } else {
                    print("  - ❌ Could not read file content")
                }
            }
            
            // Load chapters
            var chapters: [Chapter] = []
            
            print("\n======== DETAILED CHAPTER CREATION DEBUGGING ========")
            
            for (index, chapterPath) in chapterPaths.enumerated() {
                do {
                    print("\nProcessing chapter file \(index + 1): \(chapterPath.path)")
                    
                    guard fileManager.fileExists(atPath: chapterPath.path) else {
                        print("❌ Chapter file does not exist: \(chapterPath.path)")
                        continue
                    }
                    
                    // Read the content with explicit encoding types to debug potential encoding issues
                    let encodingsToTry: [String.Encoding] = [.utf8, .ascii, .isoLatin1, .isoLatin2, .unicode]
                    var contentString: String = ""
                    var usedEncoding: String.Encoding = .utf8
                    var readSuccess = false
                    
                    // Try different encodings
                    for encoding in encodingsToTry {
                        if let content = try? String(contentsOf: chapterPath, encoding: encoding) {
                            contentString = content
                            usedEncoding = encoding
                            readSuccess = true
                            print("- Read HTML content using encoding: \(encoding.description), \(content.count) bytes")
                            break
                        }
                    }
                    
                    // Fallback to data approach if no encoding worked
                    if !readSuccess {
                        print("❌ Could not read file with any encoding. Trying data approach...")
                        if let data = try? Data(contentsOf: chapterPath),
                           let content = String(data: data, encoding: .utf8) {
                            contentString = content
                            usedEncoding = .utf8
                            readSuccess = true
                            print("- Successfully read content using data approach, \(content.count) bytes")
                        } else {
                            print("❌ Complete failure to read file content")
                            continue
                        }
                    }
                    
                    print("- Content starts with: \(contentString.prefix(50))")
                    
                    // Validate that content has HTML structure
                    let hasHtmlTag = contentString.range(of: "<html", options: .caseInsensitive) != nil
                    let hasBodyTag = contentString.range(of: "<body", options: .caseInsensitive) != nil
                    print("- Has HTML tag: \(hasHtmlTag), Body tag: \(hasBodyTag)")
                    
                    // Debug: Check content type/media type
                    let isXhtml = contentString.range(of: "<!DOCTYPE html", options: .caseInsensitive) != nil || 
                                  contentString.range(of: "<html xmlns=", options: .caseInsensitive) != nil
                    print("- Appears to be XHTML: \(isXhtml)")
                    
                    let chapterId = "chapter-\(index)"
                    
                    // Use chapter title from TOC if available
                    let chapterTitle: String
                    if let tocItem = tocItems.first(where: { $0.chapterIndex == index }) {
                        chapterTitle = tocItem.title
                        print("- Using title from TOC index match: \(chapterTitle)")
                    } else if let tocItem = tocItems.first(where: { tocItem in
                        if let href = tocItem.href {
                            return chapterPath.lastPathComponent.contains(href)
                        }
                        return false
                    }) {
                        chapterTitle = tocItem.title
                        print("- Using title from TOC href match: \(chapterTitle)")
                    } else {
                        chapterTitle = "Chapter \(index + 1)"
                        print("- Using default title: \(chapterTitle)")
                    }
                    
                    // Process HTML content to extract blocks and plain text
                    let plainTextContent = contentString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    print("- Extracted plain text content, \(plainTextContent.count) bytes")
                    print("- Plain text starts with: \(plainTextContent.prefix(50))")
                    
                    // Extract images from the chapter
                    var chapterImages: [ChapterImage] = []
                    do {
                        let pattern = #"<img[^>]*src="([^"]+)"[^>]*>"#
                        let regex = try NSRegularExpression(pattern: pattern, options: [])
                        let matches = regex.matches(in: contentString, options: [], range: NSRange(contentString.startIndex..., in: contentString))
                        
                        print("- Found \(matches.count) images in chapter")
                        
                        for (imgIndex, match) in matches.enumerated() {
                            if let srcRange = Range(match.range(at: 1), in: contentString) {
                                let src = String(contentString[srcRange])
                                let imagePath = chapterPath.deletingLastPathComponent().appendingPathComponent(src).path
                                
                                if fileManager.fileExists(atPath: imagePath) {
                                    print("  - Image \(imgIndex): \(src) exists at path")
                                    let image = ChapterImage(
                                        id: "img-\(index)-\(imgIndex)",
                                        name: src,
                                        caption: nil,
                                        imagePath: imagePath,
                                        altText: nil,
                                        sourceURL: nil
                                    )
                                    chapterImages.append(image)
                                } else {
                                    print("  - Image \(imgIndex): \(src) not found at path: \(imagePath)")
                                }
                            }
                        }
                    } catch {
                        print("- Error extracting images: \(error)")
                    }
                    
                    let chapter = Chapter(
                        id: chapterId,
                        title: chapterTitle,
                        htmlContent: contentString,
                        plainTextContent: plainTextContent,
                        blocks: [],
                        images: chapterImages
                    )
                    
                    print("✅ Successfully created chapter: \(chapterTitle) with \(plainTextContent.count) bytes of text and \(chapterImages.count) images")
                    chapters.append(chapter)
                } catch {
                    print("❌ Error parsing chapter at \(chapterPath): \(error)")
                }
            }
            
            print("\n======== Chapter creation summary ========")
            print("Successfully created \(chapters.count) chapters from \(chapterPaths.count) spine items")
            
            // If no chapters were loaded, try using the resolver's chapter paths as a fallback
            if chapters.isEmpty {
                print("\n======== No chapters loaded from spine, trying pathResolver as fallback ========")
                let fallbackChapterPaths = pathResolver.resolveChapterPaths(from: opfPath)
                print("Found \(fallbackChapterPaths.count) fallback chapter paths")
                
                for (index, chapterPath) in fallbackChapterPaths.enumerated() {
                    do {
                        print("\nLoading fallback chapter \(index + 1) from \(chapterPath.path)")
                        
                        guard fileManager.fileExists(atPath: chapterPath.path) else {
                            print("❌ Fallback chapter file does not exist: \(chapterPath.path)")
                            continue
                        }
                        
                        let htmlContent = try String(contentsOf: chapterPath, encoding: .utf8)
                        print("- Read HTML content, \(htmlContent.count) bytes")
                        let chapterId = "chapter-\(index)"
                        let chapterTitle = "Chapter \(index + 1)"
                        
                        // Process HTML content to extract plain text
                        let plainTextContent = htmlContent.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        print("- Extracted plain text content, \(plainTextContent.count) bytes")
                        
                        let chapter = Chapter(
                            id: chapterId,
                            title: chapterTitle,
                            htmlContent: htmlContent,
                            plainTextContent: plainTextContent
                        )
                        
                        print("✅ Successfully created fallback chapter: \(chapterTitle) with \(plainTextContent.count) bytes of text")
                        chapters.append(chapter)
                    } catch {
                        print("❌ Error parsing fallback chapter at \(chapterPath): \(error)")
                    }
                }
            }
            
            // Manual fallback if still no chapters
            if chapters.isEmpty {
                print("\n======== All chapter loading methods failed, creating a placeholder chapter ========")
                let placeholderChapter = Chapter(
                    id: "placeholder",
                    title: "Unable to Load Content",
                    htmlContent: "<html><body><h1>Unable to Load Content</h1><p>The EPUB file could not be properly parsed. This may be due to an unsupported format or corrupted file.</p></body></html>",
                    plainTextContent: "Unable to Load Content. The EPUB file could not be properly parsed."
                )
                chapters.append(placeholderChapter)
                print("✅ Created placeholder chapter")
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
            
            print("\n======== Book creation summary ========")
            print("Successfully created book:")
            print("- Title: \(book.title)")
            print("- Author: \(book.author)")
            print("- Chapters: \(book.chapters.count)")
            print("- TOC items: \(book.tocItems.count)")
            print("- Has cover image: \(book.coverImagePath != nil)")
            
            return book
        } catch {
            print("\n======== EPUB parsing error ========")
            print("Error parsing EPUB: \(error)")
            return nil
        }
    }
    
    func unzipToDirectory(from sourceURL: URL, destination: URL) throws -> Bool {
        return try zipService.unzip(from: sourceURL, to: destination)
    }
    
    private func parseFromExtractedDirectory(_ extractedDir: URL, bookId: String, originalURL: URL) -> Book? {
        print("\n======== PARSING EXTRACTED DIRECTORY ========")
        print("Extracted directory: \(extractedDir.path)")
        print("Book ID: \(bookId)")
        
        // 1. Find container.xml
        guard let containerPath = pathResolver.resolveContainerPath(in: extractedDir) else {
            print("❌ Error: container.xml not found in META-INF directory")
            return nil
        }
        
        print("✅ Found container.xml at: \(containerPath.path)")
        
        // 2. Find OPF file path
        guard let opfPath = pathResolver.resolveOPFPath(from: containerPath) else {
            print("❌ Error: OPF file not found from container.xml")
            return nil
        }
        
        print("✅ Found OPF file at: \(opfPath.path)")
        
        // 3. Extract NCX file path (optional)
        let ncxPath = pathResolver.resolveNCXPath(from: opfPath)
        print(ncxPath != nil ? "✅ Found NCX file at: \(ncxPath!.path)" : "No NCX file found")
        
        // 4. Load resources from the manifest
        let resources = resourceManager.resolveManifestResources(from: opfPath)
        print("✅ Processed \(resources.count) resources from manifest")
        
        // 5. Get spine items using the resource manager
        let chapterPaths = spineService.getSpineItems(from: opfPath)
        print("✅ Found \(chapterPaths.count) spine items")
        
        if chapterPaths.isEmpty {
            print("❌ No spine items found - cannot create book")
            return nil
        }
        
        // 6. Parse metadata
        let (title, author, metadata, coverPath) = metadataParser.parseMetadata(from: opfPath)
        print("✅ Parsed metadata - Title: \(title), Author: \(author)")
        
        // 7. Parse TOC
        let tocItems = tocParser.parseTOC(from: opfPath, ncxURL: ncxPath)
        print("✅ Parsed TOC with \(tocItems.count) entries")
        
        // 8. Load chapters
        var chapters: [Chapter] = []
        
        print("\n======== LOADING CHAPTERS ========")
        for (index, path) in chapterPaths.enumerated() {
            print("Loading chapter \(index) from: \(path.path)")
            
            do {
                // Verify file exists
                guard fileManager.fileExists(atPath: path.path) else {
                    print("❌ Chapter file does not exist at: \(path.path)")
                    continue
                }
                
                // Try to read content with a more robust approach
                let chapterContent = try String(contentsOf: path, encoding: .utf8)
                
                // Create chapter
                let chapterId = "chapter-\(index)"
                let chapterTitle = "Chapter \(index + 1)"
                
                // Create chapter with relative path for storage
                let relativePath = path.path.replacingOccurrences(of: extractedDir.path, with: "")
                
                let chapter = Chapter(
                    id: chapterId,
                    title: chapterTitle,
                    htmlContent: chapterContent,
                    plainTextContent: chapterContent.stripHTML()
                )
                
                chapters.append(chapter)
                print("✅ Added chapter: \(chapterTitle)")
            } catch {
                print("❌ Error loading chapter: \(error)")
                
                // Try alternative encodings if UTF-8 failed
                let alternativeEncodings: [String.Encoding] = [.ascii, .isoLatin1, .windowsCP1252, .macOSRoman]
                var loaded = false
                
                for encoding in alternativeEncodings {
                    if loaded { break }
                    
                    do {
                        let chapterContent = try String(contentsOf: path, encoding: encoding)
                        
                        let chapterId = "chapter-\(index)"
                        let chapterTitle = "Chapter \(index + 1)"
                        
                        let chapter = Chapter(
                            id: chapterId,
                            title: chapterTitle,
                            htmlContent: chapterContent,
                            plainTextContent: chapterContent.stripHTML()
                        )
                        
                        chapters.append(chapter)
                        print("✅ Added chapter with alternative encoding (\(encoding)): \(chapterTitle)")
                        loaded = true
                    } catch {
                        // Continue to the next encoding
                    }
                }
                
                if !loaded {
                    print("❌ Failed to load chapter with any encoding")
                }
            }
        }
        
        if chapters.isEmpty {
            print("❌ No chapters could be loaded - cannot create book")
            return nil
        }
        
        // Create and return the Book object
        print("✅ Successfully parsed book: \(title) with \(chapters.count) chapters")
        
        return Book(
            id: UUID(uuidString: bookId) ?? UUID(),
            title: title,
            author: author,
            coverImagePath: coverPath,
            chapters: chapters,
            metadata: metadata,
            filePath: originalURL.path,
            tocItems: tocItems
        )
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

// Helper extension to strip HTML tags
extension String {
    func stripHTML() -> String {
        // A simple replacement method - not complete but sufficient for basic stripping
        return self
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&[^;]+;", with: " ", options: .regularExpression)
    }
} 
