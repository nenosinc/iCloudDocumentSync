//
//  iCloud.m
//  iCloud Document Sync
//
//  Some portions of this project are based
//      off of the iCloudPlayground project
//
//  Created by iRare Media on 3/23/13.
//
//

#import "iCloud.h"

@interface iCloud () {
    UIBackgroundTaskIdentifier backgroundProcess;
    NSFileManager *fileManager;
    NSNotificationCenter *notificationCenter;
    NSString *fileExtension;
    NSURL *ubiquityContainer;
}
- (void)enumerateCloudDocuments;
- (void)startUpdate:(NSMetadataQuery *)notification;
- (BOOL)quickCloudCheck;
@end

@implementation iCloud
@synthesize query, previousQueryResults, fileList;
@synthesize delegate, verboseLogging, verboseAvailabilityLogging;

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Setup --------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Setup

+ (id)sharedCloud {
    static iCloud *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (id)init {
    // Setup Starter Sync
    self = [super init];
    if (self) {
        // Setup the File Manager
        if (fileManager == nil) fileManager = [NSFileManager defaultManager];
        
        // Setup the Notification Center
        if (notificationCenter == nil) notificationCenter = [NSNotificationCenter defaultCenter];
        
        // Initialize file lists, results, and queries
        if (fileList == nil) fileList = [NSMutableArray array];
        if (previousQueryResults == nil) previousQueryResults = [NSMutableArray array];
        if (query == nil) query = [[NSMetadataQuery alloc] init];
        
        // Log the setup
        if (verboseLogging == YES) NSLog(@"[iCloud] Initialized");
        
        // Check the iCloud Ubiquity Container
        [self checkCloudUbiquityContainer];
        
        // Check iCloud Availability
        [self checkCloudAvailability];
        
        // Subscribe to changes in iCloud availability
        [notificationCenter addObserver:self selector:@selector(checkCloudAvailability) name:NSUbiquityIdentityDidChangeNotification object:nil];
        
        // Sync and Update Documents List
        [self enumerateCloudDocuments];
    }
    
    return self;
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Basic --------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Basic

- (BOOL)checkCloudAvailability {
    id cloudToken = [fileManager ubiquityIdentityToken];
    if (cloudToken) {
        if (verboseAvailabilityLogging == YES) NSLog(@"iCloud is available. Ubiquity URL: %@\nUbiquity Token: %@", ubiquityContainer, cloudToken);
        
        if ([delegate respondsToSelector:@selector(iCloudAvailabilityDidChangeToState:withUbiquityToken:withUbiquityContainer:)])
            [delegate iCloudAvailabilityDidChangeToState:YES withUbiquityToken:cloudToken withUbiquityContainer:ubiquityContainer];
        
        return YES;
    } else {
        if (verboseAvailabilityLogging == YES)
            NSLog(@"iCloud is not available. iCloud may be unavailable for a number of reasons:\n• The device has not yet been configured with an iCloud account, or the Documents & Data option is disabled\n• Your app, %@, does not have properly configured entitlements\nGo to http://bit.ly/15ECEWj for more information on setting up iCloud", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]);
        else
            NSLog(@"iCloud unavailable");
        
        if ([delegate respondsToSelector:@selector(iCloudAvailabilityDidChangeToState:withUbiquityToken:withUbiquityContainer:)])
            [delegate iCloudAvailabilityDidChangeToState:NO withUbiquityToken:nil withUbiquityContainer:ubiquityContainer];
        
        return NO;
    }
}

- (BOOL)checkCloudUbiquityContainer {
    dispatch_async (dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        // Check for iCloud Availability by finishing the Ubiquity URL of the app
        ubiquityContainer = [fileManager URLForUbiquityContainerIdentifier:nil];
    });
    
    if (ubiquityContainer){
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)quickCloudCheck {
    if ([fileManager ubiquityIdentityToken]) {
        return YES;
    } else {
        return NO;
    }
}

- (NSURL *)ubiquitousContainerURL {
    dispatch_async (dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        ubiquityContainer = [fileManager URLForUbiquityContainerIdentifier:nil];
    });
    
    return ubiquityContainer;
}

- (NSURL *)ubiquitousDocumentsDirectoryURL {
    return [ubiquityContainer URLByAppendingPathComponent:DOCUMENT_DIRECTORY];
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Sync ---------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Sync

- (void)enumerateCloudDocuments {
    // Log document enumeration
    if (verboseLogging == YES) NSLog(@"[iCloud] Creating metadata query and notifications");
    
    // Request information from the delegate
    if ([delegate respondsToSelector:@selector(iCloudQueryLimitedToFileExtension)]) {
        NSString *fileExt = [delegate iCloudQueryLimitedToFileExtension];
        if (fileExt != nil || ![fileExt isEqualToString:@""]) fileExtension = fileExt;
        else fileExtension = @"*";
    } else {
        fileExtension = @"*";
    }
    
    // Setup iCloud Metadata Query
	[query setSearchScopes:@[NSMetadataQueryUbiquitousDocumentsScope]];
	[query setPredicate:[NSPredicate predicateWithFormat:[NSString stringWithFormat:@"%%K like '*.%@'", fileExtension], NSMetadataItemFSNameKey]];
    
	// Pull a list of all the documents in the cloud
	[notificationCenter addObserver:self selector:@selector(startUpdate:) name:NSMetadataQueryDidFinishGatheringNotification object:query];
	[notificationCenter addObserver:self selector:@selector(startUpdate:) name:NSMetadataQueryDidUpdateNotification object:query];
    
    // Start the query
    BOOL startedQuery = [query startQuery];
    if (!startedQuery) NSLog(@"Failed to start query.");
}

- (void)startUpdate:(NSMetadataQuery *)query {
    [self updateFiles];
}

- (void)updateFiles {
    // Log file update
    if (verboseLogging == YES) NSLog(@"[iCloud] Beginning file update with NSMetadataQuery");
    
    if ([self quickCloudCheck] == NO) return;
    
    // Create and Update the list of files on the background thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        // Disable updates to iCloud while we update to avoid errors
        [query disableUpdates];
        
        NSMutableArray *discoveredFiles = [NSMutableArray array];
        
        // The query reports all files found, every time
        NSArray *queryResults = query.results;
        NSLog(@"Query Results: %@", query.results);
        for (NSMetadataItem *result in queryResults) {
            NSURL *fileURL = [result valueForAttribute:NSMetadataItemURLKey];
            NSNumber *aBool = nil;
            
            // Don't include hidden files
            [fileURL getResourceValue:&aBool forKey:NSURLIsHiddenKey error:nil];
            if (aBool && ![aBool boolValue])
                [discoveredFiles addObject:result];
        }
        
        // Get file names in from the query
        NSMutableArray *names = [NSMutableArray array];
        for (NSMetadataItem *item in query.results) {
            [names addObject:[item valueForAttribute:NSMetadataItemFSNameKey]];
        }
        
        // Log query completion
        if (verboseLogging == YES) NSLog(@"[iCloud] Finished file update with NSMetadataQuery");
        
        // Notify the delegate of the results on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([delegate respondsToSelector:@selector(iCloudFilesDidChange:withNewFileNames:)])
                [delegate iCloudFilesDidChange:discoveredFiles withNewFileNames:names];
        });
        
        // Reenable Updates
        [query enableUpdates];
    });
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Write --------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Write

- (void)saveAndCloseDocumentWithName:(NSString *)name withContent:(NSData *)content completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler {
    // Log save
    if (verboseLogging == YES) NSLog(@"[iCloud] Beginning document save");
    
    if ([self quickCloudCheck] == NO) return;
    
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        // Get the URL to save the new file to
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:name];
        
        // Initialize a document with that path
        iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
        document.contents = content;
        [document updateChangeCount:UIDocumentChangeDone];
        
        // If the file exists, close it; otherwise, create it.
        if ([fileManager fileExistsAtPath:[fileURL path]]) {
            // Log closing
            if (verboseLogging == YES) NSLog(@"[iCloud] Document exists, saving and closing");
            
            // Save and close the document
            [document closeWithCompletionHandler:^(BOOL success) {
                if (success) {
                    // Log
                    if (verboseLogging == YES) NSLog(@"[iCloud] Saved and closed document");
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(document, document.contents, nil);
                    });
                } else {
                    NSLog(@"[iCloud] Error while saving document: %s", __PRETTY_FUNCTION__);
                    NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while saving the document, %@, to iCloud", __PRETTY_FUNCTION__, document.fileURL] code:110 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(document, document.contents, error);
                    });
                }
            }];
        } else {
            // Log saving
            if (verboseLogging == YES) NSLog(@"[iCloud] Document is new, saving and then closing");
            
            // Save and create the new document, then close it
            [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
                if (success) {
                    // Saving implicitly opens the file
                    [document closeWithCompletionHandler:^(BOOL success) {
                        // Log the save and close
                        if (verboseLogging == YES) NSLog(@"[iCloud] New document closed and saved successfully");
                        
                        // Run the completion block and pass the document
                        dispatch_async(dispatch_get_main_queue(), ^{
                            // Run process on the main thread
                            handler(document, document.contents, nil);
                        });
                    }];
                    
                    
                } else {
                    NSLog(@"[iCloud] Error while creating the document: %s", __PRETTY_FUNCTION__);
                    NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while creating the document, %@, in iCloud", __PRETTY_FUNCTION__, document.fileURL] code:100 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(document, document.contents, error);
                    });
                }
            }];
        }
    });
}

- (void)saveDocumentChangesWithoutClosingWithName:(NSString *)name withContent:(NSData *)content completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler {
    // Log save
    if (verboseLogging == YES) NSLog(@"[iCloud] Beginning document change save");
    
    if ([self quickCloudCheck] == NO) return;
    
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        // Get the URL to save the changes to
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:name];
        
        // Initialize a document with that path
        iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
        document.contents = content;
        
        // If the file exists, close it; otherwise, create it.
        if ([fileManager fileExistsAtPath:[fileURL path]]) {
            // Log recording
            if (verboseLogging == YES) NSLog(@"[iCloud] Document exists, saving changes");
            
            // Record Changes
            [document updateChangeCount:UIDocumentChangeDone];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(document, document.contents, nil);
            });
        } else {
            // Log saving
            if (verboseLogging == YES) NSLog(@"[iCloud] Document is new, saving");
            
            // Save and create the new document
            [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
                if (success) {
                    // Log the save
                    if (verboseLogging == YES) NSLog(@"[iCloud] New document created successfully, recorded changes");
                    
                    // Run the completion block and pass the document
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // Run process on the main thread
                        handler(document, document.contents, nil);
                    });
                } else {
                    NSLog(@"[iCloud] Error while creating the document: %s", __PRETTY_FUNCTION__);
                    NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while creating the document, %@, in iCloud", __PRETTY_FUNCTION__, document.fileURL] code:100 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(document, document.contents, error);
                    });
                }
            }];
        }
    });
}

- (void)uploadLocalOfflineDocumentsWithRepeatingHandler:(void (^)(NSString *fileName, NSError *error))repeatingHandler completion:(void (^)(void))completion {
    // Log upload
    if (verboseLogging == YES) NSLog(@"[iCloud] Beginning local file upload to iCloud. This process may take a long time.");
    
    // Check if iCloud is available
    if ([self quickCloudCheck] == NO) return;
    
    // Perform tasks on background thread to avoid problems on the main / UI thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        // Get the array of files in the documents directory
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSArray *localDocuments = [fileManager contentsOfDirectoryAtPath:documentsDirectory error:nil];
        
        // Log local files
        if (verboseLogging == YES) NSLog(@"[iCloud] Files stored locally available for uploading: %@", localDocuments);
        
        // Compare the arrays then upload documents not already existent in iCloud
        for (int item = 0; item < [localDocuments count]; item++) {
            
            // Check to make sure the documents aren't hidden
            if (![[localDocuments objectAtIndex:item] hasPrefix:@"."]) {
                
                // If the file does not exist in iCloud, upload it
                if (![previousQueryResults containsObject:[localDocuments objectAtIndex:item]]) {
                    // Log
                    if (verboseLogging == YES) NSLog(@"[iCloud] Uploading %@ to iCloud (%i out of %lu)", [localDocuments objectAtIndex:item], item, (unsigned long)[localDocuments count]);
                    
                    // Move the file to iCloud
                    NSURL *destinationURL = [[fileManager URLForUbiquityContainerIdentifier:nil] URLByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@",[localDocuments objectAtIndex:item]]];
                    NSError *error;
                    NSURL *directoryURL = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:[localDocuments objectAtIndex:item]]];
                    
                    BOOL success = [fileManager setUbiquitous:YES itemAtURL:directoryURL destinationURL:destinationURL error:&error];
                    if (success == NO) {
                        NSLog(@"[iCloud] Error while uploading document from local directory: %@",error);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            repeatingHandler([localDocuments objectAtIndex:item], error);
                        });
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            repeatingHandler([localDocuments objectAtIndex:item], nil);
                        });
                    }
                    
                } else {
                    // Check if the local document is newer than the cloud document
                    
                    // Log conflict
                    if (verboseLogging == YES) NSLog(@"[iCloud] Conflict between local file and remote file, attempting to automatically resolve");
                    
                    // Get the file URL for the iCloud document
                    NSURL *cloudFileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:[localDocuments objectAtIndex:item]];
                    NSURL *localFileURL = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:[localDocuments objectAtIndex:item]]];
                    
                    // Create the UIDocument object from the URL
                    iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:cloudFileURL];
                    NSDate *cloudModDate = document.fileModificationDate;
                    
                    NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:[localFileURL absoluteString] error:nil];
                    NSDate *localModDate = [fileAttributes fileModificationDate];
                    NSData *localFileData = [fileManager contentsAtPath:[localFileURL absoluteString]];
                    
                    if ([cloudModDate compare:localModDate] == NSOrderedDescending) {
                        NSLog(@"[iCloud] The iCloud file was modified more recently than the local file. The local file will be deleted and the iCloud file will be preserved.");
                        NSError *error;
                        
                        if (![fileManager removeItemAtPath:[localFileURL absoluteString] error:&error]) {
                            NSLog(@"[iCloud] Error deleting %@.\n\n%@", [localFileURL absoluteString], error);
                        }
                    } else if ([cloudModDate compare:localModDate] == NSOrderedAscending) {
                        NSLog(@"[iCloud] The local file was modified more recently than the iCloud file. The iCloud file will be overwritten with the contents of the local file.");
                        // Set the document's new content
                        document.contents = localFileData;
                        
                        // Save and close the document in iCloud
                        [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
                            if (success) {
                                // Close the document
                                [document closeWithCompletionHandler:^(BOOL success) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        repeatingHandler([localDocuments objectAtIndex:item], nil);
                                    });
                                }];
                            } else {
                                NSLog(@"[iCloud] Error while overwriting old iCloud file: %s", __PRETTY_FUNCTION__);
                                NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while saving the document, %@, to iCloud", __PRETTY_FUNCTION__, document.fileURL] code:110 userInfo:[NSDictionary dictionaryWithObject:[localDocuments objectAtIndex:item] forKey:@"FileName"]];
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    repeatingHandler([localDocuments objectAtIndex:item], error);
                                });
                            }
                        }];
                    } else {
                        NSLog(@"[iCloud] The local file and iCloud file have the same modification date. Before overwriting or deleting, iCloud Document Sync will check if both files have the same content.");
                        if ([fileManager contentsEqualAtPath:[cloudFileURL absoluteString] andPath:[localFileURL absoluteString]] == YES) {
                            NSLog (@"[iCloud] The contents of the local file and the contents of the iCloud file match. The local file will be deleted.");
                            NSError *error;
                            
                            if (![fileManager removeItemAtPath:[localFileURL absoluteString] error:&error]) {
                                NSLog(@"[iCloud] Error deleting %@.\n\n%@", [localFileURL absoluteString], error);
                            }
                        } else {
                            NSLog(@"[iCloud] Both the iCloud file and the local file were last modified at the same time, however their contents do not match. You'll need to handle the conflict using the iCloudFileUploadConflictWithCloudFile:andLocalFile: delegate method.");
                            NSDictionary *cloudFile = [[NSDictionary alloc] initWithObjects:@[document.contents, cloudFileURL, cloudModDate]
                                                                                    forKeys:@[@"fileContents", @"fileURL", @"modifiedDate"]];
                            NSDictionary *localFile = [[NSDictionary alloc] initWithObjects:@[localFileData, localFileURL, localModDate]
                                                                                    forKeys:@[@"fileContents", @"fileURL", @"modifiedDate"]];;
                            
                            if ([delegate respondsToSelector:@selector(iCloudFileUploadConflictWithCloudFile:andLocalFile:)])
                                [delegate iCloudFileUploadConflictWithCloudFile:cloudFile andLocalFile:localFile];
                        }
                    }
                }
            } else {
                // The file is hidden, do not proceed
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSError *error = [[NSError alloc] initWithDomain:@"File in directory is hidden and will not be uploaded to iCloud." code:520 userInfo:[NSDictionary dictionaryWithObject:[localDocuments objectAtIndex:item] forKey:@"FileName"]];
                    repeatingHandler([localDocuments objectAtIndex:item], error);
                });
            }
        }
        
        // Log completion
        if (verboseLogging == YES) NSLog(@"[iCloud] Finished uploading all local files to iCloud");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion();
        });
    });
}

- (void)uploadLocalDocumentToCloudWithName:(NSString *)name completion:(void (^)(NSError *error))handler {
    // Log download
    if (verboseLogging == YES) NSLog(@"[iCloud] Attempting to upload document, %@", name);
    
    if ([self quickCloudCheck] == NO) return;
    
    NSLog(@"[iCloud] This method, uploadLocalDocumentToCloudWithName:completion:, is not yet available. It should be available soon.");
}

- (void)downloadCloudDocumentWithName:(NSString *)name completion:(void (^)(NSError *error))handler {
    // Log download
    if (verboseLogging == YES) NSLog(@"[iCloud] Attempting to download document, %@", name);
    
    if ([self quickCloudCheck] == NO) return;
    
    NSLog(@"[iCloud] This method, downloadCloudDocumentWithName:completion:, is not yet available. It should be available soon.");
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Read ---------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Read

- (void)retrieveCloudDocumentWithName:(NSString *)documentName completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler {
    // Log Retrieval
    if (verboseLogging == YES) NSLog(@"[iCloud] Retrieving iCloud document, %@", documentName);
    
    // Check for iCloud availability
    if ([self quickCloudCheck] == NO) return;
    
    @try {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
            // Get the URL to get the file from
            NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
            
            // If the file exists open it; otherwise, create it
            if ([fileManager fileExistsAtPath:[fileURL path]]) {
                // Log opening
                if (verboseLogging == YES) NSLog(@"[iCloud] The document, %@, already exists and will be opened", documentName);
                
                // Create the UIDocument object from the URL
                iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
                
                if (document.documentState & UIDocumentStateClosed) {
                    [document openWithCompletionHandler:^(BOOL success){
                        if (success) {
                            // Log open
                            if (verboseLogging == YES) NSLog(@"[iCloud] Opened document");
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                handler(document, document.contents, nil);
                            });
                        } else {
                            NSLog(@"[iCloud] Error while retrieving document: %s", __PRETTY_FUNCTION__);
                            NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while retrieving document, %@, from iCloud", __PRETTY_FUNCTION__, document.fileURL] code:200 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                handler(document, document.contents, error);
                            });
                        }
                    }];
                }
            } else {
                // Log creation
                if (verboseLogging == YES) NSLog(@"[iCloud] The document, %@, does not exist and will be created as an empty document", documentName);
                
                // Create the UIDocument
                iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
                document.contents = [[NSData alloc] init];
                
                // Save the new document to disk
                [document saveToURL:fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
                    // Log save
                    if (verboseLogging == YES) NSLog(@"[iCloud] Saved and opened the document");
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(document, document.contents, nil);
                    });
                }];
            }
        });
    } @catch (NSException *exception) {
        NSLog(@"[iCloud] Caught exception while retrieving file: %@\n\n%s", exception, __PRETTY_FUNCTION__);
    }
}

- (NSNumber *)fileSize:(NSString *)fileName {
    if ([self quickCloudCheck] == NO) return NO;
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:fileName];
    
    // Check if the file exists, and return
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
        unsigned long long fileSize = [[fileManager attributesOfItemAtPath:[fileURL path] error:nil] fileSize];
        NSNumber *bytes = [NSNumber numberWithUnsignedLongLong:fileSize];
        return bytes;
    } else {
        return nil;
    }
}

- (NSDate *)fileModifiedDate:(NSString *)fileName {
    if ([self quickCloudCheck] == NO) return NO;
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:fileName];
    
    // Check if the file exists, and return
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
        NSDate *fileModified = [[fileManager attributesOfItemAtPath:[fileURL path] error:nil] fileModificationDate];
        return fileModified;
    } else {
        return nil;
    }
}

- (NSDate *)fileCreatedDate:(NSString *)fileName {
    if ([self quickCloudCheck] == NO) return NO;
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:fileName];
    
    // Check if the file exists, and return
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
        NSDate *fileModified = [[fileManager attributesOfItemAtPath:[fileURL path] error:nil] fileCreationDate];
        return fileModified;
    } else {
        return nil;
    }
}

- (BOOL)doesFileExistInCloud:(NSString *)fileName {
    if ([self quickCloudCheck] == NO) return NO;
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:fileName];
    
    // Check if the file exists, and return
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
        return YES;
    } else {
        return NO;
    }
    
}

- (UIDocumentState)documentStateForFile:(NSString *)fileName {
    if ([self quickCloudCheck] == NO) return NO;
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:fileName];
    
    // Check if the file exists, and return
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
        // Create the UIDocument
        iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
        UIDocumentState state = document.documentState;
        return state;
    } else {
        return UIDocumentStateClosed;
    }
}

- (NSArray *)getListOfCloudFiles {
    if ([self quickCloudCheck] == NO) return nil;
    
    // Get the directory contents
    NSArray *directoryContent = [fileManager contentsOfDirectoryAtURL:[self ubiquitousDocumentsDirectoryURL] includingPropertiesForKeys:nil options:0 error:nil];
    
    // Return the list of files
    return directoryContent;
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Share --------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Share

- (NSURL *)shareDocumentWithName:(NSString *)name completion:(void (^)(NSURL *sharedURL, NSDate *expirationDate, NSError *error))handler {
    // Log share
    if (verboseLogging == YES) NSLog(@"[iCloud] Attempting to share document");
    
    if ([self quickCloudCheck] == NO) return nil;
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:name];
        
        // Create the Error Object and the Date Object
        NSError *error;
        NSDate *date;
        
        // Create the URL
        NSURL *url = [fileManager URLForPublishingUbiquitousItemAtURL:fileURL expirationDate:&date error:&error];
        
        // Log share
        if (verboseLogging == YES) NSLog(@"[iCloud] Shared iCloud document");
        
        // Pass the data to the handler
        handler(url, date, error);
        
        // Return the URL
        return url;
    } @catch (NSException *exception) {
        NSLog(@"[iCloud] Caught exception while sharing file: %@\n\n%s", exception, __PRETTY_FUNCTION__);
    }
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Delete -------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Delete

- (void)deleteDocumentWithName:(NSString *)name completion:(void (^)(NSError *error))handler {
    // Log delete
    if (verboseLogging == YES) NSLog(@"[iCloud] Attempting to delete document");
    
    if ([self quickCloudCheck] == NO) return;
    
    @try {
        // Create the URL for the file that is being removed
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:name];
        
        if ([fileManager fileExistsAtPath:[fileURL path]]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
                [fileCoordinator coordinateWritingItemAtURL:fileURL options:NSFileCoordinatorWritingForDeleting error:nil byAccessor:^(NSURL *writingURL) {
                    // Create the error handler
                    NSError *error;
                    
                    [fileManager removeItemAtURL:writingURL error:&error];
                    if (error) {
                        // Log failure
                        if (verboseLogging == YES) NSLog(@"[iCloud] An error occured while deleting the document: %@", error);
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            handler(error);
                        });
                        return;
                    } else {
                        // Log success
                        if (verboseLogging == YES) NSLog(@"[iCloud] The document has been deleted");
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            handler(nil);
                        });
                        return;
                    }
                    
                }];
            });
        } else {
            // The document could not be found
            NSLog(@"[iCloud] File not found: %@", name);
            NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, does not exist at path: %@", name, fileURL] code:404 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
            dispatch_async(dispatch_get_main_queue(), ^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(error);
                });
                return;
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"[iCloud] Caught exception while deleting file: %@\n\n%s", exception, __PRETTY_FUNCTION__);
    }
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Manage -------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Manage

- (void)renameOriginalDocument:(NSString *)name withNewName:(NSString *)newName completion:(void (^)(NSError *error))handler {
    // Log rename
    if (verboseLogging == YES) NSLog(@"[iCloud] Attempting to rename document, %@, to the new name: %@", name, newName);
    
    if ([self quickCloudCheck] == NO) return;
    
    NSLog(@"[iCloud] This method, renameOriginalDocument:withNewName:completion:, is not yet available. It should be available soon.");
}

- (void)duplicateOriginalDocument:(NSString *)name withNewName:(NSString *)newName completion:(void (^)(NSError *error))handler {
    // Log duplication
    if (verboseLogging == YES) NSLog(@"[iCloud] Attempting to duplicate document, %@", name);
    
    if ([self quickCloudCheck] == NO) return;
    
    NSLog(@"[iCloud] This method, duplicateOriginalDocument:withNewName:completion:, is not yet available. It should be available soon.");
}

@end
