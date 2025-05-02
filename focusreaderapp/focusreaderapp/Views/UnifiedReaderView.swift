import SwiftUI

struct UnifiedReaderView: View {
    @ObservedObject var bookViewModel: BookViewModel
    @ObservedObject var readingContentVM: ReadingContentViewModel
    
    @State private var displayMode: ReaderDisplayMode = .standard
    @State private var lastSentenceIndex: Int = 0
    @State private var animateSentence: Bool = false
    
    var onShowSettings: () -> Void
    var onShowTOC: () -> Void
    var onExitToLibrary: () -> Void
    
    var body: some View {
        ZStack {
            Color(bookViewModel.settings.darkMode ? .black : .white)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    if displayMode == .standard {
                        Button(action: onShowTOC) {
                            Image(systemName: "list.bullet")
                                .font(.title3)
                                .padding()
                        }
                    } else {
                        Button(action: { toggleDisplayMode() }) {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .padding()
                        }
                    }
                    
                    Spacer()
                    
                    if displayMode == .standard {
                        Text(bookViewModel.currentBook?.title ?? "")
                            .font(.headline)
                            .lineLimit(1)
                    } else {
                        Text("Inline Highlight Mode")
                            .font(.headline)
                    }
                    
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
                        htmlContent: displayMode == .standard ? 
                            processedChapter.processedHTMLContent : 
                            readingContentVM.generateHTMLForCurrentSentence(sentenceIndex: readingContentVM.currentSentenceIndex),
                        baseURL: getBaseURL(),
                        displayOptions: readingContentVM.displayOptions,
                        onSentenceTap: { index in
                            readingContentVM.moveToSentence(index: index)
                            lastSentenceIndex = index
                            bookViewModel.saveReadingPosition(
                                chapterIndex: bookViewModel.currentChapterIndex,
                                sentenceIndex: index,
                                displayMode: displayMode
                            )
                        },
                        onImageTap: { _ in
                            // Handle image tap if needed
                        },
                        onMarginTap: { side in
                            if displayMode == .standard {
                                if side == .left {
                                    bookViewModel.navigateToPreviousChapter()
                                } else {
                                    bookViewModel.navigateToNextChapter()
                                }
                            }
                        }
                    )
                } else {
                    Text("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Footer with controls based on current mode
                getControlsForCurrentMode()
            }
        }
        .onAppear {
            restoreChapterPosition()
        }
        .onDisappear {
            // Save the current position when view disappears
            bookViewModel.saveReadingPosition(
                chapterIndex: bookViewModel.currentChapterIndex,
                sentenceIndex: lastSentenceIndex,
                displayMode: displayMode
            )
        }
        .navigationBarHidden(true)
    }
    
    private func toggleDisplayMode() {
        withAnimation {
            displayMode = displayMode == .standard ? .inlineHighlightReading : .standard
            readingContentVM.setDisplayMode(displayMode)
        }
    }
    
    private func getControlsForCurrentMode() -> some View {
        Group {
            if displayMode == .standard {
                HStack {
                    StandardNavigationControls(
                        currentIndex: bookViewModel.currentChapterIndex,
                        totalCount: bookViewModel.currentBook?.chapters.count ?? 0,
                        onPrevious: {
                            bookViewModel.navigateToPreviousChapter()
                        },
                        onNext: {
                            bookViewModel.navigateToNextChapter()
                        }
                    )
                    
                    Spacer()
                    
                    // Highlight mode button
                    Button(action: toggleDisplayMode) {
                        Image(systemName: "highlighter")
                            .font(.title3)
                            .padding()
                    }
                    .padding(.trailing)
                }
                .padding(.horizontal)
                .background(Color(.systemBackground).opacity(0.9))
            } else {
                InlineHighlightControls(
                    currentSentenceIndex: readingContentVM.currentSentenceIndex,
                    totalSentences: readingContentVM.totalSentences,
                    onPrevious: {
                        readingContentVM.moveToPreviousSentence()
                    },
                    onNext: {
                        readingContentVM.moveToNextSentence()
                    },
                    onExitHighlightMode: toggleDisplayMode
                )
            }
        }
    }
    
    private func getCurrentSentence() -> String {
        return readingContentVM.sentenceAtIndex(index: readingContentVM.currentSentenceIndex) ?? ""
    }
    
    private func restoreChapterPosition() {
        // If we have a last position, restore it
        if let book = bookViewModel.currentBook,
           let position = book.lastReadPosition {
            // For the current chapter, use the position's sentenceIndex
            if position.chapterIndex == bookViewModel.currentChapterIndex {
                let sentenceIndex = position.sentenceIndex
                readingContentVM.moveToSentence(index: sentenceIndex)
                lastSentenceIndex = sentenceIndex
            } 
            // For any other chapter, use the stored chapter position
            else {
                let sentenceIndex = position.sentenceIndexForChapter(bookViewModel.currentChapterIndex)
                if sentenceIndex > 0 {
                    readingContentVM.moveToSentence(index: sentenceIndex)
                    lastSentenceIndex = sentenceIndex
                }
            }
            
            // Set the display mode from the reading position if available
            if let mode = position.displayMode {
                displayMode = mode
                readingContentVM.setDisplayMode(mode)
            }
        }
    }
    
    private func getBaseURL() -> URL? {
        guard let chapter = readingContentVM.currentChapter else {
            return nil
        }
        
        // Try to construct a base URL from the chapter's location
        if let book = bookViewModel.currentBook {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            let bookDirectory = documentsDirectory?.appendingPathComponent(book.id.uuidString)
            // Return the book directory as base URL since we don't have chapter paths
            return bookDirectory
        }
        
        return nil
    }
} 