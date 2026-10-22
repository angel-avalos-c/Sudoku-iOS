# SudokuApp iOS scaffold

The native app is a minimal SwiftUI application with one root screen. It links
the repository's `SudokuCore` Swift package as a local dependency; no game UI
is implemented here.

The deployment target is iOS 16.0. The committed Xcode project is described by
`project.yml`; CI regenerates it with XcodeGen 2.46.0 and fails when the result
differs from the committed project. The iOS workflow uses the `macos-15`
GitHub-hosted image and selects Xcode 16.4 explicitly.

The simulator build cannot be run on Windows. On macOS, use the same command as
CI from the repository root:

```sh
xcodebuild -project iOS/SudokuApp.xcodeproj -scheme SudokuApp -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
```
