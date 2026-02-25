// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "EICShared",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "EICShared", targets: ["EICShared"]),
  ],
  dependencies: [
    .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "EICShared",
      dependencies: [
        .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
      ],
      path: "Sources"
    ),
  ]
)
