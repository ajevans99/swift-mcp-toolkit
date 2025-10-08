# Response Customization Strategy

## Overview
Client applications now have complete control over how the toolkit communicates back to the model and, by extension, the user. Prior to this work, the toolkit shipped fixed English strings for success and error paths. That limitation prevented product teams from expressing their own voice, surfacing structured data, or tailoring the tone to specific scenarios (support, compliance, experimentation, etc.).

The implementation introduces a flexible response customization layer that keeps the previous behaviour by default while enabling integrators to override any message or payload the toolkit emits.

## Current State
- `Server.register(tools:)` constructs `CallTool.Result` responses in-line with hard-coded strings whenever registration or invocation fails.【F:Sources/MCPToolkit/Extensions/Server+register.swift†L18-L42】
- `MCPTool.call(arguments:)` translates validation and decoding failures directly into English-only error messages.【F:Sources/MCPToolkit/Extensions/MCPTool+MCP.swift†L13-L56】
- Callers cannot intercept or modify the payload before it is returned to the model, so adopting a different tone, format, or locale requires forking the toolkit.

## Goals
1. Decouple message creation from business logic so every response can be customized.
2. Preserve backwards compatibility by providing a default configuration that reproduces the current strings and structure.
3. Allow overrides to supply plain strings, richly formatted results, or async closures that compute content dynamically.
4. Ensure the customization API remains ergonomic for both lightweight tweaks (e.g. replacing a single message) and fully branded experiences.

## Implemented Solution
### 1. Response Customization Provider
- Added a `ResponseMessaging` protocol enumerating every toolkit-managed response. Each method receives a strongly typed context (e.g. `ResponseMessagingToolErrorContext`) so overrides can inspect tool names, thrown errors, parse issues, or validation results.
- Introduced `DefaultResponseMessaging`, which preserves the previous hard-coded English messages to keep the API backwards compatible.

### 2. Wiring Through Core APIs
- Extended `Server.register(tools:messaging:)` with an optional `messaging` parameter that defaults to `DefaultResponseMessaging()`.
- Updated `MCPTool.call(arguments:messaging:)` to accept the provider and route parsing/validation failures through it.
- All toolkit-owned error surfaces—unknown tool, missing arguments, thrown errors, parsing failures, validation failures—now flow through the messaging abstraction.

### 3. Convenience Builders
- Added `ResponseMessagingFactory.defaultWithOverrides(_:)` so integrators can override only the messages they care about while inheriting defaults for the rest.
- Builder closures are `@Sendable`, making them safe for concurrent invocation.

### 4. Documentation & Migration Guidance
- README and DocC samples now show how to pass a custom messaging provider when registering tools.
- The `docs/` plan doubles as a quick reference for the available contexts and extension points.

### 5. Testing & Validation
- Added unit tests covering default behaviour, custom parsing overrides, and `Server.register` integration with bespoke messaging.
- Existing tests exercising validation output continue to pass, ensuring no regressions for the default strings.

## Rollout Strategy
1. **Introduce** – Ship the protocol, default implementation, and builder APIs with backwards compatible defaults.
2. **Integrate** – Route all existing response paths through the provider.
3. **Document** – Publish examples and guidance in README, DocC, and this document.
4. **Iterate** – Gather adopter feedback for future enhancements (e.g. async overrides or richer metadata helpers).

## Risks & Mitigations
- **API surface growth**: Keep protocol requirements tightly scoped to existing message types and evolve via new methods when necessary.
- **Performance**: Closures should execute quickly; document that expensive operations belong outside the response layer.
- **Backward compatibility**: Default implementation preserves today’s behavior, and the new parameter remains optional.

## Acceptance Criteria
- Integrators can customize any toolkit-generated message without duplicating toolkit logic.
- Default responses remain unchanged for consumers who do not opt in.
- Examples and tests clearly illustrate how to adopt the new customization layer for tone, structure, or localization.
