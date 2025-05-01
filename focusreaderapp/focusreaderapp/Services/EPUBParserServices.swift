import Foundation

// MARK: - Path Resolver Service Implementation
class DefaultPathResolverService: PathResolverService {
    private let fileManager = FileManager.default
    
    func resolveContainerPath(in epubDirectory: URL) -> URL? {
        let containerPath = epubDirectory.appendingPathComponent("META-INF/container.xml")
        return fileManager.fileExists(atPath: containerPath.path) ? containerPath : nil
    }
    
    func resolveOPFPath(from containerXML: URL) -> URL? {
        guard let containerData = try? Data(contentsOf: containerXML),
              let xmlString = String(data: containerData, encoding: .utf8) else {
            return nil
        }
        
        // Simple XML parsing to find the OPF path
        if let range = xmlString.range(of: #"full-path="([^"]+).opf"#, options: .regularExpression) {
            let fullPathAttr = String(xmlString[range])
            if let opfPathRange = fullPathAttr.range(of: #"full-path="([^"]+)"#, options: .regularExpression) {
                let opfPathAttr = String(fullPathAttr[opfPathRange])
                let opfPath = opfPathAttr.replacingOccurrences(of: "full-path=\"", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                
                return containerXML.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(opfPath)
            }
        }
        
        return nil
    }
    
    func resolveNCXPath(from opfURL: URL) -> URL? {
        guard let opfData = try? Data(contentsOf: opfURL),
              let xmlString = String(data: opfData, encoding: .utf8) else {
            return nil
        }
        
        // Simple XML parsing to find the NCX path
        if let range = xmlString.range(of: #"href="([^"]+)\.ncx"#, options: .regularExpression) {
            let hrefAttr = String(xmlString[range])
            if let ncxPathRange = hrefAttr.range(of: #"href="([^"]+)"#, options: .regularExpression) {
                let ncxPathAttr = String(hrefAttr[ncxPathRange])
                let ncxPath = ncxPathAttr.replacingOccurrences(of: "href=\"", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                
                return resolveBaseDirectory(from: opfURL).appendingPathComponent(ncxPath)
            }
        }
        
        return nil
    }
    
    func resolveChapterPaths(from opfURL: URL) -> [URL] {
        let baseDirectory = resolveBaseDirectory(from: opfURL)
        
        guard let opfData = try? Data(contentsOf: opfURL),
              let xmlString = String(data: opfData, encoding: .utf8) else {
            return []
        }
        
        // Very simple XML parsing to find chapter paths
        var chapterPaths: [URL] = []
        let pattern = #"<item[^>]*href="([^"]+)"[^>]*media-type="application/xhtml\+xml"[^>]*/?>"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let matches = regex.matches(in: xmlString, options: [], range: NSRange(xmlString.startIndex..., in: xmlString))
            
            for match in matches {
                if let rangeOfHref = Range(match.range(at: 1), in: xmlString) {
                    let href = String(xmlString[rangeOfHref])
                    let chapterURL = baseDirectory.appendingPathComponent(href)
                    chapterPaths.append(chapterURL)
                }
            }
        } catch {
            print("Error parsing chapter paths: \(error)")
        }
        
        return chapterPaths
    }
    
    func resolveBaseDirectory(from opfURL: URL) -> URL {
        return opfURL.deletingLastPathComponent()
    }
}

// MARK: - Metadata Parser Service Implementation
class DefaultEPUBMetadataParserService: EPUBMetadataParserService {
    func parseMetadata(from opfPath: URL) -> (title: String, author: String, metadata: BookMetadata, coverPath: String?) {
        guard let opfData = try? Data(contentsOf: opfPath),
              let xmlString = String(data: opfData, encoding: .utf8) else {
            return ("Unknown", "Unknown", BookMetadata(), nil)
        }
        
        // Parse title
        let title = extractMetadataValue(from: xmlString, element: "dc:title") ?? "Unknown Title"
        
        // Parse author
        let author = extractMetadataValue(from: xmlString, element: "dc:creator") ?? "Unknown Author"
        
        // Parse other metadata
        let publisher = extractMetadataValue(from: xmlString, element: "dc:publisher")
        let language = extractMetadataValue(from: xmlString, element: "dc:language")
        let identifier = extractMetadataValue(from: xmlString, element: "dc:identifier")
        let description = extractMetadataValue(from: xmlString, element: "dc:description")
        let rights = extractMetadataValue(from: xmlString, element: "dc:rights")
        let source = extractMetadataValue(from: xmlString, element: "dc:source")
        let modified = extractMetadataValue(from: xmlString, element: "meta", attribute: "property", value: "dcterms:modified")
        
        // Parse subjects (categories/genres)
        var subjects: [String] = []
        let subjectPattern = #"<dc:subject[^>]*>(.*?)</dc:subject>"#
        
        do {
            let regex = try NSRegularExpression(pattern: subjectPattern, options: [])
            let matches = regex.matches(in: xmlString, options: [], range: NSRange(xmlString.startIndex..., in: xmlString))
            
            for match in matches {
                if let rangeOfSubject = Range(match.range(at: 1), in: xmlString) {
                    let subject = String(xmlString[rangeOfSubject])
                    subjects.append(subject)
                }
            }
        } catch {
            print("Error parsing subjects: \(error)")
        }
        
        // Extract cover image path
        var coverPath: String? = nil
        
        do {
            // First try to find the cover ID
            let coverIdPattern = #"<meta[^>]*name="cover"[^>]*content="([^"]+)"[^>]*/?>"#
            let regex = try NSRegularExpression(pattern: coverIdPattern, options: [])
            let matches = regex.matches(in: xmlString, options: [], range: NSRange(xmlString.startIndex..., in: xmlString))
            
            if let match = matches.first, let rangeOfCoverId = Range(match.range(at: 1), in: xmlString) {
                let coverId = String(xmlString[rangeOfCoverId])
                
                // Find the image path for the cover ID
                let coverHrefPattern = #"<item[^>]*id="\#(coverId)"[^>]*href="([^"]+)"[^>]*/?>"#
                let hrefRegex = try NSRegularExpression(pattern: coverHrefPattern, options: [])
                let hrefMatches = hrefRegex.matches(in: xmlString, options: [], range: NSRange(xmlString.startIndex..., in: xmlString))
                
                if let hrefMatch = hrefMatches.first, let rangeOfHref = Range(hrefMatch.range(at: 1), in: xmlString) {
                    let coverHref = String(xmlString[rangeOfHref])
                    let baseDir = opfPath.deletingLastPathComponent()
                    let coverImageURL = baseDir.appendingPathComponent(coverHref)
                    coverPath = coverImageURL.path
                }
            }
        } catch {
            print("Error parsing cover image: \(error)")
        }
        
        let metadata = BookMetadata(
            publisher: publisher,
            language: language,
            identifier: identifier,
            description: description,
            subjects: subjects,
            rights: rights,
            source: source,
            modified: modified
        )
        
        return (title, author, metadata, coverPath)
    }
    
    // Helper method to extract metadata values
    private func extractMetadataValue(from xmlString: String, element: String, attribute: String? = nil, value: String? = nil) -> String? {
        do {
            var pattern: String
            if let attribute = attribute, let value = value {
                pattern = #"<\#(element)[^>]*\#(attribute)="\#(value)"[^>]*>(.*?)</\#(element)>"#
            } else {
                pattern = #"<\#(element)[^>]*>(.*?)</\#(element)>"#
            }
            
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let matches = regex.matches(in: xmlString, options: [], range: NSRange(xmlString.startIndex..., in: xmlString))
            
            if let match = matches.first, let rangeOfValue = Range(match.range(at: 1), in: xmlString) {
                return String(xmlString[rangeOfValue])
            }
        } catch {
            print("Error extracting metadata value for \(element): \(error)")
        }
        
        return nil
    }
}

// MARK: - TOC Parsing Service Implementation
class DefaultTOCParsingService: TOCParsingService {
    func parseTOC(from opfURL: URL, ncxURL: URL?) -> [TocItem] {
        var tocItems: [TocItem] = []
        
        print("Parsing TOC from EPUB file")
        
        // First try to parse from NCX if available
        if let ncxURL = ncxURL {
            print("Attempting to parse TOC from NCX file: \(ncxURL.path)")
            tocItems = parseNCX(from: ncxURL)
            print("Found \(tocItems.count) TOC items from NCX")
        } else {
            print("No NCX file found for TOC")
        }
        
        // If no TOC items were found, try to parse from the OPF
        if tocItems.isEmpty {
            print("Attempting to parse TOC from OPF file: \(opfURL.path)")
            tocItems = parseOPF(from: opfURL)
            print("Found \(tocItems.count) TOC items from OPF")
        }
        
        return tocItems
    }
    
    private func parseNCX(from ncxURL: URL) -> [TocItem] {
        guard let ncxData = try? Data(contentsOf: ncxURL),
              let xmlString = String(data: ncxData, encoding: .utf8) else {
            print("Failed to load NCX data from \(ncxURL.path)")
            return []
        }
        
        var tocItems: [TocItem] = []
        
        // More flexible pattern to match navPoint elements in NCX files
        let pattern = #"<navPoint[^>]*id="([^"]+)".*?>\s*<navLabel.*?>\s*<text.*?>(.*?)</text>.*?<content[^>]*src="([^"]+)"[^>]*/?>"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            let matches = regex.matches(in: xmlString, options: [], range: NSRange(xmlString.startIndex..., in: xmlString))
            
            print("NCX regex found \(matches.count) matches")
            
            for (index, match) in matches.enumerated() {
                if let idRange = Range(match.range(at: 1), in: xmlString),
                   let titleRange = Range(match.range(at: 2), in: xmlString),
                   let hrefRange = Range(match.range(at: 3), in: xmlString) {
                    
                    let id = String(xmlString[idRange])
                    let title = String(xmlString[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let href = String(xmlString[hrefRange])
                    
                    print("Found TOC item: \(title) -> \(href)")
                    
                    let tocItem = TocItem(
                        id: id,
                        title: title,
                        href: href,
                        level: 0,
                        children: [],
                        chapterIndex: index
                    )
                    
                    tocItems.append(tocItem)
                }
            }
        } catch {
            print("Error parsing NCX: \(error)")
        }
        
        return tocItems
    }
    
    private func parseOPF(from opfURL: URL) -> [TocItem] {
        guard let opfData = try? Data(contentsOf: opfURL),
              let xmlString = String(data: opfData, encoding: .utf8) else {
            print("Failed to load OPF data from \(opfURL.path)")
            return []
        }
        
        var tocItems: [TocItem] = []
        
        // First try to find a manifest item that is the TOC
        let tocManifestPattern = #"<item[^>]*id="([^"]+)"[^>]*media-type="application/x-dtbncx\+xml"[^>]*href="([^"]+)"[^>]*/?>"#
        
        do {
            // Try to find a TOC item in the manifest
            let tocRegex = try NSRegularExpression(pattern: tocManifestPattern, options: [])
            let tocMatches = tocRegex.matches(in: xmlString, options: [], range: NSRange(xmlString.startIndex..., in: xmlString))
            
            if let tocMatch = tocMatches.first,
               let hrefRange = Range(tocMatch.range(at: 2), in: xmlString) {
                let tocHref = String(xmlString[hrefRange])
                let tocPath = opfURL.deletingLastPathComponent().appendingPathComponent(tocHref)
                
                print("Found TOC reference in OPF: \(tocHref)")
                
                // If we found a TOC reference, try to parse it directly
                if FileManager.default.fileExists(atPath: tocPath.path) {
                    print("Found NCX file at \(tocPath.path)")
                    return parseNCX(from: tocPath)
                }
            }
            
            // If no TOC was found or couldn't be parsed, fall back to spine items
            print("No TOC found in OPF, falling back to spine items")
            let pattern = #"<itemref[^>]*idref="([^"]+)"[^>]*/?>"#
            
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let matches = regex.matches(in: xmlString, options: [], range: NSRange(xmlString.startIndex..., in: xmlString))
            
            print("Found \(matches.count) spine items in OPF")
            
            for (index, match) in matches.enumerated() {
                if let idRefRange = Range(match.range(at: 1), in: xmlString) {
                    let idRef = String(xmlString[idRefRange])
                    
                    // Find the corresponding item to get the href
                    let itemPattern = #"<item[^>]*id="\#(idRef)"[^>]*href="([^"]+)"[^>]*/?>"#
                    let itemRegex = try NSRegularExpression(pattern: itemPattern, options: [])
                    let itemMatches = itemRegex.matches(in: xmlString, options: [], range: NSRange(xmlString.startIndex..., in: xmlString))
                    
                    if let itemMatch = itemMatches.first,
                       let hrefRange = Range(itemMatch.range(at: 1), in: xmlString) {
                        let href = String(xmlString[hrefRange])
                        let id = "toc-\(index)"
                        
                        // Try to extract a better title from the chapter file
                        var title = "Chapter \(index + 1)"
                        
                        // Try to read the HTML file to extract the title
                        let chapterPath = opfURL.deletingLastPathComponent().appendingPathComponent(href)
                        if let chapterContent = try? String(contentsOf: chapterPath, encoding: .utf8) {
                            // Look for title in the HTML
                            let titlePattern = #"<title[^>]*>(.*?)</title>"#
                            if let titleRegex = try? NSRegularExpression(pattern: titlePattern, options: [.dotMatchesLineSeparators]),
                               let titleMatch = titleRegex.firstMatch(in: chapterContent, options: [], range: NSRange(chapterContent.startIndex..., in: chapterContent)),
                               let titleRange = Range(titleMatch.range(at: 1), in: chapterContent) {
                                let extractedTitle = String(chapterContent[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                                if !extractedTitle.isEmpty {
                                    title = extractedTitle
                                }
                            }
                        }
                        
                        print("Found chapter: \(title) -> \(href)")
                        
                        let tocItem = TocItem(
                            id: id,
                            title: title,
                            href: href,
                            level: 0,
                            children: [],
                            chapterIndex: index
                        )
                        
                        tocItems.append(tocItem)
                    }
                }
            }
        } catch {
            print("Error parsing OPF: \(error)")
        }
        
        return tocItems
    }
}

// MARK: - Spine Service Implementation
class DefaultEPUBSpineService: EPUBSpineService {
    func getSpineItems(from opfURL: URL) -> [URL] {
        guard let opfData = try? Data(contentsOf: opfURL),
              let xmlString = String(data: opfData, encoding: .utf8) else {
            return []
        }
        
        var spineItems: [URL] = []
        
        do {
            // Find spine itemrefs
            let itemRefPattern = #"<itemref[^>]*idref="([^"]+)"[^>]*/?>"#
            let itemRefRegex = try NSRegularExpression(pattern: itemRefPattern, options: [])
            let itemRefMatches = itemRefRegex.matches(in: xmlString, options: [], range: NSRange(xmlString.startIndex..., in: xmlString))
            
            // Extract each ID reference from the spine
            var idRefs: [String] = []
            for match in itemRefMatches {
                if let idRefRange = Range(match.range(at: 1), in: xmlString) {
                    let idRef = String(xmlString[idRefRange])
                    idRefs.append(idRef)
                }
            }
            
            // Find the corresponding item with href for each id reference
            for idRef in idRefs {
                let itemPattern = #"<item[^>]*id="\#(idRef)"[^>]*href="([^"]+)"[^>]*/?>"#
                let itemRegex = try NSRegularExpression(pattern: itemPattern, options: [])
                let itemMatches = itemRegex.matches(in: xmlString, options: [], range: NSRange(xmlString.startIndex..., in: xmlString))
                
                if let itemMatch = itemMatches.first,
                   let hrefRange = Range(itemMatch.range(at: 1), in: xmlString) {
                    let href = String(xmlString[hrefRange])
                    let baseDir = opfURL.deletingLastPathComponent()
                    let chapterURL = baseDir.appendingPathComponent(href)
                    spineItems.append(chapterURL)
                }
            }
        } catch {
            print("Error getting spine items: \(error)")
        }
        
        return spineItems
    }
} 