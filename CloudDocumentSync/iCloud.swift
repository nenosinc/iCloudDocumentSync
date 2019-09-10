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
    
    /// Return application's local documents directory URL
    open var localDocumentsURL: URL? {
        get { return self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first }
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
    private var previousQueryResults: [UbiquitousMetadataItem] = []
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
    @objc public func setupiCloudDocumentSync(withUbiquityContainer containerID: String?) {
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
    
    /// Check if iCloud is available
    @objc public func checkCloudAvailability() -> Bool {
        if let cloudToken: UbiquityIdentityToken = fileManager.ubiquityIdentityToken {
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
    
    /// Check for and update the list of files stored in your app's iCloud Documents Folder. This method is automatically called by the system when there are changes to files in the iCloud Directory.
    public func updateFiles() {
        // Log file update
        printVerbose("[iCloud] Beginning file update with NSMetadataQuery")
        
        // Check for iCloud
        guard approximateCloudAvailability == true else { return }
        
        updatesQueue.addOperation {
            var files: [CloudFile] = []
            
            let results: [UbiquitousMetadataItem] = self.query.results.compactMap {
                UbiquitousMetadataItem($0 as! NSMetadataItem)
            }
            
            results.forEach { metadata in
                switch metadata.status {
                case .downloaded:
                    break
                case .current:
                    files.append(CloudFile.init(filename: metadata.name, 
                                                meta: metadata, 
                                                document: iCloudDocument.init(fileURL: metadata.url)))
                case .notDownloaded:
                    var downloading: Bool = true
                    do {
                        try FileManager.default.startDownloadingUbiquitousItem(at: metadata.url)
                    } catch {
                        downloading = false
                        self.printVerbose("[iCloud] Ubiquitous item failed to start downloading with error: " + error.localizedDescription)
                    }
                    
                    self.printVerbose("[iCloud] " + metadata.url.lastPathComponent + " started downloading locally, successfull? " + (downloading ? "true" : "false"))
                default:
                    break
                }
            }
            
            self.previousQueryResults = results
            
            // Notify delegate about results
            DispatchQueue.main.async {
                self.delegate?.filesChanged(files)
            }
        }
    }
    
    
    // MARK: - Saving
    
    /// Create, save, and close a document in iCloud.
    /// 
    /// First, iCloud Document Sync checks if the specified document exists. If the document exists it is saved and closed. If the document does not exist, it is created then closed.
    ///
    /// iCloud Document Sync uses `UIDocument` and `Data` to store and manage files. All of the heavy lifting with `Data` and `UIDocument` is handled for you. There's no need to actually create or manage any files, just give iCloudDocumentSync your data, and the rest is done for you.
    /// 
    /// To create a new document or save an existing one (close the document), use this method. 
    /// Documents can be created even if the user is not connected to the internet. The only case in which a document will not be created is when the user has disabled iCloud or if the current application is not setup for iCloud.
    /// 
    /// - parameter name: Filename of document being written to iCloud.
    /// - parameter content: Data containing file content.
    /// - parameter completion: Code block which is called after succesful file saving. Error will be `nil` if no error occured.
    public func saveAndCloseDocument(_ name: String, with content: Data, completion: ((UIDocument?, Data?, Error?) -> Void)? = nil) {
        printVerbose("[iCloud] Beginning document save")
        
        // Don't Check for iCloud... we need to save the file
        // regardless of being connected so that the saved file
        // can be pushed to the cloud later on.
        
        guard !name.isEmpty else {
            print("[iCloud] Specified document name must not be empty")
            completion?(nil, nil, NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return
        }
        
        guard let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name) else {
            print("[iCloud] Cannot create URL for file")
            completion?(nil, nil, NSError(domain: "Cannot create URL for file. Check iCloud's ubiquitousDocumentsDirectoryURL.", code: 001, userInfo: nil) as Error)
            return
        }
        
        let document: iCloudDocument = iCloudDocument(fileURL: fileURL)
        document.contents = content
        document.updateChangeCount(.done)
        
        if self.fileManager.fileExists(atPath: fileURL.path) {
            
            printVerbose("[iCloud] Document exists; overwriting, saving and closing")
            
            // Save and create the new document, then close it
            document.save(to: document.fileURL, for: .forOverwriting, completionHandler: {
                success in
                
                if success {
                    document.close(completionHandler: {
                        closed in
                        if closed {
                            self.printVerbose("[iCloud] Written, saved and closed document")
                            completion?(document, document.contents, nil)
                        } else {
                            print("[iCloud] Error while saving document: @saveAndCloseDocument")
                            completion?(document, document.contents, NSError(domain: "saveAndCloseDocument: error while saving document " + document.fileURL.path + " to iCloud", code: 110, userInfo: ["fileURL": fileURL]) as Error)
                        }
                    })
                } else {
                    print("[iCloud] Error while writing to the document: @saveAndCloseDocument")
                    completion?(document, document.contents, NSError(domain: "saveAndCloseDocument: error while writing to the document " + document.fileURL.path + " at iCloud", code: 100, userInfo: ["fileURL": fileURL]) as Error)
                }
            })
        } else {
            printVerbose("[iCloud] Document is new; creating, saving and then closing")
            document.save(to: document.fileURL, for: .forCreating, completionHandler: {
                success in
                if success {
                    document.close(completionHandler: {
                        closed in
                        if closed {
                            // Log the save and close
                            self.printVerbose("[iCloud] New document created, saved and closed successfully")
                            completion?(document, document.contents, nil)
                        } else {
                            print("[iCloud] Error while saving and closing document: @saveAndCloseDocument")
                            completion?(document, document.contents, NSError(domain: "saveAndCloseDocument: error while saving document " + document.fileURL.path + " to iCloud", code: 110, userInfo: ["fileURL": fileURL]) as Error)
                        }
                    })
                } else {
                    print("[iCloud] Error while creating the document: @saveAndCloseDocument")
                    completion?(document, document.contents, NSError(domain: "saveAndCloseDocument: error while creating the document " + document.fileURL.path + " in iCloud", code: 100, userInfo: ["fileURL": fileURL]) as Error)
                }
            })
        }
    }
    
    public func uploadLocalOfflineDocuments(repeatingHandler: ((String?, Error?) -> Void)!, completion: (() -> Void)? = nil) {
        printVerbose("[iCloud] Beginning local file upload to iCloud. This process may take a long time.")
        
        guard
            approximateCloudAvailability == true,
            let localDocuments: URL = self.localDocumentsURL,
            let localFiles: [String] = try? self.fileManager.contentsOfDirectory(atPath: localDocuments.path)
            else { return }
        
        DispatchQueue.global(qos: .background).async {
            self.printVerbose("[iCloud] Files stored locally available for uploading: ", localFiles)
            
            for item in localFiles {
                guard !item.hasPrefix(".") else {
                    DispatchQueue.main.async {
                        repeatingHandler(item, NSError(domain: "File in directory is hidden and will not be uploaded to iCloud.", code: 520, userInfo: ["Filename": item]) as Error)
                    }
                    continue
                }
                
                let cloudURL: URL = self.ubiquitousDocumentsDirectoryURL!.appendingPathComponent(item)
                let localURL: URL = localDocuments.appendingPathComponent(item)
                
                guard (self.previousQueryResults.map{ $0.name }).contains(item) else {
                    self.printVerbose("[iCloud] Uploading " + item + " to iCloud")
                    
                    // Move file to iCloud
                    var err: Error? = nil
                    do {
                        try self.fileManager.setUbiquitous(true, itemAt: localURL, destinationURL: cloudURL)
                    } catch {
                        err = error
                        print("[iCloud] Error while uploading document from local directory: " + error.localizedDescription)
                    }
                    
                    DispatchQueue.main.async {
                        repeatingHandler(item, err)
                    }
                    continue
                }
                
                // Log conflict
                self.printVerbose("[iCloud] Conflict between local file and remote file, attempting to automatically resolve")
                
                let document: iCloudDocument = iCloudDocument(fileURL: cloudURL)
                
                if
                    let cloud_modDate: Date = document.fileModificationDate,
                    let fileAttrs: [FileAttributeKey: Any] = try? self.fileManager.attributesOfItem(atPath: localURL.path),
                    let local_modDate: Date = fileAttrs[FileAttributeKey.modificationDate] as? Date,
                    let local_fileData: Data = self.fileManager.contents(atPath: localURL.path) {
                    
                    if cloud_modDate.compare(local_modDate) == .orderedDescending {
                        
                        print("[iCloud] The iCloud file was modified more recently than the local file. The local file will be deleted and the iCloud file will be preserved.")
                        
                        do {
                            try self.fileManager.removeItem(at: localURL)
                        } catch {
                            print("[iCloud] Error deleting " + localURL.path + ".\n\n" + error.localizedDescription);
                        }
                    } else if cloud_modDate.compare(local_modDate) == .orderedAscending {
                        
                        print("[iCloud] The local file was modified more recently than the iCloud file. The iCloud file will be overwritten with the contents of the local file.")
                        
                        // Replace iCloud document's content
                        document.contents = local_fileData
                        
                        DispatchQueue.main.async {
                            // Save and close the document in iCloud
                            document.save(to: document.fileURL, for: .forOverwriting, completionHandler: {
                                success in
                                if success {
                                    // Close the document
                                    document.close(completionHandler: {
                                        closed in
                                        repeatingHandler(item, nil)
                                    })
                                } else {
                                    print("[iCloud] Error while overwriting old iCloud file: @uploadLocalOfflineDocuments")
                                    repeatingHandler(item, NSError(domain: "uploadLocalOfflineDocuments: error while saving the document " + document.fileURL.path + " to iCloud", code: 110, userInfo: ["Filename": item]) as Error)
                                }
                            })
                        }
                    } else { // Modification date is same for both, local and cloud file
                        
                        print("[iCloud] The local file and iCloud file have the same modification date. Before overwriting or deleting, we will check if both files have the same content.")
                        
                        if self.fileManager.contentsEqual(atPath: cloudURL.path, andPath: localURL.path) {
                            print("[iCloud] The contents of local file and remote file match. The local file will be deleted.")
                            do {
                                try self.fileManager.removeItem(at: localURL)
                            } catch {
                                print("[iCloud] Error deleting " + localURL.path + ".\n\n" + error.localizedDescription);
                            }
                        } else { 
                            // Local and remote file did not match with equal contents.
                            print("[iCloud] Both the iCloud file and the local file were last modified at the same time, however their contents do not match. You'll need to handle the conflict using the iCloudFileConflictBetweenCloudFile(_ cloudFile: [String: Any]?, with localFile: [String: Any]?) delegate method.")
                            DispatchQueue.main.async {
                                self.delegate?.fileConflictBetweenCloudFile(["fileContents": document.contents, "fileURL": cloudURL, "modifiedDate": cloud_modDate], and: ["fileContents": local_fileData, "fileURL": localURL, "modifiedDate": local_modDate])
                            }
                        }
                    }
                } else {
                    print("[iCloud] Failed to retrieve information about either or both, local and remote file. You will need to handle the conflict using iCloudFileConflictBetweenCloudFile(_ cloudFile: [String: Any]?, with localFile: [String: Any]?) delegate method.")
                    DispatchQueue.main.async {
                        self.delegate?.fileConflictBetweenCloudFile(["fileURL": cloudURL], and: ["fileURL": localURL])
                    }
                }
            }
            
            // Log completion
            self.printVerbose("[iCloud] Finished uploading all local files to iCloud")
            DispatchQueue.main.async { completion?() }
        }
    }
    
    public func uploadLocalDocumentToCloud(_ name: String, completion: ((Error?) -> Void)? = nil ) {
        printVerbose("[iCloud] Attempting to upload document: " + name)
        
        guard
            approximateCloudAvailability == true,
            let localDocuments: URL = self.localDocumentsURL,
            let localURL: URL = localDocuments.appendingPathComponent(name) as URL?,
            let cloudURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name)
            else { return }
        
        guard !name.isEmpty else {
            print("[iCloud] Specified document name must not be empty")
            completion?(NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return
        }
        
        // Perform tasks on background thread to avoid problems on the main / UI thread
        DispatchQueue.global(qos: .background).async {
            // If the file does not exist in iCloud, upload it
            if (self.previousQueryResults.map{ $0.name }).contains(name) {
                self.printVerbose("[iCloud] Uploading " + name + " to iCloud")
                
                var err: Error? = nil
                // Move the file to iCloud
                do {
                    try self.fileManager.setUbiquitous(true, itemAt: localURL, destinationURL: cloudURL)
                } catch {
                    print("[iCloud] Error while uploading document from local directory: " +  error.localizedDescription);
                    err = error
                }
                
                DispatchQueue.main.async { completion?(err) }
            } else {
                // Check if the local document is newer than the cloud document
                self.printVerbose("[iCloud] Conflict between local file and remote file, attempting to automatically resolve")
                
                let document: iCloudDocument = iCloudDocument(fileURL: cloudURL)
                
                if
                    let cloud_modDate: Date = document.fileModificationDate,
                    let fileAttrs: [FileAttributeKey: Any] = try? self.fileManager.attributesOfItem(atPath: localURL.path),
                    let local_modDate: Date = fileAttrs[FileAttributeKey.modificationDate] as? Date,
                    let local_fileData: Data = self.fileManager.contents(atPath: localURL.path) {
                    
                    if cloud_modDate.compare(local_modDate) == .orderedDescending {
                        print("[iCloud] The iCloud file was modified more recently than the local file. The local file will be deleted and the iCloud file will be preserved.")
                        
                        do {
                            try self.fileManager.removeItem(at: localURL)
                        } catch {
                            print("[iCloud] Error deleting " + localURL.path + ".\n\n" + error.localizedDescription);
                        }
                    } else if cloud_modDate.compare(local_modDate) == .orderedAscending {
                        print("[iCloud] The local file was modified more recently than the iCloud file. The iCloud file will be overwritten with the contents of the local file.")
                        
                        // Replace iCloud document's content
                        document.contents = local_fileData
                        
                        DispatchQueue.main.async {
                            // Save and close the document in iCloud
                            document.save(to: document.fileURL, for: .forOverwriting, completionHandler: {
                                success in
                                if success {
                                    // Close the document
                                    document.close(completionHandler: {
                                        closed in
                                        completion?(nil)
                                    })
                                } else {
                                    print("[iCloud] Error while overwriting old iCloud file: @uploadLocalDocumentToCloud")
                                    completion?(NSError(domain: "uploadLocalDocumentToCloud: error while saving the document " + document.fileURL.path + " to iCloud", code: 110, userInfo: ["Filename": name]) as Error)
                                }
                            })
                        }
                    } else { 
                        // Modification date is same for both, local and cloud file
                        print("[iCloud] The local file and iCloud file have the same modification date. Before overwriting or deleting, we will check if both files have the same content.")
                        
                        if self.fileManager.contentsEqual(atPath: cloudURL.path, andPath: localURL.path) {
                            print("[iCloud] The contents of local file and remote file match. The local file will be deleted.")
                            
                            do {
                                try self.fileManager.removeItem(at: localURL)
                            } catch {
                                print("[iCloud] Error deleting " + localURL.path + ".\n\n" + error.localizedDescription);
                            }
                        } else { // Local and remote file did not match with equal contents.
                            print("[iCloud] Both the iCloud file and the local file were last modified at the same time, however their contents do not match. You'll need to handle the conflict using the iCloudFileConflictBetweenCloudFile(_ cloudFile: [String: Any]?, with localFile: [String: Any]?) delegate method.")
                            
                            DispatchQueue.main.async {
                                self.delegate?.fileConflictBetweenCloudFile([
                                    "fileContents": document.contents,
                                    "fileURL": cloudURL,
                                    "modifiedDate": cloud_modDate
                                    ], and: [
                                        "fileContents": local_fileData,
                                        "fileURL": localURL,
                                        "modifiedDate": local_modDate
                                    ])
                            }
                        }
                    }
                } else {
                    print("[iCloud] Failed to retrieve information about either or both, local and remote file. You will need to handle the conflict using iCloudFileConflictBetweenCloudFile(_ cloudFile: [String: Any]?, with localFile: [String: Any]?) delegate method.")
                    
                    DispatchQueue.main.async {
                        self.delegate?.fileConflictBetweenCloudFile(["fileURL": cloudURL], and: ["fileURL": localURL])
                    }
                }
            }
            
            // Log completion
            self.printVerbose("[iCloud] Finished uploading local file to iCloud")
            
            DispatchQueue.main.async { completion?(nil) }
        }
    }
    
    
    // MARK: - Sharing
    
    /**
     Share an iCloud document by uploading it to a public URL.
     
     Upload a document stored in iCloud to a public location on the internet for a limited amount of time.
     
     - Parameter name: The name of the iCloud file being uploaded to a public URL.
     - Parameter completion: Code block called after document is uploaded.
     
     - Returns: The public URL where the file is available */
    @discardableResult
    public func shareDocument(_ name: String, completion: ((URL?, Date?, Error?) -> Void)? = nil) -> URL? {
        printVerbose("[iCloud] Attempting to share document: " + name)
        
        guard
            approximateCloudAvailability == true,
            let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name)
            else { return nil }
        
        guard !name.isEmpty else {
            print("[iCloud] Specified document name must not be empty")
            completion?(nil, nil, NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return nil
        }
        
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            print("[iCloud] File not found: " + name)
            completion?(nil, nil, NSError(domain: "The document, " + name + ", does not exist at path " + fileURL.path, code: 404, userInfo: ["fileURL": fileURL]) as Error)
            return nil
        }
        
        printVerbose("[iCloud] File exists, preparing to share it")
        
        var resultURL: URL? = nil
        
        // Move to the background thread for safety
        DispatchQueue.global(qos: .background).async {
            var date: NSDate? = nil
            var err: Error? = nil
            
            do { // Create URL
                resultURL = try self.fileManager.url(forPublishingUbiquitousItemAt: fileURL, expiration: &date)
            } catch {
                resultURL = nil
                err = error
            }
            
            // Log share
            self.printVerbose("[iCloud] Shared iCloud document")
            DispatchQueue.main.async { completion?(resultURL, date == nil ? nil : Date(timeIntervalSinceReferenceDate: date!.timeIntervalSinceReferenceDate), err) }
        }
        
        return resultURL
    }
    
    
    // MARK: - Deleting
    
    /**
     Delete a document from iCloud.
     
     Permanently delete a document stored in iCloud. This will only affect copies of the specified file stored in iCloud, if there is a copy stored locally it will not be affected.
     
     - Parameter name: The name of the document to delete from iCloud.
     - Parameter completion: called when a file is successfully deleted from iCloud. Error object contains any error information if an error occurred, otherwise it will be nil. */
    public func deleteDocument(_ name: String, completion: ((Error?) -> Void)? = nil) {
        // Log delete
        printVerbose("[iCloud] Attempting to delete document: " + name)
        
        guard
            approximateCloudAvailability == true,
            let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name)
            else { return }
        
        guard !name.isEmpty else {
            print("[iCloud] Specified document name must not be empty")
            completion?(NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return
        }
        
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            print("[iCloud] File not found: " + name)
            completion?(NSError(domain: "The document, " + name + ", does not exist at path " + fileURL.path, code: 404, userInfo: ["fileURL": fileURL]) as Error)
            return
        }
        
        func finish() {
            completion?(nil)
        }
        
        printVerbose("[iCloud] File exists, attempting to delete it")
        
        let successfulSecurityScopedResourceAccess = fileURL.startAccessingSecurityScopedResource()
        
        // Use a file coordinator to safely delete the file
        let fileCoordinator: NSFileCoordinator = NSFileCoordinator(filePresenter: nil)
        let writingIntent: NSFileAccessIntent = NSFileAccessIntent.writingIntent(with: fileURL, options: .forDeleting)
        let backgroundQueue: OperationQueue = OperationQueue()
        fileCoordinator.coordinate(with: [writingIntent], queue: backgroundQueue, byAccessor: {
            accessError in
            
            if accessError != nil {
                print("[iCloud] Access error occurred while deleting document: " + accessError!.localizedDescription)
                completion?(accessError)
            } else {
                
                var success: Bool = true
                var _error: Error? = nil
                
                do {
                    try self.fileManager.removeItem(at: writingIntent.url)
                } catch {
                    success = false
                    print("[iCloud] An error occurred while deleting document: " + error.localizedDescription)
                    _error = error
                    DispatchQueue.main.async { completion?(error) }
                }
                
                if successfulSecurityScopedResourceAccess {
                    fileURL.stopAccessingSecurityScopedResource()
                }
                
                DispatchQueue.main.async {
                    if success {
                        self.updateFiles()
                    }
                    completion?(_error)
                }
            }
        })
    }
    
    /**
     Evict a document from iCloud, move it from iCloud to the current application's local documents directory.
     
     Remove a document from iCloud storage and move it into the local document's directory. This method may call the fileConflictBetweenCloudFile(cloudFile: [String: Any]?, with localFile: [String: Any]?)  iCloud Delegate method if there is a file conflict. */
    public func evictCloudDocument(_ name: String, completion: ((Error?) -> Void)? = nil) {
        // Log delete
        printVerbose("[iCloud] Attempting to evict iCloud document: " + name)
        
        guard
            approximateCloudAvailability == true,
            let localDocuments: URL = self.localDocumentsURL,
            let localURL: URL = localDocuments.appendingPathComponent(name) as URL?,
            let cloudURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name)
            else { return }
        
        guard !name.isEmpty else {
            print("[iCloud] Specified document name must not be empty")
            completion?(NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return
        }
        
        // Move to the background thread for safety
        DispatchQueue.global(qos: .background).async {
            if (self.previousQueryResults.map{ $0.name }).contains(name) {
                self.printVerbose("[iCloud] Conflict between local file and remote file, attempting to automatically resolve")
                
                // Create UIDocument object from URL
                let document: iCloudDocument = iCloudDocument(fileURL: cloudURL)
                
                if
                    let cloud_modDate: Date = document.fileModificationDate,
                    let fileAttrs: [FileAttributeKey: Any] = try? self.fileManager.attributesOfItem(atPath: localURL.path),
                    let local_modDate: Date = fileAttrs[FileAttributeKey.modificationDate] as? Date,
                    let local_fileData: Data = self.fileManager.contents(atPath: localURL.path) {
                    
                    if local_modDate.compare(cloud_modDate) == .orderedDescending {
                        print("[iCloud] The local file was modified more recently than the iCloud file. The iCloud file will be deleted and the local file will be preserved.")
                        self.deleteDocument(name, completion: {
                            err in
                            if err != nil {
                                print("[iCloud] Error deleting " + localURL.path + ".\n\n" + err!.localizedDescription)
                            }
                            DispatchQueue.main.async { completion?(err) }
                        })
                    } else if local_modDate.compare(cloud_modDate) == .orderedAscending {
                        print("[iCloud] The iCloud file was modified more recently than the local file. The local file will be overwritten with the contents of the iCloud file.")
                        var err: Error? = nil
                        do {
                            try document.contents.write(to: localURL, options: Data.WritingOptions.atomicWrite)
                        } catch {
                            print("[iCloud] Failed to overwrite file at URL: " + localURL.path)
                            err = error
                        }
                        DispatchQueue.main.async { completion?(err) }
                    } else { // Same
                        print("[iCloud] The local file and iCloud file have the same modification date. Before overwriting or deleting, we will check if both files have the same content.")
                        if self.fileManager.contentsEqual(atPath: cloudURL.path, andPath: localURL.path) {
                            print("[iCloud] The contents of local file and remote file match. Remote file will be deleted.")
                            self.deleteDocument(name, completion: {
                                err in
                                if err != nil {
                                    print("[iCloud] Error deleting " + localURL.path + ".\n\n" + err!.localizedDescription)
                                }
                                DispatchQueue.main.async { completion?(err) }
                            })
                            return
                        } else { // Local and remote file did not match with equal contents.
                            print("[iCloud] Both the iCloud file and the local file were last modified at the same time, however their contents do not match. You'll need to handle the conflict using the iCloudFileConflictBetweenCloudFile(_ cloudFile: [String: Any]?, with localFile: [String: Any]?) delegate method.")
                            DispatchQueue.main.async {
                                self.delegate?.fileConflictBetweenCloudFile([
                                    "fileContents": document.contents,
                                    "fileURL": cloudURL,
                                    "modifiedDate": cloud_modDate
                                    ], and: [
                                        "fileContents": local_fileData,
                                        "fileURL": localURL,
                                        "modifiedDate": local_modDate
                                    ])
                            }
                        }
                    }
                } else {
                    print("[iCloud] Failed to retrieve information about either or both, local and remote file. You will need to handle the conflict using iCloudFileConflictBetweenCloudFile(_ cloudFile: [String: Any]?, with localFile: [String: Any]?) delegate method.")
                    DispatchQueue.main.async {
                        self.delegate?.fileConflictBetweenCloudFile([
                            "fileURL": cloudURL
                            ], and: [
                                "fileURL": localURL
                            ])
                    }
                }
            } else {
                var err: Error? = nil
                do {
                    try self.fileManager.setUbiquitous(false, itemAt: cloudURL, destinationURL: localURL)
                } catch {
                    err = error
                }
                
                DispatchQueue.main.async { completion?(err) }
            }
        }
    }
    
    
    // MARK: - Retrieving
    
    /**
     Open a UIDocument stored in iCloud. If the document does not exist, a new blank document will be created using the documentName provided. You can use the doesFileExistInCloud: method to check if a file exists before calling this method.
     
     This method will attempt to open the specified document. If the file does not exist, a blank one will be created. The completion handler is called when the file is opened or created (either successfully or not). The completion handler contains a UIDocument, Data, and Error all of which contain information about the opened document.
     
     - Parameter name: The name of the document in iCloud.
     - Parameter completion: Called when the document is successfully retrieved (opened or downloaded). The completion block passes UIDocument and Data objects containing the opened document and it's contents in the form of Data. If there is an error, the Error object will have an error message (may be nil if there is no error). This value must not be nil.
     */
    
    public func retrieveCloudDocument(_ name: String, completion: ((UIDocument?, Data?, Error?) -> Void)!) {
        // Log retrieval
        
        printVerbose("[iCloud] Retrieving iCloud document: " + name)
        
        guard
            approximateCloudAvailability == true,
            let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name)
            else { return }
        
        guard !name.isEmpty else {
            print("[iCloud] Specified document name must not be empty")
            completion(nil, nil, NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return
        }
        
        // If file exists, open it - otherwise, create it
        if self.fileManager.fileExists(atPath: fileURL.path) {
            // Log open
            printVerbose("[iCloud] The document, " + name + ", already exists and will be opened")
            
            // Create the UIDocument object from the URL
            let document: iCloudDocument = iCloudDocument(fileURL: fileURL)
            
            if document.documentState == .closed {
                printVerbose("[iCloud] Document is closed and will be opened")
                
                document.open(completionHandler: {
                    success in
                    if success { // Log open
                        self.printVerbose("[iCloud] Opened document")
                        
                        // Pass data on to the completion handler
                        DispatchQueue.main.async { completion(document, document.contents, nil) }
                        return
                    } else {
                        print("[iCloud] Error while retrieving document: @retrieveCloudDocument")
                        // Pass data on to the completion handler
                        DispatchQueue.main.async {
                            completion(document, document.contents, NSError(domain: "retrieveCloudDocument: error while retrieving document, " + document.fileURL.path + " from iCloud", code: 200, userInfo: ["fileURL": fileURL]) as Error)
                        }
                        return
                    }
                })
            } else if document.documentState == .normal {
                
                // Log open
                printVerbose("[iCloud] Document already opened, retrieving content")
                
                // Pass data on to the completion handler
                DispatchQueue.main.async { completion(document, document.contents, nil) }
                return
                
            } else if document.documentState == .inConflict {
                
                // Log open
                printVerbose("[iCloud] Document in conflict. The document may not contain correct data. An error will be returned along with the other parameters in the completion handler")
                
                print("[iCloud] Error while retrieving document, " + name + ", because the document is in conflict")
                
                // Pass data on to the completion handler
                DispatchQueue.main.async { completion(document, document.contents, NSError(domain: "The iCloud document, " + name + ", is in conflict. Please resolve this conflict before editing the document.", code: 200, userInfo: ["fileURL": fileURL]) as Error) }
                return
                
                
            } else if document.documentState == .editingDisabled {
                
                // Log open
                printVerbose("[iCloud] Document editing disabled. The document is not currently editable, use the documentState: method to determine when the document is available again. The document and its contents will still be passed as parameters in the completion handler.")
                
                // Pass data on to the completion handler
                DispatchQueue.main.async { completion(document, document.contents, nil) }
                return
            }
        } else { // File did not exists, create it
            // Log creation
            printVerbose("[iCloud] The document, " + name + ", does not exist and will be created as an empty document")
            
            // Create UIDocument
            let document: iCloudDocument = iCloudDocument(fileURL: fileURL)
            document.contents = Data()
            
            // Save the new document to disk
            document.save(to: fileURL, for: .forCreating, completionHandler: {
                success in
                
                var err: Error? = nil
                
                // Log saving
                self.printVerbose("[iCloud] Saved and opened the document: " + name)
                
                if !success {
                    print("[iCloud] Failure when saving document " + name + " to iCloud: @retrieveCloudDocument")
                    err = NSError(domain: "retrieveCloudDocument: error while saving the document " + document.fileURL.path + " to iCloud", code: 110, userInfo: ["Filename": name]) as Error
                }
                
                DispatchQueue.main.async { completion(document, document.contents, err) }
            })
        }
    }
    
    /**
     Get the relevant iCloudDocument object for the specified file
     
     This method serves a very different purpose from the retrieveCloudDocument(_ name: String, completion: (UIDocument?, Data?, Error?) -> Void) method. Understand the differences between both methods and ensure that you are using the correct one. This method does not open, create, or save any UIDocuments - it simply returns the iCloudDocument object which you can then use for various purposes.
     
     - Parameter name: The name of the document in iCloud.
     */
    public func retrieveCloudDocumentObject(_ name: String) -> iCloudDocument? {
        
        // Log retrieval
        printVerbose("[iCloud] Retrieving iCloud document: " + name)
        
        guard
            approximateCloudAvailability == true,
            let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name)
            else { return nil }
        
        guard !name.isEmpty else {
            print("[iCloud] Specified document name must not be empty")
            return nil
        }
        
        let document: iCloudDocument = iCloudDocument(fileURL: fileURL)
        
        // If file exists, open it - otherwise, create it
        if self.fileManager.fileExists(atPath: fileURL.path), self.verboseLogging { print("[iCloud] The document, " + name + ", already exists and will be returned as iCloudDocument object")
        } else if self.verboseLogging {
            print("[iCloud] The document, " + name + ", does not exist but will be returned as an empty iCloudDocument object")
        }
        
        return document
    }
    
    /**
     Check if a file exists in iCloud
     
     - Parameter name: The name of the document in iCloud.
     
     - Returns: Boolean value. True if the file does exist in iCloud, false if it does not. May return false also if iCloud is unavailable.
     */
    public func fileExistInCloud(_ name: String) -> Bool {
        // Check for iCloud
        guard
            approximateCloudAvailability == true,
            !name.isEmpty,
            let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name)
            else { return false }
        
        return self.fileManager.fileExists(atPath: fileURL.path)
    }
    
    /**
     Returns a Boolean indicating whether the item is targeted for storage in iCloud.
     
     This method reflects only whether the item should be stored in iCloud because a call was made to the setUbiquitous(_:itemAt:destinationURL:) method with a value of true for its flag parameter. This method does not reflect whether the file has actually been uploaded to any iCloud servers. To determine a file’s upload status, check the NSURLUbiquitousItemIsUploadedKey attribute of the corresponding NSURL object.
     
     - Parameter name: Specify the name for the file or directory whose status you want to check.
     
     - Returns: true if the item is targeted for iCloud storage or false if it is not. This method also returns false if no item exists at url or iCloud is not available.
     */
    public func isUbiquitousItem(_ name: String) -> Bool {
        // Check for iCloud
        guard
            approximateCloudAvailability == true,
            !name.isEmpty,
            let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name)
            else { return false }
        
        return self.fileManager.isUbiquitousItem(at: fileURL)
    }
    
    /**
     Get the size of a file stored in iCloud
     
     - Parameter name: name of file in iCloud.
     - Returns: The number of bytes in an unsigned long long. Returns nil if the file does not exist. May return a nil value if iCloud is unavailable. */
    public func fileSize(_ name: String) -> NSNumber? {
        // Check for iCloud
        guard
            approximateCloudAvailability == true,
            !name.isEmpty,
            let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name)
            else { return nil }
        
        // Check if file exists, and return it's size
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            print("[iCloud] File not found: " + name)
            return nil
        }
        
        guard
            let attrs: [FileAttributeKey: Any] = try? self.fileManager.attributesOfItem(atPath: fileURL.path),
            let size: NSNumber = attrs[FileAttributeKey.size] as? NSNumber
            else { return nil }
        
        return size
    }
    
    /**
     Get the last modified date of a file stored in iCloud
     
     - Parameter name: name of file in iCloud.
     - Returns: The date that the file was last modified. Returns nil if the file does not exist. May return a nil value if iCloud is unavailable. */
    public func fileModified(_ name: String) -> Date? {
        // Check for iCloud
        guard
            approximateCloudAvailability == true,
            !name.isEmpty,
            let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name)
            else { return nil }
        
        // Check if file exists, and return it's modification date
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            print("[iCloud] File not found: " + name)
            return nil
        }
        
        guard
            let attrs: [FileAttributeKey: Any] = try? self.fileManager.attributesOfItem(atPath: fileURL.path),
            let date: Date = attrs[FileAttributeKey.modificationDate] as? Date
            else { return nil }
        
        return date
    }
    
    /**
     Get the creation date of a file stored in iCloud
     
     - Parameter name: name of file in iCloud.
     - Returns: The date that the file was created. Returns nil if the file does not exist. May return a nil value if iCloud is unavailable. */
    public func fileCreated(_ name: String) -> Date? {
        // Check for iCloud
        guard
            approximateCloudAvailability == true,
            !name.isEmpty,
            let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name)
            else { return nil }
        
        // Check if file exists, and return it's creation date
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            print("[iCloud] File not found: " + name)
            return nil
        }
        
        guard
            let attrs: [FileAttributeKey: Any] = try? self.fileManager.attributesOfItem(atPath: fileURL.path),
            let date: Date = attrs[FileAttributeKey.creationDate] as? Date
            else { return nil }
        
        return date
    }
    
    /**
     Get a list of files stored in iCloud
     
     - Returns: String array with a list of all the files currently stored in your app's iCloud Documents directory. May return a nil value if iCloud is unavailable. */
    public var listCloudFiles: [URL]? {
        get {
            printVerbose("[iCloud] Getting list of iCloud documents")
            
            guard
                approximateCloudAvailability == true,
                let documentURL: URL = self.ubiquitousDocumentsDirectoryURL,
                let documentDirectoryContents: [URL] = try? self.fileManager.contentsOfDirectory(at: documentURL, includingPropertiesForKeys: nil, options: [])
                else { return nil }
            
            printVerbose("[iCloud] Retrieved list of iCloud documents")
            
            return documentDirectoryContents
        }
    }
    
    
    // MARK: - Content Managing
    
    /**
     Rename a document in iCloud
     
     - Parameter name: name of file in iCloud to be renamed.
     - Parameter newName: The new name which the document should be renamed with. The file specified should not exist, otherwise an error will occur. This value must not be empty.
     - Parameter completion: Code block called when the document renaming has completed. The completion block passes and NSError object which contains any error information if an error occurred, otherwise it will be nil. */
    public func renameDocument(_ name: String, with newName: String, completion: ((Error?) -> Void)? = nil) {
        printVerbose("[iCloud] Attempting to rename document, " + name + ", to the new name " + newName)
        
        // Check for iCloud
        guard
            approximateCloudAvailability == true,
            let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name),
            let newFileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(newName)
            else { return }
        
        guard !name.isEmpty else {
            print("[iCloud] Specified document name must not be empty")
            completion?(NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return
        }
        
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            print("[iCloud] File not found: " + name)
            completion?(NSError(domain: "The document, " + name + ", does not exist at path " + fileURL.path, code: 404, userInfo: ["fileURL": fileURL]) as Error)
            return
        }
        
        guard !self.fileManager.fileExists(atPath: newFileURL.path) else {
            print("[iCloud] Rename failed. File already exists at: " + newFileURL.path)
            completion?(NSError(domain: "The document, " + newName + ", already exist at path " + newFileURL.path, code: 404, userInfo: ["fileURL": newFileURL]) as Error)
            return
        }
        
        printVerbose("[iCloud] Renaming Files")
        
        DispatchQueue.global(qos: .background).async {
            var coordinatorError: NSError? = nil
            var _coordinatorError: NSError? {
                get { return coordinatorError }
            }
            
            let fileCoordinator: NSFileCoordinator = NSFileCoordinator(filePresenter: nil)
            fileCoordinator.coordinate(writingItemAt: fileURL, options: .forMoving, writingItemAt: newFileURL, options: .forReplacing, error: &coordinatorError, byAccessor: {
                url1, url2 in
                var err: Error? = nil
                
                do {
                    try self.fileManager.moveItem(at: fileURL, to: newFileURL)
                } catch {
                    print("[iCloud] Failed to rename file, " + name + ", to new name: " + newName + ". Error: " + error.localizedDescription);
                    err = error
                }
                
                if err == nil, _coordinatorError == nil {
                    // Log success
                    self.printVerbose("[iCloud] Renamed Files")
                    DispatchQueue.main.async { completion?(nil) }
                    return
                } else if err != nil {
                    // Log failure
                    print("[iCloud] Failed to rename file, " + name + ", to new name: " + newName + ". Error: " + err!.localizedDescription)
                    
                    DispatchQueue.main.async { completion?(err) }
                    return
                } else if _coordinatorError != nil {
                    // Log failure
                    print("[iCloud] Failed to rename file, " + name + ", to new name: " + newName + ". Error: " + (_coordinatorError! as Error).localizedDescription)
                    
                    DispatchQueue.main.async { completion?(_coordinatorError! as Error) }
                    return
                }
            })
        }
    }
    
    /**
     Duplicate a document in iCloud
     
     - Parameter name: name of file in iCloud to be renamed.
     - Parameter newName: The new name which the document should be duplicated to. The file specified should not exist, otherwise an error will occur. This value must not be empty.
     - Parameter completion: Code block called when the document duplication has completed. The completion block passes and NSError object which contains any error information if an error occurred, otherwise it will be nil.
     */
    public func duplicateDocument(_ name: String, with newName: String, completion: ((Error?) -> Void)? = nil) {
        // Log duplication
        printVerbose("[iCloud] Attempting to duplicate document, " + name + ", to " + newName)
        
        // Check for iCloud
        guard
            approximateCloudAvailability == true,
            let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name),
            let newFileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(newName)
            else { return }
        
        guard !name.isEmpty else {
            print("[iCloud] Specified document name must not be empty")
            completion?(NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return
        }
        
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            print("[iCloud] File not found: " + name)
            completion?(NSError(domain: "The document, " + name + ", does not exist at path " + fileURL.path, code: 404, userInfo: ["fileURL": fileURL]) as Error)
            return
        }
        
        guard !self.fileManager.fileExists(atPath: newFileURL.path) else {
            print("[iCloud] Duplication failed. Target file already exists at: " + newFileURL.path)
            completion?(NSError(domain: "The document, " + newName + ", already exist at path " + newFileURL.path, code: 404, userInfo: ["fileURL": newFileURL]) as Error)
            return
        }
        
        // Log success of existence and duplication
        if self.verboseLogging {
            print("[iCloud] Files passed existence check, preparing to duplicate")
            print("[iCloud] Duplicating Files")
        }
        
        DispatchQueue.global(qos: .background).async {
            var err: Error? = nil
            do {
                try self.fileManager.copyItem(at: fileURL, to: newFileURL)
            } catch {
                print("[iCloud] Failed to duplicate file, " + name + ", with new name: " + newName + ". Error: " + error.localizedDescription)
                err = error
            }
            
            DispatchQueue.main.async { completion?(err) }
        }
    }
    
    
    // MARK: - iCloud Document State
    
    /**
     Get the current document state of a file stored in iCloud
     
     - Parameter name: The name of the file in iCloud. This value must not be nil.
     - Parameter completion: Completion handler that passes three parameters, an NSError, NSString and a UIDocumentState. The documentState parameter represents the document state that the specified file is currently in (may be nil if the file does not exist). The userReadableDocumentState parameter is an NSString which succinctly describes the current document state; if the file does not exist, a non-scary error will be displayed. The NSError parameter will contain a 404 error if the file does not exist. */
    public func documentState(_ name: String, completion: ((UIDocument.State?, String?, Error?) -> Void)!) {
        guard
            approximateCloudAvailability == true,
            let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name)
            else { return }
        
        guard !name.isEmpty else {
            print("[iCloud] Specified document name must not be empty")
            completion(nil, nil, NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return
        }
        
        if self.fileManager.fileExists(atPath: fileURL.path) {
            // Create the document
            let document: iCloudDocument = iCloudDocument(fileURL: fileURL)
            let state: UIDocument.State = document.documentState
            let description: String = document.stateDescription
            completion(state, description, nil)
        } else { // The document didn't exist            
            print("[iCloud] File not found: " + name)
            
            completion(nil, nil, NSError(domain: "The document, " + name + ", does not exist at path: " + self.ubiquitousDocumentsDirectoryURL!.path, code: 404, userInfo: ["fileURL": fileURL]) as Error)
        }
    }
    
    /**
     Observe changes in the state of a document stored in iCloud
     
     - Parameter name: The name of the file in iCloud. This value must not be nil.
     - Parameter observer: Object registering as an observer. This value must not be nil.
     - Parameter selector: Selector to be called when the document state changes. Must only have one argument, an instance of NSNotifcation whose object is an iCloudDocument (UIDocument subclass). This value must not be nil.
     - Returns: true if observing was succesfully setup, otherwise false. */
    @discardableResult
    public func observeDocumentState(_ name: String, observer: Any, selector: Selector) -> Bool {
        printVerbose("[iCloud] Preparing to observe changes to " + name)
        
        // Check for iCloud
        guard
            approximateCloudAvailability == true,
            let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name)
            else { return false }
        
        guard !name.isEmpty else {
            print("[iCloud] Specified document name must not be empty")
            return false
        }
        
        // Log monitoring
        printVerbose("[iCloud] Checking for existance of " + name)
        
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            print("[iCloud] File not found: " + name)
            return false
        }
        
        let document: iCloudDocument = iCloudDocument(fileURL: fileURL)
        
        self.notificationCenter.addObserver(observer, selector: selector, name: UIDocument.stateChangedNotification, object: document)
        
        // Log monitoring success
        printVerbose("[iCloud] Observing for changes to " + name)
        return true
    }
    
    /**
     Stop observing changes to the state of a document stored in iCloud
     
     - Parameter name: The name of the file in iCloud. This value must not be nil.
     - Parameter observer: Object registered as an observer. This value must not be nil.
     
     - Returns: true if observing was succesfully ended, otherwise false. */
    @discardableResult
    public func removeDocumentStateObserver(_ name: String, observer: Any) -> Bool {
        printVerbose("[iCloud] Preparing to stop observing changes to " + name)
        
        // Check for iCloud
        guard
            approximateCloudAvailability == true,
            let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name)
            else { return false }
        
        guard !name.isEmpty else {
            print("[iCloud] Specified document name must not be empty")
            return false
        }
        
        // Log monitoring
        printVerbose("[iCloud] Checking for existance of " + name)
        
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            print("[iCloud] File not found: " + name)
            return false
        }
        
        let document: iCloudDocument = iCloudDocument(fileURL: fileURL)
        
        self.notificationCenter.removeObserver(observer, name: UIDocument.stateChangedNotification, object: document)
        
        // Log monitoring success
        printVerbose("[iCloud] Stopped observing for changes to " + name)
        return true
    }
    
    /**
     Observe changes in the state of iCloud availability
     
     - Parameter observer: Object registering as an observer. This value must not be nil.
     - Parameter selector: Selector to be called when state changes. Must only have one argument, an instance of NSNotifcation whose object is an bool. This value must not be nil. */
    public func observeCloudState(_ observer: Any, selector: Selector) {
        self.notificationCenter.addObserver(observer, selector: selector, name: NSNotification.Name.NSUbiquityIdentityDidChange, object: self.checkCloudAvailability)
        printVerbose("[iCloud] Observing for changes to iCloud availability")
    }
    
    /**
     Stop observing changes to state of iCloud availability
     
     - Parameter observer: Object registered as an observer. This value must not be nil. */
    public func removeCloudStateObserver(observer: Any) {
        self.notificationCenter.removeObserver(observer, name: NSNotification.Name.NSUbiquityIdentityDidChange, object: self.checkCloudAvailability)
        printVerbose("[iCloud] Stopped observing for changes to iCloud availability")
    }
    
    
    // MARK: - Resolving Conflicts
    
    /**
     Find all the conflicting versions of a specified document
     
     - Parameter name: The name of the file in iCloud. This value must not be nil.
     - Returns: Array of NSFileVersion objects, or nil if no such version object exists.
     */
    public func findUnresolvedConflictingVersionsOfFile(_ name: String) -> [NSFileVersion]? {
        printVerbose("[iCloud] Preparing to find all version conflicts for " + name)
        
        // Check for iCloud
        guard
            approximateCloudAvailability == true,
            let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name)
            else { return nil }
        
        guard !name.isEmpty else {
            print("[iCloud] Specified document name must not be empty")
            return nil
        }
        
        printVerbose("[iCloud] Checking for existance of " + name)
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            print("[iCloud] File not found: " + name)
            return nil
        }
        
        printVerbose("[iCloud] " + name + " exists at the correct path, proceeding to find conflicts")
        
        var fileVersions: [NSFileVersion] = []
        if let currentVersion: NSFileVersion = NSFileVersion.currentVersionOfItem(at: fileURL) {
            fileVersions.append(currentVersion)
        }
        if let otherVersions: [NSFileVersion] = NSFileVersion.otherVersionsOfItem(at: fileURL) {
            fileVersions.append(contentsOf: otherVersions)
        }
        return fileVersions
    }
    
    /**
     Resolve a document conflict for a file stored in iCloud
     
     Your application can follow one of three strategies for resolving document-version conflicts:
     
     * Merge the changes from the conflicting versions.
     * Choose one of the document versions based on some pertinent factor, such as the version with the latest modification date.
     * Enable the user to view conflicting versions of a document and select the one to use.
     
     - Parameter name: The name of the file in iCloud. This value must not be nil.
     - Parameter documentVersion: The version of the document which should be kept and saved. All other conflicting versions will be removed. */
    public func resolveConflictForFile(_ name: String, with documentVersion: NSFileVersion) {
        printVerbose("[iCloud] Preparing to resolve version conflict for " + name)
        
        // Check for iCloud
        guard
            approximateCloudAvailability == true,
            let fileURL: URL = self.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(name)
            else { return }
        
        guard !name.isEmpty else {
            print("[iCloud] Specified document name must not be empty")
            return
        }
        
        printVerbose("[iCloud] Checking for existance of " + name)
        
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            print("[iCloud] File not found: " + name)
            return
        }
        
        printVerbose("[iCloud] " + name + " exists at the correct path, proceeding to resolve conflict")
        
        // Force the current version to win comparison in conflict
        if documentVersion != NSFileVersion.currentVersionOfItem(at: fileURL) {
            printVerbose("iCloud] The current version (" + documentVersion.description + ") of " + name + " matches the selected version. Resolving conflict...")
            let _ = try? documentVersion.replaceItem(at: fileURL, options: [])
        }
        
        try? NSFileVersion.removeOtherVersionsOfItem(at: fileURL)
        printVerbose("[iCloud] Removing all unresolved other versions of " + name)
        
        if let conflictVersions: [NSFileVersion] = NSFileVersion.unresolvedConflictVersionsOfItem(at: fileURL) {
            for fileVersion in conflictVersions {
                fileVersion.isResolved = true
            }
        }
        
        printVerbose("[iCloud] Finished resolving conflicts for " + name)
    }
}
