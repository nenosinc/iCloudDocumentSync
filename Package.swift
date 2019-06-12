// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "iCloud Document Sync",
    products: [
        .library(name: "iCloudDocumentSync", targets: ["CloudDocumentSync"])
    ],
    dependencies: [
        
    ],
    targets: [
        .target(name: "CloudDocumentSync", 
                dependencies: [],
                path: "CloudDocumentSync"
        ),
    ]
)
