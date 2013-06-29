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

@interface iCloud ()
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
//- Setup -------------------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Setup

- (id)init {
    //Setup Starter Sync
    self = [super init];
    if (self) {
        //Check iCloud Availability
        [iCloud checkCloudAvailability];
        
        //No Know Docs Yet - Initialize Array
        self.fileList = [NSMutableArray array];
        self.previousQueryResults = [NSMutableArray array];
        
        //Sync and Update Documents List
        [self enumerateCloudDocuments];
        //[iCloud updateFilesWithDelegate:delegate];
        
        //Add a timer that updates out for changes in the file metadata
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
//- Check -------------------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Check

+ (BOOL)checkCloudAvailability {
    //Check for iCloud Availability by finsing the Ubiquity URl of the app
	NSURL *returnedURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
	if (returnedURL){
		NSLog(@"iCloud is available at the following URL\n%@", returnedURL);
        return YES;
	} else {
#if TARGET_IPHONE_SIMULATOR
        //Simulator
        NSLog(@"iCloud is not available in the iOS Simulator. Please run this app on a device to test iCloud.");
#else
        //Device
		NSLog(@"iCloud is not available. iCloud may be unavailable for a number of reasons:\n• The device has not yet been configured with an iCloud account, or the Documents & Data option is disabled\n• Your app, %@, does not have properly configured entitlements\nGo to http://bit.ly/15ECEWj for more information on setting up iCloud", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]);
#endif
        return NO;
	}
}

- (void)doNothingAtAll {
    //For some strange reason, deleting this method and the line that creates the timer that calls it causes iCloud not to function and the app to crash... If anyone can figure out this mystery, please submit a pull request / issue on Github at https://github.com/iRareMedia/iCloudDocumentSync
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//- Sync --------------------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Sync

- (void)enumerateCloudDocuments {
    //Setup iCloud Metadata Query
	//self.query = [[NSMetadataQuery alloc] init];
	[[iCloud query] setSearchScopes:[NSArray arrayWithObjects:NSMetadataQueryUbiquitousDocumentsScope, nil]];
	[[iCloud query] setPredicate:[NSPredicate predicateWithFormat:[NSString stringWithFormat:@"%%K like '*.*'"], NSMetadataItemFSNameKey]];
    
	//Pull a list of all the documents in the cloud
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startUpdate) name:NSMetadataQueryDidFinishGatheringNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startUpdate) name:NSMetadataQueryDidUpdateNotification object:nil];
    
	[[iCloud query] startQuery];
}

- (void)startUpdate {
    [iCloud updateFilesWithDelegate:delegate];
}

+ (void)updateFilesWithDelegate:(id<iCloudDelegate>)delegate {
    //Create and Update the list of files
    
    //Start Process on Background Thread
    dispatch_queue_t iCloudFiles = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(iCloudFiles, ^{
        
        //Disable updates to iCloud while we update to avoid errors
        [[iCloud query] disableUpdates];
        
        NSMutableArray *discoveredFiles = [NSMutableArray array];
        
        // The query reports all files found, every time.
        NSArray *queryResults = [[iCloud query] results];
        for (NSMetadataItem *result in queryResults) {
            NSURL *fileURL = [result valueForAttribute:NSMetadataItemURLKey];
            NSNumber *aBool = nil;
            
            // Don't include hidden files.
            [fileURL getResourceValue:&aBool forKey:NSURLIsHiddenKey error:nil];
            if (aBool && ![aBool boolValue])
                [discoveredFiles addObject:fileURL];
        }
        
        //Get File Names in from the Query
        NSMutableArray *names = [NSMutableArray array];
        for (NSMetadataItem *item in [iCloud query].results) {
            [names addObject:[item valueForAttribute:NSMetadataItemFSNameKey]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate iCloudFilesDidChange:discoveredFiles withNewFileNames:names];
        });
        
        //Reenable Updates
        [[iCloud query] enableUpdates];
    });
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//- Add ---------------------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Add

+ (void)saveDocumentWithName:(NSString *)name withContent:(NSData *)content withDelegate:(id<iCloudDelegate>)delegate completion:(void (^)(UIDocument *cloudDocument, NSData *documentData))handler {
	//Get the URL to save the new file to
	NSURL *folderURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
	folderURL = [folderURL URLByAppendingPathComponent:@"Documents"];
	NSURL *fileURL = [folderURL URLByAppendingPathComponent:name];
    
    //Initialize a document with that path
	iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
    document.contents = content;
    
    //If the file exists, close it; otherwise, create it.
    if ([[NSFileManager defaultManager] fileExistsAtPath:[fileURL path]]) {
        //Save and close the document
        [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
            if (success) {
                handler(document, document.contents);
            } else {
                NSLog(@"%s error while saving", __PRETTY_FUNCTION__);
                NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while saving document", __PRETTY_FUNCTION__] code:110 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
                [delegate iCloudError:error];
            }
        }];
    } else {
        //Save and create the new document, then close it
        [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
            if (success) {
                //Saving implicitly opens the file. An open document will restore the its (remotely) deleted file representation.
                [document closeWithCompletionHandler:nil];
                
                //Run the completion block and pass the document
                handler(document, document.contents);
            } else {
                NSLog(@"%s error while saving", __PRETTY_FUNCTION__);
                NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while creating document", __PRETTY_FUNCTION__] code:100 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
                [delegate iCloudError:error];
            }
        }];
    }
}

+ (void)uploadLocalOfflineDocumentsWithDelegate:(id<iCloudDelegate>)delegate completion:(void (^)(void))completionBlock {
    //Perform tasks on background thread to avoid problems on the main / UI thread
	dispatch_queue_t upload = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(upload, ^{
        //Get the array of files in the documents directory
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSArray *localDocuments = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
        
        NSLog(@"Local Files: %@", localDocuments);
        
        //Compare the arrays then upload documents not already existent in iCloud
        for (int item = 0; item < [localDocuments count]; item++) {
            NSLog(@"Items: %i", item);
            if (![[localDocuments objectAtIndex:item] hasPrefix:@"."] || ![[localDocuments objectAtIndex:item] hasSuffix:@".sqlite"]) {
                //If the file does not exist in iCloud, upload it
                if (![[iCloud previousQueryResults] containsObject:[localDocuments objectAtIndex:item]]) {
                    NSLog(@"Uploading %@ to iCloud...", [localDocuments objectAtIndex:item]);
                    //Move the file to iCloud
                    NSURL *destinationURL = [[[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil] URLByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@",[localDocuments objectAtIndex:item]]];
                    NSError *error;
                    NSURL *directoryURL = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:[localDocuments objectAtIndex:item]]];
                    BOOL success = [[NSFileManager defaultManager] setUbiquitous:YES itemAtURL:directoryURL destinationURL:destinationURL error:&error];
                    if (success == NO) {
                        // Maybe try to determine cause of error and recover first.
                        NSLog(@"%@",error);
                        [delegate iCloudError:error];
                    }
                    
                } else {
                    //Check if the local document is newer than the cloud document
                }
            } else {
                //Hidden or messy file, do not proceed
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock();
        });
    });
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//- Read --------------------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Read

+ (void)retrieveCloudDocumentWithName:(NSString *)documentName completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler {
    //Get the URL to get the file from
	NSURL *folderURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
	folderURL = [folderURL URLByAppendingPathComponent:@"Documents"];
	NSURL *fileURL = [folderURL URLByAppendingPathComponent:documentName];
    
    //Create the document and assign the delegate.
    iCloudDocument *document = [[iCloudDocument alloc] initWithFileURL:fileURL];
    
    //If the file exists, open it; otherwise, create it.
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:[fileURL path]]) {
        [document openWithCompletionHandler:^(BOOL success){
            if (success) {
                handler(document, document.contents, nil);
            } else {
                NSLog(@"%s error while retrieving document", __PRETTY_FUNCTION__);
                NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while retrieving document", __PRETTY_FUNCTION__] code:200 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
                handler(document, nil, error);
            }
        }];
    } else {
        //Save the new document to disk.
        [document saveToURL:fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success){
            handler(document, document.contents, nil);
        }];
    }
}

+ (BOOL)doesFileExistInCloud:(NSString *)fileName {
    //Get the URL to get the file from
	NSURL *folderURL = [[[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil] URLByAppendingPathComponent:@"Documents"];
	NSURL *fileURL = [folderURL URLByAppendingPathComponent:fileName];
    
    //Check if the file exists, and return
    if ([[NSFileManager defaultManager] fileExistsAtPath:[fileURL path]]) {
        return YES;
    } else {
        return NO;
    }
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//- Delete ------------------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Delete

+ (void)deleteDocumentWithName:(NSString *)name withDelegate:(id<iCloudDelegate>)delegate completion:(void (^)(void))completionBlock {
	//Get the URL to remove the file from
	NSURL *folderURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
	folderURL = [folderURL URLByAppendingPathComponent:@"Documents"];
	NSURL *fileURL = [folderURL URLByAppendingPathComponent:name];
    
    //Start Process on Background Thread
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
		NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
		[fileCoordinator coordinateWritingItemAtURL:fileURL options:NSFileCoordinatorWritingForDeleting error:&error byAccessor:^(NSURL *writingURL) {
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            [fileManager removeItemAtURL:writingURL error:nil];
            completionBlock();
        }];
	});
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//- Delegate ----------------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Delegate

- (void)iCloudFilesDidChange:(NSMutableArray *)files withNewFileNames:(NSMutableArray *)fileNames {
    [[self delegate] iCloudFilesDidChange:files withNewFileNames:fileNames];
}

- (void)iCloudError:(NSError *)error {
    [[self delegate] iCloudError:error];
}

@end
