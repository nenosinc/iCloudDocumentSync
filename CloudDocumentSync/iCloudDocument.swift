//
//  iCloudDocument.swift
//  CloudDocumentSync
//
//  Created by Sam Spencer on 6/11/19.
//  Copyright © 2019 iRare Media. All rights reserved.
//

import UIKit

public protocol iCloudDocumentDelegate {
    /// Handle errors during an attempt to read, save, or revert a document.
    func documentErrorOccurred(error: Error)
}

/// iCloudDocumentSync will normally manage all reading and writing using an iCloudDocument object. All document content will be stored and returned as `Data`. However, if you choose to subclass an iCloudDocument to define your own document structure and data format, you must still provide mechanisms to read and write your custom format using the `Data` type.
public class iCloudDocument: UIDocument {
    
    public var contents: Data = Data.init()
    public var delegate: iCloudDocumentDelegate?
    
    public override var localizedName: String {
        return fileURL.lastPathComponent
    }
    
    public var stateDescription: String {
        var string = ""
        
        switch documentState {
        case .normal:
            string = NSLocalizedString("Document state is normal", comment: "iCloud Document State")
        case .closed:
            string = NSLocalizedString("Document is closed", comment: "iCloud Document State")
        case .inConflict:
            string = NSLocalizedString("Document is in conflict", comment: "iCloud Document State")
        case .savingError:
            string = NSLocalizedString("Document is experiencing a saving error", comment: "iCloud Document State")
        case .editingDisabled:
            string = NSLocalizedString("Document editing is disabled", comment: "iCloud Document State")
        default:
            string = NSLocalizedString("Document state is unknown", comment: "iCloud Document State")
        }
        
        return string
    }
    
    public override init(fileURL url: URL) {
        super.init(fileURL: url)
    }
    
    public override func load(fromContents contents: Any, ofType typeName: String?) throws {
        if let documentContents = contents as? NSData {
            self.contents = Data.init(referencing: documentContents)
        } else {
            // Could be an NSFileWrapper. This is not yet supported.
            self.contents = Data.init()
        }
    }
    
    public override func contents(forType typeName: String) throws -> Any {
        if self.contents.count <= 0 {
            throw NSError.init(domain: "No valid document data available.", code: 404, userInfo: ["typeName" : typeName])
        }
        
        return self.contents
    }
    
    public override func handleError(_ error: Error, userInteractionPermitted: Bool) {
        delegate?.documentErrorOccurred(error: error)
        super.handleError(error, userInteractionPermitted: userInteractionPermitted)
    }
    
    @objc func setDocumentData(_ newData: Data) {
        let oldData = contents
        contents = newData
        
        // Register the undo operation
        undoManager?.setActionName("Data Change")
        undoManager?.registerUndo(withTarget: self, selector: #selector(self.setDocumentData(_:)), object: oldData)
    }

}

extension NSFileVersion {
    
    func laterVersion(_ first: NSFileVersion, second: NSFileVersion) -> NSFileVersion {
        guard let firstDate = first.modificationDate else { return first }
        guard let secondDate = second.modificationDate else { return second }
        return (firstDate.compare(secondDate) != .orderedDescending) ? second : first
    }
    
}
