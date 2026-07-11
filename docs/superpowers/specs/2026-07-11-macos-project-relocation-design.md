# macOS Project Relocation Design

## Goal

Move the existing macOS Swift/Xcode project under a top-level `macos/` directory so the repository can host additional platform implementations without mixing platform-specific source at the root.

## Scope

Move the macOS project as one unit:

```text
macos/
├── DevPilot/
├── DevPilot.xcodeproj/
└── DevPilotInfo.plist
```

Keep `script/`, `assets/`, `web/`, `.github/`, `docs/`, and the root `README.md` in their current locations.

## Path Updates

Update root-level macOS build and version scripts to reference `macos/DevPilot.xcodeproj`. Update the release workflow wherever it invokes the same Xcode project so automated releases continue to build after the move. Update user-facing build commands in the root README only where necessary to prevent stale instructions, while preserving the existing uncommitted README change.

Because the Xcode project, source directory, and Info.plist move together, their existing relative references inside `project.pbxproj` should remain valid. They will be changed only if verification shows otherwise.

## Verification

- Search tracked files for stale root-level `DevPilot.xcodeproj` references.
- Confirm Xcode can list the project and schemes at `macos/DevPilot.xcodeproj`.
- Run a macOS Debug build without code signing.
- Run relevant shell syntax checks for changed scripts.
- Confirm unrelated files and the user's existing README edit are preserved.

## Non-goals

- Moving or reorganizing `script/`.
- Refactoring Swift code or changing application behavior.
- Reorganizing shared marketing assets, documentation, or the web project.
- Adding another platform implementation in this change.
