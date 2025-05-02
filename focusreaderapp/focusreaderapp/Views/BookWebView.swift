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
    var onImageTap: (ChapterImage) -> Void
    var onMarginTap: (MarginSide) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let preferences = WKPreferences()
        
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        
        // Set up JavaScript support
        let webpagePreferences = WKWebpagePreferences()
        webpagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = webpagePreferences
        
        // Add message handler for taps
        configuration.userContentController.add(context.coordinator, name: "sentenceTapped")
        configuration.userContentController.add(context.coordinator, name: "imageTapped")
        configuration.userContentController.add(context.coordinator, name: "marginTapped")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only reload if content changed
        if webView.tag != htmlContent.hashValue {
            webView.loadHTMLString(htmlContent, baseURL: baseURL)
            webView.tag = htmlContent.hashValue
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
            if message.name == "sentenceTapped", 
               let data = message.body as? [String: Any],
               let text = data["text"] as? String {
                
                // Find the sentence index by matching text
                let processed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if let sentenceIndex = findSentenceIndex(for: processed) {
                    DispatchQueue.main.async {
                        self.parent.onSentenceTap(sentenceIndex)
                    }
                }
            } 
            else if message.name == "imageTapped", 
                    let data = message.body as? [String: Any],
                    let imageId = data["id"] as? String {
                
                // Create a dummy ChapterImage since we don't have real data here
                let image = ChapterImage(
                    id: imageId,
                    name: "Image",
                    imagePath: ""
                )
                
                DispatchQueue.main.async {
                    self.parent.onImageTap(image)
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
        
        private func findSentenceIndex(for text: String) -> Int? {
            // In a real app, this would use the processed chapter sentences
            // For now, we'll just return 0 as a placeholder
            return 0
        }
    }
} 