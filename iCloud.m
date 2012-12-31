//
//  iCloud.m
//  iCloud Document Sync
//
//  Created by iRare Media on 12/29/12.
//
//

#import "iCloud.h"

@implementation iCloud
@synthesize query, previousQueryResults, updateTimer, FileList;
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
        [iCloud checkCloudAvailability];
        [self syncWithCloud];
        [self updateCloudFiles];
        self.previousQueryResults = [NSMutableArray array];
        
        //Add a timer that updates out for changes in the file metadata
        //updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimerFired) userInfo:nil repeats:YES];
    }
    
    return self;
}

//Check for iCloud Availability
+ (BOOL)checkCloudAvailability
{
    NSLog(@"Checking iCloud availablity...");
	NSURL *returnedURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
	
	if (returnedURL){
		NSLog(@"iCloud is available");
        return YES;
	} else {
		NSLog(@"iCloud not available. ☹");
        return NO;
	}
}

//Enumerate through the iCloud Document Metadata
- (void)syncWithCloud
{
	self.query = [[NSMetadataQuery alloc] init];
	[query setSearchScopes:[NSArray arrayWithObjects:NSMetadataQueryUbiquitousDocumentsScope, nil]];
    
	//Pull a list of all the Documents in The Cloud
	[[NSNotificationCenter defaultCenter] addObserver:self  selector:@selector(updateCloudFiles)
												 name:NSMetadataQueryDidFinishGatheringNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCloudFiles)
												 name:NSMetadataQueryDidUpdateNotification object:nil];
    
	[self.query startQuery];
}

//Create and Update the list of files
- (void)updateCloudFiles
{
    //Move process to background thread
    dispatch_queue_t iCloudFiles = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(iCloudFiles, ^{
        //Get URLs out of query results
        NSMutableArray* queryResultURLs = [NSMutableArray array];
        for (NSMetadataItem *aResult in [self.query results]) {
            [queryResultURLs addObject:[aResult valueForAttribute:NSMetadataItemURLKey]];
        }
        
        //Calculate difference between arrays to find which are new, which are to be removed
        NSMutableArray* newURLs = [queryResultURLs mutableCopy];
        NSMutableArray* removedURLs = [previousQueryResults mutableCopy];
        [newURLs removeObjectsInArray:previousQueryResults];
        [removedURLs removeObjectsInArray:queryResultURLs];
        
        //Remove entries from array
        for (int i = 0; i < [FileList count]; ) {
            NSFileVersion *aFile = [FileList objectAtIndex:i];
            if ([removedURLs containsObject:aFile.URL]) {
                [FileList removeObjectAtIndex:i];
            } else {
                i++;
            }}
            
        //Add entries (file exists, but we have to create a new NSFileVersion to track it)
        for (NSURL *aNewURL in newURLs) {
            [FileList addObject:[NSFileVersion currentVersionOfItemAtURL:aNewURL]];
        }
        
        self.previousQueryResults = queryResultURLs;
        [[self delegate] fileList:FileList];
    });
}

//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
//Region: Saving and Deleting ----------------------------------------------------------------------------------------------------------------------------------//
//--------------------------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Saving and Deleting

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
        NSString *documentsDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
        NSURL *directoryURL = [[NSURL alloc] initWithString:[documentsDirectory stringByAppendingPathComponent:name]];
        
        //Delete file from iCloud
        NSFileCoordinator* fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
		[fileCoordinator coordinateWritingItemAtURL:directoryURL options:NSFileCoordinatorWritingForDeleting error:nil byAccessor:^(NSURL* writingURL)
		 {
             //Delete file from local directory
			 NSFileManager* fileManager = [[NSFileManager alloc] init];
			 [fileManager removeItemAtURL:writingURL error:nil];
             
             //Notify Delegate
             if ([delegate respondsToSelector:@selector(documentWasDeleted)])
                 [delegate documentWasDeleted];
         }];
    });
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


- (void)fileList:(NSMutableArray *)files
{
    [[self delegate] fileList:files];
}

@end