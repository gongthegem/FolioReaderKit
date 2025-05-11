import Foundation
import UIKit

class FileSystemBookStorageService: BookStorageService {
    private let fileManager: FileManager
    private let booksDirectory: URL
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        // Get or create books directory in the documents folder
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.booksDirectory = documentsDirectory.appendingPathComponent("Books", isDirectory: true)
        
        // Create books directory if it doesn't exist
        if !fileManager.fileExists(atPath: booksDirectory.path) {
            try? fileManager.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
        }
    }
    
    func hasExtractedBook(id: String) -> Bool {
        let bookDirectory = getExtractedBookDirectory(id: id)
        return fileManager.fileExists(atPath: bookDirectory.path)
    }
    
    func getExtractedBookDirectory(id: String) -> URL {
        return booksDirectory.appendingPathComponent(id, isDirectory: true)
    }
    
    func saveExtractedBook(from sourceURL: URL, withId id: String) throws {
        let destinationURL = getExtractedBookDirectory(id: id)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        }
        
        // If it's a directory, copy all contents
        if sourceURL.hasDirectoryPath {
            let contents = try fileManager.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil)
            for url in contents {
                let destinationFileURL = destinationURL.appendingPathComponent(url.lastPathComponent)
                if !fileManager.fileExists(atPath: destinationFileURL.path) {
                    try fileManager.copyItem(at: url, to: destinationFileURL)
                }
            }
        } else {
            // It's a file, so just copy it
            let destinationFileURL = destinationURL.appendingPathComponent(sourceURL.lastPathComponent)
            if !fileManager.fileExists(atPath: destinationFileURL.path) {
                try fileManager.copyItem(at: sourceURL, to: destinationFileURL)
            }
        }
    }
    
    func getBookMetadata(id: String) -> Book? {
        let metadataURL = getExtractedBookDirectory(id: id).appendingPathComponent("metadata.json")
        
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: metadataURL)
            let decoder = JSONDecoder()
            return try decoder.decode(Book.self, from: data)
        } catch {
            print("Error loading book metadata: \(error)")
            return nil
        }
    }
    
    func saveBookMetadata(_ book: Book) throws {
        let bookDirectory = getExtractedBookDirectory(id: book.id.uuidString)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: bookDirectory.path) {
            try fileManager.createDirectory(at: bookDirectory, withIntermediateDirectories: true)
        }
        
        let metadataURL = bookDirectory.appendingPathComponent("metadata.json")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(book)
        try data.write(to: metadataURL)
    }
    
    func getAllSavedBooks() -> [Book] {
        do {
            let contents = try fileManager.contentsOfDirectory(at: booksDirectory, includingPropertiesForKeys: nil)
            var books: [Book] = []
            
            for url in contents {
                if url.hasDirectoryPath, let bookId = url.lastPathComponent as String?, let book = getBookMetadata(id: bookId) {
                    books.append(book)
                }
            }
            
            return books
        } catch {
            print("Error listing books: \(error)")
            return []
        }
    }
} 