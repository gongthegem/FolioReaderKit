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
            if bookViewModel.currentBook == nil {
                // Show the library view
                LibraryView()
            } else {
                // Show the reader view
                let container = DependencyContainer.shared
                let readingContentVM = container.makeReadingContentViewModel()
                let speedReadingVM = container.makeSpeedReadingViewModel(readingContentVM: readingContentVM)
                
                ReaderContainerView(
                    bookViewModel: bookViewModel,
                    readingContentVM: readingContentVM,
                    speedReadingVM: speedReadingVM
                )
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
