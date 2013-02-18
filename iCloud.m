//
//  iCloud.m
//  iCloud Document Sync
//
//  Created by iRare Media on 12/29/12.
//
//

#import "iCloud.h"

@interface iCloud ()
- (void) enumerateCloudDocuments;
+ (void) fileListReceivedWithDelegate:(id<iCloudDelegate>)delegate;
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
        [iCloud fileListReceivedWithDelegate:delegate];
        
        //Add a timer that updates out for changes in the file metadata
        updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimerFired:) userInfo:nil repeats:YES];
    }
    
    return self;
}

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
//Region: List -------------------------------------------------------------------------------------------------------------------------------------------------//
//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - List

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
    [iCloud fileListReceivedWithDelegate:delegate];
}

//Create and Update the list of files
+ (void)fileListReceivedWithDelegate:(id<iCloudDelegate>)delegate
{
    dispatch_queue_t iCloudFiles = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
        dispatch_async(iCloudFiles, ^{
            //Background Process
            
            //Disable updates while we update
            [[iCloud query] disableUpdates];
            
            //Get URLs out of query results
            NSMutableArray* queryResultURLs = [NSMutableArray array];
            for (NSMetadataItem *aResult in [[iCloud query] results])  {
                [queryResultURLs addObject:[aResult valueForAttribute:NSMetadataItemURLKey]];
            }
            
            //Calculate difference between arrays to find which are new, which are to be removed
            NSMutableArray* newURLs = [queryResultURLs mutableCopy];
            NSMutableArray* removedURLs = [[iCloud previousQueryResults] mutableCopy];
            [newURLs removeObjectsInArray:[iCloud previousQueryResults]];
            [removedURLs removeObjectsInArray:queryResultURLs];
            
            //Remove entries (file is already gone, we are just updating the array)
            for (int i = 0; i < [[iCloud fileList] count];) {
                NSFileVersion *aFile = [[iCloud fileList] objectAtIndex:i];
                if ([removedURLs containsObject:aFile.URL]) {
                    [[iCloud fileList] removeObjectAtIndex:i];
                    // Make a nice animation or swap to the cell with the hint text
                    if ([[iCloud fileList] count] != 0) {
                        //Here is where you could update a table or collection view (possibly coming in a future update)
                        //[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:i inSection:0]] withRowAnimation:UITableViewRowAnimationLeft];
                    } else {
                        //Here is where you could update a table or collection view (possibly coming in a future update)
                        //[self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:i inSection:0]] withRowAnimation:UITableViewRowAnimationLeft];
                    }
                } else {
                    i++;
                }
            }
            
            //Add tableview entries (file exists, but we have to create a new NSFileVersion to track it)
            for (NSURL *aNewURL in newURLs) {
                [[iCloud fileList] addObject:[NSFileVersion currentVersionOfItemAtURL:aNewURL]];
                
                if ([[iCloud fileList] count] != 1) {
                    //Here is where you could update a table or collection view (possibly coming in a future update)
                    //[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:([self.fileList count] -1) inSection:0]] withRowAnimation:UITableViewRowAnimationLeft];
                } else {
                    //Here is where you could update a table or collection view (possibly coming in a future update)
                    //[self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:([self.fileList count] -1) inSection:0]] withRowAnimation:UITableViewRowAnimationRight];
                }
            }
            
            NSMutableArray *array = [NSMutableArray array];
            for (NSMetadataItem *item in [iCloud query].results) {
                [array addObject:[item valueForAttribute:NSMetadataItemFSNameKey]];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                //Main UI Process
                NSLog(@"File Names:%@", array);
                
                //[iCloud previousQueryResults] = queryResultURLs;
                
                [delegate fileListChanged:array];
            });
            
            //Reenable Updates
            [[iCloud query] enableUpdates];
        });
}

//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
//Region: Uploading --------------------------------------------------------------------------------------------------------------------------------------------//
//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Uploading

+ (void)uploadDocumentsWithDelegate:(id<iCloudDelegate>)delegate
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
//Region: Downloading ------------------------------------------------------------------------------------------------------------------------------------------//
//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Downloading

+ (void)downloadDocumentsWithDelegate:(id<iCloudDelegate>)delegate
{
    //Notify Delegate
    if ([delegate respondsToSelector:@selector(documentsStartedDownloading)])
        [delegate documentsStartedDownloading];
    
    //Perform tasks on background thread to avoid problems on the main / UI thread
	dispatch_queue_t download = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(download, ^{
        
        NSLog(@"This feature isn't ready yet. Fork our project on GitHub and help us out! www.github.com/iraremedia/iclouddocumentsync");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            //Notify Delegate
            if ([delegate respondsToSelector:@selector(documentsFinishedUploading)])
                [delegate documentsFinishedUploading];
        });
    });
}

//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
//Region: Save, Delete, Download -------------------------------------------------------------------------------------------------------------------------------//
//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Save, Delete, Download

+ (void)createDocumentWithData:(NSData *)data withName:(NSString *)name withDelegate:(id<iCloudDelegate>)delegate
{
    //Perform tasks on background thread to avoid problems on the main / UI thread
	dispatch_queue_t addDoc = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(addDoc, ^{
        //Save the file locally using the specified data and name
        NSFileManager *filemgr = [NSFileManager defaultManager];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        [filemgr createFileAtPath:[documentsDirectory stringByAppendingPathComponent:name] contents:data attributes:nil];
        
        //Move the file to iCloud
        NSURL *ubiquitousURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
        NSURL *destinationURL = [ubiquitousURL URLByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@",name]];
        NSURL *directoryURL = [[NSURL alloc] initWithString:[documentsDirectory stringByAppendingPathComponent:name]];
        [filemgr setUbiquitous:YES itemAtURL:directoryURL destinationURL:destinationURL error:nil];
        
        //Notify Delegate
        if ([delegate respondsToSelector:@selector(documentWasSaved)])
            [delegate documentWasSaved];
    });
}

+ (void)removeDocumentWithName:(NSString *)name withDelegate:(id<iCloudDelegate>)delegate
{
    //Perform tasks on background thread to avoid problems on the main / UI thread
	dispatch_queue_t minusDoc = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(minusDoc, ^{
        //Create the complete file path
        NSURL *cloudURL = [[[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil] URLByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@",name]];
        NSFileCoordinator* fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        //Delete file from iCloud
		[fileCoordinator coordinateWritingItemAtURL:cloudURL options:NSFileCoordinatorWritingForDeleting error:nil byAccessor:^(NSURL* writingURL){
             //Notify Delegate
             if ([delegate respondsToSelector:@selector(documentWasDeleted)])
                 [delegate documentWasDeleted];
         }];
    });
}

+ (NSData*)retrieveDocumentDatawithName:(NSString *)name
{
    //Get the iCloud file URL
    NSURL *ubiquitousURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
    NSURL *URL = [ubiquitousURL URLByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@",name]];
    
    //Get Data From File
    NSData *data = [[NSData alloc] init];
    data = [[NSData alloc] initWithContentsOfURL:URL];
    
    return data;
}
//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
//Region: Delegate ---------------------------------------------------------------------------------------------------------------------------------------------//
//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Delegate

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

- (void)fileListChanged:(NSMutableArray *)files
{
    [[self delegate] fileListChanged:files];
}

- (void)cloudError:(NSError *)error
{
    [[self delegate] cloudError:error];
}

@end