// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RTKMenuBar",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.16.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "RTKCore",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: "Sources/RTKCore"
        ),
        .executableTarget(
            name: "RTKStats",
            dependencies: [
                "RTKCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/RTKStats"
        ),
        .testTarget(
            name: "RTKMenuBarTests",
            dependencies: [
                "RTKCore",
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: "RTKMenuBarTests",
            exclude: ["StatsModelTests.swift"]
        ),
    ]
)
