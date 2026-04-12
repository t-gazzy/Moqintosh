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
        .testTarget(
            name: "MoqintoshTests",
            dependencies: ["Moqintosh"],
            path: "MoqintoshTests"
        )
    ]
)
