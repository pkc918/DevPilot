# macOS Project Relocation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the existing Swift/Xcode macOS project into `macos/` while keeping root-level build, versioning, release, and documentation references working.

**Architecture:** Treat `DevPilot/`, `DevPilot.xcodeproj/`, and `DevPilotInfo.plist` as one relocatable project unit. Keep repository-wide tooling at the root and update only paths that address the relocated Xcode project.

**Tech Stack:** Swift 6, SwiftUI, Xcode 16, Bash/Zsh, GitHub Actions

## Global Constraints

- Keep `script/`, `assets/`, `web/`, `.github/`, `docs/`, and `README.md` at the repository root.
- Preserve the user's existing uncommitted README change.
- Do not refactor Swift code or change application behavior.
- Do not reorganize the web project, shared assets, or documentation.

---

### Task 1: Relocate the macOS Xcode Project and Repair References

**Files:**
- Move: `DevPilot/` → `macos/DevPilot/`
- Move: `DevPilot.xcodeproj/` → `macos/DevPilot.xcodeproj/`
- Move: `DevPilotInfo.plist` → `macos/DevPilotInfo.plist`
- Modify: `script/build_and_run.sh:6`
- Modify: `script/set_version.sh:29`
- Modify: `.github/workflows/release.yml:43,50`
- Modify: `.gitignore:15-17`
- Modify: `README.md:43,46,52-65`

**Interfaces:**
- Consumes: Existing Xcode-relative references among `DevPilot.xcodeproj`, `DevPilot/`, and `DevPilotInfo.plist`.
- Produces: A macOS project addressable at `macos/DevPilot.xcodeproj` from repository-root tooling.

- [ ] **Step 1: Record the clean project baseline**

Run:

```bash
xcodebuild -project DevPilot.xcodeproj -scheme DevPilot -list
```

Expected: exit status `0` and output listing the `DevPilot` scheme. If package resolution requires unavailable network access, record that limitation and continue with the local structural checks below.

- [ ] **Step 2: Create the platform directory and move the project unit**

Run:

```bash
mkdir macos
mv DevPilot macos/DevPilot
mv DevPilot.xcodeproj macos/DevPilot.xcodeproj
mv DevPilotInfo.plist macos/DevPilotInfo.plist
```

Expected: all three paths exist under `macos/`, and none remains at the repository root.

- [ ] **Step 3: Update repository-root project references**

Make these exact substitutions while preserving all unrelated content:

```text
script/build_and_run.sh:
PROJECT_PATH="macos/DevPilot.xcodeproj"

script/set_version.sh:
project_file="macos/DevPilot.xcodeproj/project.pbxproj"

.github/workflows/release.yml:
-project macos/DevPilot.xcodeproj

.gitignore SwiftPM lockfile exception:
!macos/DevPilot.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

README.md build command:
xcodebuild -project macos/DevPilot.xcodeproj -scheme DevPilot -configuration Release

README.md Xcode path:
macos/DevPilot.xcodeproj
```

Update the README project tree so the Swift files are shown beneath `macos/DevPilot/`; do not alter the user's existing badge/link edit.

- [ ] **Step 4: Verify scripts and path consistency**

Run:

```bash
bash -n script/build_and_run.sh
zsh -n script/set_version.sh
rg -n -P '(?<!macos/)DevPilot\.xcodeproj' --glob '!docs/superpowers/**' --glob '!web/node_modules/**' --glob '!web/.nuxt/**' --glob '!web/.output/**' .
if git check-ignore -q macos/DevPilot.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved; then
  exit 1
fi
```

Expected: both syntax checks exit `0`; the search returns no active root-level project reference; the lockfile ignore check produces no output because the relocated `Package.resolved` remains trackable.

- [ ] **Step 5: Verify the relocated Xcode project**

Run:

```bash
xcodebuild -project macos/DevPilot.xcodeproj -scheme DevPilot -list
xcodebuild -project macos/DevPilot.xcodeproj -scheme DevPilot -configuration Debug -derivedDataPath /tmp/DevPilotDerivedData CODE_SIGNING_ALLOWED=NO build
```

Expected: the project lists the `DevPilot` scheme and the build ends with `** BUILD SUCCEEDED **`. If dependency download is blocked, verify `macos/DevPilot.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` and report the environmental blocker separately from structural correctness.

- [ ] **Step 6: Review the final diff and commit**

Run:

```bash
git status --short
git diff --check
git diff --stat
```

Expected: Git recognizes the project files as moves where possible, only the planned path references changed, and `git diff --check` reports no whitespace errors.

Commit only the relocation and its necessary reference updates:

```bash
git add macos script/build_and_run.sh script/set_version.sh .github/workflows/release.yml .gitignore README.md
git commit -m "chore: move macOS project into platform directory"
```
