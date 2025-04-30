import Foundation
import SwiftUI
import SwiftSoup

class ContentProcessor {
    static let shared = ContentProcessor()
    
    private init() {}
    
    // MARK: - Chapter Processing
    
    func processChapter(chapter: Chapter, fontSize: CGFloat) -> ProcessedChapter {
        // Extract sentences from plain text content
        let sentences = extractSentences(from: chapter.plainTextContent)
        
        // Compute sentence ranges
        let sentenceRanges = computeSentenceRanges(text: chapter.plainTextContent)
        
        // Process HTML content
        let processedHTMLContent = generateHTMLContent(
            chapter: chapter,
            options: ContentDisplayOptions(fontSize: fontSize)
        )
        
        // Create attributed strings for each sentence (for speed reading mode)
        let attributedSentences = sentences.map { sentence in
            convertToAttributedString(html: "<p>\(sentence)</p>", fontSize: fontSize)
        }
        
        return ProcessedChapter(
            originalChapter: chapter,
            processedTextContent: chapter.plainTextContent,
            sentences: sentences,
            sentenceRanges: sentenceRanges,
            attributedSentences: attributedSentences,
            processedHTMLContent: processedHTMLContent
        )
    }
    
    // MARK: - Sentence Extraction
    
    func extractSentences(from text: String) -> [String] {
        // Simple sentence extraction based on punctuation
        let sentenceSeparators = ".!?"
        var sentences: [String] = []
        var currentSentence = ""
        
        for char in text {
            currentSentence.append(char)
            
            if sentenceSeparators.contains(char) {
                // Check if the next character is a space or newline or end of string
                if let nextIndex = text.firstIndex(of: char)?.encodedOffset, 
                   nextIndex + 1 < text.count, 
                   [" ", "\n"].contains(text[text.index(text.startIndex, offsetBy: nextIndex + 1)]) {
                    
                    // Trim whitespace and add to sentences
                    let trimmed = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        sentences.append(trimmed)
                    }
                    currentSentence = ""
                }
            }
        }
        
        // Add the last sentence if there's anything left
        let trimmed = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            sentences.append(trimmed)
        }
        
        return sentences
    }
    
    private func computeSentenceRanges(text: String) -> [Range<String.Index>] {
        // Simple sentence range computation based on punctuation
        var ranges: [Range<String.Index>] = []
        let sentenceSeparators = ".!?"
        
        var currentStart = text.startIndex
        var index = text.startIndex
        
        while index < text.endIndex {
            let char = text[index]
            
            if sentenceSeparators.contains(char) {
                // Check if the next character is a space or newline or end of string
                let nextIndex = text.index(after: index)
                if nextIndex == text.endIndex || [" ", "\n"].contains(text[nextIndex]) {
                    // Include the punctuation mark in the sentence
                    let endIndex = text.index(after: index)
                    let range = currentStart..<endIndex
                    
                    // Skip any leading whitespace for the next sentence
                    var nextStart = endIndex
                    while nextStart < text.endIndex && text[nextStart].isWhitespace {
                        nextStart = text.index(after: nextStart)
                    }
                    
                    ranges.append(range)
                    currentStart = nextStart
                }
            }
            
            if index < text.endIndex {
                index = text.index(after: index)
            }
        }
        
        // Add the last range if there's anything left
        if currentStart < text.endIndex {
            ranges.append(currentStart..<text.endIndex)
        }
        
        return ranges
    }
    
    // MARK: - HTML Processing
    
    func generateHTMLContent(chapter: Chapter, options: ContentDisplayOptions) -> String {
        // Process the HTML content with SwiftSoup
        do {
            let doc = try SwiftSoup.parse(chapter.htmlContent)
            
            // Handle special elements (images, tables, etc.)
            handleSpecialElements(doc: doc)
            
            // Get the modified HTML
            let processedHTML = try doc.html()
            
            // Wrap the processed HTML with appropriate styles
            return HTMLRenderer.shared.wrapContentInHTML(content: processedHTML, options: options)
        } catch {
            print("Error processing HTML: \(error)")
            
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
        } catch {
            print("Error handling special elements: \(error)")
        }
    }
    
    // MARK: - Attributed String Conversion
    
    func convertToAttributedString(html: String, fontSize: CGFloat) -> NSAttributedString {
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
            return NSAttributedString()
        }
        
        do {
            return try NSAttributedString(data: data, options: options, documentAttributes: nil)
        } catch {
            print("Error converting HTML to attributed string: \(error)")
            return NSAttributedString(string: html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
        }
    }
}

class HTMLRenderer {
    static let shared = HTMLRenderer()
    
    private init() {}
    
    func wrapContentInHTML(content: String, options: ContentDisplayOptions) -> String {
        let baseStyles = """
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                font-size: \(options.fontSize)px;
                line-height: \(options.lineSpacing);
                margin: 0;
                padding: 0 \(options.horizontalPadding)px;
                \(options.darkMode ? "background-color: #121212; color: #F0F0F0;" : "background-color: #F5F5F5; color: #121212;")
            }
            
            .reader-heading {
                margin-top: 1.5em;
                margin-bottom: 0.5em;
                line-height: 1.2;
                \(options.darkMode ? "color: #e0e0e0;" : "color: #333333;")
            }
            
            .reader-image {
                max-width: 100%;
                height: auto;
                margin: 1em 0;
                \(options.darkMode ? "filter: brightness(0.8);" : "")
            }
            
            .reader-blockquote {
                border-left: 3px solid \(options.darkMode ? "#555555" : "#dddddd");
                margin-left: 1em;
                padding-left: 1em;
                \(options.darkMode ? "color: #cccccc;" : "color: #555555;")
            }
            
            .highlighted-sentence {
                background-color: \(options.darkMode ? "rgba(255, 255, 0, 0.3)" : "rgba(255, 255, 0, 0.5)");
                border-radius: 2px;
            }
            
            p {
                margin-top: 0.5em;
                margin-bottom: 0.5em;
            }
            
            h1 { font-size: \(options.fontSize * 1.8)px; }
            h2 { font-size: \(options.fontSize * 1.6)px; }
            h3 { font-size: \(options.fontSize * 1.4)px; }
            h4 { font-size: \(options.fontSize * 1.2)px; }
            h5 { font-size: \(options.fontSize * 1.1)px; }
            h6 { font-size: \(options.fontSize)px; font-weight: bold; }
        </style>
        """
        
        let highlightStyles = getHighlightStyles()
        let highlightScript = getHighlightJavaScript()
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            \(baseStyles)
            \(highlightStyles)
        </head>
        <body>
            <div id="content">
                \(content)
            </div>
            \(highlightScript)
        </body>
        </html>
        """
        
        return html
    }
    
    func highlightSentenceInHTML(html: String, sentenceIndex: Int, sentences: [String], options: ContentDisplayOptions) -> String {
        guard sentenceIndex >= 0, sentenceIndex < sentences.count,
              let sentenceToHighlight = sentences[safe: sentenceIndex]?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return html
        }
        
        // Add JavaScript to highlight the sentence
        let scriptToInject = """
        <script>
            window.onload = function() {
                highlightSentence(`\(sentenceToHighlight.replacingOccurrences(of: "\"", with: "\\\""))`);
            }
        </script>
        """
        
        return html.replacingOccurrences(of: "</body>", with: "\(scriptToInject)</body>")
    }
    
    func getHighlightStyles() -> String {
        return """
        <style>
            .highlight-animation {
                transition: background-color 0.3s ease;
            }
        </style>
        """
    }
    
    func getHighlightJavaScript() -> String {
        return """
        <script>
            function highlightSentence(sentence) {
                if (!sentence) return;
                
                // Simple text search and highlight
                const content = document.getElementById('content');
                const textNodes = [];
                
                // Helper function to get all text nodes
                function getTextNodes(node) {
                    if (node.nodeType === Node.TEXT_NODE) {
                        textNodes.push(node);
                    } else {
                        for (let i = 0; i < node.childNodes.length; i++) {
                            getTextNodes(node.childNodes[i]);
                        }
                    }
                }
                
                getTextNodes(content);
                
                // Try to find the sentence in text nodes
                for (let i = 0; i < textNodes.length; i++) {
                    const textNode = textNodes[i];
                    const text = textNode.nodeValue;
                    
                    if (text.includes(sentence)) {
                        const range = document.createRange();
                        const startIndex = text.indexOf(sentence);
                        const endIndex = startIndex + sentence.length;
                        
                        range.setStart(textNode, startIndex);
                        range.setEnd(textNode, endIndex);
                        
                        const span = document.createElement('span');
                        span.className = 'highlighted-sentence highlight-animation';
                        
                        range.surroundContents(span);
                        
                        // Scroll to the highlighted element
                        span.scrollIntoView({ behavior: 'smooth', block: 'center' });
                        break;
                    }
                }
            }
            
            // Add tap event listeners to detect sentence taps
            document.addEventListener('DOMContentLoaded', function() {
                document.body.addEventListener('click', function(e) {
                    // Find closest paragraph or heading
                    let element = e.target;
                    while (element && !['P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6'].includes(element.tagName)) {
                        element = element.parentElement;
                    }
                    
                    if (element) {
                        // Send message to Swift
                        window.webkit.messageHandlers.sentenceTapped.postMessage({
                            text: element.innerText,
                            tag: element.tagName
                        });
                    }
                });
            });
        </script>
        """
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 