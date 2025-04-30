import Foundation
import SwiftUI

class ReaderSettings: ObservableObject {
    @Published var fontSize: CGFloat
    @Published var lineSpacing: CGFloat
    @Published var horizontalPadding: CGFloat
    @Published var darkMode: Bool
    
    init(
        fontSize: CGFloat = 16,
        lineSpacing: CGFloat = 1.5,
        horizontalPadding: CGFloat = 20,
        darkMode: Bool = false
    ) {
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.horizontalPadding = horizontalPadding
        self.darkMode = darkMode
    }
    
    func save() {
        UserDefaults.standard.set(Double(fontSize), forKey: "fontSize")
        UserDefaults.standard.set(Double(lineSpacing), forKey: "lineSpacing")
        UserDefaults.standard.set(Double(horizontalPadding), forKey: "horizontalPadding")
        UserDefaults.standard.set(darkMode, forKey: "darkMode")
    }
    
    func load() {
        if let fontSize = UserDefaults.standard.object(forKey: "fontSize") as? Double {
            self.fontSize = CGFloat(fontSize)
        }
        
        if let lineSpacing = UserDefaults.standard.object(forKey: "lineSpacing") as? Double {
            self.lineSpacing = CGFloat(lineSpacing)
        }
        
        if let horizontalPadding = UserDefaults.standard.object(forKey: "horizontalPadding") as? Double {
            self.horizontalPadding = CGFloat(horizontalPadding)
        }
        
        self.darkMode = UserDefaults.standard.bool(forKey: "darkMode")
    }
}

class ReadingProgressManager: ObservableObject {
    private let userDefaults = UserDefaults.standard
    
    func saveProgress(bookId: String, position: ReadingPosition) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(position)
            userDefaults.set(data, forKey: "progress_\(bookId)")
        } catch {
            print("Error saving reading position: \(error)")
        }
    }
    
    func loadProgress(bookId: String) -> ReadingPosition? {
        guard let data = userDefaults.data(forKey: "progress_\(bookId)") else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(ReadingPosition.self, from: data)
        } catch {
            print("Error loading reading position: \(error)")
            return nil
        }
    }
    
    func updateLastReadDate(bookId: String) {
        guard var position = loadProgress(bookId: bookId) else {
            return
        }
        
        position.lastReadDate = Date()
        saveProgress(bookId: bookId, position: position)
    }
    
    func getRecentBooks() -> [String] {
        let keys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("progress_") }
        
        // Map the keys to book IDs and sort by last read date
        let bookIds = keys.compactMap { key -> (String, Date)? in
            let bookId = String(key.dropFirst("progress_".count))
            guard let position = loadProgress(bookId: bookId) else {
                return nil
            }
            return (bookId, position.lastReadDate)
        }
        .sorted { $0.1 > $1.1 } // Sort by date descending
        .map { $0.0 } // Extract just the book ID
        
        return bookIds
    }
} 