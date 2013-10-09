//
//  iCloud.m
//  iCloud Document Sync
//
//  Originally from iCloudPlayground
//
//  Created by iRare Media on 3/23/13.
//
//

#import "iCloud.h"

@interface iCloud () {
    UIBackgroundTaskIdentifier backgroundProcess;
}
- (void)enumerateCloudDocuments;
+ (void)updateFilesWithDelegate:(id<iCloudDelegate>)delegate;
- (void)doNothingAtAll;
- (void)startUpdate;
@end

@implementation iCloud
@synthesize query;
@synthesize previousQueryResults;
@synthesize updateTimer;
@synthesize fileList;
@synthesize delegate;

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Setup --------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Setup

- (id)init {
    // Setup Starter Sync
    self = [super init];
    if (self) {
        // Check iCloud Availability
        [iCloud checkCloudAvailability];
        
        // No Know Docs Yet - Initialize Array
        self.fileList = [NSMutableArray array];
        self.previousQueryResults = [NSMutableArray array];
        
        // Sync and Update Documents List
        [self enumerateCloudDocuments];
        // [iCloud updateFilesWithDelegate:delegate];
        
        // Add a timer that updates out for changes in the file metadata
        updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(doNothingAtAll) userInfo:nil repeats:NO];
    }
    
    return self;
}

+ (NSMetadataQuery *) query {
    static NSMetadataQuery* q = nil;
    if (q == nil) {
        q = [[NSMetadataQuery alloc] init];
    }
    
    return q;
}

+ (NSMutableArray *) fileList {
    static NSMutableArray* f = nil;
    if (f == nil) {
        f = [NSMutableArray array];
    }
    
    return f;
}

+ (NSMutableArray *) previousQueryResults {
    static NSMutableArray* p = nil;
    if (p == nil) {
        p = [NSMutableArray array];
    }
    
    return p;
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Check --------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Check

+ (BOOL)checkCloudAvailability {
    // Check for iCloud Availability by finsing the Ubiquity URl of the app
	NSURL *returnedURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
	if (returnedURL){
		NSLog(@"iCloud is available at the following URL\n%@", returnedURL);
        return YES;
	} else {
#if TARGET_IPHONE_SIMULATOR
        // Simulator
        NSLog(@"iCloud is not available in the iOS Simulator. Please run this app on a device to test iCloud.");
#else
        // Device
		NSLog(@"iCloud is not available. iCloud may be unavailable for a number of reasons:\n• The device has not yet been configured with an iCloud account, or the Documents & Data option is disabled\n• Your app, %@, does not have properly configured entitlements\nGo to http://bit.ly/15ECEWj for more information on setting up iCloud", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]);
#endif
        return NO;
	}
}

- (void)doNothingAtAll {
    // For some strange reason, deleting this method and the line that creates the timer that calls it causes iCloud not to function and the app to crash... If anyone can figure out this mystery, please submit a pull request / issue on Github at https://github.com/iRareMedia/iCloudDocumentSync
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Sync ---------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Sync

- (void)enumerateCloudDocuments {
    // Setup iCloud Metadata Query
	// self.query = [[NSMetadataQuery alloc] init];
	[[iCloud query] setSearchScopes:[NSArray arrayWithObjects:NSMetadataQueryUbiquitousDocumentsScope, nil]];
	[[iCloud query] setPredicate:[NSPredicate predicateWithFormat:[NSString stringWithFormat:@"%%K like '*.*'"], NSMetadataItemFSNameKey]];
    
	// Pull a list of all the documents in the cloud
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startUpdate) name:NSMetadataQueryDidFinishGatheringNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startUpdate) name:NSMetadataQueryDidUpdateNotification object:nil];
    
	[[iCloud query] startQuery];
}

- (void)startUpdate {
    [iCloud updateFilesWithDelegate:delegate];
}

+ (void)updateFilesWithDelegate:(id<iCloudDelegate>)delegate {
    // Create and Update the list of files
    
    // Start Process on Background Thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        // Disable updates to iCloud while we update to avoid errors
        [[iCloud query] disableUpdates];
        
        NSMutableArray *discoveredFiles = [NSMutableArray array];
        
        // The query reports all files found, every time.
        NSArray *queryResults = [[iCloud query] results];
        for (NSMetadataItem *result in queryResults) {
            NSURL *fileURL = [result valueForAttribute:NSMetadataItemURLKey];
            NSNumber *aBool = nil;
            
            // Don't include hidden files
            [fileURL getResourceValue:&aBool forKey:NSURLIsHiddenKey error:nil];
            if (aBool && ![aBool boolValue])
                [discoveredFiles addObject:fileURL];
        }
        
        // Get File Names in from the Query
        NSMutableArray *names = [NSMutableArray array];
        for (NSMetadataItem *item in [iCloud query].results) {
            [names addObject:[item valueForAttribute:NSMetadataItemFSNameKey]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([delegate respondsToSelector:@selector(iCloudFilesDidChange:withNewFileNames:)])
                [delegate iCloudFilesDidChange:discoveredFiles withNewFileNames:names];
        });
        
        // Reenable Updates
        [[iCloud query] enableUpdates];
    });
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Add ----------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Add

+ (void)saveDocumentWithName:(NSString *)name withContent:(NSData *)content completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        // Run process on the background thread
        
        // Get the URL to save the new file to
        NSURL *folderURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
        folderURL = [folderURL URLByAppendingPathComponent:DOCUMENT_DIRECTORY];
        NSURL *fileURL = [folderURL URLByAppendingPathComponent:name];
        
        // Initialize a document with that path
        iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
        document.contents = content;
        
        // If the file exists, close it; otherwise, create it.
        if ([[NSFileManager defaultManager] fileExistsAtPath:[fileURL path]]) {
            // Save and close the document
            [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
                if (success) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(document, document.contents, nil);
                    });
                } else {
                    NSLog(@"%s error while saving", __PRETTY_FUNCTION__);
                    NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while saving the document, %@, to iCloud", __PRETTY_FUNCTION__, document.fileURL] code:110 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(document, document.contents, error);
                    });
                }
            }];
        } else {
            // Save and create the new document, then close it
            [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
                if (success) {
                    // Saving implicitly opens the file. An open document will restore the its (remotely) deleted file representation.
                    [document closeWithCompletionHandler:nil];
                    
                    // Run the completion block and pass the document
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // Run process on the main thread
                        handler(document, document.contents, nil);
                    });
                } else {
                    NSLog(@"%s error while creating the document in iCloud", __PRETTY_FUNCTION__);
                    NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while creating the document, %@, in iCloud", __PRETTY_FUNCTION__, document.fileURL] code:100 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(document, document.contents, error);
                    });
                }
            }];
        }
    });
}

+ (void)uploadLocalOfflineDocumentsWithDelegate:(id<iCloudDelegate>)delegate repeatingHandler:(void (^)(NSString *fileName, NSError *error))repeatingHandler completion:(void (^)(void))completion {
    // Perform tasks on background thread to avoid problems on the main / UI thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        // Get the array of files in the documents directory
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSArray *localDocuments = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
        
        NSLog(@"Local Files: %@", localDocuments);
        
        // Compare the arrays then upload documents not already existent in iCloud
        for (int item = 0; item < [localDocuments count]; item++) {
            NSLog(@"Items: %i", item);
            
            // Check to make sure the documents aren't hidden
            if (![[localDocuments objectAtIndex:item] hasPrefix:@"."]) {
                // If the file does not exist in iCloud, upload it
                if (![[iCloud previousQueryResults] containsObject:[localDocuments objectAtIndex:item]]) {
                    NSLog(@"Uploading %@ to iCloud...", [localDocuments objectAtIndex:item]);
                    // Move the file to iCloud
                    NSURL *destinationURL = [[[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil] URLByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@",[localDocuments objectAtIndex:item]]];
                    NSError *error;
                    NSURL *directoryURL = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:[localDocuments objectAtIndex:item]]];
                    BOOL success = [[NSFileManager defaultManager] setUbiquitous:YES itemAtURL:directoryURL destinationURL:destinationURL error:&error];
                    if (success == NO) {
                        NSLog(@"Error while uploading document from local directory: %@",error);
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
                    
                    // Get the file URL for the iCloud document
                    NSURL *folderURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
                    NSURL *cloudFileURL = [[folderURL URLByAppendingPathComponent:DOCUMENT_DIRECTORY] URLByAppendingPathComponent:[localDocuments objectAtIndex:item]];
                    NSURL *localFileURL = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:[localDocuments objectAtIndex:item]]];
                    
                    // Create the UIDocument object from the URL
                    iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:cloudFileURL];
                    NSDate *cloudModDate = document.fileModificationDate;
                    
                    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[localFileURL absoluteString] error:nil];
                    NSDate *localModDate = [fileAttributes fileModificationDate];
                    NSData *localFileData = [[NSFileManager defaultManager] contentsAtPath:[localFileURL absoluteString]];
                    
                    if ([cloudModDate compare:localModDate] == NSOrderedDescending) {
                        NSLog(@"The iCloud file was modified more recently than the local file. The local file will be deleted and the iCloud file will be preserved.");
                        NSError *error;
                        if (![[NSFileManager defaultManager] removeItemAtPath:[localFileURL absoluteString] error:&error]) {
                            NSLog(@"Error deleting %@.\n\n%@", [localFileURL absoluteString], error);
                        }
                    } else if ([cloudModDate compare:localModDate] == NSOrderedAscending) {
                        NSLog(@"The local file was modified more recently than the iCloud file. The iCloud file will be overwritten with the contents of the local file.");
                        // Set the document's new content
                        document.contents = localFileData;
                        // Save and close the document in iCloud
                        [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
                            if (success) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    repeatingHandler([localDocuments objectAtIndex:item], nil);
                                });
                            } else {
                                NSLog(@"%s error while overwriting old iCloud file", __PRETTY_FUNCTION__);
                                NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while saving the document, %@, to iCloud", __PRETTY_FUNCTION__, document.fileURL] code:110 userInfo:[NSDictionary dictionaryWithObject:[localDocuments objectAtIndex:item] forKey:@"FileName"]];
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    repeatingHandler([localDocuments objectAtIndex:item], error);
                                });
                            }
                        }];
                    } else {
                        NSLog(@"The local file and iCloud file have the same modification date. Before overwriting or deleting, iCloud Document Sync will check if both files have the same content.");
                        if ([[NSFileManager defaultManager] contentsEqualAtPath:[cloudFileURL absoluteString] andPath:[localFileURL absoluteString]] == YES) {
                            NSLog (@"The contents of the local file and the contents of the iCloud file match. The local file will be deleted.");
                            NSError *error;
                            if (![[NSFileManager defaultManager] removeItemAtPath:[localFileURL absoluteString] error:&error]) {
                                NSLog(@"Error deleting %@.\n\n%@", [localFileURL absoluteString], error);
                            }
                        } else {
                            NSLog (@"Both the iCloud file and the local file were last modified at the same time, however their contents do not match. You'll need to handle the conflict using the iCloudFileUploadConflictWithCloudFile:andLocalFile: delegate method.");
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
        dispatch_async(dispatch_get_main_queue(), ^{
            completion();
        });
    });
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Read ---------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Read

+ (void)retrieveCloudDocumentWithName:(NSString *)documentName completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        // Get the URL to get the file from
        NSURL *folderURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
        NSURL *fileURL = [[folderURL URLByAppendingPathComponent:DOCUMENT_DIRECTORY] URLByAppendingPathComponent:documentName];
        
        // Create the UIDocument object from the URL
        iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
        
        // If the file exists open it; otherwise, create it
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:[fileURL path]]) {
            [document openWithCompletionHandler:^(BOOL success){
                if (success) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(document, document.contents, nil);
                    });
                } else {
                    NSLog(@"%s error while retrieving document", __PRETTY_FUNCTION__);
                    NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while retrieving document, %@, from iCloud", __PRETTY_FUNCTION__, document.fileURL] code:200 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(document, document.contents, error);
                    });
                }
            }];
        } else {
            // Save the new document to disk
            [document saveToURL:fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(document, document.contents, nil);
                });
            }];
        }
    });
}

+ (BOOL)doesFileExistInCloud:(NSString *)fileName {
    // Get the URL to get the file from
	NSURL *folderURL = [[[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil] URLByAppendingPathComponent:DOCUMENT_DIRECTORY];
	NSURL *fileURL = [folderURL URLByAppendingPathComponent:fileName];
    
    // Check if the file exists, and return
    if ([[NSFileManager defaultManager] fileExistsAtPath:[fileURL path]]) {
        return YES;
    } else {
        return NO;
    }
    
}

+ (NSArray *)getListOfCloudFiles {
    // Create iCloud Documents Directory URL
    NSURL *folderURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
    NSURL *fileURL = [folderURL URLByAppendingPathComponent:DOCUMENT_DIRECTORY];
    
    // Get the directory contents
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:fileURL includingPropertiesForKeys:nil options:0 error:nil];
    
    return directoryContent;
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Delete -------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Delete

+ (void)deleteDocumentWithName:(NSString *)name completion:(void (^)(NSError *error))handler {
    // Create the File Manager
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
	// Create the URL for the file that is being removed
	NSURL *folderURL = [[fileManager URLForUbiquityContainerIdentifier:nil] URLByAppendingPathComponent:DOCUMENT_DIRECTORY];
	NSURL *fileURL = [folderURL URLByAppendingPathComponent:name];
    
    // Start Process on Background Thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Create the UIDocument Object
        __block iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
        
        // Close the document before deleting
        [document closeWithCompletionHandler:^(BOOL success){
            if (success) {
                // Set the Document to NIL
                document = nil;
                
                // Create the Error Handler
                NSError *error;
                
                // Remove the file at the specified URL
                [fileManager removeItemAtURL:fileURL error:&error];
                if (error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(error);
                    });
                    return;
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(nil);
                    });
                    return;
                }
            } else {
                // The document failed to close, return an error
                NSLog(@"%s error while closing document", __PRETTY_FUNCTION__);
                NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while closing document, %@, from iCloud", __PRETTY_FUNCTION__, document.fileURL] code:300 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(error);
                    });
                    return;
                });
            }
        }];
    });
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Deprecated Methods -------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Deprecated Methods

+ (void)deleteDocumentWithName:(NSString *)name withDelegate:(id<iCloudDelegate>)delegate completion:(void (^)(NSError *error))handler {
    NSLog(@"\n\n---------- WARNING ----------\nThe iCloud Document Sync method, [deleteDocumentWithName: withDelegate: completion:], is deprecated. This method no longer does anything - calling it will have no effect and will not delete any documents. Please use the newer, [deleteDocumentWithName: completion:], method instead.\n\n---------- WARNING ----------\n\n");
}

+ (void)saveDocumentWithName:(NSString *)name withContent:(NSData *)content withDelegate:(id<iCloudDelegate>)delegate completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler {
    NSLog(@"\n\n---------- WARNING ----------\nThe iCloud Document Sync method, [saveDocumentWithName: withContent: withDelegate: completion:], is deprecated. This method no longer does anything - calling it will have no effect and will not save any documents. Please use the newer, [saveDocumentWithName: withContent: completion:], method instead.\n\n---------- WARNING ----------\n\n");
}

+ (void)uploadLocalOfflineDocumentsWithDelegate:(id<iCloudDelegate>)delegate completion:(void (^)(NSError *error))handler {
    NSLog(@"\n\n---------- WARNING ----------\nThe iCloud Document Sync method, [uploadLocalOfflineDocumentsWithDelegate: completion:], is deprecated. This method no longer does anything - calling it has no effect and will not upload any documents. Please use the newer, [uploadLocalDocumentsWithHandler: completion:], method instead.\n\n---------- WARNING ----------\n\n");
}

@end
