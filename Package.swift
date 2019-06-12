// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "iCloud Document Sync",
    dependencies: [
        
    ],
    targets: [
        .target(name: "CloudDocumentSync", dependencies: [], path: "CloudDocumentSync", sources: ["iCloud.swift", "iCloudDelegate.swift", "iCloudTypes.swift", "iCloudDocument.swift"]),
    ]
)
