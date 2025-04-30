import SwiftUI

@main
struct FocusReaderApp: App {
    @StateObject private var bookViewModel = DependencyContainer.shared.makeBookViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bookViewModel)
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject var bookViewModel: BookViewModel
    @State private var isImporting = false
    
    var body: some View {
        NavigationView {
            VStack {
                if bookViewModel.library.isEmpty {
                    VStack {
                        Text("Your library is empty")
                            .font(.headline)
                        
                        Button("Import EPUB") {
                            isImporting = true
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                } else {
                    List {
                        ForEach(bookViewModel.library, id: \.id) { book in
                            BookRow(book: book)
                                .onTapGesture {
                                    bookViewModel.loadBook(book)
                                }
                        }
                        .onDelete { indexSet in
                            bookViewModel.removeBook(at: indexSet)
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarItems(trailing: Button(action: {
                isImporting = true
            }) {
                Image(systemName: "plus")
            })
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.epub],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        bookViewModel.loadEPUB(from: url)
                    }
                case .failure(let error):
                    print("Error importing EPUB: \(error.localizedDescription)")
                }
            }
        }
        .onAppear {
            bookViewModel.loadLibrary()
        }
    }
}

struct BookRow: View {
    let book: Book
    
    var body: some View {
        HStack {
            if let coverImage = book.coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 70)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 70)
                    .overlay(
                        Image(systemName: "book.closed")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading) {
                Text(book.title)
                    .font(.headline)
                
                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let lastReadDate = book.lastReadPosition?.lastReadDate {
                    Text("Last read: \(formattedDate(lastReadDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#if os(iOS)
import UniformTypeIdentifiers

extension UTType {
    static var epub: UTType {
        UTType(importedAs: "org.idpf.epub-container")
    }
}
#endif 