// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "FolioReaderKit",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "FolioReaderKit", targets: ["FolioReaderKit"])
    ],
    dependencies: [
        // your needed dependencies (SwiftSoup, ZIPFoundation, etc.)
    ],
    targets: [
        .target(
            name: "FolioReaderKit",
            dependencies: [
                // reference .product(name: "ZIPFoundation", package: "ZIPFoundation"), etc.
            ],
            path: "Source" // or whatever the correct folder is
        ),
        .testTarget(
            name: "FolioReaderKitTests",
            dependencies: ["FolioReaderKit"],
            path: "Tests"
        )
    ]
)
