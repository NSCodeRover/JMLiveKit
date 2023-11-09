// swift-tools-version:5.4

import PackageDescription

let package = Package(
    name: "JMMediaStackSDK",
    products: [
        .library(name: "JMMediaStackSDK", targets: ["JMMediaStackSDK"])
    ],
    dependencies: [
        .package(
            name: "SwiftyJSON",
            url: "https://github.com/SwiftyJSON/SwiftyJSON.git",
            .upToNextMajor(from: "5.0.1")
        ),
        .package(
            name: "SocketIO",
            url: "https://github.com/socketio/socket.io-client-swift.git", 
            .upToNextMajor(from: "16.1.0")
        ),
        .package(
            name: "SwiftyBeaver",
            url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", 
           .upToNextMajor(from: "2.0.0")
        ),
        .package(
            name: "MMWormhole",
            url: "https://github.com/JioMeet/MMWormhole.git",
            from: "2.1.0"
        ),
    ],
    targets: [
        .binaryTarget(
            name: "Mediasoup",
            url: "https://storage.googleapis.com/cpass-sdk/libs/iOS/public/JMMedia/v_1_0_0/Mediasoup.xcframework.zip",
            checksum: "756904959dbe4bbf3bc843dff64548d89c8ea54226e81982b84d234d128901f1"
        ),
        .binaryTarget(
            name: "WebRTC",
            url: "https://storage.googleapis.com/cpass-sdk/libs/iOS/public/JMMedia/v_1_0_0/WebRTC.xcframework.zip",
            checksum: "0ca49f18e1e099bc1732c1949cc50111d79086ed575136477207e8646a553b2f"
        ),
        .target(
            name: "JMMediaStackSDK",
            dependencies: [
                .target(name: "Mediasoup"),
                .target(name: "WebRTC"),
                .product(name: "SwiftyJSON", package: "SwiftyJSON"),
                .product(name: "SocketIO", package: "SocketIO"),
                .product(name: "SwiftyBeaver", package: "SwiftyBeaver"),
                .product(name: "MMWormhole", package: "MMWormhole"),
            ],
            path: "JMMediaStackSDK",
			exclude: [], 
			linkerSettings: [
				.linkedFramework("UIKit", .when(platforms: [.iOS])),
				.linkedFramework("AVFoundation", .when(platforms: [.iOS])),
				.linkedFramework("AudioToolbox", .when(platforms: [.iOS])),
				.linkedFramework("CoreAudio", .when(platforms: [.iOS])),
				.linkedFramework("CoreMedia", .when(platforms: [.iOS])),
				.linkedFramework("CoreVideo", .when(platforms: [.iOS])),
			]
        ),
    ]
)
