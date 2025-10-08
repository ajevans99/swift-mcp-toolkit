// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "spm-template",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v17),
    .macOS(.v13),
    .tvOS(.v17),
    .watchOS(.v10),
  ],
  products: [
    .library(
      name: "SPMTemplate",
      targets: ["SPMTemplate"]
    ),
    .executable(
      name: "Playground",
      targets: ["Playground"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "SPMTemplate"
    ),
    .executableTarget(
      name: "Playground",
      dependencies: ["SPMTemplate"]
    ),
    .testTarget(
      name: "SPMTemplateTests",
      dependencies: ["SPMTemplate"]
    ),
  ]
)
