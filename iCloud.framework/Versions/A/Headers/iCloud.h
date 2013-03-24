//
//  iCloud.h
//  iRare Media
//
//  Originally from iCloudPlayground
//
//  Created by iRare Media on 3/23/13.
//
//

#import <Foundation/Foundation.h>
#import <iCloud/iCloudDocument.h>

/** The iCloud Class and Delegate provides methods to integrate iCloud into document projects. Sync, download, save, and remove documents to and from iCloud with only a few lines of code. These methods are standardized throughout iRare Media products. Updates and more details on this project can be found at www.GitHub.com/iRareMedia/iCloudDocumentSync
 
     Only available on iOS 5.0 and later on apps with valid code signing and entitlements.
 */
@class iCloud;
@protocol iCloudDelegate;
NS_CLASS_AVAILABLE_IOS(5_0) @interface iCloud : NSObject

/** @name Delegate */

/** iCloud Delegate helps call methods when document processes begin or end */
@property (nonatomic, weak) id <iCloudDelegate> delegate;

/** @name Properties */

/** Returns an NSMetadataQuery
 @return The iCloud NSMetadataQuery.
 */
+(NSMetadataQuery *) query;

/** Returns a list of files stored in iCloud
 @return NSMutableArray (editable list) of files stored in iCloud.
 */
+(NSMutableArray *) fileList;

/** Returns a list of the files from the previous iCloud Query
 @return NSMutableArray (editable list) of files in iCloud during the previous sync.
 */
+(NSMutableArray *) previousQueryResults;

//Private Properties
@property (retain) NSMetadataQuery *query;
@property (retain) NSMutableArray *fileList;
@property (retain) NSMutableArray *previousQueryResults;
@property (retain) NSTimer *updateTimer;

/** @name Checking iCloud */

/** Check for iCloud Availability. This method may return NO (iCloud Not Available) for a number of reasons:  
 - iCloud is turned off by the user  
 - The app is being run in the iOS Simulator  
 - The entitlements profile or code signing identities are incorrect  
 
 @return Boolean value that shows if iCloud is available or not.
 */
+ (BOOL)checkCloudAvailability;

/** @name Syncing with iCloud */

- (void)enumerateCloudDocuments;

/** Check for and update the list of files stored in your app's iCloud Documents Folder. This method is automatically called by iOS when there are changes to files in the iCloud Directory.
 @param delegate The iCloud Class requires a delegate. Make sure to set the delegate of iCloud before calling this method. The [fileListChangedWithFiles: andFileNames:] delegate method is triggered by this method.
 */
+ (void)updateFileListWithDelegate:(id<iCloudDelegate>)delegate;

/** @name Uploading to iCloud */

/** Create a document to upload to iCloud.
 @param name The name of the UIDocument file being written to iCloud
 @param content The data to write to the UIDocument file
 @param delegate The iCloud Class requires a delegate. Make sure to set the delegate of iCloud before calling this method. The documentWasSaved delegate method is triggered by this method.
 */
+ (void)createDocumentNamed:(NSString *)name withContent:(NSData *)content withDelegate:(id<iCloudDelegate>)delegate;

/** Upload any local files that weren't created with iCloud or were created while offline
 @param delegate The iCloud Class requires a delegate. Make sure to set the delegate of iCloud before calling this method.
 */
+ (void)uploadLocalOfflineDocumentsWithDelegate:(id<iCloudDelegate>)delegate;

/** @name Removing content from iCloud */

/** Delete a document from iCloud.
 @param name The name of the UIDocument file to delete from iCloud
 @param delegate The iCloud Class requires a delegate. Make sure to set the delegate of iCloud before calling this method. The documentWasSaved delegate method is triggered by this method.
 */
+ (void)removeDocumentNamed:(NSString *)name withDelegate:(id<iCloudDelegate>)delegate;

/** @name Getting content from iCloud */

/** Open a UIDocument stored in iCloud.
 @param name The name of the UIDocument file in iCloud
 @return UIDocument file from iCloud
 */
+ (UIDocument *)openDocumentNamed:(NSString *)name;

/** Retrieve the data of a UIDocument stored in iCloud.
 @param name The name of the UIDocument file in iCloud
 @return NSData of the UIDocument file from iCloud
 */
+ (NSData *)getDataFromDocumentNamed:(NSString *)name;

@end

@class iCloud;

/** The `iCloudDelegate` protocol defines the methods used to receive event notifications and allow for deeper control of the iCloud Class.
 */
@protocol iCloudDelegate <NSObject>

/** @name Required Delegate Methods */
@required

/** Tells the delegate that the files in iCloud have been modified
 @param files Returns a list of the files now in the app's iCloud documents directory - each file in the array contains information such as file version, url, localized name, date, etc.
 @param fileNames Returns a list of the file names now in the app's iCloud documents directory
 */
- (void)fileListChangedWithFiles:(NSMutableArray *)files andFileNames:(NSMutableArray *)fileNames;

/** Tells the delegate that there was an error while performing a process
 @param error Returns the NSError that occured
 */
- (void)cloudError:(NSError *)error;

/** @name Optional Delegate Methods */
@optional

/** Tells the delegate that a document was successfully deleted */
- (void)documentWasDeleted;

/** Tells the delegate that a document was successfully saved */
- (void)documentWasSaved;

/** Tells the delegate that a document finished uploading */
- (void)documentsFinishedUploading;

/** Tells the delegate that a document started uploading */
- (void)documentsStartedUploading;

/** Tells the delegate that a document started downloading */
- (void)documentsStartedDownloading;

/** Tells the delegate that a document finished downloading */
- (void)documentsFinishedDownloading;

/* Tells the delegate that the UI should be updated to reflect a deletion in the File List
 - (void)deleteListItemAtIndexPath:(NSIndexPath *)indexPath;
 
 // Tells the delegate that the UI should be updated to reflect a reload and removal of a File List item
 - (void)reloadListRowsAtIndexPaths:(NSIndexPath *)indexPath;
 
 // Tells the delegate that the UI should be updated to reflect a reload and addition of a File List item
 - (void)reloadNewListRowsAtIndexPaths:(NSIndexPath *)indexPath;
 
 // Tells the delegate that the UI should be updated to reflect an addition to the File List
 - (void)insertListItemAtIndexPath:(NSIndexPath *)indexPath;
 */

@end