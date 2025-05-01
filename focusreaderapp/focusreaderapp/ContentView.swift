//
//  ContentView.swift
//  focusreaderapp
//
//  Created by gong chunyan on 30/04/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bookViewModel: BookViewModel
    @State private var hasCheckedLibrary = false
    
    var body: some View {
        Group {
            // Show Reader only when both book and chapter content are loaded
            if bookViewModel.currentBook != nil && bookViewModel.currentChapterContent != nil {
                // Show the reader view
                let container = DependencyContainer.shared
                let readingContentVM = container.makeReadingContentViewModel()
                let speedReadingVM = container.makeSpeedReadingViewModel(readingContentVM: readingContentVM)
                
                ReaderContainerView(
                    bookViewModel: bookViewModel,
                    readingContentVM: readingContentVM,
                    speedReadingVM: speedReadingVM
                )
            } else if bookViewModel.isLoading { 
                // Show loading indicator while the book/chapter is processing
                VStack {
                    Text("Loading Book...")
                        .font(.title)
                    ProgressView()
                        .padding()
                }
            } else {
                // Show the library view otherwise (no book selected or loaded yet)
                LibraryView()
            }
        }
        .onAppear {
            // Check if this is the first launch and library is empty
            if !hasCheckedLibrary {
                bookViewModel.loadLibrary()
                
                if bookViewModel.library.isEmpty {
                    // Load the sample book on first launch with empty library
                    bookViewModel.loadSampleBook()
                }
                hasCheckedLibrary = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DependencyContainer.shared.makeBookViewModel())
}
