//
//  iCloud.m
//  iCloud Document Sync
//
//  Created by iRare Media. Last updated January 2015.
//  Available on GitHub. Licensed under MIT with Attribution.
//

#import "iCloud.h"

// Check for ARC
#if !__has_feature(objc_arc)
    // Add the -fobjc-arc flag to enable ARC for only these files, as described in the ARC documentation: http://clang.llvm.org/docs/AutomaticReferenceCounting.html
    #error iCloudDocumentSync is built with Objective-C ARC. You must enable ARC for iCloudDocumentSync.
#endif

@interface iCloud ()

@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundProcess;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, copy) NSString *fileExtension;
@property (nonatomic, strong) NSURL *ubiquityContainer;

/// Setup and start the metadata query and related notifications
- (void)enumerateCloudDocuments;

/// Called by the NSMetadataQuery notifications to updateFiles
- (void)startUpdate:(NSMetadataQuery *)notification;

/// Perform a quick a straightforward iCloud check without logging - for internal use
- (BOOL)quickCloudCheck;

@end

@implementation iCloud

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Setup --------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Setup

+ (instancetype)sharedCloud {
    static iCloud *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    return self;
}

- (void)dealloc {
    [self.notificationCenter removeObserver:self];
}

- (void)setupiCloudDocumentSyncWithUbiquityContainer:(NSString *)containerID {
    // Setup the File Manager
    if (_fileManager == nil) _fileManager = [NSFileManager defaultManager];
    
    // Setup the Notification Center
    if (_notificationCenter == nil) _notificationCenter = [NSNotificationCenter defaultCenter];
    
    // Initialize file lists, results, and queries
    if (_fileList == nil) _fileList = [NSMutableArray array];
    if (_previousQueryResults == nil) _previousQueryResults = [NSMutableArray array];
    if (_query == nil) _query = [[NSMetadataQuery alloc] init];
    
    // Check the iCloud Ubiquity Container
    dispatch_async(dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSLog(@"[iCloud] Initializing Ubiquity Container");
        
        _ubiquityContainer = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:containerID];
        if (_ubiquityContainer) {
            // We can write to the ubiquity container
            
            dispatch_async(dispatch_get_main_queue (), ^(void) {
                // On the main thread, update UI and state as appropriate
                NSLog(@"[iCloud] Initializing Document Enumeration");
                
                // Check iCloud Availability
                id cloudToken = [_fileManager ubiquityIdentityToken];
                
                // Sync and Update Documents List
                [self enumerateCloudDocuments];
                
                // Subscribe to changes in iCloud availability (should run on main thread)
                [_notificationCenter addObserver:self selector:@selector(checkCloudAvailability) name:NSUbiquityIdentityDidChangeNotification object:nil];
                
                if ([_delegate respondsToSelector:@selector(iCloudDidFinishInitializingWitUbiquityToken: withUbiquityContainer:)])
                    [_delegate iCloudDidFinishInitializingWitUbiquityToken:cloudToken withUbiquityContainer:_ubiquityContainer];
            });
            
            // Log the setup
            NSLog(@"[iCloud] Ubiquity Container Created and Ready");
        } else {
            NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
            NSLog(@"[iCloud] The systemt could not retrieve a valid iCloud container URL. iCloud is not available. iCloud may be unavailable for a number of reasons:\n• The device has not yet been configured with an iCloud account, or the Documents & Data option is disabled\n• Your app, %@, does not have properly configured entitlements\n• Your app, %@, has a provisioning profile which does not support iCloud.\nGo to http://bit.ly/18HkxPp for more information on setting up iCloud", appName, appName);
            
            if ([self.delegate respondsToSelector:@selector(iCloudAvailabilityDidChangeToState:withUbiquityToken:withUbiquityContainer:)])
                [self.delegate iCloudAvailabilityDidChangeToState:NO withUbiquityToken:nil withUbiquityContainer:self.ubiquityContainer];
        }
    });
    
    // Log the setup
    NSLog(@"[iCloud] Initialized");
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Basic --------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Basic

- (BOOL)checkCloudAvailability {
    id cloudToken = [self.fileManager ubiquityIdentityToken];
    if (cloudToken) {
        if (self.verboseAvailabilityLogging == YES) NSLog(@"[iCloud] iCloud is available. Ubiquity URL: %@\nUbiquity Token: %@", self.ubiquityContainer, cloudToken);
        
        if ([self.delegate respondsToSelector:@selector(iCloudAvailabilityDidChangeToState:withUbiquityToken:withUbiquityContainer:)])
            [self.delegate iCloudAvailabilityDidChangeToState:YES withUbiquityToken:cloudToken withUbiquityContainer:self.ubiquityContainer];
        
        return YES;
    } else {
        if (self.verboseAvailabilityLogging == YES)
            NSLog(@"[iCloud] iCloud is not available. iCloud may be unavailable for a number of reasons:\n• The device has not yet been configured with an iCloud account, or the Documents & Data option is disabled\n• Your app, %@, does not have properly configured entitlements\nGo to http://bit.ly/18HkxPp for more information on setting up iCloud", [[NSBundle mainBundle] infoDictionary][@"CFBundleName"]);
        else
            NSLog(@"[iCloud] iCloud unavailable");
        
        if ([self.delegate respondsToSelector:@selector(iCloudAvailabilityDidChangeToState:withUbiquityToken:withUbiquityContainer:)])
            [self.delegate iCloudAvailabilityDidChangeToState:NO withUbiquityToken:nil withUbiquityContainer:self.ubiquityContainer];
        
        return NO;
    }
}

- (BOOL)checkCloudUbiquityContainer {
	if (self.ubiquityContainer) return YES;
	else return NO;
}

- (BOOL)quickCloudCheck {
    if ([self.fileManager ubiquityIdentityToken]) return YES;
    else return NO;
}

- (NSURL *)ubiquitousContainerURL {
    return self.ubiquityContainer;
}

- (NSURL *)ubiquitousDocumentsDirectoryURL {
    // Use the instance variable here - no need to start the retrieval process again
    if (self.ubiquityContainer == nil) self.ubiquityContainer = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
    NSURL *documentsDirectory = [self.ubiquityContainer URLByAppendingPathComponent:DOCUMENT_DIRECTORY];
    NSError *error;
    
    // Ensure that the documents directory is not nil, if it is return the local path
    if (documentsDirectory == nil) {
        NSURL *nonUbiquitousDocumentsDirectory = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
        
        NSLog(@"[iCloud] iCloud is not available. iCloud may be unavailable for a number of reasons:\n• The device has not yet been configured with an iCloud account, or the Documents & Data option is disabled\n• Your app, %@, does not have properly configured entitlements\nGo to http://bit.ly/18HkxPp for more information on setting up iCloud", [[NSBundle mainBundle] infoDictionary][@"CFBundleName"]);
        
        NSLog(@"[iCloud] WARNING: Using local documents directory until iCloud is available.");
        
        if ([self.delegate respondsToSelector:@selector(iCloudAvailabilityDidChangeToState:withUbiquityToken:withUbiquityContainer:)])
            [self.delegate iCloudAvailabilityDidChangeToState:NO withUbiquityToken:nil withUbiquityContainer:self.ubiquityContainer];
        
        return nonUbiquitousDocumentsDirectory;
    }
    
    BOOL isDirectory = NO;
    BOOL isFile = [self.fileManager fileExistsAtPath:[documentsDirectory path] isDirectory:&isDirectory];
    
    if (isFile) {
        // It exists, check if it's a directory
        if (isDirectory == YES) return documentsDirectory;
        else {
            [self.fileManager removeItemAtPath:[documentsDirectory path] error:&error];
            [self.fileManager createDirectoryAtURL:documentsDirectory withIntermediateDirectories:YES attributes:nil error:&error];
            return documentsDirectory;
        }
    } else {
        [self.fileManager createDirectoryAtURL:documentsDirectory withIntermediateDirectories:YES attributes:nil error:&error];
        return documentsDirectory;
    }
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Sync ---------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Sync

- (void)enumerateCloudDocuments {
    // Log document enumeration
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Creating metadata query and notifications");
    
    // Request information from the delegate
    if ([self.delegate respondsToSelector:@selector(iCloudQueryLimitedToFileExtension)]) {
        NSString *fileExt = [self.delegate iCloudQueryLimitedToFileExtension];
        if (fileExt != nil && ![fileExt isEqualToString:@""]) self.fileExtension = fileExt;
        else self.fileExtension = @"*";
        
        // Log file extension
        NSLog(@"[iCloud] Document query filter has been set to %@", self.fileExtension);
    } else self.fileExtension = @"*";
    
    // Setup iCloud Metadata Query
	[self.query setSearchScopes:@[NSMetadataQueryUbiquitousDocumentsScope]];
	[self.query setPredicate:[NSPredicate predicateWithFormat:[NSString stringWithFormat:@"%%K.pathExtension LIKE '%@'", self.fileExtension], NSMetadataItemFSNameKey]];
    
    // Notify the responder that an update has begun
	[self.notificationCenter addObserver:self selector:@selector(startUpdate:) name:NSMetadataQueryDidStartGatheringNotification object:self.query];
    
    // Notify the responder that an update has been pushed
	[self.notificationCenter addObserver:self selector:@selector(recievedUpdate:) name:NSMetadataQueryDidUpdateNotification object:self.query];
    
    // Notify the responder that the update has completed
	[self.notificationCenter addObserver:self selector:@selector(endUpdate:) name:NSMetadataQueryDidFinishGatheringNotification object:self.query];
    
    // Start the query on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL startedQuery = [self.query startQuery];
        if (!startedQuery) {
            NSLog(@"[iCloud] Failed to start query.");
            return;
        } else {
            if (self.verboseLogging == YES) NSLog(@"[iCloud] Query initialized successfully"); // Log file query success
        }
    });
}

- (void)startUpdate:(NSNotification *)notification {
    // Log file update
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Beginning file update with NSMetadataQuery");
    
    // Notify the delegate of the results on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(iCloudFileUpdateDidBegin)])
            [self.delegate iCloudFileUpdateDidBegin];
    });
}

- (void)recievedUpdate:(NSNotification *)notification {
    // Log file update
    if (self.verboseLogging == YES) NSLog(@"[iCloud] An update has been pushed from iCloud with NSMetadataQuery");
    
    // Get the updated files
    [self updateFiles];
}

- (void)endUpdate:(NSNotification *)notification {
    // Get the updated files
    [self updateFiles];
    
    // Notify the delegate of the results on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(iCloudFileUpdateDidEnd)])
            [self.delegate iCloudFileUpdateDidEnd];
    });
    
    // Log query completion
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Finished file update with NSMetadataQuery");
}

- (void)updateFiles {
    // Log file update
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Beginning file update with NSMetadataQuery");
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Initialize the discovered files and file names array
    NSMutableArray *discoveredFiles = [NSMutableArray array];
    NSMutableArray *names = [NSMutableArray array];

    if ([self.query respondsToSelector:@selector(enumerateResultsUsingBlock:)]) {
        // Code for iOS 7.0 and later
        
        // Enumerate through the results
        [self.query enumerateResultsUsingBlock:^(id result, NSUInteger idx, BOOL *stop) {
            // Grab the file URL
            NSURL *fileURL = [result valueForAttribute:NSMetadataItemURLKey];
            NSString *fileStatus;
            [fileURL getResourceValue:&fileStatus forKey:NSURLUbiquitousItemDownloadingStatusKey error:nil];
            
            if ([fileStatus isEqualToString:NSURLUbiquitousItemDownloadingStatusDownloaded]) {
                // File will be updated soon
            }
            
            if ([fileStatus isEqualToString:NSURLUbiquitousItemDownloadingStatusCurrent]) {
                // Add the file metadata and file names to arrays
                [discoveredFiles addObject:result];
                [names addObject:[result valueForAttribute:NSMetadataItemFSNameKey]];
                
                if (self.query.resultCount-1 >= idx) {
                    // Notify the delegate of the results on the main thread
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([self.delegate respondsToSelector:@selector(iCloudFilesDidChange:withNewFileNames:)])
                            [self.delegate iCloudFilesDidChange:discoveredFiles withNewFileNames:names];
                    });
                }
            } else if ([fileStatus isEqualToString:NSURLUbiquitousItemDownloadingStatusNotDownloaded]) {
                NSError *error;
                BOOL downloading = [[NSFileManager defaultManager] startDownloadingUbiquitousItemAtURL:fileURL error:&error];
                if (self.verboseLogging == YES) NSLog(@"[iCloud] %@ started downloading locally, successful? %@", [fileURL lastPathComponent], downloading ? @"YES" : @"NO");
                if (error) {
                    if (self.verboseLogging == YES) NSLog(@"[iCloud] Ubiquitous item failed to start downloading with error: %@", error);
                }
            }
        }];
    } else {
        // Code for iOS 6.1 and earlier
        
        // Disable updates to iCloud while we update to avoid errors
        [self.query disableUpdates];
        
        // The query reports all files found, every time
        NSArray *queryResults = self.query.results;
        
        // Log the query results
        if (self.verboseLogging == YES) NSLog(@"Query Results: %@", self.query.results);
        
        // Gather the query results
        for (NSMetadataItem *result in queryResults) {
            NSURL *fileURL = [result valueForAttribute:NSMetadataItemURLKey];
            [discoveredFiles addObject:result];
        }
        
        // Get file names in from the query
        NSMutableArray *names = [NSMutableArray array];
        for (NSMetadataItem *item in self.query.results) {
            [names addObject:[item valueForAttribute:NSMetadataItemFSNameKey]];
        }
        
        // Log query completion
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Finished file update with NSMetadataQuery");
        
        // Notify the delegate of the results on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(iCloudFilesDidChange:withNewFileNames:)])
                [self.delegate iCloudFilesDidChange:discoveredFiles withNewFileNames:names];
        });
        
        // Reenable Updates
        [self.query enableUpdates];
    }
}


//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Write --------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Write

- (void)saveAndCloseDocumentWithName:(NSString *)documentName withContent:(NSData *)content completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler {
    // Log save
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Beginning document save");
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        NSError *error = [NSError errorWithDomain:@"The specified document name was empty / blank and could not be saved. Specify a document name next time." code:001 userInfo:nil];
        
        handler(nil, nil, error);
        
        return;
    }
    
    // Get the URL to save the new file to
    NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    
    // Initialize a document with that path
    iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
    document.contents = content;
    [document updateChangeCount:UIDocumentChangeDone];
    
    if ([self.fileManager fileExistsAtPath:[fileURL path]]) {
		// The document did not exist and is being saved for the first time.
		
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Document exists; overwriting, saving and closing");
        // Save and create the new document, then close it
        [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
            if (success) {
				// Save and close the document
				[document closeWithCompletionHandler:^(BOOL closeSuccess) {
					if (closeSuccess) {
						// Log
						if (self.verboseLogging == YES) NSLog(@"[iCloud] Written, saved and closed document");
						
						handler(document, document.contents, nil);
					} else {
						NSLog(@"[iCloud] Error while saving document: %s", __PRETTY_FUNCTION__);
						NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while saving the document, %@, to iCloud", __PRETTY_FUNCTION__, document.fileURL] code:110 userInfo:@{@"FileURL": fileURL}];
						
						handler(document, document.contents, error);
					}
				}];
				
			} else {
                NSLog(@"[iCloud] Error while writing to the document: %s", __PRETTY_FUNCTION__);
                NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while writing to the document, %@, in iCloud", __PRETTY_FUNCTION__, document.fileURL] code:100 userInfo:@{@"FileURL": fileURL}];
                
                handler(document, document.contents, error);
            }
		}];
    } else {
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Document is new; creating, saving and then closing");
        
        // The document is being saved by overwriting the current version, then closed.
        [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
            if (success) {
                // Saving implicitly opens the file
                [document closeWithCompletionHandler:^(BOOL closeSuccess) {
                    if (closeSuccess) {
                        // Log the save and close
                        if (self.verboseLogging == YES) NSLog(@"[iCloud] New document created, saved and closed successfully");
                        
                        handler(document, document.contents, nil);
                    } else {
                        NSLog(@"[iCloud] Error while saving and closing document: %s", __PRETTY_FUNCTION__);
                        NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while saving the document, %@, to iCloud", __PRETTY_FUNCTION__, document.fileURL] code:110 userInfo:@{@"FileURL": fileURL}];
                        
                        handler(document, document.contents, error);
                    }
                }];
                
                
            } else {
                NSLog(@"[iCloud] Error while creating the document: %s", __PRETTY_FUNCTION__);
                NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while creating the document, %@, in iCloud", __PRETTY_FUNCTION__, document.fileURL] code:100 userInfo:@{@"FileURL": fileURL}];
                
                handler(document, document.contents, error);
            }
        }];
    }
}

- (void)uploadLocalOfflineDocumentsWithRepeatingHandler:(void (^)(NSString *documentName, NSError *error))repeatingHandler completion:(void (^)(void))completion {
    // Log upload
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Beginning local file upload to iCloud. This process may take a long time.");
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Perform tasks on background thread to avoid problems on the main / UI thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        // Get the array of files in the documents directory
        NSString *documentsDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        NSArray *localDocuments = [self.fileManager contentsOfDirectoryAtPath:documentsDirectory error:nil];
        
        // Log local files
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Files stored locally available for uploading: %@", localDocuments);
        
        // Compare the arrays then upload documents not already existent in iCloud
        for (NSUInteger item = 0; item < [localDocuments count]; item++) {
            
            // Check to make sure the documents aren't hidden
            if (![localDocuments[item] hasPrefix:@"."]) {
                
                // If the file does not exist in iCloud, upload it
                if (![self.previousQueryResults containsObject:localDocuments[item]]) {
                    // Log
                    if (self.verboseLogging == YES) NSLog(@"[iCloud] Uploading %@ to iCloud (%lu out of %lu)", localDocuments[item], (unsigned long)item, (unsigned long)[localDocuments count]);
                    
                    // Move the file to iCloud
                    NSURL *cloudURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:localDocuments[item]];
                    NSURL *localURL = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:localDocuments[item]]];
                    NSError *error;
                    
                    BOOL success = [self.fileManager setUbiquitous:YES itemAtURL:localURL destinationURL:cloudURL error:&error];
                    if (success == NO) {
                        NSLog(@"[iCloud] Error while uploading document from local directory: %@",error);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            repeatingHandler(localDocuments[item], error);
                        });
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            repeatingHandler(localDocuments[item], nil);
                        });
                    }
                    
                } else {
                    // Check if the local document is newer than the cloud document
                    
                    // Log conflict
                    if (self.verboseLogging == YES) NSLog(@"[iCloud] Conflict between local file and remote file, attempting to automatically resolve");
                    
                    // Get the file URL for the iCloud document
                    NSURL *cloudFileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:localDocuments[item]];
                    NSURL *localFileURL = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:localDocuments[item]]];
                    
                    // Create the UIDocument object from the URL
                    iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:cloudFileURL];
                    NSDate *cloudModDate = document.fileModificationDate;
                    
                    NSDictionary *fileAttributes = [self.fileManager attributesOfItemAtPath:[localFileURL absoluteString] error:nil];
                    NSDate *localModDate = [fileAttributes fileModificationDate];
                    NSData *localFileData = [self.fileManager contentsAtPath:[localFileURL absoluteString]];
                    
                    if ([cloudModDate compare:localModDate] == NSOrderedDescending) {
                        NSLog(@"[iCloud] The iCloud file was modified more recently than the local file. The local file will be deleted and the iCloud file will be preserved.");
                        NSError *error;
                        
                        if (![self.fileManager removeItemAtPath:[localFileURL absoluteString] error:&error]) {
                            NSLog(@"[iCloud] Error deleting %@.\n\n%@", [localFileURL absoluteString], error);
                        }
                    } else if ([cloudModDate compare:localModDate] == NSOrderedAscending) {
                        NSLog(@"[iCloud] The local file was modified more recently than the iCloud file. The iCloud file will be overwritten with the contents of the local file.");
                        // Set the document's new content
                        document.contents = localFileData;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            // Save and close the document in iCloud
                            [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
                                if (success) {
                                    // Close the document
                                    [document closeWithCompletionHandler:^(BOOL closeSuccess) {
                                        repeatingHandler(localDocuments[item], nil);
                                    }];
                                } else {
                                    NSLog(@"[iCloud] Error while overwriting old iCloud file: %s", __PRETTY_FUNCTION__);
                                    NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while saving the document, %@, to iCloud", __PRETTY_FUNCTION__, document.fileURL] code:110 userInfo:@{@"FileName": localDocuments[item]}];
                                    
                                    repeatingHandler(localDocuments[item], error);
                                }
                            }];
                        });
                    } else {
                        NSLog(@"[iCloud] The local file and iCloud file have the same modification date. Before overwriting or deleting, iCloud Document Sync will check if both files have the same content.");
                        if ([self.fileManager contentsEqualAtPath:[cloudFileURL absoluteString] andPath:[localFileURL absoluteString]] == YES) {
                            NSLog (@"[iCloud] The contents of the local file and the contents of the iCloud file match. The local file will be deleted.");
                            NSError *error;
                            
                            if (![self.fileManager removeItemAtPath:[localFileURL absoluteString] error:&error]) {
                                NSLog(@"[iCloud] Error deleting %@.\n\n%@", [localFileURL absoluteString], error);
                            }
                        } else {
                            NSLog(@"[iCloud] Both the iCloud file and the local file were last modified at the same time, however their contents do not match. You'll need to handle the conflict using the iCloudFileConflictBetweenCloudFile:andLocalFile: delegate method.");
                            NSDictionary *cloudFile = @{@"fileContents": document.contents, @"fileURL": cloudFileURL, @"modifiedDate": cloudModDate};
                            NSDictionary *localFile = @{@"fileContents": localFileData, @"fileURL": localFileURL, @"modifiedDate": localModDate};;
                            
                            if ([self.delegate respondsToSelector:@selector(iCloudFileUploadConflictWithCloudFile:andLocalFile:)]) {
                                [self.delegate iCloudFileConflictBetweenCloudFile:cloudFile andLocalFile:localFile];
                            } else if ([self.delegate respondsToSelector:@selector(iCloudFileUploadConflictWithCloudFile:andLocalFile:)]) {
                                NSLog(@"[iCloud] WARNING: iCloudFileUploadConflictWithCloudFile:andLocalFile is deprecated and will become unavailable in a future version. Use iCloudFileConflictBetweenCloudFile:andLocalFile instead.");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                                [self.delegate iCloudFileUploadConflictWithCloudFile:cloudFile andLocalFile:localFile];
#pragma clang diagnostic pop
                            }
                        }
                    }
                }
            } else {
                // The file is hidden, do not proceed
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSError *error = [[NSError alloc] initWithDomain:@"File in directory is hidden and will not be uploaded to iCloud." code:520 userInfo:@{@"FileName": localDocuments[item]}];
                    repeatingHandler(localDocuments[item], error);
                });
            }
        }
        
        // Log completion
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Finished uploading all local files to iCloud");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion)
                completion();
        });
    });
}

- (void)uploadLocalDocumentToCloudWithName:(NSString *)documentName completion:(void (^)(NSError *error))handler {
    // Log download
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Attempting to upload document, %@", documentName);
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        NSError *error = [NSError errorWithDomain:@"The specified document name was empty / blank and could not be saved. Specify a document name next time." code:001 userInfo:nil];
        
        handler(error);
        
        return;
    }
    
    // Perform tasks on background thread to avoid problems on the main / UI thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        // Get the array of files in the documents directory
        NSString *documentsDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        NSString *localDocument = [documentsDirectory stringByAppendingPathComponent:documentName];
        
        // If the file does not exist in iCloud, upload it
        if (![self.previousQueryResults containsObject:localDocument]) {
            // Log
            if (self.verboseLogging == YES) NSLog(@"[iCloud] Uploading %@ to iCloud", localDocument);
            
            // Move the file to iCloud
            NSURL *cloudURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
            NSURL *localURL = [NSURL fileURLWithPath:localDocument];
            NSError *error;
            
            BOOL success = [self.fileManager setUbiquitous:YES itemAtURL:localURL destinationURL:cloudURL error:&error];
            if (!success) {
                NSLog(@"[iCloud] Error while uploading document from local directory: %@", error);
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(error);
                    return;
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(nil);
                    return;
                });
            }
            
        } else {
            // Check if the local document is newer than the cloud document
            
            // Log conflict
            if (self.verboseLogging == YES) NSLog(@"[iCloud] Conflict between local file and remote file, attempting to automatically resolve");
            
            // Get the file URL for the documents
            NSURL *cloudURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
            NSURL *localURL = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:localDocument]];
            
            // Create the UIDocument object from the URL
            iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:cloudURL];
            NSDate *cloudModDate = document.fileModificationDate;
            
            NSDictionary *fileAttributes = [self.fileManager attributesOfItemAtPath:[localURL absoluteString] error:nil];
            NSDate *localModDate = [fileAttributes fileModificationDate];
            NSData *localFileData = [self.fileManager contentsAtPath:[localURL absoluteString]];
            
            if ([cloudModDate compare:localModDate] == NSOrderedDescending) {
                NSLog(@"[iCloud] The iCloud file was modified more recently than the local file. The local file will be deleted and the iCloud file will be preserved.");
                NSError *error;
                
                if (![self.fileManager removeItemAtPath:[localURL absoluteString] error:&error]) {
                    NSLog(@"[iCloud] Error deleting %@.\n\n%@", [localURL absoluteString], error);
                    return;
                }
            } else if ([cloudModDate compare:localModDate] == NSOrderedAscending) {
                NSLog(@"[iCloud] The local file was modified more recently than the iCloud file. The iCloud file will be overwritten with the contents of the local file.");
                // Set the document's new content
                document.contents = localFileData;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Save and close the document in iCloud
                    [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
                        if (success) {
                            // Close the document
                            [document closeWithCompletionHandler:^(BOOL closeSuccess) {
                                handler(nil);
                                return;
                            }];
                        } else {
                            NSLog(@"[iCloud] Error while overwriting old iCloud file: %s", __PRETTY_FUNCTION__);
                            NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while saving the document, %@, to iCloud", __PRETTY_FUNCTION__, document.fileURL] code:110 userInfo:@{@"FileName": localDocument}];
                            
                            handler(error);
                            return;
                        }
                    }];
                });
            } else {
                NSLog(@"[iCloud] The local file and iCloud file have the same modification date. Before overwriting or deleting, iCloud Document Sync will check if both files have the same content.");
                if ([self.fileManager contentsEqualAtPath:[cloudURL absoluteString] andPath:[localURL absoluteString]] == YES) {
                    NSLog (@"[iCloud] The contents of the local file and the contents of the iCloud file match. The local file will be deleted.");
                    NSError *error;
                    
                    if (![self.fileManager removeItemAtPath:[localURL absoluteString] error:&error]) {
                        NSLog(@"[iCloud] Error deleting %@.\n\n%@", [localURL absoluteString], error);
                        return;
                    }
                } else {
                    NSLog(@"[iCloud] Both the iCloud file and the local file were last modified at the same time, however their contents do not match. You'll need to handle the conflict using the iCloudFileConflictBetweenCloudFile:andLocalFile: delegate method.");
                    NSDictionary *cloudFile = @{@"fileContents": document.contents, @"fileURL": cloudURL, @"modifiedDate": cloudModDate};
                    NSDictionary *localFile = @{@"fileContents": localFileData, @"fileURL": localURL, @"modifiedDate": localModDate};;
                    
                    if ([self.delegate respondsToSelector:@selector(iCloudFileUploadConflictWithCloudFile:andLocalFile:)]) {
                        [self.delegate iCloudFileConflictBetweenCloudFile:cloudFile andLocalFile:localFile];
                    } else if ([self.delegate respondsToSelector:@selector(iCloudFileUploadConflictWithCloudFile:andLocalFile:)]) {
                        NSLog(@"[iCloud] WARNING: iCloudFileUploadConflictWithCloudFile:andLocalFile is deprecated and will become unavailable in a future version. Use iCloudFileConflictBetweenCloudFile:andLocalFile instead.");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                        [self.delegate iCloudFileUploadConflictWithCloudFile:cloudFile andLocalFile:localFile];
#pragma clang diagnostic pop
                    }
                    
                    return;
                }
            }
        }
        
        // Log completion
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Finished uploading local file to iCloud");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(nil);
            return;
        });
    });
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Read ---------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Read

- (void)retrieveCloudDocumentWithName:(NSString *)documentName completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler {
    // Log Retrieval
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Retrieving iCloud document, %@", documentName);
    
    // Check for iCloud availability
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        NSError *error = [NSError errorWithDomain:@"The specified document name was empty / blank and could not be saved. Specify a document name next time." code:001 userInfo:nil];
        
        handler(nil, nil, error);
        
        return;
    }
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        // If the file exists open it; otherwise, create it
        if ([self.fileManager fileExistsAtPath:[fileURL path]]) {
            // Log opening
            if (self.verboseLogging == YES) NSLog(@"[iCloud] The document, %@, already exists and will be opened", documentName);
            
            // Create the UIDocument object from the URL
            iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
            
            if (document.documentState & UIDocumentStateClosed) {
                if (self.verboseLogging == YES) NSLog(@"[iCloud] Document is closed and will be opened");
                
                [document openWithCompletionHandler:^(BOOL success){
                    if (success) {
                        // Log open
                        if (self.verboseLogging == YES) NSLog(@"[iCloud] Opened document");
                        
                        // Pass data on to the completion handler on the main thread
                        dispatch_async(dispatch_get_main_queue(), ^{
                            handler(document, document.contents, nil);
                        });
                        
                        return;
                    } else {
                        NSLog(@"[iCloud] Error while retrieving document: %s", __PRETTY_FUNCTION__);
                        NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while retrieving document, %@, from iCloud", __PRETTY_FUNCTION__, document.fileURL] code:200 userInfo:@{@"FileURL": fileURL}];
                        
                        // Pass data on to the completion handler on the main thread
                        dispatch_async(dispatch_get_main_queue(), ^{
                            handler(document, document.contents, error);
                        });
                        
                        return;
                    }
                }];
            } else if (document.documentState & UIDocumentStateNormal) {
                // Log open
                if (self.verboseLogging == YES) NSLog(@"[iCloud] Document already opened, retrieving content");
                
                // Pass data on to the completion handler on the main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(document, document.contents, nil);
                });
                
                return;
            } else if (document.documentState & UIDocumentStateInConflict) {
                // Log open
                if (self.verboseLogging == YES) NSLog(@"[iCloud] Document in conflict. The document may not contain correct data. An error will be returned along with the other parameters in the completion handler.");
                
                // Create Error
                NSLog(@"[iCloud] Error while retrieving document, %@, because the document is in conflict", documentName);
                NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The iCloud document, %@, is in conflict. Please resolve this conflict before editing the document.", documentName] code:200 userInfo:@{@"FileURL": fileURL}];
                
                // Pass data on to the completion handler on the main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(document, document.contents, error);
                });
                
                return;
            } else if (document.documentState & UIDocumentStateEditingDisabled) {
                // Log open
                if (self.verboseLogging == YES) NSLog(@"[iCloud] Document editing disabled. The document is not currently editable, use the documentStateForFile: method to determine when the document is available again. The document and its contents will still be passed as parameters in the completion handler.");
                
                // Pass data on to the completion handler on the main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(document, document.contents, nil);
                });
                
                return;
            }
            
        } else {
            // Log creation
            if (self.verboseLogging == YES) NSLog(@"[iCloud] The document, %@, does not exist and will be created as an empty document", documentName);
            
            // Create the UIDocument
            iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
            document.contents = [[NSData alloc] init];
            
            // Save the new document to disk
            [document saveToURL:fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
                // Log save
                if (self.verboseLogging == YES) NSLog(@"[iCloud] Saved and opened the document");
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(document, document.contents, nil);
                });
            }];
        }
    } @catch (NSException *exception) {
        NSLog(@"[iCloud] Caught exception while retrieving document: %@\n\n%s", exception, __PRETTY_FUNCTION__);
    }
}

- (iCloudDocument *)retrieveCloudDocumentObjectWithName:(NSString *)documentName {
    // Log Retrieval
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Retrieving iCloudDocument object with name: %@", documentName);
    
    // Check for iCloud availability
    if ([self quickCloudCheck] == NO) return nil;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return nil;
    }
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        // Create the iCloudDocument
        iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
        
        if ([self.fileManager fileExistsAtPath:[fileURL path]]) {
            if (self.verboseLogging == YES) NSLog(@"[iCloud] The document, %@, exists and will be returned as an iCloudDocument object", documentName);
        } else {
            if (self.verboseLogging == YES) NSLog(@"[iCloud] The document, %@, does not exist but will be returned as an empty iCloudDocument object", documentName);
        }
        
        // Return the iCloudDocument object
        return document;
        
    } @catch (NSException *exception) {
        NSLog(@"[iCloud] Caught exception while retrieving document: %@\n\n%s", exception, __PRETTY_FUNCTION__);
        return nil;
    }
}

- (NSNumber *)fileSize:(NSString *)documentName {
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return nil;
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    
    // Check if the file exists, and return
    if ([self.fileManager fileExistsAtPath:[fileURL path]]) {
        unsigned long long fileSize = [[self.fileManager attributesOfItemAtPath:[fileURL path] error:nil] fileSize];
        NSNumber *bytes = @(fileSize);
        return bytes;
    } else {
        // The document could not be found
        NSLog(@"[iCloud] File not found: %@", documentName);
        
        return nil;
    }
}

- (NSDate *)fileModifiedDate:(NSString *)documentName {
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return nil;
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    
    
    // Check if the file exists, and return
    if ([self.fileManager fileExistsAtPath:[fileURL path]]) {
        NSDate *fileModified = [[self.fileManager attributesOfItemAtPath:[fileURL path] error:nil] fileModificationDate];
        return fileModified;
    } else {
        // The document could not be found
        NSLog(@"[iCloud] File not found: %@", documentName);
        
        return nil;
    }
}

- (NSDate *)fileCreatedDate:(NSString *)documentName {
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return nil;
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    
    
    // Check if the file exists, and return
    if ([self.fileManager fileExistsAtPath:[fileURL path]]) {
        NSDate *fileModified = [[self.fileManager attributesOfItemAtPath:[fileURL path] error:nil] fileCreationDate];
        return fileModified;
    } else {
        return nil;
    }
}

- (BOOL)doesFileExistInCloud:(NSString *)documentName {
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return NO;
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    
    // Check if the file exists, and return
    if ([self.fileManager fileExistsAtPath:[fileURL path]]) return YES;
    else return NO;
}

- (NSArray *)listCloudFiles {
    // Log retrieval
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Getting list of iCloud documents");
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return nil;
    
    // Get the directory contents
    NSArray *directoryContent = [self.fileManager contentsOfDirectoryAtURL:[self ubiquitousDocumentsDirectoryURL] includingPropertiesForKeys:nil options:0 error:nil];
    
    // Log retrieval
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Retrieved list of iCloud documents");
    
    // Return the list of files
    return directoryContent;
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ State --------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - State

- (void)documentStateForFile:(NSString *)documentName completion:(void (^)(UIDocumentState *documentState, NSString *userReadableDocumentState, NSError *error))handler {
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        NSError *error = [NSError errorWithDomain:@"The specified document name was empty / blank and could not be saved. Specify a document name next time." code:001 userInfo:nil];
        
        handler(nil, nil, error);
        
        return;
    }
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    
    // Check if the file exists, and return
    if ([self.fileManager fileExistsAtPath:[fileURL path]]) {
        // Create the UIDocument
        iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
        UIDocumentState state = document.documentState;
        NSString *userStateDescription = document.stateDescription;
        handler(&state, userStateDescription, nil);
    } else {
        // The document could not be found
        NSLog(@"[iCloud] File not found: %@", documentName);
        NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, does not exist at path: %@", documentName, fileURL] code:404 userInfo:@{@"FileURL": fileURL}];
        handler(nil, @"No document available", error);
        return;
    }
}

- (BOOL)monitorDocumentStateForFile:(NSString *)documentName onTarget:(id)sender withSelector:(SEL)selector {
    // Log monitoring
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Preparing to monitor for changes to %@", documentName);
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return NO;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return NO;
    }
    
    // Log monitoring
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Checking for existance of %@", documentName);
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        
        // Check if the file exists, and return
        if ([self.fileManager fileExistsAtPath:[fileURL path]]) {
            // Create the UIDocument
            iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
            [self.notificationCenter addObserver:sender selector:selector name:UIDocumentStateChangedNotification object:document];
            
            // Log monitoring
            if (self.verboseLogging == YES) NSLog(@"[iCloud] Now successfully monitoring for changes to %@ on %@", documentName, sender);
            
            return YES;
        } else {
            // The document could not be found
            NSLog(@"[iCloud] File not found: %@", documentName);
            
            return NO;
        }
    } @catch (NSException *exception) {
        // Log exception
        NSLog(@"[iCloud] Exception while attempting to stop monitoring document state changes to %@", exception);
        
        return NO;
    }
}

- (BOOL)stopMonitoringDocumentStateChangesForFile:(NSString *)documentName onTarget:(id)sender {
    // Log monitoring
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Preparing to stop monitoring document changes to %@", documentName);
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return NO;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return NO;
    }
    
    // Log monitoring
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Checking for existance of %@", documentName);
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        
        // Check if the file exists, and return
        if ([self.fileManager fileExistsAtPath:[fileURL path]]) {
            // Create the UIDocument
            iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
            
            [self.notificationCenter removeObserver:sender name:UIDocumentStateChangedNotification object:document];
            
            // Log monitoring
            if (self.verboseLogging == YES) NSLog(@"[iCloud] Stopped monitoring document state changes to %@", documentName);
            
            return YES;
        } else {
            // The document could not be found
            NSLog(@"[iCloud] File not found: %@", documentName);
            
            return NO;
        }
    } @catch (NSException *exception) {
        // Log exception
        NSLog(@"[iCloud] Exception while attempting to stop monitoring document state changes to %@", exception);
        
        return NO;
    }
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Conflict -----------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Conflict

- (NSArray *)findUnresolvedConflictingVersionsOfFile:(NSString *)documentName {
    // Log conflict search
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Preparing to find all version conflicts for %@", documentName);
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return nil;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return nil;
    }
    
    // Log conflict search
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Checking for existance of %@", documentName);
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        
        // Check if the file exists, and return
        if ([self.fileManager fileExistsAtPath:[fileURL path]]) {
            // Log conflict search
            if (self.verboseLogging == YES) NSLog(@"[iCloud] %@ exists at the correct path, proceeding to find the conflicts", documentName);
        
            NSMutableArray *fileVersions = [NSMutableArray array];
            
            NSFileVersion *currentVersion = [NSFileVersion currentVersionOfItemAtURL:fileURL];
            [fileVersions addObject:currentVersion];
            
            NSArray *otherVersions = [NSFileVersion otherVersionsOfItemAtURL:fileURL];
            [fileVersions addObjectsFromArray:otherVersions];
            
            return fileVersions;
        } else {
            // The document could not be found
            NSLog(@"[iCloud] File not found: %@", documentName);
            
            return nil;
        }
    } @catch (NSException *exception) {
        // Log exception
        NSLog(@"[iCloud] Exception while attempting to stop monitoring document state changes to %@", exception);
        
        return nil;
    }
}

- (void)resolveConflictForFile:(NSString *)documentName withSelectedFileVersion:(NSFileVersion *)documentVersion {
    // Log resolution
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Preparing to resolve version conflict for %@", documentName);
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return;
    }
    
    // Log resolution
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Checking for existance of %@", documentName);
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        
        // Check if the file exists, and return
        if ([self.fileManager fileExistsAtPath:[fileURL path]]) {
            // Log resolution
            if (self.verboseLogging == YES) NSLog(@"[iCloud] %@ exists at the correct path, proceeding to resolve the conflict", documentName);
            
            // Make the current version "win" the conflict if it is selected
            if (![documentVersion isEqual:[NSFileVersion currentVersionOfItemAtURL:fileURL]]) {
                // Log resolution
                if (self.verboseLogging == YES) NSLog(@"[iCloud] The current version (%@) of %@ matches the selected version. Resolving conflict...", documentVersion, documentName);
                
                [documentVersion replaceItemAtURL:fileURL options:0 error:nil];
            }
            
            // Remove other versions of the document
            [NSFileVersion removeOtherVersionsOfItemAtURL:fileURL error:nil];
            
            // Log resolution
            if (self.verboseLogging == YES) NSLog(@"[iCloud] Removing all unresolved other versions of %@", documentName);
            
            NSArray *conflictVersions = [NSFileVersion unresolvedConflictVersionsOfItemAtURL:fileURL];
            for (NSFileVersion *fileVersion in conflictVersions) {
                fileVersion.resolved = YES;
            }
            
            // Log resolution
            if (self.verboseLogging == YES) NSLog(@"[iCloud] Finished resolving conflicts for %@", documentName);
        } else {
            // The document could not be found
            NSLog(@"[iCloud] File not found: %@", documentName);
            
            return;
        }
    } @catch (NSException *exception) {
        // Log exception
        NSLog(@"[iCloud] Exception while attempting to stop monitoring document state changes to %@", exception);
        
        return;
    }
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Share --------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Share

- (NSURL *)shareDocumentWithName:(NSString *)documentName completion:(void (^)(NSURL *sharedURL, NSDate *expirationDate, NSError *error))handler {
    // Log share
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Attempting to share document");
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return nil;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return nil;
    }
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        // Check that the file exists
        if ([self.fileManager fileExistsAtPath:[fileURL path]]) {
            // Log share
            if (self.verboseLogging == YES) NSLog(@"[iCloud] File exists, preparing to share it");
            
            // Create the URL to be returned outside of the block
            __block NSURL *url;
            
            // Move to the background thread for safety
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                // Create the Error Object and the Date Object
                NSError *error;
                NSDate *date;
                
                // Create the URL
                url = [self.fileManager URLForPublishingUbiquitousItemAtURL:fileURL expirationDate:&date error:&error];
                
                // Log share
                if (self.verboseLogging == YES) NSLog(@"[iCloud] Shared iCloud document");
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Pass the data to the handler
                    handler(url, date, error);
                });
            });
            
            // Return the URL
            return url;
        } else {
            // The document could not be found
            NSLog(@"[iCloud] File not found: %@", documentName);
            NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, does not exist at path: %@", documentName, fileURL] code:404 userInfo:@{@"FileURL": fileURL}];
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(nil, nil, error);
                return;
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"[iCloud] Caught exception while sharing file: %@\n\n%s", exception, __PRETTY_FUNCTION__);
    }
    return nil;
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Delete -------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Delete

- (void)deleteDocumentWithName:(NSString *)documentName completion:(void (^)(NSError *error))handler {
    // Log delete
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Attempting to delete document");
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return;
    }
    
    @try {
        // Create the URL for the file that is being removed
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        // Check that the file exists
        if ([self.fileManager fileExistsAtPath:[fileURL path]]) {
            // Log share
            if (self.verboseLogging == YES) NSLog(@"[iCloud] File exists, attempting to delete it");
            
            // Move to the background thread for safety
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                
                // Use a file coordinator to safely delete the file
                NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
                [fileCoordinator coordinateWritingItemAtURL:fileURL options:NSFileCoordinatorWritingForDeleting error:nil byAccessor:^(NSURL *writingURL) {
                    // Create the error handler
                    NSError *error;
                    
                    [self.fileManager removeItemAtURL:writingURL error:&error];
                    if (error) {
                        // Log failure
                        NSLog(@"[iCloud] An error occurred while deleting the document: %@", error);
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (handler) handler(error);
                        });
                        
                        return;
                    } else {
                        // Log success
                        if (self.verboseLogging == YES) NSLog(@"[iCloud] The document has been deleted");
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self updateFiles];
                            if (handler) handler(nil);
                        });
                        
                        return;
                    }
                }];
            });
        } else {
            // The document could not be found
            NSLog(@"[iCloud] File not found: %@", documentName);
            NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, does not exist at path: %@", documentName, fileURL] code:404 userInfo:@{@"FileURL": fileURL}];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (handler) handler(error);
                return;
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"[iCloud] Caught exception while deleting file: %@\n\n%s", exception, __PRETTY_FUNCTION__);
    }
}

- (void)evictCloudDocumentWithName:(NSString *)documentName completion:(void (^)(NSError *error))handler {
    // Log download
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Attempting to evict iCloud document, %@", documentName);
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return;
    }
    
    // Perform tasks on background thread to avoid problems on the main / UI thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        // Get the array of files in the documents directory
        NSString *documentsDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        NSString *localDocument = [documentsDirectory stringByAppendingPathComponent:documentName];
        
        // If the file does not exist in iCloud, upload it
        if (![self.previousQueryResults containsObject:localDocument]) {
            // Log
            if (self.verboseLogging == YES) NSLog(@"[iCloud] Evicting %@ from iCloud", localDocument);
            
            // Move the file to iCloud
            NSURL *cloudURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
            NSURL *localURL = [NSURL fileURLWithPath:localDocument];
            NSError *error;
            
            BOOL success = [self.fileManager setUbiquitous:NO itemAtURL:cloudURL destinationURL:localURL error:&error];
            if (!success) {
                NSLog(@"[iCloud] Error while evicting document from local directory: %@", error);
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(error);
                    return;
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(nil);
                    return;
                });
            }
            
        } else {
            // Check if the cloud document is newer than the local document
            
            // Log conflict
            if (self.verboseLogging == YES) NSLog(@"[iCloud] Conflict between local file and remote file, attempting to automatically resolve");
            
            // Get the file URL for the documents
            NSURL *cloudURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
            NSURL *localURL = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:localDocument]];
            
            // Create the UIDocument object from the URL
            iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:cloudURL];
            NSDate *cloudModDate = document.fileModificationDate;
            
            NSDictionary *fileAttributes = [self.fileManager attributesOfItemAtPath:[localURL absoluteString] error:nil];
            NSDate *localModDate = [fileAttributes fileModificationDate];
            NSData *localFileData = [self.fileManager contentsAtPath:[localURL absoluteString]];
            
            if ([localModDate compare:cloudModDate] == NSOrderedDescending) {
                NSLog(@"[iCloud] The local file was modified more recently than the iCloud file. The iCloud file will be deleted and the local file will be preserved.");
                
                [self deleteDocumentWithName:documentName completion:^(NSError *error) {
                    if (error) {
                        NSLog(@"[iCloud] Error deleting %@.\n\n%@", [localURL absoluteString], error);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            handler(error);
                            return;
                        });
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            handler(nil);
                            return;
                        });
                    }
                }];
                
            } else if ([localModDate compare:cloudModDate] == NSOrderedAscending) {
                NSLog(@"[iCloud] The iCloud file was modified more recently than the local file. The local file will be overwritten with the contents of the iCloud file.");
                
                BOOL success = [document.contents writeToURL:localURL atomically:YES];
                if (success) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(nil);
                        return;
                    });
                } else {
                    NSLog(@"[iCloud] Failed to overwrite file at URL: %@", localURL);
                    NSError *error = [[NSError alloc] initWithDomain:@"Unknown error occured while writing file to URL." code:100 userInfo:@{@"FileURL": localURL}];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(error);
                        return;
                    });
                }
            } else {
                NSLog(@"[iCloud] The iCloud file and local file have the same modification date. Before overwriting or deleting, iCloud Document Sync will check if both files have the same content.");
                if ([self.fileManager contentsEqualAtPath:[localURL absoluteString] andPath:[cloudURL absoluteString]] == YES) {
                    NSLog (@"[iCloud] The contents of the iCloud file and the contents of the local file match. The iCloud file will be deleted.");
                    
                    [self deleteDocumentWithName:documentName completion:^(NSError *error) {
                        if (error) {
                            NSLog(@"[iCloud] Error deleting %@.\n\n%@", [localURL absoluteString], error);
                            dispatch_async(dispatch_get_main_queue(), ^{
                                handler(error);
                                return;
                            });
                        } else {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                handler(nil);
                                return;
                            });
                        }
                    }];
                } else {
                    NSLog(@"[iCloud] Both the local file and the iCloud file were last modified at the same time, however their contents do not match. You'll need to handle the conflict using the iCloudFileConflictBetweenCloudFile:andLocalFile: delegate method.");
                    NSDictionary *cloudFile = @{@"fileContents": document.contents, @"fileURL": cloudURL, @"modifiedDate": cloudModDate};
                    NSDictionary *localFile = @{@"fileContents": localFileData, @"fileURL": localURL, @"modifiedDate": localModDate};;
                    
                    if ([self.delegate respondsToSelector:@selector(iCloudFileUploadConflictWithCloudFile:andLocalFile:)]) {
                        [self.delegate iCloudFileConflictBetweenCloudFile:cloudFile andLocalFile:localFile];
                    } else if ([self.delegate respondsToSelector:@selector(iCloudFileUploadConflictWithCloudFile:andLocalFile:)]) {
                        NSLog(@"[iCloud] WARNING: iCloudFileUploadConflictWithCloudFile:andLocalFile is deprecated and will become unavailable in a future version. Use iCloudFileConflictBetweenCloudFile:andLocalFile instead.");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                        [self.delegate iCloudFileUploadConflictWithCloudFile:cloudFile andLocalFile:localFile];
#pragma clang diagnostic pop
                    }
                    
                    return;
                }
            }
        }
        
        // Log completion
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Finished evicting iCloud document. Successfully moved to local storage.");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(nil);
            return;
        });
    });
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Manage -------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Manage

- (void)renameOriginalDocument:(NSString *)documentName withNewName:(NSString *)newName completion:(void (^)(NSError *error))handler {
    // Log rename
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Attempting to rename document, %@, to the new name: %@", documentName, newName);
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""] || newName == nil || [newName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return;
    }
    
    // Create the URLs for the files that are being renamed
    NSURL *sourceFileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    NSURL *newFileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:newName];
    
    // Check if file exists at source URL
    if (![self.fileManager fileExistsAtPath:[sourceFileURL path]]) {
        NSLog(@"[iCloud] File does not exist at path: %@", sourceFileURL);
        NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, does not exist at path: %@", documentName, sourceFileURL] code:404 userInfo:@{@"FileURL": sourceFileURL}];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (handler)
                handler(error);
        });
        
        return;
    }
    
    // Check if file does not exist at new URL
    if ([self.fileManager fileExistsAtPath:[newFileURL path]]) {
        NSLog(@"[iCloud] File already exists at path: %@", newFileURL);
        NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, already exists at path: %@", newName, newFileURL] code:512 userInfo:@{@"FileURL": newFileURL}];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (handler)
                handler(error);
        });
        
        return;
    }
    
    // Log success of existence
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Files passed existence check, preparing to rename");
    
    // Move to the background thread for safety
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        // Coordinate renaming safely with a file coordinator
        NSError *coordinatorError = nil;
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        [coordinator coordinateWritingItemAtURL:sourceFileURL options:NSFileCoordinatorWritingForMoving writingItemAtURL:newFileURL options:NSFileCoordinatorWritingForReplacing error:&coordinatorError byAccessor:^(NSURL *newURL1, NSURL *newURL2) {
            NSError *moveError;
            BOOL moveSuccess;
            
            // Log rename
            if (self.verboseLogging == YES) NSLog(@"[iCloud] Renaming Files");
            
            // Do the actual renaming
            moveSuccess = [self.fileManager moveItemAtURL:sourceFileURL toURL:newFileURL error:&moveError];
            
            if (moveSuccess) {
                // Log success
                if (self.verboseLogging == YES) NSLog(@"[iCloud] Renamed Files");
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (handler)
                        handler(nil);
                });
                return;
            }
            
            if (moveError) {
                // Log failure
                NSLog(@"[iCloud] Failed to rename file, %@, to new name: %@. Error: %@", documentName, newName , moveError);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (handler)
                        handler(moveError);
                });
                
                return;
            }
            
            if (coordinatorError) {
                // Log failure
                NSLog(@"[iCloud] Failed to rename file, %@, to new name: %@. Error: %@", documentName, newName , coordinatorError);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (handler)
                        handler(coordinatorError);
                });
                
                return;
            }
        }];
    });
}

- (void)duplicateOriginalDocument:(NSString *)documentName withNewName:(NSString *)newName completion:(void (^)(NSError *error))handler {
    // Log duplication
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Attempting to duplicate document, %@", documentName);
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""] || newName == nil || [newName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return;
    }
    
    // Create the URLs for the files that are being renamed
    NSURL *sourceFileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    NSURL *newFileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:newName];
    
    // Check if file exists at source URL
    if (![self.fileManager fileExistsAtPath:[sourceFileURL path]]) {
        NSLog(@"[iCloud] File does not exist at path: %@", sourceFileURL);
        NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, does not exist at path: %@", documentName, sourceFileURL] code:404 userInfo:@{@"FileURL": sourceFileURL}];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (handler)
                handler(error);
        });
        
        return;
    }
    
    // Check if file does not exist at new URL
    if ([self.fileManager fileExistsAtPath:[newFileURL path]]) {
        NSLog(@"[iCloud] File already exists at path: %@", newFileURL);
        NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, already exists at path: %@", newName, newFileURL] code:512 userInfo:@{@"FileURL": newFileURL}];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (handler)
                handler(error);
        });
        
        return;
    }
    
    // Log success of existence
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Files passed existence check, preparing to duplicate");
    
    // Move to the background thread for safety
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSError *moveError;
        BOOL moveSuccess;
        
        // Log duplication
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Duplicating Files");
        
        // Do the actual duplicating
        moveSuccess = [self.fileManager copyItemAtURL:sourceFileURL toURL:newFileURL error:&moveError];
        
        if (moveSuccess) {
            // Log success
            if (self.verboseLogging == YES) NSLog(@"[iCloud] Duplicated Files");
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (handler)
                    handler(nil);
            });
            return;
        }
        
        if (moveError) {
            // Log failure
            NSLog(@"[iCloud] Failed to duplicate file, %@, with new name: %@. Error: %@", documentName, newName , moveError);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (handler)
                    handler(moveError);
            });
            
            return;
        }
    });
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Deprecated Methods -------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Deprecated Methods

+ (void)uploadLocalOfflineDocumentsWithDelegate:(id<iCloudDelegate>)delegate {
    for (int i = 0; i <= 5; i++) NSLog(@"[iCloud] WARNING: uploadLocalOfflineDocumentsWithDelegate: is deprecated and will become unavailable in version 8.0. Use [- uploadLocalOfflineDocuments] instead.");
}

+ (void)updateFilesWithDelegate:(id<iCloudDelegate>)delegate {
    for (int i = 0; i <= 5; i++) NSLog(@"[iCloud] WARNING: updateFilesWithDelegate: is deprecated and will become unavailable in version 8.0. Use [- updateFiles] instead.");
}

- (NSArray *)getListOfCloudFiles {
    for (int i = 0; i <= 5; i++) NSLog(@"[iCloud] WARNING: getListOfCloudFiles is deprecated and will become unavailable in a future version. Use [- listCloudFiles] instead. This method will return nil.");
    return nil;
}

- (void)saveChangesToDocumentWithName:(NSString *)documentName withContent:(NSData *)content completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler {
    // This method is deprecated: Due to the fact, that the document is recreated in closed state on every call, it is just a copy of the saveAndCloseDocumentWithName-method above
    for (int i = 0; i <= 5; i++) NSLog(@"[iCloud] WARNING: saveChangesToDocumentWithName:withContent:completion: is deprecated and will become unavailable in version 8.0. Use [- saveAndCloseDocumentWithName:withContent:completion:] instead.");
    
	[self saveAndCloseDocumentWithName:documentName withContent:content completion:handler];
    
	/*
     
     // Log save
     if (verboseLogging == YES) NSLog(@"[iCloud] Beginning document change save");
     
     // Check for iCloud
     if ([self quickCloudCheck] == NO) return;
     
     // Check for nil / null document name
     if (documentName == nil || [documentName isEqualToString:@""]) {
     // Log error
     if (verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
     NSError *error = [NSError errorWithDomain:@"The specified document name was empty / blank and could not be saved. Specify a document name next time." code:001 userInfo:nil];
     
     handler(nil, nil, error);
     
     return;
     }
     
     // Get the URL to save the changes to
     NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
     
     // Initialize a document with that path
     iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
     document.contents = content;
     
     // If the file exists, close it; otherwise, create it.
     if ([fileManager fileExistsAtPath:[fileURL path]]) {
     // Log recording
     if (verboseLogging == YES) NSLog(@"[iCloud] Document exists, saving changes");
     
     // Record Changes
     [document updateChangeCount:UIDocumentChangeDone];
     
     handler(document, document.contents, nil);
     } else {
     // Log saving
     if (verboseLogging == YES) NSLog(@"[iCloud] Document is new, saving");
     
     // Save and create the new document
     [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
     if (success) {
     // Log the save
     if (verboseLogging == YES) NSLog(@"[iCloud] New document created successfully, recorded changes");
     
     // Run the completion block and pass the document
     handler(document, document.contents, nil);;
     } else {
     NSLog(@"[iCloud] Error while creating the document: %s", __PRETTY_FUNCTION__);
     NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while creating the document, %@, in iCloud", __PRETTY_FUNCTION__, document.fileURL] code:100 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
     
     handler(document, document.contents, error);
     }
     }];
     }
	 */
}

@end
