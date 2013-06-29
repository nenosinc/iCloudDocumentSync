//
//  iCloud.h
//  iCloud Document Sync
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
+ (NSMetadataQuery *)query;

/** Returns a list of files stored in iCloud
 @return NSMutableArray (editable list) of files stored in iCloud.
 */
+ (NSMutableArray *)fileList;

/** Returns a list of the files from the previous iCloud Query
 @return NSMutableArray (editable list) of files in iCloud during the previous sync.
 */
+ (NSMutableArray *)previousQueryResults;

//Private Properties
@property (retain) NSMetadataQuery *query;
@property (retain) NSMutableArray *fileList;
@property (retain) NSMutableArray *previousQueryResults;
@property (retain) NSTimer *updateTimer;

/** @name Checking iCloud */

/** Check for iCloud Availability. This method may return NO (iCloud Not Available) for a number of reasons:  
 - iCloud is turned off by the user  
 - The app is being run in the iOS Simulator  
 - The entitlements profile, code signing identity, and/or provisioning profile is invalid  
 
 @return Boolean value that shows if iCloud is available or not.
 */
+ (BOOL)checkCloudAvailability;


/** @name Syncing with iCloud */

- (void)enumerateCloudDocuments;

/** Check for and update the list of files stored in your app's iCloud Documents Folder. This method is automatically called by iOS when there are changes to files in the iCloud Directory.
 @param delegate The iCloud Class requires a delegate. Make sure to set the delegate of iCloud before calling this method. The [fileListChangedWithFiles: andFileNames:] delegate method is triggered by this method.
 */
+ (void)updateFilesWithDelegate:(id<iCloudDelegate>)delegate;


/** @name Uploading to iCloud */

/** Create a document to upload to iCloud.
 @param name The name of the UIDocument file being written to iCloud
 @param content The data to write to the UIDocument file
 @param delegate The iCloud Class requires a delegate. Make sure to set the delegate of iCloud before calling this method. The documentWasSaved delegate method is triggered by this method.
 @param handler Code block called when the document is successfully saved. The completion block passes UIDocument and NSData objects containing the saved document and it's contents in the form of NSData
 */
+ (void)saveDocumentWithName:(NSString *)name withContent:(NSData *)content withDelegate:(id<iCloudDelegate>)delegate completion:(void (^)(UIDocument *cloudDocument, NSData *documentData))handler;

/** Upload any local files that weren't created with iCloud or were created while offline
 @param delegate The iCloud Class requires a delegate. Make sure to set the delegate of iCloud before calling this method.
 @param completionBlock Code block called when files are uploaded to iCloud
 */
+ (void)uploadLocalOfflineDocumentsWithDelegate:(id<iCloudDelegate>)delegate completion:(void (^)(void))completionBlock;


/** @name Deleting content from iCloud */

/** Delete a document from iCloud.
 @param name The name of the UIDocument file to delete from iCloud
 @param delegate The iCloud Class requires a delegate. Make sure to set the delegate of iCloud before calling this method. The documentWasSaved delegate method is triggered by this method.
 @param completionBlock Code block called when a file is successfully deleted from iCloud
 */
+ (void)deleteDocumentWithName:(NSString *)name withDelegate:(id<iCloudDelegate>)delegate completion:(void (^)(void))completionBlock;

/** @name Getting content from iCloud */

/** Open a UIDocument stored in iCloud. If the document does not exist, a new blank document will be created using the documentName provided. You can use the doesFileExistInCloud: method to check if a file exists before calling this method.
 @param documentName The name of the UIDocument file in iCloud
 @param handler Code block called when the document is successfully retrieved (opened or downloaded). The completion block passes UIDocument and NSData objects containing the opened document and it's contents in the form of NSData. If there is an error, the NSError object will have an error message
 */
+ (void)retrieveCloudDocumentWithName:(NSString *)documentName completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler;

/** Check if a file exists in iCloud
 @param fileName The name of the UIDocument in iCloud
 @return BOOL value, YES if the file does exist in iCloud, NO if it does not
 */
+ (BOOL)doesFileExistInCloud:(NSString *)fileName;

@end

@class iCloud;

/** The iCloudDelegate protocol defines the methods used to receive event notifications and allow for deeper control of the iCloud Class.
 */
@protocol iCloudDelegate <NSObject>

/** @name Required Delegate Methods */
@required

/** Tells the delegate that the files in iCloud have been modified
 @param files A list of the files now in the app's iCloud documents directory - each file in the array contains information such as file version, url, localized name, date, etc.
 @param fileNames A list of the file names now in the app's iCloud documents directory
 */
- (void)iCloudFilesDidChange:(NSMutableArray *)files withNewFileNames:(NSMutableArray *)fileNames;

/** Called where there is an error while performing an iCloud process
 @param error An NSError with a message, error code, and information
 */
- (void)iCloudError:(NSError *)error;

@optional

/** @name Deprecated Delegate Methods */

/** Tells the delegate that there was an error while performing a process
 @param error Returns the NSError that occured
 @deprecated This method is deprecated, use iCloudError: delegate method instead.
 */
- (void)cloudError:(NSError *)error __deprecated;

/** Tells the delegate that the files in iCloud have been modified
 @param files Returns a list of the files now in the app's iCloud documents directory - each file in the array contains information such as file version, url, localized name, date, etc.
 @param fileNames Returns a list of the file names now in the app's iCloud documents directory
 @deprecated This method is deprecated, use iCloud:cloudFilesDidChange:withNewFileNames: delegate method instead.
 */
- (void)fileListChangedWithFiles:(NSMutableArray *)files andFileNames:(NSMutableArray *)fileNames __deprecated;

/** Tells the delegate that a document was successfully deleted. 
 @deprecated This method is deprecated, use the completion block in the removedDocumentNamed: method instead.
 */
- (void)documentWasDeleted __deprecated;

/** Tells the delegate that a document was successfully saved
 @deprecated This method is deprecated, use the completion block in the createDocumentNamed: method instead.
 */
- (void)documentWasSaved __deprecated;

/** Tells the delegate that a document finished uploading
 @deprecated This method is deprecated, use the completion block in the uploadLocalOfflineDocumentsWithDelegate: method instead.
 */
- (void)documentsFinishedUploading __deprecated;

/** Tells the delegate that a document started uploading
 @deprecated This method is deprecated, avoid use.
 */
- (void)documentsStartedUploading __deprecated;

/** Tells the delegate that a document started downloading
 @deprecated This method is deprecated, avoid use.
 */
- (void)documentsStartedDownloading __deprecated;

/** Tells the delegate that a document finished downloading
 @deprecated This method is deprecated, avoid use.
 */
- (void)documentsFinishedDownloading __deprecated;

@end