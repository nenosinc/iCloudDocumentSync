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

/** iCloud Document Sync helps integrate iCloud into iOS (OS X coming soon) Objective-C document projects with one-line code methods. Sync, upload, manage, and remove documents to and from iCloud with only a few lines of code (compared to the 400+ lines that it usually takes). Updates and more details on this project can be found on [GitHub](http://www.github.com/iRareMedia/iCloudDocumentSync). If you like the project, please [star it](https://github.com/iRareMedia/iCloudDocumentSync) on GitHub!
 
 The `iCloud` class provides methods to integrate iCloud into document projects.
 
 <br />
 Adding iCloud Document Sync to your project is easy. Follow these steps below to get everything up and running.
 
 1. Drag the iCloud Framework into your project
 2. Add `#import <iCloud/iCloud.h>` to your header file(s) iCloud Document Sync
 3. Subscribe to the `<iCloudDelegate>` delegate.
 4. Call the following methods to setup iCloud when your app starts:
 
        iCloud *cloud = [[iCloud alloc] init]; // This will help to begin the sync process and register for document updates.
        [cloud setDelegate:self]; // Only set this if you plan to use the delegate
 
 
 @warning Only available on iOS 5.0 and later on apps with valid code signing and entitlements.
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
@property (strong) NSMetadataQuery *query;
@property (strong) NSMutableArray *fileList;
@property (strong) NSMutableArray *previousQueryResults;
@property (strong) NSTimer *updateTimer;

/** @name Checking for iCloud */

/** Check whether or not iCloud is available and that it can be accessed. Returns a boolean value.  
 
 @discussion You should always check if iCloud is available before performing any iCloud operations. Additionally, you may want to check if your users want to opt-in to iCloud on a per-app basis. The Return value could be **NO** (iCloud Unavailable) for one or more of the following reasons:
 
 - iCloud is turned off by the user  
 - The app is being run in the iOS Simulator  
 - The entitlements profile, code signing identity, and/or provisioning profile is invalid  
 
 @return YES if iCloud is available. NO if iCloud is not available.
 */
+ (BOOL)checkCloudAvailability;


/** @name Syncing with iCloud */

/** Check for and update the list of files stored in your app's iCloud Documents Folder. This method is automatically called by iOS when there are changes to files in the iCloud Directory.
 @param delegate The iCloud Class uses a delegate. The iCloudFilesDidChange:withNewFileNames: delegate method is triggered by this method.
 */
+ (void)updateFilesWithDelegate:(id<iCloudDelegate>)delegate;


/** @name Uploading to iCloud */

/** Create a document to upload to iCloud.
 
 @discussion iCloud Document Sync uses UIDocument and NSData to store and manage files. All of the heavy lifting with NSData and UIDocument is handled for you. There's no need to actually create or manage any files, just give iCloud Document Sync your data, and the rest is done for you.
 
 To create a new document or save an exisiting one (close the document), use this method. Below is a code example of how to use it.
 
    [iCloud saveDocumentWithName:@"Name.ext" withContent:[NSData data] withDelegate:self completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
        if (error == nil) {
            // Code here to use the UIDocument or NSData objects which have been passed with the completion handler
        }
    }];
 
 
 @param name The name of the UIDocument file being written to iCloud
 @param content The data to write to the UIDocument file
 @param handler Code block called when the document is successfully saved. The completion block passes UIDocument and NSData objects containing the saved document and it's contents in the form of NSData. The NSError object contains any error information if an error occured, otherwise it will ne nil.
 */
+ (void)saveDocumentWithName:(NSString *)name withContent:(NSData *)content completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler;

/** Upload any local files that weren't created with iCloud or were created while offline
 
 @discussion Files in the local documents directory that do not already exist in iCloud will be **moved** into iCloud one by one. This process involves lots of file manipulation and as a result it may take a long time. This process will be performed on the background thread to avoid any lag or memory problems. When the upload processes end, the completion block is called on the main thread.
 
    [iCloud uploadLocalOfflineDocumentsWithDelegate:self  repeatingHandler:^(NSString *fileName, NSError *error) {
        if (error == nil) {
            // This code block is called repeatedly until all files have been uploaded (or an upload has at least been attempted). 
            // Code here to use the NSString (the name of the uploaded file) which have been passed with the repeating handler
        }
     } completion:^{
         // Completion handler could be used to tell the user that the upload has completed
     }];
 
 @param delegate The iCloud Class uses a delegate. The iCloudFileUploadConflictWithCloudFile:andLocalFile: delegate method is triggered by this method.
 @param repeatingHandler Code block called after each file is uploaded to iCloud. This block is called everytime a local file is uploaded, therefore it may be called multiple times. The NSError object contains any error information if an error occured, otherwise it will be nil.
 @param completion Code block called after all files have been uploaded to iCloud. This block is only called once at the end of the method, regardless of any successes or failures that may have occured during the upload(s).
 */
+ (void)uploadLocalOfflineDocumentsWithDelegate:(id<iCloudDelegate>)delegate repeatingHandler:(void (^)(NSString *fileName, NSError *error))repeatingHandler completion:(void (^)(void))completion;


/** @name Deleting content from iCloud */

/** Delete a document from iCloud.
 @param name The name of the UIDocument file to delete from iCloud
 @param handler Code block called when a file is successfully deleted from iCloud. The NSError object contains any error information if an error occured, otherwise it will be nil.
 */
+ (void)deleteDocumentWithName:(NSString *)name completion:(void (^)(NSError *error))handler;


/** @name Getting content from iCloud */

/** Open a UIDocument stored in iCloud. If the document does not exist, a new blank document will be created using the documentName provided. You can use the doesFileExistInCloud: method to check if a file exists before calling this method.
 
 @discussion This method will attempt to open the specified document. If the file does not exist, a blank one will be created. The completion handler is called when the file is opened or created (either successfully or not). The completion handler contains a UIDocument, NSData, and NSError all of which contain information about the opened document.
 
    [iCloud retrieveCloudDocumentWithName:@"docName.ext" completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
        if (error == nil) {
            NSString *fileName = [cloudDocument.fileURL lastPathComponent];
            NSData *fileData = documentData;
        }
     }];
 
 @param documentName The name of the UIDocument file in iCloud
 @param handler Code block called when the document is successfully retrieved (opened or downloaded). The completion block passes UIDocument and NSData objects containing the opened document and it's contents in the form of NSData. If there is an error, the NSError object will have an error message (may be nil if there is no error).
 */
+ (void)retrieveCloudDocumentWithName:(NSString *)documentName completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler;

/** Check if a file exists in iCloud
 @param fileName The name of the UIDocument in iCloud
 @return BOOL value, YES if the file does exist in iCloud, NO if it does not
 */
+ (BOOL)doesFileExistInCloud:(NSString *)fileName;


/** @name Deprecated Methods */

/** DEPRECATED. Delete a document from iCloud.
 @param name The name of the UIDocument file to delete from iCloud
 @param delegate The iCloud Class requires a delegate. Make sure to set the delegate of iCloud before calling this method. The documentWasSaved delegate method is triggered by this method.
 @param handler Code block called when a file is successfully deleted from iCloud. The NSError object contains any error information if an error occured, otherwise it will ne nil.
 @deprecated This method is deprecated, use deleteDocumentWithName:completion: instead.
 */
+ (void)deleteDocumentWithName:(NSString *)name withDelegate:(id<iCloudDelegate>)delegate completion:(void (^)(NSError *error))handler __deprecated;

/** DEPRECATED. Create a document to upload to iCloud.
 @param name The name of the UIDocument file being written to iCloud
 @param content The data to write to the UIDocument file
 @param delegate The iCloud Class requires a delegate. Make sure to set the delegate of iCloud before calling this method. The documentWasSaved delegate method is triggered by this method.
 @param handler Code block called when the document is successfully saved. The completion block passes UIDocument and NSData objects containing the saved document and it's contents in the form of NSData. The NSError object contains any error information if an error occured, otherwise it will ne nil.
 @deprecated This method is deprecated, use saveDocumentWithName:withContent:completion: instead.
 */
+ (void)saveDocumentWithName:(NSString *)name withContent:(NSData *)content withDelegate:(id<iCloudDelegate>)delegate completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler __deprecated;

/** DEPRECATED. Upload any local files that weren't created with iCloud or were created while offline
 @param delegate The iCloud Class requires a delegate. Make sure to set the delegate of iCloud before calling this method.
 @param handler Code block called when files are uploaded to iCloud. The NSError object contains any error information if an error occured, otherwise it will ne nil.
 @deprecated This method is deprecated, use uploadLocalOfflineDocumentsWithDelegate:repeatingHandler:completion: instead.
 */
+ (void)uploadLocalOfflineDocumentsWithDelegate:(id<iCloudDelegate>)delegate completion:(void (^)(NSError *error))handler __deprecated;

@end

@class iCloud;

/** The iCloudDelegate protocol defines the methods used to receive event notifications and allow for deeper control of the iCloud Class.
 */
@protocol iCloudDelegate <NSObject>



/** @name Optional Delegate Methods */

@optional

/** Tells the delegate that the files in iCloud have been modified
 @param files A list of the files now in the app's iCloud documents directory - each file in the array contains information such as file version, url, localized name, date, etc.
 @param fileNames A list of the file names now in the app's iCloud documents directory
 */
- (void)iCloudFilesDidChange:(NSMutableArray *)files withNewFileNames:(NSMutableArray *)fileNames;

/** Sent to the delegate where there is a conflict between a local file and an iCloud file during an upload
 @param cloudFile An NSDictionary with the cloud file and various other information. This parameter contains the fileContent as NSData, fileURL as NSURL, and modifiedDate as NSDate.
 @param localFile An NSDictionary with the local file and various other information. This parameter contains the fileContent as NSData, fileURL as NSURL, and modifiedDate as NSDate.
 @discussion When both files have the same modfication date and file content, iCloud Document Sync will not be able to automatically determine how to handle the conflict. As a result, this delegate method is called to pass the file information to the delegate which should be able to appropriately handle and resolve the conflict. The delegate should, if needed, present the user with a conflict resolution interface. iCloud Document Sync does not need to know the result of the attempted resolution, it will continue to upload all files which are not conflicting. It is important to note that **this method may be called more than once in a very short period of time** - be prepared to handle the data appropriately. This delegate method is called on the main thread using GCD.
 */
- (void)iCloudFileUploadConflictWithCloudFile:(NSDictionary *)cloudFile andLocalFile:(NSDictionary *)localFile;



/** @name Deprecated Delegate Methods */


/** DEPRECATED. Called when there is an error while performing an iCloud process
 @param error An NSError with a message, error code, and information
 @deprecated Deprecated in version 6.1. use the NSError parameter available in corresponding methods' compeltion handlers. */
- (void)iCloudError:(NSError *)error __deprecated;

/** DEPRECATED. Tells the delegate that there was an error while performing a process
 @param error Returns the NSError that occured
 @deprecated Deprecated in version 6.0. Use the NSError parameter available in corresponding methods' compeltion handlers. */
- (void)cloudError:(NSError *)error __deprecated;

/** DEPRECATED. Tells the delegate that the files in iCloud have been modified
 @param files Returns a list of the files now in the app's iCloud documents directory - each file in the array contains information such as file version, url, localized name, date, etc.
 @param fileNames Returns a list of the file names now in the app's iCloud documents directory
 @deprecated Deprecated in version 6.0. Use iCloudFilesDidChange:withNewFileNames: instead. */
- (void)fileListChangedWithFiles:(NSMutableArray *)files andFileNames:(NSMutableArray *)fileNames __deprecated;

/** DEPRECATED. Tells the delegate that a document was successfully deleted. 
 @deprecated Deprecated in version 6.0. Use the completion handlers in deleteDocumentWithName:completion: instead. */
- (void)documentWasDeleted __deprecated;

/** DEPRECATED. Tells the delegate that a document was successfully saved
 @deprecated Deprecated in version 6.0. Use the completion handlers in saveDocumentWithName:withContent:completion: instead. */
- (void)documentWasSaved __deprecated;

/** DEPRECATED. Tells the delegate that a document finished uploading
 @deprecated Deprecated in version 6.0. Use the completion handlers in uploadLocalOfflineDocumentsWithDelegate:repeatingHandler:completion: instead. */
- (void)documentsFinishedUploading __deprecated;

/** DEPRECATED. Tells the delegate that a document started uploading
 @deprecated Deprecated in version 6.0. Delegate methods are no longer used to report method-specfic conditions and so this method is never called. Completion blocks are now used.  */
- (void)documentsStartedUploading __deprecated;

/** DEPRECATED. Tells the delegate that a document started downloading
 @deprecated Deprecated in version 6.0. Delegate methods are no longer used to report method-specfic conditions and so this method is never called. Completion blocks are now used.  */
- (void)documentsStartedDownloading __deprecated;

/** DEPRECATED. Tells the delegate that a document finished downloading
 @deprecated Deprecated in version 6.0. Delegate methods are no longer used to report method-specfic conditions and so this method is never called. Completion blocks are now used. */
- (void)documentsFinishedDownloading __deprecated;

@end