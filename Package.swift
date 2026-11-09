// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Radish",
    platforms: [.macOS("15.0")],
    targets: [
        // Declarations for the private CGVirtualDisplay classes in CoreGraphics.
        .target(
            name: "CVirtualDisplay",
            path: "Sources/CVirtualDisplay",
            linkerSettings: [.linkedFramework("CoreGraphics")]
        ),
        .executableTarget(
            name: "Radish",
            dependencies: ["CVirtualDisplay"],
            path: "Sources/Radish",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
