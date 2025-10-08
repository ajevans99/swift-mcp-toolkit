# AGENTS.md

This repository uses a standard Swift project template.  
These are the rules and expectations for any AI agents working inside this repo.

---

## Language & Concurrency
- All code must be written in Swift (Swift 6+).
- Use **structured concurrency**: prefer `async/await` and `actors`.
- Do not introduce completion handlers, GCD, or callbacks unless absolutely required by an API.

---

## Package & Target Naming
- Swift Package name (in `Package.swift`) must be **kebab-case**:  
  Example: `swift-json-schema`
- Targets and modules (in `Sources/` and `Tests/`) must be **PascalCase**:  
  Example: `JSONSchema`
- Update both `Sources/<TargetName>` and `Tests/<TargetName>Tests`.

---

## Formatting & Linting
- Run `make format` before committing. This auto-formats code with `swift-format`.
- Run `make lint` to check lint errors not auto-fixed by the formatter.
- Code must compile and pass both formatting and lint checks before merging.

---

## Testing
- Use **Swift Testing** (`import Testing`) instead of XCTest.
- Every new public function should include at least one test.
- Async code should be tested with `@Test func ... async throws`.
- Keep tests small and focused, unless an integration test is explicitly needed.
- Use `swift test` to run all tests and ensure they pass before merging.

---

## Documentation & Examples
- Add doc comments (`///`) for all public APIs.
- Keep README code examples in sync with the current target/module name.
- Update import examples: `import <TargetName>`.
- Use minimal imports, for example, avoid `import Foundation` unless necessary.

---

## Security & Safety
- Always handle thrown errors explicitly.
- Avoid force unwraps (`!`) or unchecked casts.
- Use type-safe APIs whenever possible.

---

## Agent Behavior
- Do not scaffold entire applications unless explicitly asked.
- Prefer to make small, precise changes that align with these rules.
- When suggesting alternatives, explain trade-offs clearly.
- Always produce code that builds and passes tests locally.

---
