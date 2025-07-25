// swift-tools-version:5.7
// (Xcode14.0+)

import PackageDescription

let package = Package(
    name: "JMLiveKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .macCatalyst(.v14),
    ],
    products: [
        .library(
            name: "JMLiveKit",
            targets: ["JMLiveKit"]
        ),
        .library(
            name: "LKObjCHelpers",
            targets: ["LKObjCHelpers"]
        ),
        // New product for MediaSoup to use LiveKit's WebRTC
        .library(
            name: "LiveKitWebRTCForMediaSoup",
            targets: ["LiveKitWebRTCForMediaSoup"]
        ),
    ],
    dependencies: [
        // LK-Prefixed Dynamic WebRTC XCFramework
        .package(url: "https://github.com/livekit/webrtc-xcframework.git", exact: "125.6422.33"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.26.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.4"),
        //.package(url: "https://github.com/NSCodeRover/swift-collections.git", branch: "livekitBranch"),
        .package(url: "https://github.com/apple/swift-collections.git", .upToNextMinor(from: "1.1.0")),
        // Only used for DocC generation
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.3.0"),
        // Only used for Testing
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "4.13.4"),
    ],
    targets: [
        .target(
            name: "LKObjCHelpers",
            publicHeadersPath: "include"
        ),
        // New target that re-exports LiveKitWebRTC for MediaSoup compatibility
        .target(
            name: "LiveKitWebRTCForMediaSoup",
            dependencies: [
                .product(name: "LiveKitWebRTC", package: "webrtc-xcframework"),
            ],
            path: "Sources/LiveKitWebRTCForMediaSoup"
        ),
        .target(
            name: "JMLiveKit",
            dependencies: [
                .product(name: "LiveKitWebRTC", package: "webrtc-xcframework"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "DequeModule", package: "swift-collections"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "Logging", package: "swift-log"),
                "LKObjCHelpers",
            ],
            path: "Sources/LiveKit",
            exclude: [
                "Broadcast/NOTICE",
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
        .testTarget(
            name: "LiveKitTests",
            dependencies: [
                "JMLiveKit",
                .product(name: "JWTKit", package: "jwt-kit"),
            ]
        ),
        .testTarget(
            name: "LiveKitTestsObjC",
            dependencies: [
                "JMLiveKit",
                .product(name: "JWTKit", package: "jwt-kit"),
            ]
        ),
    ],
    swiftLanguageVersions: [
        .v5,
    ]
)
