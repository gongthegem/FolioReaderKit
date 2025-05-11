import Foundation
import SwiftUI

class HTMLRenderer {
    static let shared = HTMLRenderer()
    
    private init() {}
    
    func wrapContentInHTML(content: String, options: ContentDisplayOptions) -> String {
        // Check if content is empty
        if content.isEmpty {
            LoggingService.shared.warning("Empty content provided for HTML wrapping", category: .contentProcessing)
            return createHTMLWithContent("<p>No content available. Please try again.</p>", options: options)
        }
        
        return createHTMLWithContent(content, options: options)
    }
    
    private func createHTMLWithContent(_ content: String, options: ContentDisplayOptions) -> String {
        let baseStyles = """
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                font-size: \(options.fontSize)px;
                line-height: \(options.lineSpacing);
                margin: 0;
                padding: 0 \(options.horizontalPadding)px;
                \(options.darkMode ? "background-color: #121212; color: #F0F0F0;" : "background-color: #FFFFFF; color: #121212;")
            }
            
            #content {
                padding: 20px;
                min-height: 100vh; /* Ensure content takes at least full height */
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
        
        // Add debugging script to report content loaded successfully
        let debuggingScript = """
        <script>
            window.onload = function() {
                console.log("Content loaded successfully. Content length: " + document.getElementById('content').innerHTML.length);
                
                // Force layout update
                setTimeout(function() {
                    window.webkit.messageHandlers.logging.postMessage({
                        type: 'info',
                        message: 'Content display completed and rendered'
                    });
                    document.body.style.opacity = 0.99;
                    setTimeout(function() {
                        document.body.style.opacity = 1;
                    }, 50);
                }, 100);
            };
        </script>
        """
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            \(baseStyles)
            \(debuggingScript)
        </head>
        <body>
            <div id="content">
                \(content)
            </div>
        </body>
        </html>
        """
        
        LoggingService.shared.debug("Generated HTML with length: \(html.count)", category: .contentProcessing)
        return html
    }
} 