import Foundation

protocol BookStorageService {
    func hasExtractedBook(id: String) -> Bool
    func getExtractedBookDirectory(id: String) -> URL
    func saveExtractedBook(from: URL, withId: String) throws
    func getBookMetadata(id: String) -> Book?
    func saveBookMetadata(_ book: Book) throws
    func getAllSavedBooks() -> [Book]
} 