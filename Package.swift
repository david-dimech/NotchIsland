// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchIsland",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NotchIslandCore", targets: ["NotchIslandCore"]),
    ],
    targets: [
        // Pure-logic library — no AppKit/SwiftUI, fully unit-testable.
        .target(
            name: "NotchIslandCore",
            path: "Sources/NotchIslandCore"
        ),

        // Main application executable.
        .executableTarget(
            name: "NotchIsland",
            dependencies: ["NotchIslandCore"],
            path: "Sources/NotchIsland",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("EventKit"),
                .linkedFramework("CoreMIDI"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/NotchIsland/Info.plist",
                ]),
            ]
        ),

        // Unit tests — depend only on the pure-logic library.
        .testTarget(
            name: "NotchIslandTests",
            dependencies: ["NotchIslandCore"],
            path: "Tests/NotchIslandTests"
        ),
    ]
)
