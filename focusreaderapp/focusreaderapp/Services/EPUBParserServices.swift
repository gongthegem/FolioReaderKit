import Foundation

// MARK: - EPUB Resource Manager
protocol EPUBResourceManager {
    func registerResource(id: String, url: URL, mediaType: String)
    func getResourceURL(id: String) -> URL?
    func getResourceURL(href: String, relativeTo: URL) -> URL?
    func resolveManifestResources(from opfURL: URL) -> [String: URL]
    func getResourceMediaType(id: String) -> String?
    func getAllResources() -> [String: URL]
}

class DefaultEPUBResourceManager: EPUBResourceManager {
    private var resources: [String: (url: URL, mediaType: String)] = [:]
    private var baseURL: URL?
    
    func registerResource(id: String, url: URL, mediaType: String) {
        resources[id] = (url: url, mediaType: mediaType)
    }
    
    func getResourceURL(id: String) -> URL? {
        return resources[id]?.url
    }
    
    func getResourceURL(href: String, relativeTo: URL) -> URL? {
        // First check if we have an ID matching this href
        if let resource = resources.first(where: { $0.value.url.lastPathComponent == href }) {
            return resource.value.url
        }
        
        // Otherwise construct a URL relative to the base
        return URL(string: href, relativeTo: relativeTo)
    }
    
    func getResourceMediaType(id: String) -> String? {
        return resources[id]?.mediaType
    }
    
    func getAllResources() -> [String: URL] {
        return resources.mapValues { $0.url }
    }
    
    func resolveManifestResources(from opfURL: URL) -> [String: URL] {
        guard let opfData = try? Data(contentsOf: opfURL),
              let xmlString = String(data: opfData, encoding: .utf8) else {
            print("❌ Failed to read OPF file for manifest resources")
            return [:]
        }
        
        self.baseURL = opfURL.deletingLastPathComponent()
        var foundResources: [String: URL] = [:]
        
        // Look for item elements in the manifest
        let manifestPattern = #"<manifest[^>]*>(.*?)</manifest>"#
        if let manifestRange = xmlString.range(of: manifestPattern, options: .regularExpression) {
            let manifestContent = String(xmlString[manifestRange])
            
            // Find all item elements
            let itemPattern = #"<item([^>]*)>"#
            let itemMatches = manifestContent.matches(of: try! Regex(itemPattern))
            
            for match in itemMatches {
                let itemAttributes = String(match.0)
                
                // Extract id, href and media-type
                if let idMatch = itemAttributes.range(of: #"id="([^"]*)"#, options: .regularExpression),
                   let hrefMatch = itemAttributes.range(of: #"href="([^"]*)"#, options: .regularExpression),
                   let mediaTypeMatch = itemAttributes.range(of: #"media-type="([^"]*)"#, options: .regularExpression) {
                    
                    // Extract values from attributes
                    var id = String(itemAttributes[idMatch])
                    id = id.replacingOccurrences(of: "id=\"", with: "").replacingOccurrences(of: "\"", with: "")
                    
                    var href = String(itemAttributes[hrefMatch])
                    href = href.replacingOccurrences(of: "href=\"", with: "").replacingOccurrences(of: "\"", with: "")
                    
                    var mediaType = String(itemAttributes[mediaTypeMatch])
                    mediaType = mediaType.replacingOccurrences(of: "media-type=\"", with: "").replacingOccurrences(of: "\"", with: "")
                    
                    // Create URL for resource
                    if let baseURL = baseURL {
                        let resourceURL = baseURL.appendingPathComponent(href)
                        registerResource(id: id, url: resourceURL, mediaType: mediaType)
                        foundResources[id] = resourceURL
                    }
                }
            }
        }
        
        print("📚 Registered \(resources.count) resources from manifest")
        resources.forEach { id, resource in
            print("  - Resource: \(id), URL: \(resource.url.path), Type: \(resource.mediaType)")
        }
        
        return foundResources
    }
}

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
            let regex = try NSRegularExpression(pattern: pattern, options: [])
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
    private var resourceManager: EPUBResourceManager?
    
    func getSpineItems(from opfURL: URL) -> [URL] {
        guard let opfData = try? Data(contentsOf: opfURL),
              let xmlString = String(data: opfData, encoding: .utf8) else {
            print("❌ Failed to read OPF file for spine items")
            return []
        }
        
        // Create and initialize the resource manager
        let resourceManager = DefaultEPUBResourceManager()
        let resources = resourceManager.resolveManifestResources(from: opfURL)
        self.resourceManager = resourceManager
        
        print("\n======== 📖 SPINE EXTRACTION PROCESS ========")
        print("Base directory: \(opfURL.deletingLastPathComponent().path)")
            
        // First get the spine element
        let spineItems: [URL] = []
        var itemrefs: [(idref: String, linear: Bool)] = []
        
        // Extract spine items references
        let spinePattern = #"<spine[^>]*>(.*?)</spine>"#
        if let spineRange = xmlString.range(of: spinePattern, options: [.regularExpression]) {
            let spineContent = String(xmlString[spineRange])
            print("Found spine element: \(spineContent.prefix(50))...")
            
            // Extract all itemref elements
            let itemrefPattern = #"<itemref([^>]*)/?>"#
            let itemrefMatches = spineContent.matches(of: try! Regex(itemrefPattern))
            
            for match in itemrefMatches {
                let itemrefAttributes = String(match.0)
                
                // Extract idref attribute
                if let idrefMatch = itemrefAttributes.range(of: #"idref="([^"]*)"#, options: .regularExpression) {
                    var idref = String(itemrefAttributes[idrefMatch])
                    idref = idref.replacingOccurrences(of: "idref=\"", with: "").replacingOccurrences(of: "\"", with: "")
                
                    // Check if item is linear (default is true)
                    var linear = true
                    if let linearMatch = itemrefAttributes.range(of: #"linear="([^"]*)"#, options: .regularExpression) {
                        let linearValue = String(itemrefAttributes[linearMatch])
                            .replacingOccurrences(of: "linear=\"", with: "")
                            .replacingOccurrences(of: "\"", with: "")
                        linear = linearValue != "no"
                    }
                    
                    itemrefs.append((idref: idref, linear: linear))
                }
            }
                    } else {
            print("❌ No spine element found in OPF file")
        }
        
        // Convert itemrefs to URLs using the resource manager
        var spineURLs: [URL] = []
        
        print("\n📚 Found \(itemrefs.count) spine items (itemrefs):")
        for (index, itemref) in itemrefs.enumerated() {
            print("  📄 Spine item \(index): idref=\(itemref.idref), linear=\(itemref.linear)")
            if let resourceURL = resourceManager.getResourceURL(id: itemref.idref) {
                print("    ✅ Resolved to: \(resourceURL.path)")
                if FileManager.default.fileExists(atPath: resourceURL.path) {
                    print("    ✅ File exists at path")
                    spineURLs.append(resourceURL)
                } else {
                    print("    ❌ File does not exist at resolved path")
                }
            } else {
                print("    ❌ Could not resolve resource URL for idref: \(itemref.idref)")
            }
        }
        
        // Fallback: If no spine items were found, try to find XHTML files in the package
        if spineURLs.isEmpty {
            print("\n⚠️ No spine items found using spine element, trying fallback methods...")
            
            // Try to find all HTML/XHTML resources in the manifest
            let htmlResources = resources.filter { id, _ in 
                let mediaType = resourceManager.getResourceMediaType(id: id) ?? ""
                return mediaType.contains("html") || mediaType.contains("xhtml")
            }
            
            if !htmlResources.isEmpty {
                print("✅ Found \(htmlResources.count) HTML resources in manifest")
                spineURLs = Array(htmlResources.values)
                    .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
                    } else {
                print("❌ No HTML resources found in manifest")
                        
                // Last resort: Directory scan for HTML/XHTML files
                let baseDir = opfURL.deletingLastPathComponent()
                print("🔍 Scanning directory for HTML/XHTML files: \(baseDir.path)")
                        
                if let contents = try? FileManager.default.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil) {
                    let htmlFiles = contents.filter { 
                        $0.pathExtension.lowercased() == "html" || 
                        $0.pathExtension.lowercased() == "xhtml" || 
                        $0.pathExtension.lowercased() == "htm"
                    }
                    
                    if !htmlFiles.isEmpty {
                        print("✅ Found \(htmlFiles.count) HTML files by scanning directory")
                        spineURLs = htmlFiles.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
                        }
                    }
                }
            }
            
        if spineURLs.isEmpty {
            print("❌ Could not find any spine items using any method")
        } else {
            print("\n📚 Final spine items list (\(spineURLs.count) items):")
            for (index, url) in spineURLs.enumerated() {
                print("  \(index): \(url.path)")
            }
        }
        
        return spineURLs
                }
            }
            
// Extension to make code cleaner
extension String {
    var deletingPathExtension: String {
        (self as NSString).deletingPathExtension
        }
    }

