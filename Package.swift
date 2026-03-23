// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RTKMenuBar",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.0")
    ],
    targets: [
        .executableTarget(
            name: "RTKMenuBar",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "RTKMenuBar",
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "RTKMenuBarTests",
            dependencies: [
                "RTKMenuBar",
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "RTKMenuBarTests"
        )
    ]
)
