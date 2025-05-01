import SwiftUI

struct ReaderContainerView: View {
    @ObservedObject var bookViewModel: BookViewModel
    @ObservedObject var readingContentVM: ReadingContentViewModel
    @ObservedObject var speedReadingVM: SpeedReadingViewModel
    
    @State private var readerMode: ReaderMode = .standard
    @State private var showSettings: Bool = false
    @State private var showTOC: Bool = false
    
    var body: some View {
        ZStack {
            if readerMode == .standard {
                StandardReaderView(
                    bookViewModel: bookViewModel,
                    readingContentVM: readingContentVM,
                    onShowSettings: { showSettings = true },
                    onShowTOC: { showTOC = true },
                    onModeChange: { readerMode = $0 }
                )
            } else {
                SpeedReaderView(
                    speedReadingVM: speedReadingVM,
                    readingContentVM: readingContentVM,
                    onShowSettings: { showSettings = true },
                    onExit: { readerMode = .standard }
                )
            }
            
            // Overlays
            if showSettings {
                SettingsView(
                    settings: bookViewModel.settings,
                    onDismiss: { showSettings = false }
                )
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
            
            if showTOC {
                GeometryReader { geometry in
                    TOCView(
                        tocItems: getTOCItems(),
                        currentChapterIndex: bookViewModel.currentChapterIndex,
                        onChapterSelected: { index in
                            bookViewModel.navigateToChapter(index: index)
                            showTOC = false
                        },
                        onDismiss: { showTOC = false }
                    )
                    .frame(width: geometry.size.width * 0.8, height: geometry.size.height)
                    .background(Color(.systemBackground))
                    .shadow(radius: 10)
                    .transition(.move(edge: .leading))
                }
                .zIndex(2)
                .animation(.spring(), value: showTOC)
            }
        }
        .onAppear {
            // Load current chapter for reading content view
            if let processedChapter = bookViewModel.currentChapterContent {
                readingContentVM.loadChapter(
                    chapter: processedChapter.originalChapter,
                    options: ContentDisplayOptions(
                        fontSize: bookViewModel.settings.fontSize,
                        lineSpacing: bookViewModel.settings.lineSpacing,
                        horizontalPadding: bookViewModel.settings.horizontalPadding,
                        darkMode: bookViewModel.settings.darkMode
                    )
                )
                
                // Setup speed reading if needed
                if let book = bookViewModel.currentBook,
                   let lastPosition = book.lastReadPosition {
                    speedReadingVM.configure(
                        with: book.id.uuidString,
                        initialSentenceIndex: lastPosition.sentenceIndex
                    )
                }
            }
        }
    }
    
    private func getTOCItems() -> [TocItem] {
        guard let book = bookViewModel.currentBook else { return [] }
        
        // Use the TOC items from the book if available
        if !book.tocItems.isEmpty {
            return book.tocItems
        }
        
        // Fallback to creating a simple TOC based on chapter titles
        return book.chapters.enumerated().map { index, chapter in
            TocItem(
                id: chapter.id,
                title: chapter.title,
                level: 0,
                chapterIndex: index
            )
        }
    }
} 
