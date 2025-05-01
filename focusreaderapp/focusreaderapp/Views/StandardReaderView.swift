import SwiftUI

struct StandardReaderView: View {
    @ObservedObject var bookViewModel: BookViewModel
    @ObservedObject var readingContentVM: ReadingContentViewModel
    
    var onShowSettings: () -> Void
    var onShowTOC: () -> Void
    var onModeChange: (ReaderMode) -> Void
    
    @State private var lastSentenceIndex: Int = 0
    
    var body: some View {
        ZStack {
            Color(bookViewModel.settings.darkMode ? .black : .white)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onShowTOC) {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .padding()
                    }
                    
                    Spacer()
                    
                    Text(bookViewModel.currentBook?.title ?? "")
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: onShowSettings) {
                        Image(systemName: "gear")
                            .font(.title3)
                            .padding()
                    }
                }
                .padding(.horizontal)
                .background(Color(.systemBackground).opacity(0.9))
                
                // Content
                if let processedChapter = readingContentVM.processedChapter {
                    BookWebView(
                        htmlContent: processedChapter.processedHTMLContent,
                        baseURL: getBaseURL(),
                        displayOptions: readingContentVM.displayOptions,
                        onSentenceTap: { index in
                            readingContentVM.moveToSentence(index: index)
                            lastSentenceIndex = index
                            bookViewModel.saveReadingPosition(
                                chapterIndex: bookViewModel.currentChapterIndex,
                                sentenceIndex: index
                            )
                        },
                        onImageTap: { _ in
                            // Handle image tap if needed
                        },
                        onMarginTap: { side in
                            if side == .left {
                                bookViewModel.navigateToPreviousChapter()
                            } else {
                                bookViewModel.navigateToNextChapter()
                            }
                        }
                    )
                } else {
                    Text("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Footer with controls
                HStack {
                    Button(action: {
                        bookViewModel.navigateToPreviousChapter()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .padding()
                    }
                    .disabled(bookViewModel.currentChapterIndex <= 0)
                    
                    Spacer()
                    
                    // Progress indicator
                    Text("Chapter \(bookViewModel.currentChapterIndex + 1) of \(bookViewModel.currentBook?.chapters.count ?? 0)")
                        .font(.caption)
                    
                    Spacer()
                    
                    // Speed reading mode button
                    Button(action: {
                        onModeChange(.speedReading)
                    }) {
                        Image(systemName: "gauge.with.dots.needle.33percent")
                            .font(.title3)
                            .padding()
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        bookViewModel.navigateToNextChapter()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .padding()
                    }
                    .disabled(bookViewModel.currentChapterIndex >= (bookViewModel.currentBook?.chapters.count ?? 0) - 1)
                }
                .padding(.horizontal)
                .background(Color(.systemBackground).opacity(0.9))
            }
        }
        .onAppear {
            // If we have a last position, restore it
            if let book = bookViewModel.currentBook,
               let position = book.lastReadPosition,
               position.chapterIndex == bookViewModel.currentChapterIndex {
                readingContentVM.moveToSentence(index: position.sentenceIndex)
                lastSentenceIndex = position.sentenceIndex
            }
        }
        .navigationBarHidden(true)
    }
    
    private func getBaseURL() -> URL? {
        guard let book = bookViewModel.currentBook else { return nil }
        
        // In a real app, this would be the directory where EPUB content is extracted
        return URL(fileURLWithPath: book.filePath).deletingLastPathComponent()
    }
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
        preferences.javaScriptEnabled = true
        
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        
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

import WebKit 