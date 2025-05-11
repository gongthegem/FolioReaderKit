import Foundation
import SwiftUI
import SwiftSoup

class ContentProcessor {
    static let shared = ContentProcessor()
    
    private init() {}
    
    // MARK: - Chapter Processing
    
    func processChapter(chapter: Chapter, fontSize: CGFloat) -> ProcessedChapter {
        LoggingService.shared.debug("Processing chapter: \(chapter.title)", category: .contentProcessing)
        LoggingService.shared.debug("HTML content length: \(chapter.htmlContent.count)", category: .contentProcessing)
        LoggingService.shared.debug("Plain text content length: \(chapter.plainTextContent.count)", category: .contentProcessing)
        
        // Check for empty content
        if chapter.htmlContent.isEmpty {
            LoggingService.shared.error("Empty HTML content for chapter: \(chapter.title)", category: .contentProcessing)
        }
        
        // Process HTML content
        let processedHTMLContent = generateHTMLContent(
            chapter: chapter,
            options: ContentDisplayOptions(fontSize: fontSize)
        )
        LoggingService.shared.debug("Generated HTML content length: \(processedHTMLContent.count)", category: .contentProcessing)
        
        return ProcessedChapter(
            originalChapter: chapter,
            processedTextContent: chapter.plainTextContent,
            processedHTMLContent: processedHTMLContent
        )
    }
    
    // MARK: - HTML Processing
    
    func generateHTMLContent(chapter: Chapter, options: ContentDisplayOptions) -> String {
        LoggingService.shared.debug("Generating HTML content for chapter: \(chapter.title)", category: .contentProcessing)
        
        // Check for empty content
        if chapter.htmlContent.isEmpty {
            LoggingService.shared.error("Empty HTML content for generating processed HTML", category: .contentProcessing)
            return HTMLRenderer.shared.wrapContentInHTML(content: "<p>No content available</p>", options: options)
        }
        
        // Process the HTML content with SwiftSoup
        do {
            let doc = try SwiftSoup.parse(chapter.htmlContent)
            
            // Handle special elements (images, tables, etc.)
            handleSpecialElements(doc: doc)
            
            // Get the modified HTML
            let processedHTML = try doc.html()
            LoggingService.shared.debug("Processed HTML length: \(processedHTML.count)", category: .contentProcessing)
            
            // Wrap the processed HTML with appropriate styles
            let wrappedHTML = HTMLRenderer.shared.wrapContentInHTML(content: processedHTML, options: options)
            LoggingService.shared.debug("Wrapped HTML length: \(wrappedHTML.count)", category: .contentProcessing)
            
            return wrappedHTML
        } catch {
            LoggingService.shared.error("Error processing HTML: \(error.localizedDescription)", category: .contentProcessing)
            
            // Fallback to wrapping the original HTML
            return HTMLRenderer.shared.wrapContentInHTML(content: chapter.htmlContent, options: options)
        }
    }
    
    private func handleSpecialElements(doc: SwiftSoup.Document) {
        do {
            // Add CSS classes to headings
            try doc.select("h1, h2, h3, h4, h5, h6").forEach { element in
                try element.addClass("reader-heading")
            }
            
            // Enhance images
            try doc.select("img").forEach { element in
                try element.addClass("reader-image")
                if !element.hasAttr("alt") {
                    try element.attr("alt", "Image")
                }
            }
            
            // Mark blockquotes
            try doc.select("blockquote").forEach { element in
                try element.addClass("reader-blockquote")
            }
            
            // Add non-breaking spaces to empty paragraphs
            try doc.select("p").forEach { element in
                if try element.text().isEmpty {
                    try element.text(" ")
                }
            }
            
            // Ensure body has content
            if try doc.select("body").isEmpty() {
                try doc.append("<body><p>Content appears to be missing. Please try reloading.</p></body>")
                LoggingService.shared.warning("Document had no body, added placeholder", category: .contentProcessing)
            }
        } catch {
            LoggingService.shared.error("Error handling special elements: \(error.localizedDescription)", category: .contentProcessing)
        }
    }
    
    // MARK: - Attributed String Conversion
    
    func convertToAttributedString(html: String, fontSize: CGFloat) -> NSAttributedString {
        LoggingService.shared.debug("Converting HTML to attributed string, HTML length: \(html.count)", category: .contentProcessing)
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        // Wrap the HTML with basic styling
        let styledHTML = """
        <html>
        <head>
        <style>
        body {
            font-family: -apple-system, sans-serif;
            font-size: \(fontSize)px;
        }
        </style>
        </head>
        <body>
        \(html)
        </body>
        </html>
        """
        
        guard let data = styledHTML.data(using: .utf8) else {
            LoggingService.shared.error("Failed to convert HTML to data", category: .contentProcessing)
            return NSAttributedString(string: "Error converting content")
        }
        
        do {
            let attributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            return attributedString
        } catch {
            LoggingService.shared.error("Error creating attributed string: \(error.localizedDescription)", category: .contentProcessing)
            return NSAttributedString(string: "Error converting content")
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 