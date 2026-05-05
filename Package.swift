// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RTKInfos",
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
            name: "RTKInfosTests",
            dependencies: [
                "RTKCore",
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: "RTKInfosTests",
            exclude: ["StatsModelTests.swift"]
        ),
    ]
)
