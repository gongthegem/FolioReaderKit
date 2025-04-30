import Foundation

class PathResolver {
    static let shared = PathResolver()
    
    private init() {}
    
    func resolveRelativePath(path: String, basePath: String) -> String {
        let baseURL = URL(fileURLWithPath: basePath)
        let fullURL = URL(fileURLWithPath: path, relativeTo: baseURL)
        return fullURL.path
    }
    
    func resolveURL(for path: String, baseURL: URL) -> URL? {
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        } else {
            return URL(fileURLWithPath: path, relativeTo: baseURL)
        }
    }
    
    func directoryFromPath(path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.deletingLastPathComponent().path
    }
} 