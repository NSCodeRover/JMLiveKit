// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JMLiveKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "JMLiveKit",
            targets: ["JMLiveKit"]
        ),
        .library(
            name: "JMLiveKitCore",
            targets: ["JMLiveKitCore"]
        ),
        .library(
            name: "JMLiveKitScreenShare",
            targets: ["JMLiveKitScreenShare"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.25.0"),
        .package(url: "https://github.com/google/promises.git", from: "2.3.0"),
        .package(url: "https://github.com/livekit/webrtc-sdk.git", from: "114.5735.08"),
        .package(url: "https://github.com/livekit/webrtc-lk.git", from: "125.6422.33"),
        .package(url: "https://github.com/NSCodeRover/SwiftLogJM.git", exact: "1.6.5")
    ],
    targets: [
        .target(
            name: "JMLiveKit",
            dependencies: [
                "JMLiveKitCore",
                "JMLiveKitScreenShare"
            ],
            path: "Sources/LiveKit"
        ),
        .target(
            name: "JMLiveKitCore",
            dependencies: [
                .product(name: "Starscream", package: "Starscream"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "PromisesSwift", package: "promises"),
                .product(name: "WebRTC", package: "webrtc-sdk"),
                .product(name: "LiveKitWebRTC", package: "webrtc-lk"),
                .product(name: "SwiftLogJM", package: "SwiftLogJM")
            ],
            path: "Sources/Core"
        ),
        .target(
            name: "JMLiveKitScreenShare",
            dependencies: [
                .product(name: "Starscream", package: "Starscream"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "PromisesSwift", package: "promises"),
                .product(name: "WebRTC", package: "webrtc-sdk"),
                .product(name: "LiveKitWebRTC", package: "webrtc-lk"),
                .product(name: "SwiftLogJM", package: "SwiftLogJM")
            ],
            path: "Sources/ScreenShare",
            swiftSettings: [
                .define("APPLICATION_EXTENSION_API_ONLY")
            ]
        )
    ]
)
