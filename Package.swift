// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ChessMove",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ChessCore", path: "Sources/ChessCore"),
        .executableTarget(
            name: "ChessMove",
            dependencies: ["ChessCore"],
            path: "Sources/ChessMove"
        ),
        .testTarget(name: "ChessCoreTests", dependencies: ["ChessCore"], path: "Tests/ChessCoreTests"),
    ],
    swiftLanguageModes: [.v5]
)
