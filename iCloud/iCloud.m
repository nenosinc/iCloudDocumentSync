//
//  iCloud.m
//  iCloud Document Sync
//
//  Created by iRare Media. Last updated November 2013.
//  Available on GitHub. Licensed under MIT with Attribution.
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
	
	NSLog(@"cloud init ...");
	
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
        NSLog(@"[iCloud] Initialized");
        
        // Check the iCloud Ubiquity Container
        dispatch_async (dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
			ubiquityContainer = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier: nil];
			if (ubiquityContainer != nil) {
				// We can write to the ubiquity container
				
				dispatch_async (dispatch_get_main_queue (), ^(void) {
					// On the main thread, update UI and state as appropriate
					
					// Check iCloud Availability
					id cloudToken = [fileManager ubiquityIdentityToken];
					
					// Sync and Update Documents List
					[self enumerateCloudDocuments];
					
					// Subscribe to changes in iCloud availability (should run on main thread)
					[notificationCenter addObserver:self selector:@selector(checkCloudAvailability) name:NSUbiquityIdentityDidChangeNotification object:nil];
					
					if ([delegate respondsToSelector:@selector(iCloudDidFinishInitializingWitUbiquityToken: withUbiquityContainer:)])
						[delegate iCloudDidFinishInitializingWitUbiquityToken:cloudToken withUbiquityContainer:ubiquityContainer];
				});
			}
		});
		
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
            NSLog(@"iCloud is not available. iCloud may be unavailable for a number of reasons:\n• The device has not yet been configured with an iCloud account, or the Documents & Data option is disabled\n• Your app, %@, does not have properly configured entitlements\nGo to http://bit.ly/18HkxPp for more information on setting up iCloud", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]);
        else
            NSLog(@"iCloud unavailable");
        
        if ([delegate respondsToSelector:@selector(iCloudAvailabilityDidChangeToState:withUbiquityToken:withUbiquityContainer:)])
            [delegate iCloudAvailabilityDidChangeToState:NO withUbiquityToken:nil withUbiquityContainer:ubiquityContainer];
        
        return NO;
    }
}

- (BOOL)checkCloudUbiquityContainer {
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
    return ubiquityContainer;
}

- (NSURL *)ubiquitousDocumentsDirectoryURL {
	// Use the instance variable here - no need to start the retrieval process again
    NSURL *documentsDirectory = [ubiquityContainer URLByAppendingPathComponent:DOCUMENT_DIRECTORY];
    NSError *error;
    
    BOOL isDirectory = NO;
    BOOL isFile = [fileManager fileExistsAtPath:[documentsDirectory path] isDirectory:&isDirectory];
    
    if (isFile) {
        // It exists, check if it's a directory
        if (isDirectory == YES) {
            return documentsDirectory;
        } else {
            [fileManager removeItemAtPath:[documentsDirectory path] error:&error];
            [fileManager createDirectoryAtURL:documentsDirectory withIntermediateDirectories:YES attributes:nil error:&error];
            return documentsDirectory;
        }
    } else {
        [fileManager createDirectoryAtURL:documentsDirectory withIntermediateDirectories:YES attributes:nil error:&error];
        return documentsDirectory;
    }
    
    if (error) NSLog(@"[iCloud] POSSIBLY FATAL ERROR - Document directory creation error. This error may be fatal and should be recovered from. If the documents directory is not correctly created, this can cause iCloud to stop functioning properly (including exceptiosn being thrown). Error: %@", error);
    
    NSLog(@"Documents URL: %@", documentsDirectory);
    return documentsDirectory;
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Sync ---------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Sync

- (void)enumerateCloudDocuments {
    // Log document enumeration
    NSLog(@"[iCloud] Creating metadata query and notifications");
    
    // Request information from the delegate
    if ([delegate respondsToSelector:@selector(iCloudQueryLimitedToFileExtension)]) {
        NSString *fileExt = [delegate iCloudQueryLimitedToFileExtension];
        if (fileExt != nil || ![fileExt isEqualToString:@""]) fileExtension = fileExt;
        else fileExtension = @"*";
        
        // Log file extensiom
        NSLog(@"[iCloud] Document query filter has been set to %@", fileExtension);
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
    if (!startedQuery) {
        NSLog(@"[iCloud] Failed to start query.");
        return;
    } else {
        // Log file query success
        NSLog(@"[iCloud] Query initialized successfully");
    }
}

- (void)startUpdate:(NSMetadataQuery *)query {
    [self updateFiles];
}

- (void)updateFiles {
    // Log file update
    if (verboseLogging == YES) NSLog(@"[iCloud] Beginning file update with NSMetadataQuery");
    
    // Check for iCloud
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

- (void)saveAndCloseDocumentWithName:(NSString *)documentName withContent:(NSData *)content completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler {
    // Log save
    if (verboseLogging == YES) NSLog(@"[iCloud] Beginning document save");
    
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
    
    // Get the URL to save the new file to
    NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    
    // Initialize a document with that path
    iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
    document.contents = content;
    [document updateChangeCount:UIDocumentChangeDone];
    
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
		// The document did not exist and is being saved for the first time.
		
        if (verboseLogging == YES) NSLog(@"[iCloud] Document exists; overwriting, saving and closing");
        // Save and create the new document, then close it
        [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
            if (success) {
				// Save and close the document
				[document closeWithCompletionHandler:^(BOOL success) {
					if (success) {
						// Log
						if (verboseLogging == YES) NSLog(@"[iCloud] Written, saved and closed document");
						
						handler(document, document.contents, nil);
					} else {
						NSLog(@"[iCloud] Error while saving document: %s", __PRETTY_FUNCTION__);
						NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while saving the document, %@, to iCloud", __PRETTY_FUNCTION__, document.fileURL] code:110 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
						
						handler(document, document.contents, error);
					}
				}];
				
			} else {
                NSLog(@"[iCloud] Error while writing to the document: %s", __PRETTY_FUNCTION__);
                NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while writing to the document, %@, in iCloud", __PRETTY_FUNCTION__, document.fileURL] code:100 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
                
                handler(document, document.contents, error);
            }
		}];
    } else {
        if (verboseLogging == YES) NSLog(@"[iCloud] Document is new; creating, saving and then closing");
        
        // The document is being saved by overwriting the current version, then closed.
        [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
            if (success) {
                // Saving implicitly opens the file
                [document closeWithCompletionHandler:^(BOOL success) {
                    if (success) {
                        // Log the save and close
                        if (verboseLogging == YES) NSLog(@"[iCloud] New document created, saved and closed successfully");
                        
                        handler(document, document.contents, nil);
                    } else {
                        NSLog(@"[iCloud] Error while saving and closing document: %s", __PRETTY_FUNCTION__);
                        NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while saving the document, %@, to iCloud", __PRETTY_FUNCTION__, document.fileURL] code:110 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
                        
                        handler(document, document.contents, error);
                    }
                }];
                
                
            } else {
                NSLog(@"[iCloud] Error while creating the document: %s", __PRETTY_FUNCTION__);
                NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while creating the document, %@, in iCloud", __PRETTY_FUNCTION__, document.fileURL] code:100 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
                
                handler(document, document.contents, error);
            }
        }];
    }
}

- (void)uploadLocalOfflineDocumentsWithRepeatingHandler:(void (^)(NSString *documentName, NSError *error))repeatingHandler completion:(void (^)(void))completion {
    // Log upload
    if (verboseLogging == YES) NSLog(@"[iCloud] Beginning local file upload to iCloud. This process may take a long time.");
    
    // Check for iCloud
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
                    NSURL *cloudURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:[localDocuments objectAtIndex:item]];
                    NSURL *localURL = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:[localDocuments objectAtIndex:item]]];
                    NSError *error;
                    
                    BOOL success = [fileManager setUbiquitous:YES itemAtURL:localURL destinationURL:cloudURL error:&error];
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
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            // Save and close the document in iCloud
                            [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
                                if (success) {
                                    // Close the document
                                    [document closeWithCompletionHandler:^(BOOL success) {
                                        repeatingHandler([localDocuments objectAtIndex:item], nil);
                                    }];
                                } else {
                                    NSLog(@"[iCloud] Error while overwriting old iCloud file: %s", __PRETTY_FUNCTION__);
                                    NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while saving the document, %@, to iCloud", __PRETTY_FUNCTION__, document.fileURL] code:110 userInfo:[NSDictionary dictionaryWithObject:[localDocuments objectAtIndex:item] forKey:@"FileName"]];
                                    
                                    repeatingHandler([localDocuments objectAtIndex:item], error);
                                }
                            }];
                        });
                    } else {
                        NSLog(@"[iCloud] The local file and iCloud file have the same modification date. Before overwriting or deleting, iCloud Document Sync will check if both files have the same content.");
                        if ([fileManager contentsEqualAtPath:[cloudFileURL absoluteString] andPath:[localFileURL absoluteString]] == YES) {
                            NSLog (@"[iCloud] The contents of the local file and the contents of the iCloud file match. The local file will be deleted.");
                            NSError *error;
                            
                            if (![fileManager removeItemAtPath:[localFileURL absoluteString] error:&error]) {
                                NSLog(@"[iCloud] Error deleting %@.\n\n%@", [localFileURL absoluteString], error);
                            }
                        } else {
                            NSLog(@"[iCloud] Both the iCloud file and the local file were last modified at the same time, however their contents do not match. You'll need to handle the conflict using the iCloudFileConflictBetweenCloudFile:andLocalFile: delegate method.");
                            NSDictionary *cloudFile = [[NSDictionary alloc] initWithObjects:@[document.contents, cloudFileURL, cloudModDate]
                                                                                    forKeys:@[@"fileContents", @"fileURL", @"modifiedDate"]];
                            NSDictionary *localFile = [[NSDictionary alloc] initWithObjects:@[localFileData, localFileURL, localModDate]
                                                                                    forKeys:@[@"fileContents", @"fileURL", @"modifiedDate"]];;
                            
                            if ([delegate respondsToSelector:@selector(iCloudFileUploadConflictWithCloudFile:andLocalFile:)]) {
                                [delegate iCloudFileConflictBetweenCloudFile:cloudFile andLocalFile:localFile];
                            } else if ([delegate respondsToSelector:@selector(iCloudFileUploadConflictWithCloudFile:andLocalFile:)]) {
                                NSLog(@"[iCloud] WARNING: iCloudFileUploadConflictWithCloudFile:andLocalFile is deprecated and will become unavailable in a future version. Use iCloudFileConflictBetweenCloudFile:andLocalFile instead.");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                                [delegate iCloudFileUploadConflictWithCloudFile:cloudFile andLocalFile:localFile];
#pragma clang diagnostic pop
                            }
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
            if (completion)
                completion();
        });
    });
}

- (void)uploadLocalDocumentToCloudWithName:(NSString *)documentName completion:(void (^)(NSError *error))handler {
    // Log download
    if (verboseLogging == YES) NSLog(@"[iCloud] Attempting to upload document, %@", documentName);
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        NSError *error = [NSError errorWithDomain:@"The specified document name was empty / blank and could not be saved. Specify a document name next time." code:001 userInfo:nil];
        
        handler(error);
        
        return;
    }
    
    // Perform tasks on background thread to avoid problems on the main / UI thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        // Get the array of files in the documents directory
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *localDocument = [documentsDirectory stringByAppendingPathComponent:documentName];
        
        // If the file does not exist in iCloud, upload it
        if (![previousQueryResults containsObject:localDocument]) {
            // Log
            if (verboseLogging == YES) NSLog(@"[iCloud] Uploading %@ to iCloud", localDocument);
            
            // Move the file to iCloud
            NSURL *cloudURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
            NSURL *localURL = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:localDocument]];
            NSError *error;
            
            BOOL success = [fileManager setUbiquitous:YES itemAtURL:localURL destinationURL:cloudURL error:&error];
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
            if (verboseLogging == YES) NSLog(@"[iCloud] Conflict between local file and remote file, attempting to automatically resolve");
            
            // Get the file URL for the documents
            NSURL *cloudURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
            NSURL *localURL = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:localDocument]];
            
            // Create the UIDocument object from the URL
            iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:cloudURL];
            NSDate *cloudModDate = document.fileModificationDate;
            
            NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:[localURL absoluteString] error:nil];
            NSDate *localModDate = [fileAttributes fileModificationDate];
            NSData *localFileData = [fileManager contentsAtPath:[localURL absoluteString]];
            
            if ([cloudModDate compare:localModDate] == NSOrderedDescending) {
                NSLog(@"[iCloud] The iCloud file was modified more recently than the local file. The local file will be deleted and the iCloud file will be preserved.");
                NSError *error;
                
                if (![fileManager removeItemAtPath:[localURL absoluteString] error:&error]) {
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
                            [document closeWithCompletionHandler:^(BOOL success) {
                                handler(nil);
                                return;
                            }];
                        } else {
                            NSLog(@"[iCloud] Error while overwriting old iCloud file: %s", __PRETTY_FUNCTION__);
                            NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while saving the document, %@, to iCloud", __PRETTY_FUNCTION__, document.fileURL] code:110 userInfo:[NSDictionary dictionaryWithObject:localDocument forKey:@"FileName"]];
                            
                            handler(error);
                            return;
                        }
                    }];
                });
            } else {
                NSLog(@"[iCloud] The local file and iCloud file have the same modification date. Before overwriting or deleting, iCloud Document Sync will check if both files have the same content.");
                if ([fileManager contentsEqualAtPath:[cloudURL absoluteString] andPath:[localURL absoluteString]] == YES) {
                    NSLog (@"[iCloud] The contents of the local file and the contents of the iCloud file match. The local file will be deleted.");
                    NSError *error;
                    
                    if (![fileManager removeItemAtPath:[localURL absoluteString] error:&error]) {
                        NSLog(@"[iCloud] Error deleting %@.\n\n%@", [localURL absoluteString], error);
                        return;
                    }
                } else {
                    NSLog(@"[iCloud] Both the iCloud file and the local file were last modified at the same time, however their contents do not match. You'll need to handle the conflict using the iCloudFileConflictBetweenCloudFile:andLocalFile: delegate method.");
                    NSDictionary *cloudFile = [[NSDictionary alloc] initWithObjects:@[document.contents, cloudURL, cloudModDate]
                                                                            forKeys:@[@"fileContents", @"fileURL", @"modifiedDate"]];
                    NSDictionary *localFile = [[NSDictionary alloc] initWithObjects:@[localFileData, localURL, localModDate]
                                                                            forKeys:@[@"fileContents", @"fileURL", @"modifiedDate"]];;
                    
                    if ([delegate respondsToSelector:@selector(iCloudFileUploadConflictWithCloudFile:andLocalFile:)]) {
                        [delegate iCloudFileConflictBetweenCloudFile:cloudFile andLocalFile:localFile];
                    } else if ([delegate respondsToSelector:@selector(iCloudFileUploadConflictWithCloudFile:andLocalFile:)]) {
                        NSLog(@"[iCloud] WARNING: iCloudFileUploadConflictWithCloudFile:andLocalFile is deprecated and will become unavailable in a future version. Use iCloudFileConflictBetweenCloudFile:andLocalFile instead.");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                        [delegate iCloudFileUploadConflictWithCloudFile:cloudFile andLocalFile:localFile];
#pragma clang diagnostic pop
                    }
                    
                    return;
                }
            }
        }
        
        // Log completion
        if (verboseLogging == YES) NSLog(@"[iCloud] Finished uploading local file to iCloud");
        
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
    if (verboseLogging == YES) NSLog(@"[iCloud] Retrieving iCloud document, %@", documentName);
    
    // Check for iCloud availability
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        NSError *error = [NSError errorWithDomain:@"The specified document name was empty / blank and could not be saved. Specify a document name next time." code:001 userInfo:nil];
        
        handler(nil, nil, error);
        
        return;
    }
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        // If the file exists open it; otherwise, create it
        if ([fileManager fileExistsAtPath:[fileURL path]]) {
            // Log opening
            if (verboseLogging == YES) NSLog(@"[iCloud] The document, %@, already exists and will be opened", documentName);
            
            // Create the UIDocument object from the URL
            iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
            
            if (document.documentState & UIDocumentStateClosed) {
                if (verboseLogging == YES) NSLog(@"[iCloud] Document is closed and will be opened");
                
                [document openWithCompletionHandler:^(BOOL success){
                    if (success) {
                        // Log open
                        if (verboseLogging == YES) NSLog(@"[iCloud] Opened document");
                        
                        // Pass data on to the completion handler on the main thread
                        dispatch_async(dispatch_get_main_queue(), ^{
                            handler(document, document.contents, nil);
                        });
                        
                        return;
                    } else {
                        NSLog(@"[iCloud] Error while retrieving document: %s", __PRETTY_FUNCTION__);
                        NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while retrieving document, %@, from iCloud", __PRETTY_FUNCTION__, document.fileURL] code:200 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
                        
                        // Pass data on to the completion handler on the main thread
                        dispatch_async(dispatch_get_main_queue(), ^{
                            handler(document, document.contents, error);
                        });
                        
                        return;
                    }
                }];
            } else if (document.documentState & UIDocumentStateNormal) {
                // Log open
                if (verboseLogging == YES) NSLog(@"[iCloud] Document already opened, retrieving content");
                
                // Pass data on to the completion handler on the main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(document, document.contents, nil);
                });
                
                return;
            } else if (document.documentState & UIDocumentStateInConflict) {
                // Log open
                if (verboseLogging == YES) NSLog(@"[iCloud] Document in conflict. The document may not contain correct data. An error will be returned along with the other parameters in the completion handler.");
                
                // Create Error
                NSLog(@"[iCloud] Error while retrieving document, %@, because the document is in conflict", documentName);
                NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The iCloud document, %@, is in conflict. Please resolve this conflict before editing the document.", documentName] code:200 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
                
                // Pass data on to the completion handler on the main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(document, document.contents, error);
                });
                
                return;
            } else if (document.documentState & UIDocumentStateEditingDisabled) {
                // Log open
                if (verboseLogging == YES) NSLog(@"[iCloud] Document editing disabled. The document is not currently editable, use the documentStateForFile: method to determine when the document is available again. The document and its contents will still be passed as parameters in the completion handler.");
                
                // Pass data on to the completion handler on the main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(document, document.contents, nil);
                });
                
                return;
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
    } @catch (NSException *exception) {
        NSLog(@"[iCloud] Caught exception while retrieving document: %@\n\n%s", exception, __PRETTY_FUNCTION__);
    }
}

- (iCloudDocument *)retrieveCloudDocumentObjectWithName:(NSString *)documentName {
    // Log Retrieval
    if (verboseLogging == YES) NSLog(@"[iCloud] Retrieving iCloudDocument object with name: %@", documentName);
    
    // Check for iCloud availability
    if ([self quickCloudCheck] == NO) return nil;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return nil;
    }
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        // Create the iCloudDocument
        iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
        
        if ([fileManager fileExistsAtPath:[fileURL path]]) {
            if (verboseLogging == YES) NSLog(@"[iCloud] The document, %@, exists and will be returned as an iCloudDocument object", documentName);
        } else {
            if (verboseLogging == YES) NSLog(@"[iCloud] The document, %@, does not exist but will be returned as an empty iCloudDocument object", documentName);
        }
        
        // Return the iCloudDocument object
        return document;
        
    } @catch (NSException *exception) {
        NSLog(@"[iCloud] Caught exception while retrieving document: %@\n\n%s", exception, __PRETTY_FUNCTION__);
    }
}

- (NSNumber *)fileSize:(NSString *)documentName {
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return nil;
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    
    // Check if the file exists, and return
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
        unsigned long long fileSize = [[fileManager attributesOfItemAtPath:[fileURL path] error:nil] fileSize];
        NSNumber *bytes = [NSNumber numberWithUnsignedLongLong:fileSize];
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
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
        NSDate *fileModified = [[fileManager attributesOfItemAtPath:[fileURL path] error:nil] fileModificationDate];
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
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
        NSDate *fileModified = [[fileManager attributesOfItemAtPath:[fileURL path] error:nil] fileCreationDate];
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
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
        return YES;
    } else {
        return NO;
    }
    
}

- (NSArray *)getListOfCloudFiles {
    // Log retrieval
    if (verboseLogging == YES) NSLog(@"[iCloud] Getting list of iCloud documents");
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return nil;
    
    // Get the directory contents
    NSArray *directoryContent = [fileManager contentsOfDirectoryAtURL:[self ubiquitousDocumentsDirectoryURL] includingPropertiesForKeys:nil options:0 error:nil];
    
    // Log retrieval
    if (verboseLogging == YES) NSLog(@"[iCloud] Retrieved list of iCloud documents");
    
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
        if (verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        NSError *error = [NSError errorWithDomain:@"The specified document name was empty / blank and could not be saved. Specify a document name next time." code:001 userInfo:nil];
        
        handler(nil, nil, error);
        
        return;
    }
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    
    // Check if the file exists, and return
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
        // Create the UIDocument
        iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
        UIDocumentState state = document.documentState;
        NSString *userStateDescription = document.stateDescription;
        handler(&state, userStateDescription, nil);
    } else {
        // The document could not be found
        NSLog(@"[iCloud] File not found: %@", documentName);
        NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, does not exist at path: %@", documentName, fileURL] code:404 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
        handler(nil, @"No document available", error);
        return;
    }
}

- (BOOL)monitorDocumentStateForFile:(NSString *)documentName onTarget:(id)sender withSelector:(SEL)selector {
    // Log monitoring
    if (verboseLogging == YES) NSLog(@"[iCloud] Preparing to monitor for changes to %@", documentName);
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return NO;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return NO;
    }
    
    // Log monitoring
    if (verboseLogging == YES) NSLog(@"[iCloud] Checking for existance of %@", documentName);
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        
        // Check if the file exists, and return
        if ([fileManager fileExistsAtPath:[fileURL path]]) {
            // Create the UIDocument
            iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
            [notificationCenter addObserver:sender selector:selector name:UIDocumentStateChangedNotification object:document];
            
            // Log monitoring
            if (verboseLogging == YES) NSLog(@"[iCloud] Now successfully monitoring for changes to %@ on %@", documentName, sender);
            
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
    if (verboseLogging == YES) NSLog(@"[iCloud] Preparing to stop monitoring document changes to %@", documentName);
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return NO;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return NO;
    }
    
    // Log monitoring
    if (verboseLogging == YES) NSLog(@"[iCloud] Checking for existance of %@", documentName);
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        
        // Check if the file exists, and return
        if ([fileManager fileExistsAtPath:[fileURL path]]) {
            // Create the UIDocument
            iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
            
            [notificationCenter removeObserver:sender name:UIDocumentStateChangedNotification object:document];
            
            // Log monitoring
            if (verboseLogging == YES) NSLog(@"[iCloud] Stopped monitoring document state changes to %@", documentName);
            
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
    if (verboseLogging == YES) NSLog(@"[iCloud] Preparing to find all version conflicts for %@", documentName);
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return nil;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return nil;
    }
    
    // Log conflict search
    if (verboseLogging == YES) NSLog(@"[iCloud] Checking for existance of %@", documentName);
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        
        // Check if the file exists, and return
        if ([fileManager fileExistsAtPath:[fileURL path]]) {
            // Log conflict search
            if (verboseLogging == YES) NSLog(@"[iCloud] %@ exists at the correct path, proceeding to find the conflicts", documentName);
        
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
    if (verboseLogging == YES) NSLog(@"[iCloud] Preparing to resolve version conflict for %@", documentName);
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return;
    }
    
    // Log resolution
    if (verboseLogging == YES) NSLog(@"[iCloud] Checking for existance of %@", documentName);
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        
        // Check if the file exists, and return
        if ([fileManager fileExistsAtPath:[fileURL path]]) {
            // Log resolution
            if (verboseLogging == YES) NSLog(@"[iCloud] %@ exists at the correct path, proceeding to resolve the conflict", documentName);
            
            // Make the current version "win" the conflict if it is selected
            if (![documentVersion isEqual:[NSFileVersion currentVersionOfItemAtURL:fileURL]]) {
                // Log resolution
                if (verboseLogging == YES) NSLog(@"[iCloud] The current version (%@) of %@ matches the selected version. Resolving conflict...", documentVersion, documentName);
                
                [documentVersion replaceItemAtURL:fileURL options:0 error:nil];
            }
            
            // Remove other versions of the document
            [NSFileVersion removeOtherVersionsOfItemAtURL:fileURL error:nil];
            
            // Log resolution
            if (verboseLogging == YES) NSLog(@"[iCloud] Removing all unresolved other versions of %@", documentName);
            
            NSArray *conflictVersions = [NSFileVersion unresolvedConflictVersionsOfItemAtURL:fileURL];
            for (NSFileVersion *fileVersion in conflictVersions) {
                fileVersion.resolved = YES;
            }
            
            // Log resolution
            if (verboseLogging == YES) NSLog(@"[iCloud] Finished resolving conflicts for %@", documentName);
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
    if (verboseLogging == YES) NSLog(@"[iCloud] Attempting to share document");
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return nil;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return nil;
    }
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        // Check that the file exists
        if ([fileManager fileExistsAtPath:[fileURL path]]) {
            // Log share
            if (verboseLogging == YES) NSLog(@"[iCloud] File exists, preparing to share it");
            
            // Create the URL to be returned outside of the block
            __block NSURL *url;
            
            // Move to the background thread for safety
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                // Create the Error Object and the Date Object
                NSError *error;
                NSDate *date;
                
                // Create the URL
                url = [fileManager URLForPublishingUbiquitousItemAtURL:fileURL expirationDate:&date error:&error];
                
                // Log share
                if (verboseLogging == YES) NSLog(@"[iCloud] Shared iCloud document");
                
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
            NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, does not exist at path: %@", documentName, fileURL] code:404 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(nil, nil, error);
                return;
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"[iCloud] Caught exception while sharing file: %@\n\n%s", exception, __PRETTY_FUNCTION__);
    }
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Delete -------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Delete

- (void)deleteDocumentWithName:(NSString *)documentName completion:(void (^)(NSError *error))handler {
    // Log delete
    if (verboseLogging == YES) NSLog(@"[iCloud] Attempting to delete document");
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return;
    }
    
    @try {
        // Create the URL for the file that is being removed
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        // Check that the file exists
        if ([fileManager fileExistsAtPath:[fileURL path]]) {
            // Log share
            if (verboseLogging == YES) NSLog(@"[iCloud] File exists, attempting to delete it");
            
            // Move to the background thread for safety
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                
                // Use a file coordinator to safely delete the file
                NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
                [fileCoordinator coordinateWritingItemAtURL:fileURL options:NSFileCoordinatorWritingForDeleting error:nil byAccessor:^(NSURL *writingURL) {
                    // Create the error handler
                    NSError *error;
                    
                    [fileManager removeItemAtURL:writingURL error:&error];
                    if (error) {
                        // Log failure
                        NSLog(@"[iCloud] An error occurred while deleting the document: %@", error);
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (handler)
                                handler(error);
                        });
                        
                        return;
                    } else {
                        // Log success
                        if (verboseLogging == YES) NSLog(@"[iCloud] The document has been deleted");
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self updateFiles];
                            if (handler)
                                handler(nil);
                        });
                        
                        return;
                    }
                    
                }];
            });
        } else {
            // The document could not be found
            NSLog(@"[iCloud] File not found: %@", documentName);
            NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, does not exist at path: %@", documentName, fileURL] code:404 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (handler)
                    handler(error);
                return;
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"[iCloud] Caught exception while deleting file: %@\n\n%s", exception, __PRETTY_FUNCTION__);
    }
}

- (void)evictCloudDocumentWithName:(NSString *)documentName completion:(void (^)(NSError *error))handler {
    // Log download
    if (verboseLogging == YES) NSLog(@"[iCloud] Attempting to evict iCloud document, %@", documentName);
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return;
    }
    
    // Perform tasks on background thread to avoid problems on the main / UI thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        // Get the array of files in the documents directory
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *localDocument = [documentsDirectory stringByAppendingPathComponent:documentName];
        
        // If the file does not exist in iCloud, upload it
        if (![previousQueryResults containsObject:localDocument]) {
            // Log
            if (verboseLogging == YES) NSLog(@"[iCloud] Evicting %@ from iCloud", localDocument);
            
            // Move the file to iCloud
            NSURL *cloudURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
            NSURL *localURL = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:localDocument]];
            NSError *error;
            
            BOOL success = [fileManager setUbiquitous:NO itemAtURL:cloudURL destinationURL:localURL error:&error];
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
            if (verboseLogging == YES) NSLog(@"[iCloud] Conflict between local file and remote file, attempting to automatically resolve");
            
            // Get the file URL for the documents
            NSURL *cloudURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
            NSURL *localURL = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:localDocument]];
            
            // Create the UIDocument object from the URL
            iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:cloudURL];
            NSDate *cloudModDate = document.fileModificationDate;
            
            NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:[localURL absoluteString] error:nil];
            NSDate *localModDate = [fileAttributes fileModificationDate];
            NSData *localFileData = [fileManager contentsAtPath:[localURL absoluteString]];
            
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
                if ([fileManager contentsEqualAtPath:[localURL absoluteString] andPath:[cloudURL absoluteString]] == YES) {
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
                    NSDictionary *cloudFile = [[NSDictionary alloc] initWithObjects:@[document.contents, cloudURL, cloudModDate]
                                                                            forKeys:@[@"fileContents", @"fileURL", @"modifiedDate"]];
                    NSDictionary *localFile = [[NSDictionary alloc] initWithObjects:@[localFileData, localURL, localModDate]
                                                                            forKeys:@[@"fileContents", @"fileURL", @"modifiedDate"]];;
                    
                    if ([delegate respondsToSelector:@selector(iCloudFileUploadConflictWithCloudFile:andLocalFile:)]) {
                        [delegate iCloudFileConflictBetweenCloudFile:cloudFile andLocalFile:localFile];
                    } else if ([delegate respondsToSelector:@selector(iCloudFileUploadConflictWithCloudFile:andLocalFile:)]) {
                        NSLog(@"[iCloud] WARNING: iCloudFileUploadConflictWithCloudFile:andLocalFile is deprecated and will become unavailable in a future version. Use iCloudFileConflictBetweenCloudFile:andLocalFile instead.");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                        [delegate iCloudFileUploadConflictWithCloudFile:cloudFile andLocalFile:localFile];
#pragma clang diagnostic pop
                    }
                    
                    return;
                }
            }
        }
        
        // Log completion
        if (verboseLogging == YES) NSLog(@"[iCloud] Finished evicting iCloud document. Successfully moved to local storage.");
        
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
    if (verboseLogging == YES) NSLog(@"[iCloud] Attempting to rename document, %@, to the new name: %@", documentName, newName);
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""] || newName == nil || [newName isEqualToString:@""]) {
        // Log error
        if (verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return;
    }
    
    // Create the URLs for the files that are being renamed
    NSURL *sourceFileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    NSURL *newFileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:newName];
    
    // Check if file exists at source URL
    if (![fileManager fileExistsAtPath:[sourceFileURL path]]) {
        NSLog(@"[iCloud] File does not exist at path: %@", sourceFileURL);
        NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, does not exist at path: %@", documentName, sourceFileURL] code:404 userInfo:[NSDictionary dictionaryWithObject:sourceFileURL forKey:@"FileURL"]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (handler)
                handler(error);
        });
        
        return;
    }
    
    // Check if file does not exist at new URL
    if ([fileManager fileExistsAtPath:[newFileURL path]]) {
        NSLog(@"[iCloud] File already exists at path: %@", newFileURL);
        NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, already exists at path: %@", newName, newFileURL] code:512 userInfo:[NSDictionary dictionaryWithObject:newFileURL forKey:@"FileURL"]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (handler)
                handler(error);
        });
        
        return;
    }
    
    // Log success of existence
    if (verboseLogging == YES) NSLog(@"[iCloud] Files passed existence check, preparing to rename");
    
    // Move to the background thread for safety
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        // Coordinate renaming safely with a file coordinator
        NSError *coordinatorError = nil;
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        [coordinator coordinateWritingItemAtURL:sourceFileURL options:NSFileCoordinatorWritingForMoving writingItemAtURL:newFileURL options:NSFileCoordinatorWritingForReplacing error:&coordinatorError byAccessor:^(NSURL *newURL1, NSURL *newURL2) {
            NSError *moveError;
            BOOL moveSuccess;
            
            // Log rename
            if (verboseLogging == YES) NSLog(@"[iCloud] Renaming Files");
            
            // Do the actual renaming
            moveSuccess = [fileManager moveItemAtURL:sourceFileURL toURL:newFileURL error:&moveError];
            
            if (moveSuccess) {
                // Log success
                if (verboseLogging == YES) NSLog(@"[iCloud] Renamed Files");
                
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
    if (verboseLogging == YES) NSLog(@"[iCloud] Attempting to duplicate document, %@", documentName);
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""] || newName == nil || [newName isEqualToString:@""]) {
        // Log error
        if (verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return;
    }
    
    // Create the URLs for the files that are being renamed
    NSURL *sourceFileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    NSURL *newFileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:newName];
    
    // Check if file exists at source URL
    if (![fileManager fileExistsAtPath:[sourceFileURL path]]) {
        NSLog(@"[iCloud] File does not exist at path: %@", sourceFileURL);
        NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, does not exist at path: %@", documentName, sourceFileURL] code:404 userInfo:[NSDictionary dictionaryWithObject:sourceFileURL forKey:@"FileURL"]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (handler)
                handler(error);
        });
        
        return;
    }
    
    // Check if file does not exist at new URL
    if ([fileManager fileExistsAtPath:[newFileURL path]]) {
        NSLog(@"[iCloud] File already exists at path: %@", newFileURL);
        NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, already exists at path: %@", newName, newFileURL] code:512 userInfo:[NSDictionary dictionaryWithObject:newFileURL forKey:@"FileURL"]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (handler)
                handler(error);
        });
        
        return;
    }
    
    // Log success of existence
    if (verboseLogging == YES) NSLog(@"[iCloud] Files passed existence check, preparing to duplicate");
    
    // Move to the background thread for safety
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSError *moveError;
        BOOL moveSuccess;
        
        // Log duplication
        if (verboseLogging == YES) NSLog(@"[iCloud] Duplicating Files");
        
        // Do the actual duplicating
        moveSuccess = [fileManager copyItemAtURL:sourceFileURL toURL:newFileURL error:&moveError];
        
        if (moveSuccess) {
            // Log success
            if (verboseLogging == YES) NSLog(@"[iCloud] Duplicated Files");
            
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
    for (int i = 0; i <= 5; i++) NSLog(@"[iCloud] WARNING: uploadLocalOfflineDocumentsWithDelegate: is deprecated and will become unavailable in a future version. Use [- uploadLocalOfflineDocuments] instead.");
}

+ (void)updateFilesWithDelegate:(id<iCloudDelegate>)delegate {
    for (int i = 0; i <= 5; i++) NSLog(@"[iCloud] WARNING: updateFilesWithDelegate: is deprecated and will become unavailable in a future version. Use [- updateFiles] instead.");
}

- (void)saveChangesToDocumentWithName:(NSString *)documentName withContent:(NSData *)content completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler {
    // This method is deprecated: Due to the fact, that the document is recreated in closed state on every call, it is just a copy of the saveAndCloseDocumentWithName-method above
    for (int i = 0; i <= 5; i++) NSLog(@"[iCloud] WARNING: saveChangesToDocumentWithName:withContent:completion: is deprecated and will become unavailable in a future version. Use [- saveAndCloseDocumentWithName:withContent:completion:] instead.");
    
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
