//
//  CloudFile.swift
//  Cloud Files
//
//  Created by Sam Spencer on 9/10/19.
//  Copyright © 2019 Sam Spencer. All rights reserved.
//

import Foundation

/// Type-safe structure to access returned iCloud content
public struct CloudFile {
    public var name: String = ""
    public var metadata: UbiquitousMetadataItem
    public var content: iCloudDocument
    
    public init(filename: String, meta: UbiquitousMetadataItem, document: iCloudDocument) {
        name = filename
        metadata = meta
        content = document
    }
}
