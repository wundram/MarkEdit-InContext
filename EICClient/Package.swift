// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "EICClient",
  platforms: [.macOS(.v15)],
  dependencies: [
    .package(path: "../EICShared"),
    .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
  ],
  targets: [
    .executableTarget(
      name: "eic",
      dependencies: [
        "EICShared",
        .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources"
    ),
  ]
)
