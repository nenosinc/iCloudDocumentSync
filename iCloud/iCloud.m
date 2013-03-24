//
//  iCloud.m
//  iRare Media
//
//  Originally from iCloudPlayground
//
//  Created by iRare Media on 3/23/13.
//
//

#import "iCloud.h"

@interface iCloud ()
- (void) enumerateCloudDocuments;
+ (void)updateFileListWithDelegate:(id<iCloudDelegate>)delegate;
- (void) updateTimerFired:(NSTimer *)timer;
@end

@implementation iCloud
@synthesize query;
@synthesize previousQueryResults;
@synthesize updateTimer;
@synthesize fileList;
@synthesize delegate;

//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
//Region: Setup ------------------------------------------------------------------------------------------------------------------------------------------------//
//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Setup

//Setup Starter Sync
- (id)init
{
    self = [super init];
    if (self) {
        //Check iCloud Availability
        [iCloud checkCloudAvailability];
        
        //No Know Docs Yet - Initialize Array
        self.fileList = [NSMutableArray array];
        self.previousQueryResults = [NSMutableArray array];
        
        //Sync and Update Documents List
        [self enumerateCloudDocuments];
        [iCloud updateFileListWithDelegate:delegate];
        
        //Add a timer that updates out for changes in the file metadata
        updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimerFired:) userInfo:nil repeats:YES];
    }
    
    return self;
}

+ (NSMetadataQuery *) query
{
    static NSMetadataQuery* q = nil;
    if (q == nil) {
        q = [[NSMetadataQuery alloc] init];
    }
    
    return q;
}

+ (NSMutableArray *) fileList
{
    static NSMutableArray* f = nil;
    if (f == nil) {
        f = [NSMutableArray array];
    }
    
    return f;
}

+ (NSMutableArray *) previousQueryResults
{
    static NSMutableArray* p = nil;
    if (p == nil) {
        p = [NSMutableArray array];
    }
    
    return p;
}

//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
//Region: Check ------------------------------------------------------------------------------------------------------------------------------------------------//
//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Check

//Check for iCloud Availability
+ (BOOL)checkCloudAvailability
{
	NSURL *returnedURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
	
	if (returnedURL){
		NSLog(@"iCloud is available at URL: %@", returnedURL);
        return YES;
	} else {
		NSLog(@"iCloud not available. ☹");
        return NO;
	}
}

- (void)updateTimerFired:(NSTimer *)timer;
{
	//For some strange reason, deleting this method and the line that creates the timer that calls it causes iCloud not to function... If anyone can figure out this mystery, please submit a pull request / issue on Github at https://github.com/iRareMedia/iCloudDocumentSync
}

//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
//Region: Sync -------------------------------------------------------------------------------------------------------------------------------------------------//
//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Sync

//Enumerate through the iCloud Document Metadata
- (void)enumerateCloudDocuments
{
	//self.query = [[NSMetadataQuery alloc] init];
	[[iCloud query] setSearchScopes:[NSArray arrayWithObjects:NSMetadataQueryUbiquitousDocumentsScope, nil]];
	NSString* predicate = [NSString stringWithFormat:@"%%K like '*.*'"];
	[[iCloud query] setPredicate:[NSPredicate predicateWithFormat:predicate, NSMetadataItemFSNameKey]];
    
	// pull a list of all the documents in the cloud
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startUpdate)
												 name:NSMetadataQueryDidFinishGatheringNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startUpdate)
												 name:NSMetadataQueryDidUpdateNotification object:nil];
    
	[[iCloud query] startQuery];
}

- (void)startUpdate
{
    [iCloud updateFileListWithDelegate:delegate];
}

//Create and Update the list of files
+ (void)updateFileListWithDelegate:(id<iCloudDelegate>)delegate
{
    //Start Process on Background Thread
    dispatch_queue_t iCloudFiles = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(iCloudFiles, ^{
        
        //Disable updates to iCloud while we update to avoid errors
        [[iCloud query] disableUpdates];
        
        //Retrieve URLs out of query results
        NSMutableArray* queryResultURLs = [NSMutableArray array];
        for (NSMetadataItem *aResult in [[iCloud query] results])  {
            [queryResultURLs addObject:[aResult valueForAttribute:NSMetadataItemURLKey]];
        }
        
        //Calculate difference between arrays to find which are new, which are to be removed
        NSMutableArray* newURLs = [queryResultURLs mutableCopy];
        NSMutableArray* removedURLs = [[iCloud previousQueryResults] mutableCopy];
        [newURLs removeObjectsInArray:[iCloud previousQueryResults]];
        [removedURLs removeObjectsInArray:queryResultURLs];
        
        //Get File Names in from the Query
        NSMutableArray *array = [NSMutableArray array];
        for (NSMetadataItem *item in [iCloud query].results) {
            [array addObject:[item valueForAttribute:NSMetadataItemFSNameKey]];
        }
        //NSLog(@"File Names:%@", array);
        
        //Remove entries (file is already gone, we are just updating the array)
        for (int i = 0; i < [[iCloud fileList] count];) {
            NSFileVersion *aFile = [[iCloud fileList] objectAtIndex:i];
            if ([removedURLs containsObject:aFile.URL]) {
                [[iCloud fileList] removeObjectAtIndex:i];
                // Make a nice animation or swap to the cell with the hint text
                if ([[iCloud fileList] count] != 0) {
                    //Notify Delegate
                    //if ([delegate respondsToSelector:@selector(deleteListItemAtIndexPath:)])
                    //[delegate deleteListItemAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
                } else {
                    // if ([delegate respondsToSelector:@selector(reloadListRowsAtIndexPaths:)])
                    //[delegate reloadListRowsAtIndexPaths:[NSIndexPath indexPathForRow:i inSection:0]];
                }
            } else {
                i++;
            }
        }
        
        //Add tableview entries (file exists, but we have to create a new NSFileVersion to track it)
        for (NSURL *aNewURL in newURLs) {
            [[iCloud fileList] addObject:[NSFileVersion currentVersionOfItemAtURL:aNewURL]];
            
            if ([[iCloud fileList] count] != 1) {
                //if ([delegate respondsToSelector:@selector(insertListItemAtIndexPath:)])
                //[delegate insertListItemAtIndexPath:[NSIndexPath indexPathForRow:([self.fileList count] -1) inSection:0]];
            } else {
                //if ([delegate respondsToSelector:@selector(reloadNewListRowsAtIndexPaths:)])
                //[delegate reloadNewListRowsAtIndexPaths:[NSIndexPath indexPathForRow:([self.fileList count] -1) inSection:0]];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate fileListChangedWithFiles:[iCloud fileList] andFileNames:array];
        });
        
        //Reenable Updates
        [[iCloud query] enableUpdates];
    });
}

//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
//Region: Add --------------------------------------------------------------------------------------------------------------------------------------------------//
//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Add

+ (void)createDocumentNamed:(NSString *)name withContent:(NSData *)content withDelegate:(id<iCloudDelegate>)delegate
{
	//Get the URL to save the new file to
	NSURL *folderURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
	folderURL = [folderURL URLByAppendingPathComponent:@"Documents"];
	NSURL *fileURL = [folderURL URLByAppendingPathComponent:name];
    
    //Initialize a document with that path
	iCloudDocument *newDocument = [[iCloudDocument alloc] initWithFileURL:fileURL];
    newDocument.contents = content;
    
	//Save the document immediately
	[newDocument saveToURL:newDocument.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
        if (success) {
            //Saving implicitly opens the file. An open document will restore the its (remotely) deleted file representation.
            [newDocument closeWithCompletionHandler:nil];
            
            if ([delegate respondsToSelector:@selector(documentWasSaved)])
                [delegate documentWasSaved];
        } else {
            NSLog(@"%s error while saving", __PRETTY_FUNCTION__);
            NSError *error = [NSString stringWithFormat:@"%s error while saving", __PRETTY_FUNCTION__];
            [delegate cloudError:error];
        }
    }];
}

+ (void)uploadLocalOfflineDocumentsWithDelegate:(id<iCloudDelegate>)delegate
{
    //Notify Delegate
    if ([delegate respondsToSelector:@selector(documentsStartedUploading)])
        [delegate documentsStartedUploading];
    
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
                //Not a hidden or messy file, proceed
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
                        [delegate cloudError:error];
                    }
                    
                } else {
                    //Check if the local document is newer than the cloud document
                }
            } else {
                //Hidden or messy file, do not proceed
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            //Notify Delegate
            if ([delegate respondsToSelector:@selector(documentsFinishedUploading)])
                [delegate documentsFinishedUploading];
        });
    });
}

//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
//Region: Open -------------------------------------------------------------------------------------------------------------------------------------------------//
//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Open

+ (UIDocument *)openDocumentNamed:(NSString *)name
{
    //Get the URL to get the file from
	NSURL *folderURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
	folderURL = [folderURL URLByAppendingPathComponent:@"Documents"];
	NSURL *fileURL = [folderURL URLByAppendingPathComponent:name];
    
    iCloudDocument *selectedDocument = [[iCloudDocument alloc] initWithFileURL:fileURL];
    return selectedDocument;
}

+ (NSData *)getDataFromDocumentNamed:(NSString *)name
{
    //Get the URL to get the file from
	NSURL *folderURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
	folderURL = [folderURL URLByAppendingPathComponent:@"Documents"];
	NSURL *fileURL = [folderURL URLByAppendingPathComponent:name];
    
    iCloudDocument *selectedDocument = [[iCloudDocument alloc] initWithFileURL:fileURL];
    return selectedDocument.contents;
}

//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
//Region: Remove -----------------------------------------------------------------------------------------------------------------------------------------------//
//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Remove

+ (void)removeDocumentNamed:(NSString *)name withDelegate:(id<iCloudDelegate>)delegate
{
	//Get the URL to remove the file from
	NSURL *folderURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
	folderURL = [folderURL URLByAppendingPathComponent:@"Documents"];
	NSURL *fileURL = [folderURL URLByAppendingPathComponent:name];
    
    //Start Process on Background Thread
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
		NSFileCoordinator* fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        NSError *error;
		[fileCoordinator coordinateWritingItemAtURL:fileURL options:NSFileCoordinatorWritingForDeleting error:&error byAccessor:^(NSURL* writingURL) {
            NSFileManager* fileManager = [[NSFileManager alloc] init];
            [fileManager removeItemAtURL:writingURL error:nil];
            if ([delegate respondsToSelector:@selector(documentWasDeleted)])
                [delegate documentWasDeleted];
        }];
	});
}

//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
//Region: Delegate ---------------------------------------------------------------------------------------------------------------------------------------------//
//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Delegate

- (void)fileListChangedWithFiles:(NSMutableArray *)files andFileNames:(NSMutableArray *)fileNames
{
    [[self delegate] fileListChangedWithFiles:files andFileNames:fileNames];
}

- (void)cloudError:(NSError *)error
{
    [[self delegate] cloudError:error];
}

- (void)documentWasDeleted
{
    [[self delegate] documentWasDeleted];
}

- (void)documentWasSaved
{
    [[self delegate] documentWasSaved];
}

- (void)documentsFinishedUploading
{
    [[self delegate] documentsFinishedUploading];
}

- (void)documentsStartedUploading
{
    [[self delegate] documentsStartedUploading];
}

- (void)documentsStartedDownloading
{
    [[self delegate] documentsStartedDownloading];
}

- (void)documentsFinishedDownloading
{
    [[self delegate] documentsFinishedDownloading];
}

//The following delegate methods are coming soon. These methods will allow you to update your UI, specifically a UITableView or UICollectionView, when there is a change in the FileList. If you can figure out how to use these without causing a crash (in particular an Assertion Failure) please submit a pull request / issue on Github at https://github.com/iRareMedia/iCloudDocumentSync
/*
 - (void)deleteListItemAtIndexPath:(NSIndexPath *)indexPath
 {
 [[self delegate] deleteListItemAtIndexPath:indexPath];
 }
 
 - (void)reloadListRowsAtIndexPaths:(NSIndexPath *)indexPath;
 {
 [[self delegate] reloadListRowsAtIndexPaths:indexPath];
 }
 
 - (void)reloadNewListRowsAtIndexPaths:(NSIndexPath *)indexPath
 {
 [[self delegate] reloadNewListRowsAtIndexPaths:indexPath];
 }
 
 - (void)insertListItemAtIndexPath:(NSIndexPath *)indexPath
 {
 [[self delegate] insertListItemAtIndexPath:indexPath];
 }
 */

@end
