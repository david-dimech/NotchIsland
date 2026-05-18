// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchIsland",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NotchIsland",
            path: "Sources/NotchIsland",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("EventKit"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/NotchIsland/Info.plist",
                ]),
            ]
        )
    ]
)
