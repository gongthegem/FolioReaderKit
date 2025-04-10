// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "FolioReaderKit",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // This makes the module available to your projects as "FolioReaderKit"
        .library(name: "FolioReaderKit", targets: ["FolioReaderKit"])
    ],
    dependencies: [
        // List any external dependencies here.
        // These examples assume you need ZIPFoundation and SwiftSoup:
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.3.2")
    ],
    targets: [
        // Define the main target for FolioReaderKit.
        .target(
            name: "FolioReaderKit",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                "SwiftSoup"
            ],
            // Update the path if your source files are not in a folder named "FolioReaderKit"
            path: "Source"
        ),
        // Define the tests target if you have tests.
        .testTarget(
            name: "FolioReaderKitTests",
            dependencies: ["FolioReaderKit"],
            path: "FolioReaderKitTests"
        )
    ]
)
