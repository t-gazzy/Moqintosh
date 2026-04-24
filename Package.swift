// swift-tools-version: 6.2

import PackageDescription

let package: Package = Package(
    name: "Moqintosh",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .tvOS(.v26)
    ],
    products: [
        .library(
            name: "Moqintosh",
            targets: ["Moqintosh"]
        ),
        .library(
            name: "RealtimeMediaKit",
            targets: ["RealtimeMediaKit"]
        )
    ],
    targets: [
        .target(
            name: "Moqintosh",
            path: "Moqintosh",
            exclude: [
                "Moqintosh.h",
                "Moqintosh.docc",
            ],
            sources: ["Source"]
        ),
        .target(
            name: "RealtimeMediaKit",
            dependencies: ["Moqintosh"],
            path: "RealtimeMediaKit",
            exclude: [
                "RealtimeMediaKit.docc",
            ]
        ),
        .testTarget(
            name: "MoqintoshTests",
            dependencies: ["Moqintosh"],
            path: "MoqintoshTests"
        ),
        .testTarget(
            name: "RealtimeMediaKitTests",
            dependencies: ["RealtimeMediaKit"],
            path: "RealtimeMediaKitTests"
        )
    ]
)
