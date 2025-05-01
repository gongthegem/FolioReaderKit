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
            print("ReaderContainerView - onAppear: Loading chapter content")
            print("Current book: \(bookViewModel.currentBook?.title ?? "nil")")
            print("Current chapter index: \(bookViewModel.currentChapterIndex)")
            print("Is loading: \(bookViewModel.isLoading)")
            
            // Load current chapter for reading content view
            if let processedChapter = bookViewModel.currentChapterContent {
                print("ReaderContainerView - onAppear: Found processed chapter, loading into ReadingContentViewModel")
                print("Chapter title: \(processedChapter.originalChapter.title)")
                print("Chapter has \(processedChapter.sentences.count) sentences")
                
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
                    print("ReaderContainerView - onAppear: Configuring speed reading with book ID \(book.id.uuidString) and sentence index \(lastPosition.sentenceIndex)")
                    speedReadingVM.configure(
                        with: book.id.uuidString,
                        initialSentenceIndex: lastPosition.sentenceIndex
                    )
                }
            } else {
                print("ReaderContainerView - onAppear: ERROR - No processed chapter available from bookViewModel")
                print("Possible causes: Book processing not complete, chapter loading failed, or ContentProcessor error")
            }
        }
    }
    
    private func getTOCItems() -> [TocItem] {
        guard let book = bookViewModel.currentBook else { return [] }
        
        // In a real app, we'd have actual TOC data from the EPUB
        // Here we'll create a simple TOC based on chapter titles
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
