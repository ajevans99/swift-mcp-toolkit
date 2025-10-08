# spm-template

[![CI](https://github.com/ajevans99/spm-template/actions/workflows/ci.yml/badge.svg)](https://github.com/ajevans99/spm-template/actions/workflows/ci.yml)

<!-- Add after SPI published
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fajevans99%2Fspm-template%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ajevans99/spm-template)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fajevans99%2Fspm-template%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ajevans99/spm-template) -->

A minimal Swift Package template targeting Swift 6.0+ with modern Swift Testing, CI for Linux/macOS/iOS, SPI config, and swift-format.

> [!TIP]
> The [`app` branch](https://github.com/ajevans99/spm-template/tree/app) contains an Xcode project template in `AppTemplate/` for creating iOS/macOS apps that links against the package in `Sources/SPMTemplate/` and has CI to build apps.

## Usage

Add this package as a dependency, then:

```swift
import SPMTemplate

let greeter = SPMTemplate()
print(greeter.greet(name: "World"))
```

## Development

- Format code with `make format`
- Lint with `make lint`
- Run tests: `swift test`

## License

MIT. See `LICENSE`.

## Template Renaming

To quickly rename this template to your own package/target names:

1. Open `.github/prompts/rename-swift-template.prompt.md`.
2. Provide inputs:
   - `oldName`: current module identifier (default: `SPMTemplate`)
   - `newPackageName`: your package in kebab-case (e.g. `swift-my-library`)
   - `newTargetName`: your primary module in PascalCase (e.g. `MyLibrary`)
3. Run the prompt with your AI assistant.
