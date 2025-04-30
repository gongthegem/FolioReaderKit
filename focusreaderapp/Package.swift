// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.


let package = Package(
    name: "focusreaderapp",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .executable(name: "focusreaderapp", targets: ["focusreaderapp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.4.3"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.16"),
    ],
    targets: [
        .executableTarget(
            name: "focusreaderapp",
            dependencies: [
                "SwiftSoup",
                "ZIPFoundation"
            ],
            path: "Sources"),
    ]
)
