// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TodoIsland",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "TodoIsland", targets: ["TodoIsland"]),
        .library(name: "TodoIslandCore", targets: ["TodoIslandCore"]),
    ],
    targets: [
        // Pure Swift logic (models, storage, geometry, hover rules). No AppKit, fully unit-tested.
        .target(name: "TodoIslandCore"),
        // The menu bar app: notch window, SwiftUI panels, settings.
        .executableTarget(name: "TodoIsland", dependencies: ["TodoIslandCore"]),
        .testTarget(name: "TodoIslandCoreTests", dependencies: ["TodoIslandCore"]),
    ]
)
