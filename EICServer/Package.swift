// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "EICServer",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "EICServer", targets: ["EICServer"]),
  ],
  dependencies: [
    .package(path: "../EICShared"),
    .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "EICServer",
      dependencies: [
        "EICShared",
        .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
      ],
      path: "Sources"
    ),
  ]
)
