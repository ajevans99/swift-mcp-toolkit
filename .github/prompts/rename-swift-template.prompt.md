---
description: "Rename Swift template references with package + target naming conventions."
mode: agent
tools: ['codebase', 'editFiles']
---
You are an automated refactoring assistant for Swift projects. The user has cloned a Swift Package template and wants to rename it to their desired package and target names, following Swift naming conventions.

Inputs:
- `${input:oldName:SPMTemplate}` = the old template identifier
- `${input:newPackageName:swift-my-library}` = the new Swift Package name (kebab-case)
- `${input:newTargetName:MyLibrary}` = the new primary Swift target/module name (PascalCase)

Task: Refactor the repository after cloning a template.

Steps:
1. **Package.swift**
   - Replace all occurrences of `${input:oldName}` with `${input:newPackageName}` in `name:` and dependency declarations.
   - Ensure the package `name` field uses kebab-case.
   - Do not modify external dependency declarations unless they reference the template’s own name.

2. **Targets & Sources**
   - Rename `Sources/${input:oldName}` → `Sources/${input:newTargetName}`.
   - Rename `Tests/${input:oldName}Tests` → `Tests/${input:newTargetName}Tests`.
   - Update `target(name: ...)` and `testTarget(name: ...)` to `${input:newTargetName}`.
   - Update all Swift files in `Sources/` and `Tests/` to replace `${input:oldName}` with `${input:newTargetName}`.
   - Ensure module imports use PascalCase (`import ${input:newTargetName}`).
   - Update example code to rename the struct in `${input:oldName}.swift` to `${input:newTargetName}`.

3. **Configs and Misc**
   - Update `.github/workflows/*.yml`, Dockerfiles, `.env`, and other configs to replace `${input:oldName}` with `${input:newPackageName}` where referring to the package, and `${input:newTargetName}` where referring to modules.
    - If CI references the scheme `<package-name>-Package`, update to `${input:newPackageName}-Package`.
   - Update `README.md` headings, install instructions (`.package(url: ...)`), and code examples.
   - Update `.spi.yml` configs to reflect new names.
   - Update DocC bundles (e.g., `Sources/${input:newTargetName}/Documentation.docc/*.md`) to use the new module name in code blocks and symbol links (``${input:newTargetName}``).
   - Update example code to rename the struct/type in `${input:oldName}.swift` to `${input:newTargetName}`.

4. **Directory & File System**
   - If any directory names or file paths contain `${input:oldName}`, rename them consistently (kebab-case for package, PascalCase for module).
   - Use identifier-safe (whole word / symbol-aware) replacements to avoid partial matches.

5. **Verification**
   - Run `swift build` and `swift test` to confirm that the refactor succeeded.
   - Ensure all imports and module names resolve.
   - Optionally run formatting (`make format`) to normalize diffs.
   - Remove the `Template Renaming` section from `README.md` if present.

Final Output:
- A markdown checklist of applied changes (with `[x]` marks).
- A list of files updated.
- Any build/test errors encountered.