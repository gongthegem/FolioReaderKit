import SwiftUI
import WebKit

enum MarginSide {
    case left
    case right
}

struct BookWebView: UIViewRepresentable {
    var htmlContent: String
    var baseURL: URL?
    var displayOptions: ContentDisplayOptions
    var onSentenceTap: (Int) -> Void
    var onImageTap: (String) -> Void
    var onMarginTap: (MarginSide) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        LoggingService.shared.debug("Creating WebView", category: .ui)
        
        // Create configuration with script message handlers
        let configuration = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        
        // Add script message handlers
        contentController.add(context.coordinator, name: "sentenceTapped")
        contentController.add(context.coordinator, name: "imageTapped")
        contentController.add(context.coordinator, name: "marginTapped")
        contentController.add(context.coordinator, name: "logging")
        
        // Add the content controller to configuration
        configuration.userContentController = contentController
        
        // Create web view with configuration
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Disable zoom
        webView.scrollView.bouncesZoom = false
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        
        // Customize appearance
        webView.isOpaque = true
        webView.backgroundColor = displayOptions.darkMode ? .black : .white
        webView.scrollView.backgroundColor = displayOptions.darkMode ? .black : .white
        
        // Optionally disable selection
        // let script = WKUserScript(source: "document.documentElement.style.webkitUserSelect='none';", injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        // contentController.addUserScript(script)
        
        // Load initial content
        updateWebViewContent(webView)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        LoggingService.shared.debug("Updating WebView", category: .ui)
        
        // Check if the content has changed
        let currentTag = webView.tag
        let newTag = htmlContent.hashValue
        
        if currentTag != newTag {
            // Update background color based on display options
            webView.backgroundColor = displayOptions.darkMode ? .black : .white
            webView.scrollView.backgroundColor = displayOptions.darkMode ? .black : .white
            
            // Update content
            updateWebViewContent(webView)
        }
    }
    
    private func updateWebViewContent(_ webView: WKWebView) {
        LoggingService.shared.debug("Loading HTML content of length: \(htmlContent.count)", category: .ui)
        
        if htmlContent.isEmpty {
            LoggingService.shared.error("Empty HTML content", category: .contentProcessing)
            webView.loadHTMLString("""
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                        margin: 20px;
                        text-align: center;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        height: 100vh;
                        background-color: \(displayOptions.darkMode ? "#121212" : "#FFFFFF");
                        color: \(displayOptions.darkMode ? "#F0F0F0" : "#121212");
                    }
                    .reload-button {
                        background-color: #007AFF;
                        color: white;
                        border: none;
                        border-radius: 8px;
                        padding: 12px 24px;
                        font-size: 16px;
                        margin-top: 20px;
                        cursor: pointer;
                    }
                </style>
            </head>
            <body>
                <div>
                    <h2>No content available</h2>
                    <p>The content could not be loaded. Please try reloading.</p>
                    <button class="reload-button" onclick="window.webkit.messageHandlers.logging.postMessage({type: 'action', message: 'reload_requested'});">
                        Reload Content
                    </button>
                </div>
                <script>
                    // Notify that error page was displayed
                    window.webkit.messageHandlers.logging.postMessage({
                        type: 'error',
                        message: 'Displayed error page due to empty content'
                    });
                </script>
            </body>
            </html>
            """, baseURL: baseURL)
            return
        }
        
        // Load the HTML content
        webView.loadHTMLString(htmlContent, baseURL: baseURL)
        webView.tag = htmlContent.hashValue
        
        // Force layout update to ensure content is displayed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let forceRenderScript = """
            document.body.style.opacity = 0.99;
            setTimeout(function() {
                document.body.style.opacity = 1;
            }, 20);
            """
            webView.evaluateJavaScript(forceRenderScript, completionHandler: nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: BookWebView
        
        init(_ parent: BookWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "logging", 
               let data = message.body as? [String: Any] {
                
                if let type = data["type"] as? String {
                    if type == "action", let action = data["message"] as? String, action == "reload_requested" {
                        // Handle reload button press
                        DispatchQueue.main.async {
                            if let webView = message.webView {
                                self.parent.updateWebViewContent(webView)
                            }
                        }
                        return
                    }
                    
                    if let logMessage = data["message"] as? String {
                        switch type {
                        case "error":
                            LoggingService.shared.error("WebView JavaScript: \(logMessage)", category: .javascript)
                        case "warn":
                            LoggingService.shared.warning("WebView JavaScript: \(logMessage)", category: .javascript)
                        default:
                            LoggingService.shared.debug("WebView JavaScript (\(type)): \(logMessage)", category: .javascript)
                        }
                    }
                }
            }
            else if message.name == "sentenceTapped", 
                   let data = message.body as? [String: Any],
                   let index = data["index"] as? Int {
                
                DispatchQueue.main.async {
                    self.parent.onSentenceTap(index)
                }
            }
            else if message.name == "imageTapped", 
                   let data = message.body as? [String: Any],
                   let src = data["src"] as? String {
                
                DispatchQueue.main.async {
                    self.parent.onImageTap(src)
                }
            }
            else if message.name == "marginTapped", 
                   let data = message.body as? [String: Any],
                   let sideString = data["side"] as? String {
                
                let side: MarginSide = sideString == "left" ? .left : .right
                
                DispatchQueue.main.async {
                    self.parent.onMarginTap(side)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            LoggingService.shared.debug("WebView finished loading", category: .ui)
            
            // Check if content loaded properly
            webView.evaluateJavaScript("document.body.innerHTML.length") { (result, error) in
                if let error = error {
                    LoggingService.shared.error("JavaScript evaluation error: \(error.localizedDescription)", category: .javascript)
                    return
                }
                
                if let contentLength = result as? Int {
                    LoggingService.shared.debug("Content length: \(contentLength)", category: .ui)
                    
                    if contentLength < 50 {
                        LoggingService.shared.warning("Very small content detected, may indicate loading issue", category: .ui)
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            LoggingService.shared.error("WebView navigation failed: \(error.localizedDescription)", category: .ui)
        }
    }
} 