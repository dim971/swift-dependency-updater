# SwiftDependencyUpdater

A Swift Package Manager plugin that automates dependency version management across your iOS projects. This plugin updates version numbers in both `Package.swift` files and Xcode project files (`.pbxproj`) from a centralized `dependencies.yaml` configuration file.

## Table of Contents

- [Overview](#overview)
- [Setup](#setup)
  * [Method 1: Using `Package.swift` file](#method-1-using-packageswift-file)
  * [Method 2: Using Xcode UI](#method-2-using-xcode-ui-for-xcode-projects)
- [Configuration](#configuration)
  * [Creating dependencies.yaml](#creating-dependenciesyaml)
  * [Adding @dep Tags](#adding-dep-tags)
- [Usage](#usage)
  * [Option 1: Xcode UI](#option-1-xcode-ui)
  * [Option 2: Command Line](#option-2-command-line)
- [Example](#example)

---

## Overview

Managing dependency versions across multiple `Package.swift` files in a large iOS project can be error-prone and time-consuming. **SwiftDependencyUpdater** solves this by:

1. Storing all external dependency versions in a single `dependencies.yaml` file
2. Using `// @dep` comment tags to mark which dependencies should be auto-updated
3. Running a single command to update all marked dependencies across your entire project

---

## Setup

### Method 1: Using `Package.swift` file

Add the `swift-dependency-updater` package to your project's root `Package.swift`:

```swift
import PackageDescription

let package = Package(
    name: "YourProject",
    dependencies: [
        .package(
            url: "https://github.com/dim971/swift-dependency-updater.git",
            exact: "x.x.x"
        )
    ]
)
```

**Using in Xcode:**

1. Open your Xcode project
2. Go to **File > Packages > Resolve Package Versions** (or `swift package resolve` in terminal. Use `swift package update` to update the `Package.swift`)
3. Use `swift package plugin update-dependencies --allow-writing-to-package-directory` in terminal

### Method 2: Using Xcode UI (for Xcode projects)

1. Open your `.xcodeproj` file in Xcode
2. Select your project in the Project Navigator
3. Go to the **Package Dependencies** tab
4. Click the **+** button to add a package
5. Enter the URL: `https://github.com/dim971/swift-dependency-updater.git`
6. Choose the version rule (e.g., **Exact Version**: `x.x.x`)
7. Click **Add Package**
8. The plugin will be available in Xcode's context menu for your project

---

## Configuration

### Creating dependencies.yaml

Create a file named `Dependencies/dependencies.yaml` in your project root:

```yaml
firebase-ios-sdk: "12.3.0"
lottie-ios: "4.3.4"
Alamofire: "5.8.1"
swift-collections: "1.1.0"
```

**Default Location:** `Dependencies/dependencies.yaml` (relative to project root)
**Custom Location:** Use `--dependencies-path` argument to specify a different path

### Adding @dep Tags

Mark dependencies for auto-update by adding `// @dep <package-name>` comments:

```swift
let dependencies: [Package.Dependency] = [
    .package(path: "../FeatureModule"),
    .package(url: "https://github.com/firebase/firebase-ios-sdk.git", exact: "12.3.0"), // @dep firebase-ios-sdk
    .package(url: "https://github.com/airbnb/lottie-ios.git", exact: "4.3.4"), // @dep lottie-ios
    .package(url: "https://github.com/Alamofire/Alamofire.git", exact: "5.8.1"), // @dep Alamofire
]
```

**Important Rules:**
- The tag must be in the format: `// @dep <package-name>`
- Package name must match exactly with the key in `dependencies.yaml`
- Only dependencies using `exact:` version requirement are updated
- Tags can be on the same line as the `.package()` declaration

---

## Usage

### Option 1: Xcode UI

1. Open your Xcode project/workspace
2. Right-click on your project in the Project Navigator
3. Select **DependencyUpdater** from the context menu
4. Choose **Update Dependencies** command
5. Click **Run** in the confirmation dialog

The plugin will update all marked dependencies and show results in the Xcode console.

### Option 2: Command Line

Navigate to your project root directory and run:

```bash
# Update dependencies using default path (Dependencies/dependencies.yaml)
swift package plugin update-dependencies --allow-writing-to-package-directory

# Use a custom dependencies file location
swift package plugin update-dependencies \
    --dependencies-path path/to/custom-dependencies.yaml \
    --allow-writing-to-package-directory
```

**Additional Commands:**

```bash
# Resolve packages first (downloads/updates packages)
swift package resolve

# Update to latest versions matching your Package.swift requirements
swift package update

# Then run the plugin to sync versions from dependencies.yaml
swift package plugin update-dependencies --allow-writing-to-package-directory
```

**Note:** The `--allow-writing-to-package-directory` flag is required because the plugin modifies `Package.swift` files.

---

## Example

### File Structure
```
YourProject/
├── Dependencies/
│   └── dependencies.yaml
├── Package.swift
├── Modules/
│   ├── Core/Package.swift
│   ├── Networking/Package.swift
│   └── Features/Package.swift
```

### dependencies.yaml
```yaml
firebase-ios-sdk: "12.3.0"
lottie-ios: "4.3.4"
Alamofire: "5.8.1"
swift-collections: "1.1.0"
```

### Package.swift with @dep Tags
```swift
// Modules/Core/Package.swift
let dependencies: [Package.Dependency] = [
    .package(path: "../Networking"),
    .package(url: "https://github.com/firebase/firebase-ios-sdk.git", exact: "12.3.0"), // @dep firebase-ios-sdk
    .package(url: "https://github.com/airbnb/lottie-ios.git", exact: "4.3.4"), // @dep lottie-ios
    .package(url: "https://github.com/Alamofire/Alamofire.git", exact: "5.8.1"), // @dep Alamofire
]
```
