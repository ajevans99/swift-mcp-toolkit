// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "swift-mcp-toolkit",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
    .tvOS(.v17),
    .watchOS(.v10),
  ],
  products: [
    .library(
      name: "MCPToolkit",
      targets: ["MCPToolkit"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/ajevans99/swift-json-schema.git", from: "0.9.0"),
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
  ],
  targets: [
    .target(
      name: "MCPToolkit",
      dependencies: [
        .product(name: "JSONSchema", package: "swift-json-schema"),
        .product(name: "JSONSchemaBuilder", package: "swift-json-schema"),
        .product(name: "MCP", package: "swift-sdk"),
      ]
    ),
    .testTarget(
      name: "MCPToolkitTests",
      dependencies: ["MCPToolkit"]
    ),
  ]
)
