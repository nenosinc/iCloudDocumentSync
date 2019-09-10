//
//  iCloudDelegate.swift
//  CloudDocumentSync
//
//  Created by Sam Spencer on 6/11/19.
//  Copyright © 2019 iRare Media. All rights reserved.
//

import Foundation
import UIKit

public protocol iCloudDelegate {
    
    /// Called when the availability of iCloud changes
    /// 
    /// - Parameter cloudIsAvailable: Boolean value that is `true` if iCloud is available and `false` if iCloud is not available
    /// - Parameter ubiquityToken: An iCloud ubiquity token that represents the current iCloud identity. Can be used to determine if iCloud is available and if the iCloud account has been changed (ex. if the user logged out and then logged in with a different iCloud account). This object may be nil if iCloud is not available for any reason.
    /// - Parameter ubiquityContainer: The root URL path to the current application's ubiquity container. This URL may be `nil` until the ubiquity container is initialized.
    func availabilityDidChange(toState cloudIsAvailable: Bool, withUbiquityToken ubiquityToken: Any?, withUbiquityContainer ubiquityContainer: URL?)
    
    /// Called before iCloud queries begin.
    ///
    /// This may be useful to display interface updates.
    func fileUpdateDidBegin()
    
    /// Called when an iCloud query ends.
    /// 
    /// This may be useful to display interface updates.
    func fileUpdateDidEnd()
    
    /// Tells the delegate that the files in iCloud were modified
    /// 
    /// Only includes files that are downloaded and current. Not downloaded or stale downloads are **excluded**.
    /// - parameter files: List of current files in the app's iCloud documents directory. Each `CloudFile` contains a name, metadata, and contents.
    func filesChanged(_ files: [CloudFile])
    
    /// Sent to the delegate where there is a conflict between a local file and an iCloud file during an upload or download
    ///
    /// When both files have the same modification date and file content, iCloud Document Sync will not be able to automatically determine how to handle the conflict. As a result, this delegate method is called to pass the file information to the delegate which should be able to appropriately handle and resolve the conflict. The delegate should, if needed, present the user with a conflict resolution interface. iCloud Document Sync does not need to know the result of the attempted resolution, it will continue to upload all files which are not conflicting.
    /// 
    /// It is important to note that **this method may be called more than once in a very short period of time** - be prepared to handle the data appropriately.
    ///  
    /// The delegate is only notified about conflicts during upload and download procedures with iCloud. This method does not monitor for document conflicts between documents which already exist in iCloud. There are other methods provided to you to detect document state and state changes / conflicts.
    /// 
    /// - parameter cloudFile: Dictionary with the cloud file and various other information. This parameter contains the fileContent as Data, fileURL as URL, and modifiedDate as Date.
    /// - parameter localFile: Dictionary with the local file and various other information. This parameter contains the fileContent as Data, fileURL as URL, and modifiedDate as Date. */
    func fileConflictBetweenCloudFile(_ cloudFile: [String: Any]?, and localFile: [String: Any]?)
    
    /// Indicates that the availability of iCloud changed
    /// 
    /// - parameter isAvailable: Boolean value that is `true` when iCloud is available. `False` otherwise.
    /// - parameter ubiquityToken: A iCloud ubiquity identity token that represents the current iCloud identity. Can be used to determine if iCloud is available and if the iCloud account has changed (for e.g. user has logged out and again logged in with another account). This object maybe `nil` if iCloud is not available for any reason.
    /// - parameter ubiquityContainer: The root URL path to the current application's ubiquity container. This URL may be nil until the ubiquity container has been initialized.
    func iCloudAvailabilityDidChange(to isAvailable: Bool, token ubiquityToken: UbiquityIdentityToken?, with ubiquityContainer: URL?)
    
    /// Called when the iCloud initialization process is finished and the iCloud is available
    ///
    /// - Parameter ubiquityToken: A iCloud ubiquity identity token that represents current iCloud identity. Can be used to determine if iCloud is available and if the iCloud account has changed (e.g. user logged out and back in with another account). This object may be `nil` if iCloud is not available for any reason.
    /// - Parameter ubiquityContainer: The root URL path to the current application's ubiquity container. This URL may be `nil` until the ubiquity container is initialized.
    func iCloudDidFinishInitializing(with ubiquityToken: UbiquityIdentityToken?, with ubiquityContainer: URL?)
    
    /// Called before creating a iCloud Query filter. Specify the types of files to be queried.
    ///
    /// If this delegate is not implemented or returns `nil`, all files stored in the documents directory will be queried.
    ///
    /// - returns: String with one file extension formatted like this: "txt"
    var iCloudQueryLimitedToFileExtension: [String] { get }
    
}
