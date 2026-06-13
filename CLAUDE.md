# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VitaMind is a SwiftUI-based iOS + watchOS app built with Xcode 26.5 and Swift 5.0. The iOS companion app embeds the watchOS app.

## Build Commands

Build the iOS app:
```bash
xcodebuild -project VitaMind.xcodeproj -scheme VitaMind -sdk iphoneos -configuration Debug build
```

Build the watchOS app:
```bash
xcodebuild -project VitaMind.xcodeproj -scheme "VitaMind Watch App" -sdk watchos -configuration Debug build
```

Run in simulator (iOS):
```bash
xcodebuild -project VitaMind.xcodeproj -scheme VitaMind -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Run in simulator (watchOS):
```bash
xcodebuild -project VitaMind.xcodeproj -scheme "VitaMind Watch App" -sdk watchsimulator -destination 'platform=watchOS Simulator,name=Apple Watch Series 10' build
```

No test targets exist yet. To add tests, create a new target in Xcode of type Unit Testing Bundle.

## Architecture

**Two-target setup:**
- **VitaMind** (iOS, `zzz.VitaMind`) — The companion iPhone/iPad app. Entry point: `VitaMind/VitaMindApp.swift`. Deployment target: iOS 26.5.
- **VitaMind Watch App** (watchOS, `zzz.VitaMind.watchkitapp`) — The standalone watch app. Entry point: `VitaMind Watch App/VitaMindApp.swift`. Deployment target: watchOS 26.5. Embedded into the iOS app via the "Embed Watch Content" build phase.

The project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+), meaning any Swift files added to the `VitaMind/` or `VitaMind Watch App/` directories are automatically included in their respective targets — no manual Xcode file management needed.

**Key project settings:**
- Development team: `DTZHWFPHT3`
- Code signing: Automatic
- Swift concurrency: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- No external package dependencies

## Adding Features

When adding shared code between the iOS and watchOS targets, consider creating a shared framework target or adding the file to both `PBXFileSystemSynchronizedRootGroup` groups. For watch-to-phone communication, use `WatchConnectivity` framework (`WCSession`).
