//
//  iCloud.h
//  iCloud Document Sync
//
//  Some portions of this project are based
//      off of the iCloudPlayground project
//
//  Created by iRare Media on 3/23/13. Updated November 2013
//
//

#import <Foundation/Foundation.h>
#import <iCloud/iCloudDocument.h>

#define DOCUMENT_DIRECTORY @"Documents"

/** iCloud Document Sync helps integrate iCloud into iOS (OS X coming soon) Objective-C document projects with one-line code methods. Sync, upload, manage, and remove documents to and from iCloud with only a few lines of code (compared to the hundreds of lines and hours that it usually takes). Updates and more details on this project can be found on [GitHub](http://www.github.com/iRareMedia/iCloudDocumentSync). If you like the project, please [star it](https://github.com/iRareMedia/iCloudDocumentSync) on GitHub!
 
 The `iCloud` class provides methods to integrate iCloud into document projects.
 
 <br />
 Adding iCloud Document Sync to your project is easy. Follow these steps below to get everything up and running.
 
 1. Drag the iCloud Framework into your project
 2. Add `#import <iCloud/iCloud.h>` to your header file(s) iCloud Document Sync
 3. Subscribe to the `<iCloudDelegate>` delegate.
 4. Call the following methods to setup iCloud when your app starts:
 
        iCloud *cloud = [iCloud sharedCloud]; // This will help to begin the sync process and register for document updates.
        [cloud setDelegate:self]; // Only set this if you plan to use the delegate
 
 
 @warning Only available on iOS 5.1 and later on apps with valid code signing and entitlements. Requires Xcode 5.0.1 and later. Check the online documentation for more information on setting up iCloud in your app. */
@class iCloud;
@protocol iCloudDelegate;
NS_CLASS_AVAILABLE_IOS(5_1) @interface iCloud : NSObject




/** @name Singleton */

/** iCloud shared instance object
 @return The shared instance of iCloud */
+ (id)sharedCloud;



/** @name Delegate */

/** iCloud Delegate helps call methods when document processes begin or end */
@property (weak, nonatomic) id <iCloudDelegate> delegate;



/** @name Properties */

/** The current NSMetadataQuery object */
@property (strong) NSMetadataQuery *query;

/** A list of iCloud files from the current query */
@property (strong) NSMutableArray *fileList;

/** A list of iCloud files from the previous query */
@property (strong) NSMutableArray *previousQueryResults;

/** Enable verbose logging for detailed feedback in the log. Turning this off only prints crucial log notes such as errors. */
@property BOOL verboseLogging;

/** Enable verbose availability logging for repeated feedback about iCloud availability in the log. Turning this off will prevent availability-related messages from being printed in the log. This property does not relate to the verboseLogging property. */
@property BOOL verboseAvailabilityLogging;



/** @name Checking for iCloud */

/** Check whether or not iCloud is available and that it can be accessed. Returns a boolean value.  
 
 @discussion You should always check if iCloud is available before performing any iCloud operations (every method checks to make sure iCloud is available before continuing). Additionally, you may want to check if your users want to opt-in to iCloud on a per-app basis (according to Apple's documentation, you should only ask the user once to opt-in to iCloud). The Return value could be **NO** (iCloud Unavailable) for one or more of the following reasons:
 
   - iCloud is turned off by the user
   - The entitlements profile, code signing identity, and/or provisioning profile is invalid
 
 This method uses the ubiquityIdentityToken to check if iCloud is available. The delegate method iCloudAvailabilityDidChangeToState:withUbiquityToken: can be used to automatically detect changes in the availability of iCloud. A ubiquity token is passed in that method which lets you know if the iCloud account has changed.
 
 @return YES if iCloud is available. NO if iCloud is not available. */
- (BOOL)checkCloudAvailability;

/** Check that the current application's iCloud Ubiquity Container is available. Returns a boolean value.
 
 @discussion This method may not return immediately, depending on a number of factors. It is not necessary to call this method directly, although it may become useful in certain situations.
 
 @return YES if the iCloud ubiquity container is available. NO if the ubiquity container is not available. */
- (BOOL)checkCloudUbiquityContainer;

/** Retrieve the current application's ubiquitous root URL

 @return An NSURL with the root iCloud Ubiquitous URL for the current app. May return nil if iCloud is not properly setup or available. */
- (NSURL *)ubiquitousContainerURL;

/** Retrieve the current application's ubiquitous documents directory URL
 
 @return An NSURL with the iCloud ubiquitous documents directory URL for the current app. May return nil if iCloud is not properly setup or available. */
- (NSURL *)ubiquitousDocumentsDirectoryURL;



/** @name Syncing with iCloud */

/** Check for and update the list of files stored in your app's iCloud Documents Folder. This method is automatically called by iOS when there are changes to files in the iCloud Directory. The iCloudFilesDidChange:withNewFileNames: delegate method is triggered by this method. */
- (void)updateFiles;

/** UNDER DEVELOPMENT. Upload a document to iCloud
 
 @warning This method is under development.
 
 @param name The name of the local document (stored in the app's documents directory) being uploaded to iCloud
 @param handler Code block called when the document changes are recorded. The completion block passes and NSError object which contains any error information if an error occurred, otherwise it will be nil. */
- (void)uploadLocalDocumentToCloudWithName:(NSString *)name completion:(void (^)(NSError *error))handler;

/** UNDER DEVELOPMENT. Download a document from iCloud
 
 @warning This method is under development.
 
 @param name The name of the iCloud document being downloaded from iCloud to the local documents directory
 @param handler Code block called when the document changes are recorded. The completion block passes and NSError object which contains any error information if an error occurred, otherwise it will be nil. */
- (void)downloadCloudDocumentWithName:(NSString *)name completion:(void (^)(NSError *error))handler;



/** @name Uploading to iCloud */

/** Create, save, and close a document in iCloud.
 
 @discussion First, iCloud Document Sync checks if the specified document exists. If the document exists it is saved and closed. If the document does not exist, it is created then closed.
 
 iCloud Document Sync uses UIDocument and NSData to store and manage files. All of the heavy lifting with NSData and UIDocument is handled for you. There's no need to actually create or manage any files, just give iCloud Document Sync your data, and the rest is done for you.
 
 To create a new document or save an existing one (close the document), use this method. Below is a code example of how to use it.
 
    [iCloud saveAndCloseDocumentWithName:@"Name.ext" withContent:[NSData data] completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
        if (error == nil) {
            // Code here to use the UIDocument or NSData objects which have been passed with the completion handler
        }
    }];
 
 Documents can be created even if the user is not connected to the internet. The only case in which a document will not be created is when the user has disabled iCloud or if the current application is not setup for iCloud.
 
 @param name The name of the document being written to iCloud
 @param content The data to write to the document
 @param handler Code block called when the document is successfully saved. The completion block passes UIDocument and NSData objects containing the saved document and it's contents in the form of NSData. The NSError object contains any error information if an error occurred, otherwise it will be nil. */
- (void)saveAndCloseDocumentWithName:(NSString *)name withContent:(NSData *)content completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler;

/** Record changes made to a document in iCloud. Changes are saved when the document is closed.
 
 @discussion First, iCloud Document Sync checks if the specified document exists. If the document exists then the changes are recorded. If the document does not exist it will be created and the change will be recorded.
 
 To record changes to a new document or an existing one, use this method. Below is a code example of how to use it.
 
    [iCloud saveDocumentChangesWithoutClosingWithName:@"Name.ext" withContent:[NSData data] completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
        if (error == nil) {
            // Code here to use the UIDocument or NSData objects which have been passed with the completion handler
        }
    }];
 
 Documents changes can be recorded even if the user is not connected to the internet. The only case in which a document will not be created is when the user has disabled iCloud or if the current application is not setup for iCloud.
 
 @param name The name of the document being written to iCloud
 @param content The data to write to the document
 @param handler Code block called when the document changes are recorded. The completion block passes UIDocument and NSData objects containing the saved document and it's contents in the form of NSData. The NSError object contains any error information if an error occurred, otherwise it will be nil. */
- (void)saveDocumentChangesWithoutClosingWithName:(NSString *)name withContent:(NSData *)content completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler;

/** Upload any local files that weren't created with iCloud
 
 @discussion Files in the local documents directory that do not already exist in iCloud will be **moved** into iCloud one by one. This process involves lots of file manipulation and as a result it may take a long time. This process will be performed on the background thread to avoid any lag or memory problems. When the upload processes end, the completion block is called on the main thread.
 
    [iCloud uploadLocalOfflineDocumentsWithDelegate:self repeatingHandler:^(NSString *fileName, NSError *error) {
        if (error == nil) {
            // This code block is called repeatedly until all files have been uploaded (or an upload has at least been attempted). 
            // Code here to use the NSString (the name of the uploaded file) which have been passed with the repeating handler
        }
     } completion:^{
         // Completion handler could be used to tell the user that the upload has completed
     }];
 
 The iCloudFileUploadConflictWithCloudFile:andLocalFile: delegate method is triggered by this method.
 
 @param repeatingHandler Code block called after each file is uploaded to iCloud. This block is called every-time a local file is uploaded, therefore it may be called multiple times. The NSError object contains any error information if an error occurred, otherwise it will be nil.
 @param completion Code block called after all files have been uploaded to iCloud. This block is only called once at the end of the method, regardless of any successes or failures that may have occurred during the upload(s). */
- (void)uploadLocalOfflineDocumentsWithRepeatingHandler:(void (^)(NSString *fileName, NSError *error))repeatingHandler completion:(void (^)(void))completion;



/** @name Sharing iCloud Content */

/** Share an iCloud document by uploading it to a public URL.
 
 @discussion Upload a document stored in iCloud for a certain amount of time.
 
 @param name The name of the iCloud file being uploaded to a public URL
 @param handler Code block called when the document is successfully uploaded. The completion block passes NSURL, NSDate, and NSError objects. The NSURL object is the public URL where the file is available at. The NSDate object is the date that the URL expires on. The NSError object contains any error information if an error occurred, otherwise it will be nil.
 
 @return The public URL where the file is available */
- (NSURL *)shareDocumentWithName:(NSString *)name completion:(void (^)(NSURL *sharedURL, NSDate *expirationDate, NSError *error))handler;



/** @name Deleting iCloud Content */

/** Delete a document from iCloud.
 
 @param name The name of the document to delete from iCloud
 @param handler Code block called when a file is successfully deleted from iCloud. The NSError object contains any error information if an error occurred, otherwise it will be nil. */
- (void)deleteDocumentWithName:(NSString *)name completion:(void (^)(NSError *error))handler;



/** @name Retrieving iCloud Content and Info */

/** Open a UIDocument stored in iCloud. If the document does not exist, a new blank document will be created using the documentName provided. You can use the doesFileExistInCloud: method to check if a file exists before calling this method.
 
 @discussion This method will attempt to open the specified document. If the file does not exist, a blank one will be created. The completion handler is called when the file is opened or created (either successfully or not). The completion handler contains a UIDocument, NSData, and NSError all of which contain information about the opened document.
 
    [iCloud retrieveCloudDocumentWithName:@"docName.ext" completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
        if (error == nil) {
            NSString *fileName = [cloudDocument.fileURL lastPathComponent];
            NSData *fileData = documentData;
        }
     }];
 
 @param documentName The name of the document in iCloud
 @param handler Code block called when the document is successfully retrieved (opened or downloaded). The completion block passes UIDocument and NSData objects containing the opened document and it's contents in the form of NSData. If there is an error, the NSError object will have an error message (may be nil if there is no error). */
- (void)retrieveCloudDocumentWithName:(NSString *)documentName completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler;

/** Check if a file exists in iCloud
 
 @param fileName The name of the UIDocument in iCloud
 @return BOOL value, YES if the file does exist in iCloud, NO if it does not */
- (BOOL)doesFileExistInCloud:(NSString *)fileName;

/** Get the size of a file stored in iCloud
 
 @param fileName The name of the file in iCloud
 @return The number of bytes in an unsigned long long. Returns nil if the file does not exist. */
- (NSNumber *)fileSize:(NSString *)fileName;

/** Get the last modified date of a file stored in iCloud
 
 @param fileName The name of the file in iCloud
 @return The date that the file was last modified. Returns nil if the file does not exist. */
- (NSDate *)fileModifiedDate:(NSString *)fileName;

/** Get the creation date of a file stored in iCloud
 
 @param fileName The name of the file in iCloud
 @return The date that the file was created. Returns nil if the file does not exist. */
- (NSDate *)fileCreatedDate:(NSString *)fileName;

/** Get the current document state of a file stored in iCloud
 
 @param fileName The name of the file in iCloud
 @return The document state that the file is currently in. Returns nil if the file does not exist. */
- (UIDocumentState)documentStateForFile:(NSString *)fileName;

/** Get a list of files stored in iCloud
 
 @return NSArray with a list of all the files currently stored in your app's iCloud Documents directory */
- (NSArray *)getListOfCloudFiles;



/** Managing iCloud Content */

/** UNDER DEVELOPMENT. Rename a document in iCloud
 
 @warning This method is under development.
 
 @param name The name of the document being renamed in iCloud
 @param newName The new name which the document should be renamed with
 @param handler Code block called when the document changes are recorded. The completion block passes and NSError object which contains any error information if an error occurred, otherwise it will be nil. */
- (void)renameOriginalDocument:(NSString *)name withNewName:(NSString *)newName completion:(void (^)(NSError *error))handler;

/** UNDER DEVELOPMENT. Duplicate a document in iCloud
 
 @warning This method is under development.
 
 @param name The name of the document being duplicated in iCloud
 @param newName The new name which the document should be duplicated to (usually the same name with the word "copy" appeneded to the end)
 @param handler Code block called when the document changes are recorded. The completion block passes and NSError object which contains any error information if an error occurred, otherwise it will be nil. */
- (void)duplicateOriginalDocument:(NSString *)name withNewName:(NSString *)newName completion:(void (^)(NSError *error))handler;

@end


@class iCloud;
/** The iCloudDelegate protocol defines the methods used to receive event notifications and allow for deeper control of the iCloud Class. */
@protocol iCloudDelegate <NSObject>


/** @name Optional Delegate Methods */

@optional

/** Called when the availability of iCloud changes
 
 @param cloudIsAvailable Boolean value that is YES if iCloud is available and NO if iCloud is not available 
 @param ubiquityToken An iCloud ubiquity token that represents the current iCloud identity. Can be used to determine if iCloud is available and if the iCloud account has been changed (ex. if the user logged out and then logged in with a different iCloud account). This object may be nil if iCloud is not available for any reason.
 @param ubiquityContainer The root URL path to the current application's ubiquity container. This URL may be nil until the ubiquity container is initialized. */
- (void)iCloudAvailabilityDidChangeToState:(BOOL)cloudIsAvailable withUbiquityToken:(id)ubiquityToken withUbiquityContainer:(NSURL *)ubiquityContainer;

/** Called before creating an iCloud Query filter. Specify the type of file to be queried. 
 
 @discussion If this delegate is not implemented or returns nil, all files stored in the documents directory will be queried.
 
 @return An NSString with one file extension formatted like this: @"txt" */
- (NSString *)iCloudQueryLimitedToFileExtension;

/** Tells the delegate that the files in iCloud have been modified
 
 @param files A list of the files now in the app's iCloud documents directory - each NSMetadataItem in the array contains information such as file version, url, localized name, date, etc.
 @param fileNames A list of the file names (NSString) now in the app's iCloud documents directory */
- (void)iCloudFilesDidChange:(NSMutableArray *)files withNewFileNames:(NSMutableArray *)fileNames;

/** Sent to the delegate where there is a conflict between a local file and an iCloud file during an upload
 
 @discussion When both files have the same modification date and file content, iCloud Document Sync will not be able to automatically determine how to handle the conflict. As a result, this delegate method is called to pass the file information to the delegate which should be able to appropriately handle and resolve the conflict. The delegate should, if needed, present the user with a conflict resolution interface. iCloud Document Sync does not need to know the result of the attempted resolution, it will continue to upload all files which are not conflicting. It is important to note that **this method may be called more than once in a very short period of time** - be prepared to handle the data appropriately. This delegate method is called on the main thread using GCD.
 
 @param cloudFile An NSDictionary with the cloud file and various other information. This parameter contains the fileContent as NSData, fileURL as NSURL, and modifiedDate as NSDate.
 @param localFile An NSDictionary with the local file and various other information. This parameter contains the fileContent as NSData, fileURL as NSURL, and modifiedDate as NSDate. */
- (void)iCloudFileUploadConflictWithCloudFile:(NSDictionary *)cloudFile andLocalFile:(NSDictionary *)localFile;



/** @name Deprecated Delegate Methods */


/** DEPRECATED. Called when there is an error while performing an iCloud process
 @param error An NSError with a message, error code, and information
 @deprecated Deprecated in version 6.1. use the NSError parameter available in corresponding methods' completion handlers. */
- (void)iCloudError:(NSError *)error __deprecated;

/** DEPRECATED. Tells the delegate that there was an error while performing a process
 @param error Returns the NSError that occurred
 @deprecated Deprecated in version 6.0. Use the NSError parameter available in corresponding methods' completion handlers. */
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
