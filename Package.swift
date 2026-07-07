// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WordPop",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "WordPop",
            targets: ["WordPop"]
        )
    ],
    targets: [
        .executableTarget(
            name: "WordPop",
            path: "WordPop"
        )
    ]
)
