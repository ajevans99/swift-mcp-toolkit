// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-mcp-toolkit-example",
  platforms: [
    .macOS(.v15)
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.0"),
    .package(name: "swift-mcp-toolkit", path: "../"),
    .package(url: "https://github.com/vapor/vapor.git", from: "4.117.0"),
  ],
  targets: [
    .executableTarget(
      name: "MCPToolkitExample",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "MCPToolkit", package: "swift-mcp-toolkit"),
        .product(name: "Vapor", package: "vapor"),
      ]
    )
  ]
)
