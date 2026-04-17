// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PassivMac",
    platforms: [
        .macOS(.v14)   // SwiftData + @Observable + Swift Charts require macOS 14
    ],
    dependencies: [
        // Keychain wrapper — simpler than raw SecItem calls
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "PassivMac",
            dependencies: [
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ],
            path: "Sources/PassivMac",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "PassivMacTests",
            dependencies: ["PassivMac"],
            path: "Tests/PassivMacTests"
        ),
    ]
)
