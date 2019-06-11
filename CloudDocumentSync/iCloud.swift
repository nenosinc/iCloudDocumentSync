//
//  iCloud.swift
//  CloudDocumentSync
//
//  Created by Sam Spencer on 6/11/19.
//  Copyright © 2019 iRare Media. All rights reserved.
//

import UIKit

public class iCloud: NSObject {
    
    
    // MARK: - Properties
    
    /// iCloud shared instance object.
    public static let sharedCloud = iCloud()
    
    /// iCloud Delegate must be set to recieve file and availability callbacks.
    public var delegate: iCloudDelegate?
    
    /// Enable verbose logging for detailed feedback in the console log during debugging. Turning this off only prints crucial log notes such as errors.
    public var verboseLogging: Bool = false
    private func printVerbose(_ items: Any...) {
        if verboseLogging == true {
            print(items)
        }
    }
    private func printIncorrectSetupWarning() {
        print("[iCloud] The systemt could not retrieve a valid iCloud container URL. iCloud is not available. iCloud may be unavailable for a number of reasons:\n            • The device has not yet been configured with an iCloud account, or the Documents & Data option is disabled\n            • Your app, \(self.appName), does not have properly configured entitlements\n            • Your app, \(self.appName), has a provisioning profile which does not support iCloud.\n            Go to http://bit.ly/18HkxPp for more information on setting up iCloud")
    }
    
    /// A constant path where ubiquitous documents can be accessed. Except in unusual cases, this value should not be changed.
    public var documentsDirectoryExtension: String = "Documents"
    private var appName: String {
        if let appDisplayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            return appDisplayName
        } else {
            return ""
        }
    }
    
    private var ubiquityContainer: URL?
    public var ubiquitousContainerURL: URL? {
        return ubiquityContainer
    }
    public var isUbiquityContainerAvailable: Bool {
        if ubiquityContainer != nil {
            return true
        } else {
            return false
        }
    }
    public var approximateCloudAvailability: Bool {
        if fileManager.ubiquityIdentityToken != nil {
            return true
        } else {
            return false
        }
    }
    private var ubiquitousDocumentsDirectoryURL: URL? {
        // Use the instance variable here - no need to start the retrieval process again
        if ubiquityContainer == nil {
            ubiquityContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil)
        }
        
        // Ensure that the documents directory is not nil, if it is return the local path
        guard let documentsDirectory = ubiquityContainer?.appendingPathComponent(documentsDirectoryExtension) else { 
            let nonUbiquitousDocumentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            printIncorrectSetupWarning()
            print("[iCloud] WARNING: Using local documents directory until iCloud is available.")
            delegate?.availabilityDidChange(toState: false, withUbiquityToken: nil, withUbiquityContainer: ubiquityContainer)
            return nonUbiquitousDocumentsDirectory
        }
        
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: documentsDirectory.path, isDirectory: &isDirectory)
        
        if exists {
            // It exists, check if it's a directory
            if isDirectory.boolValue == true {
                return documentsDirectory
            } else {
                do {
                    try fileManager.removeItem(atPath: documentsDirectory.path)
                    try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true, attributes: nil)
                    return documentsDirectory
                } catch {
                    print("Documents directory already exist but iCloud Document Sync was unable to access the directory for some reason.")
                    return nil
                }
            }
        } else {
            do {
                try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true, attributes: nil)
                return documentsDirectory
            } catch {
                print("Documents directory does not exist and iCloud Document Sync was unable to create the directory for some reason.")
                return nil
            }
        }
    }
    
    private var notificationCenter = NotificationCenter.default
    private var fileManager = FileManager.default
    public var fileExtension: String = "*"
    
    private var fileList: [AnyHashable] = []
    private var previousQueryResults: [UbiquitousMetaDataItem] = []
    private var query: NSMetadataQuery = NSMetadataQuery.init()
    
    private var updatesQueue: OperationQueue = OperationQueue()
    /// Temporarely pauses the updates queue in case you need to ensure a smooth UI. The updates will be enqueued and performed when the flag is set to false again.
    public var suspendUpdates: Bool = false {
        didSet {
            updatesQueue.isSuspended = suspendUpdates
        }
    }
    
    
    // MARK: - Setup
    
    override init() {
        super.init()
        
        let lockQueue = DispatchQueue(label: "updateSync")
        lockQueue.sync {
            updatesQueue.maxConcurrentOperationCount = 1
            updatesQueue.qualityOfService = .background
        }
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
    
    /** Setup iCloud Document Sync and begin the initial document syncing process.
     
    You **must call this method before using iCloud Document Sync** to avoid potential issues with syncing. This setup process ensures that all variables are initialized. A preliminary file sync will be performed when this method is called.
     
    - Parameter containerID: The fully-qualified container identifier for an iCloud container directory. The string you specify must not contain wildcards and must be of the form `<TEAMID>.<CONTAINER>`, where `<TEAMID>` is your development team ID and <CONTAINER> is the bundle identifier of the container you want to access. 
     
        The container identifiers for your app must be declared in the com.apple.developer.ubiquity-container-identifiers array of the .entitlements property list file in your Xcode project. 
        
        If you specify nil for this parameter, this method uses the first container listed in the com.apple.developer.ubiquity-container-identifiers entitlement array. */
    public func setupiCloudDocumentSync(withUbiquityContainer containerID: String?) {
        // Check the iCloud Ubiquity Container
        DispatchQueue.global(qos: .background).async(execute: {
            print("[iCloud] Initializing Ubiquity Container")
            if let ubiquityURL = self.fileManager.url(forUbiquityContainerIdentifier: containerID) {
                self.ubiquityContainer = ubiquityURL
                
                // We can write to the ubiquity container
                DispatchQueue.main.async(execute: {
                    // On the main thread, update UI and state as appropriate
                    print("[iCloud] Initializing Document Enumeration")
                    
                    // Check iCloud Availability
                    let cloudToken = self.fileManager.ubiquityIdentityToken
                    
                    // Sync and Update Documents List
                    self.enumerateCloudDocuments()
                    
                    // Subscribe to changes in iCloud availability (should run on main thread)
                    self.notificationCenter.addObserver(self, selector: #selector(self.checkCloudAvailability), name: .NSUbiquityIdentityDidChange, object: nil)
                    self.delegate?.iCloudDidFinishInitializing(with: cloudToken, with: self.ubiquityContainer)
                })
                
                // Log the setup
                print("[iCloud] Ubiquity Container Created and Ready")
            } else {
                self.printIncorrectSetupWarning()
                self.delegate?.availabilityDidChange(toState: false, withUbiquityToken: nil, withUbiquityContainer: self.ubiquityContainer)
            }
        })
        
        // Log the setup
        print("[iCloud] Initialized")
    }
    
    
    // MARK: - Checking Availability
    
    @objc public func checkCloudAvailability() -> Bool {
        if let cloudToken = fileManager.ubiquityIdentityToken {
            printVerbose("[iCloud] iCloud is available. Ubiquity URL: \(ubiquityContainer?.absoluteString ?? ""), Ubiquity Token: \(cloudToken)")
            delegate?.availabilityDidChange(toState: true, withUbiquityToken: cloudToken, withUbiquityContainer: ubiquityContainer)
            return true
        } else {
            printIncorrectSetupWarning()
            delegate?.availabilityDidChange(toState: false, withUbiquityToken: nil, withUbiquityContainer: ubiquityContainer)
            return false
        }
    }
    
    
    // MARK: - Syncing
    
    private func enumerateCloudDocuments() {
        // Log document enumeration
        printVerbose("[iCloud] Creating metadata query and notifications")
        
        // Setup iCloud Metadata Query
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        
        // Request information from the delegate
        if let _fileExtensions: [String] = self.delegate?.iCloudQueryLimitedToFileExtension, !_fileExtensions.isEmpty {
            self.fileExtension = _fileExtensions.joined(separator: ",")
            printVerbose("[iCloud] Document query filter has been set to IN { " + self.fileExtension + " }")
            self.query.predicate = NSPredicate(format: "(%K.pathExtension IN { " + _fileExtensions.map { "'" + $0 + "'" }.joined(separator: ",") + " })", NSMetadataItemFSNameKey)
        } else {
            self.query.predicate = NSPredicate(format: "(%K.pathExtension LIKE '" + self.fileExtension + "')", NSMetadataItemFSNameKey)
        }
        
        // Notify the responder that an update has begun
        notificationCenter.addObserver(self, selector: #selector(self.startUpdate(_:)), name: .NSMetadataQueryDidStartGathering, object: query)
        
        // Notify the responder that an update has been pushed
        notificationCenter.addObserver(self, selector: #selector(self.recievedUpdate(_:)), name: .NSMetadataQueryDidUpdate, object: query)
        
        // Notify the responder that the update has completed
        notificationCenter.addObserver(self, selector: #selector(self.endUpdate(_:)), name: .NSMetadataQueryDidFinishGathering, object: query)
        
        // Start the query on the main thread
        DispatchQueue.main.async(execute: {
            let startedQuery = self.query.start()
            if startedQuery == false {
                print("[iCloud] Failed to start query.")
                return
            } else {
                self.printVerbose("[iCloud] Query initialized successfully") // Log file query success
            }
        })
    }
    
    @objc private func startUpdate(_ notification: Notification?) {
        weak var wself = self
        updatesQueue.addOperation({
            // Log file update
            if wself?.verboseLogging == true {
                print("[iCloud] Beginning file update with NSMetadataQuery")
            }
            
            // Notify the delegate of the results on the main thread
            DispatchQueue.main.async(execute: {
                wself?.delegate?.fileUpdateDidBegin()
            })
        })
    }
    
    @objc private func recievedUpdate(_ notification: Notification?) {
        weak var wself = self
        updatesQueue.addOperation({
            // Log file update
            if wself?.verboseLogging == true {
                print("[iCloud] An update has been pushed from iCloud with NSMetadataQuery")
            }
            
            // Get the updated files
            wself?.updateFiles()
        })
        
    }
    
    @objc private func endUpdate(_ notification: Notification?) {
        weak var wself = self
        updatesQueue.addOperation({
            // Get the updated files
            wself?.updateFiles()
            
            // Notify the delegate of the results on the main thread
            DispatchQueue.main.async(execute: {
                wself?.delegate?.fileUpdateDidEnd()
            })
            
            // Log query completion
            if wself?.verboseLogging == true {
                print("[iCloud] Finished file update with NSMetadataQuery")
            }
        })
    }

    /** Check for and update the list of files stored in your app's iCloud Documents Folder. This method is automatically called by iOS when there are changes to files in the iCloud Directory. */
    public func updateFiles() {
        // Log file update
        printVerbose("[iCloud] Beginning file update with NSMetadataQuery")
        
        // Check for iCloud
        guard approximateCloudAvailability == true else { return }
        
        updatesQueue.addOperation {
            var discoveredFiles: [NSMetadataItem] = []
            var names: [String] = []
            
            let results: [UbiquitousMetaDataItem] = self.query.results.compactMap {
                UbiquitousMetaDataItem($0 as! NSMetadataItem)
            }
            
            results.forEach {
                if $0.status == .downloaded {
                    // File will be updated soon
                } else if $0.status == .current {
                    // Append metadata and filenames into arrays
                    discoveredFiles.append($0.item)
                    names.append($0.name)
                } else if $0.status == .notDownloaded {
                    var downloading: Bool = true
                    do {
                        try FileManager.default.startDownloadingUbiquitousItem(at: $0.url)
                    } catch {
                        downloading = false
                        self.printVerbose("[iCloud] Ubiquitous item failed to start downloading with error: " + error.localizedDescription)
                    }
                    
                    self.printVerbose("[iCloud] " + $0.url.lastPathComponent + " started downloading locally, successfull? " + ( downloading ? "true" : "false"))
                }
            }
            
            self.previousQueryResults = results
            
            // Notify delegate about results
            DispatchQueue.main.async { 
                self.delegate?.filesDidChange(discoveredFiles, with: names)
            }
        }
    }
    
}
