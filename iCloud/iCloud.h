//
//  iCloud.h
//  iCloud Document Sync
//
//  Created by iRare Media. Last updated January 2015.
//  Available on GitHub. Licensed under MIT with Attribution.
//

// Check for Objective-C Modules
#if __has_feature(objc_modules)
    // We recommend enabling Objective-C Modules in your project Build Settings for numerous benefits over regular #imports. Read more from the Modules documentation: http://clang.llvm.org/docs/Modules.html
    @import Foundation;
    @import UIKit;
#else
    #import <Foundation/Foundation.h>
    #import <UIKit/UIKit.h>
#endif

// Import iCloudDocument
#import "iCloudDocument.h"

// Ensure that the build is for iOS 6.0 or higher
#ifndef __IPHONE_6_0
    #error iCloudDocumentSync is built with features only available is iOS SDK 6.0 and later.
#endif

// Create a constant for accessing the documents directory
#define DOCUMENT_DIRECTORY @"Documents"


/** iCloud Document Sync makes it easy for developers to integrate the iCloud document storage APIs into iOS applications. This is how iCloud document-storage and management should've been out of the box from Apple. Integrate iCloud into iOS (OS X coming soon) Objective-C document projects with one-line code methods. Sync, upload, manage, and remove documents to and from iCloud with only a few lines of code (compared to the hundreds of lines and hours that it usually takes). Get iCloud up and running in your iOS app in only a few minutes. Updates and more details on this project can be found on [GitHub](http://www.github.com/iRareMedia/iCloudDocumentSync). If you like the project, please star it on GitHub!
 
 The `iCloud` class provides methods to integrate iCloud into document projects.
 
 Adding iCloud Document Sync to your project is easy. Follow these steps below to get everything up and running.
 
 1. Drag the iCloud Framework into your project
 2. Add `#import <iCloud/iCloud.h>` to your header file(s) iCloud Document Sync
 3. Subscribe to the `<iCloudDelegate>` delegate.
 4. Call the following methods to setup iCloud when your app starts:
 
    [[iCloud sharedCloud] setDelegate:self]; // Set this if you plan to use the delegate
    [[iCloud sharedCloud] setVerboseLogging:YES]; // We want detailed feedback about what's going on with iCloud, this is OFF by default
    [[iCloud sharedCloud] updateFiles]; // Force iCloud Update: This is done automatically when changes are made, but we want to make sure the view is always updated when presented
 
 
 @warning Only available on iOS 6.0 and later on apps with valid code signing and entitlements. Requires Xcode 5.0.1 and later. Check the online documentation for more information on setting up iCloud in your app. */
@class iCloud;
@protocol iCloudDelegate;
NS_CLASS_AVAILABLE_IOS(6_0) @interface iCloud : NSObject



/** @name Singleton */

/** iCloud shared instance object
 @return The shared instance of iCloud */
+ (instancetype)sharedCloud;

/** Setup iCloud Document Sync and begin the initial document syncing process.
 
 @discussion You \b must call this method before using iCloud Document Sync to avoid potential issues with syncing. This setup process ensures that all variables are initialized. A preliminary file sync will be performed when this method is called.
 
 @param containerID The fully-qualified container identifier for an iCloud container directory. The string you specify must not contain wildcards and must be of the form <TEAMID>.<CONTAINER>, where <TEAMID> is your development team ID and <CONTAINER> is the bundle identifier of the container you want to access.
 The container identifiers for your app must be declared in the com.apple.developer.ubiquity-container-identifiers array of the .entitlements property list file in your Xcode project.
 If you specify nil for this parameter, this method uses the first container listed in the com.apple.developer.ubiquity-container-identifiers entitlement array. */
- (void)setupiCloudDocumentSyncWithUbiquityContainer:(NSString *)containerID;



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
 
 This method uses the ubiquityIdentityToken to check if iCloud is available. The delegate method iCloudAvailabilityDidChangeToState:withUbiquityToken:withUbiquityContainer: can be used to automatically detect changes in the availability of iCloud. A ubiquity token is passed in that method which lets you know if the iCloud account has changed.
 
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
 
 @warning If iCloud is not properly setup, this method will return the local (non-ubiquitous) documents directory. This may cause other document handling methods to return nil values. Ensure that iCloud is properly setup \b before calling any document handling methods.
 
 @return An NSURL with the iCloud ubiquitous documents directory URL for the current app. Returns the local documents directory if iCloud is not properly setup or available. */
- (NSURL *)ubiquitousDocumentsDirectoryURL;



/** @name Syncing with iCloud */

/** Check for and update the list of files stored in your app's iCloud Documents Folder. This method is automatically called by iOS when there are changes to files in the iCloud Directory. The iCloudFilesDidChange:withNewFileNames: delegate method is triggered by this method. */
- (void)updateFiles;


/** @name Uploading to iCloud */

/** Create, save, and close a document in iCloud.
 
 @discussion First, iCloud Document Sync checks if the specified document exists. If the document exists it is saved and closed. If the document does not exist, it is created then closed.
 
 iCloud Document Sync uses UIDocument and NSData to store and manage files. All of the heavy lifting with NSData and UIDocument is handled for you. There's no need to actually create or manage any files, just give iCloud Document Sync your data, and the rest is done for you.
 
 To create a new document or save an existing one (close the document), use this method. Below is a code example of how to use it.
 
    [[iCloud sharedCloud] saveAndCloseDocumentWithName:@"Name.ext" withContent:[NSData data] completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
        if (error == nil) {
            // Code here to use the UIDocument or NSData objects which have been passed with the completion handler
        }
    }];
 
 Documents can be created even if the user is not connected to the internet. The only case in which a document will not be created is when the user has disabled iCloud or if the current application is not setup for iCloud.
 
 @param documentName The name of the document being written to iCloud. This value must not be nil.
 @param content The data to write to the document
 @param handler Code block called when the document is successfully saved. The completion block passes UIDocument and NSData objects containing the saved document and it's contents in the form of NSData. The NSError object contains any error information if an error occurred, otherwise it will be nil. */
- (void)saveAndCloseDocumentWithName:(NSString *)documentName withContent:(NSData *)content completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler __attribute__((nonnull));

/** Upload any local files that weren't created with iCloud
 
 @discussion Files in the local documents directory that do not already exist in iCloud will be **moved** into iCloud one by one. This process involves lots of file manipulation and as a result it may take a long time. This process will be performed on the background thread to avoid any lag or memory problems. When the upload processes end, the completion block is called on the main thread.
 
    [[iCloud sharedCloud] uploadLocalOfflineDocumentsWithRepeatingHandler:^(NSString *documentName, NSError *error) {
        if (error == nil) {
            // This code block is called repeatedly until all files have been uploaded (or an upload has at least been attempted). 
            // Code here to use the NSString (the name of the uploaded file) which have been passed with the repeating handler
        }
     } completion:^{
         // Completion handler could be used to tell the user that the upload has completed
     }];
 
 This method may call the iCloudFileConflictBetweenCloudFile:andLocalFile: iCloud Delegate method if there is a file conflict.
 
 @param repeatingHandler Code block called after each file is uploaded to iCloud. This block is called every-time a local file is uploaded, therefore it may be called multiple times. The NSError object contains any error information if an error occurred, otherwise it will be nil.
 @param completion Code block called after all files have been uploaded to iCloud. This block is only called once at the end of the method, regardless of any successes or failures that may have occurred during the upload(s). */
- (void)uploadLocalOfflineDocumentsWithRepeatingHandler:(void (^)(NSString *documentName, NSError *error))repeatingHandler completion:(void (^)(void))completion __attribute__((nonnull (1)));

/** Upload a local file to iCloud
 
 @param documentName The name of the local file stored in the application's documents directory. This value must not be nil.
 @param handler Code block called after the file has been uploaded to iCloud */
- (void)uploadLocalDocumentToCloudWithName:(NSString *)documentName completion:(void (^)(NSError *error))handler __attribute__((nonnull));



/** @name Sharing iCloud Content */

/** Share an iCloud document by uploading it to a public URL.
 
 @discussion Upload a document stored in iCloud to a public location on the internet for a limited amount of time.
 
 @param documentName The name of the iCloud file being uploaded to a public URL. This value must not be nil.
 @param handler Code block called when the document is successfully uploaded. The completion block passes NSURL, NSDate, and NSError objects. The NSURL object is the public URL where the file is available at, could be nil. The NSDate object is the date that the URL expires on, could be nil. The NSError object contains any error information if an error occurred, otherwise it will be nil.
 
 @return The public URL where the file is available */
- (NSURL *)shareDocumentWithName:(NSString *)documentName completion:(void (^)(NSURL *sharedURL, NSDate *expirationDate, NSError *error))handler __attribute__((nonnull));



/** @name Deleting iCloud Content */

/** Delete a document from iCloud.
 
 @discussion Permanently delete a document stored in iCloud. This will only affect copies of the specified file stored in iCloud, if there is a copy stored locally it will not be affected.
 
 @param documentName The name of the document to delete from iCloud. This value must not be nil.
 @param handler Code block called when a file is successfully deleted from iCloud. The NSError object contains any error information if an error occurred, otherwise it will be nil. */
- (void)deleteDocumentWithName:(NSString *)documentName completion:(void (^)(NSError *error))handler __attribute__((nonnull (1)));

/** Evict a document from iCloud, move it from iCloud to the current application's local documents directory.
 
 @discussion Remove a document from iCloud storage and move it into the local document's directory. This method may call the iCloudFileConflictBetweenCloudFile:andLocalFile: iCloud Delegate method if there is a file conflict.
 
 @param documentName The name of the iCloud document being downloaded from iCloud to the local documents directory. This value must not be nil.
 @param handler Code block called after the file has been uploaded to iCloud. This value must not be nil. */
- (void)evictCloudDocumentWithName:(NSString *)documentName completion:(void (^)(NSError *error))handler __attribute__((nonnull));



/** @name Retrieving iCloud Content and Info */

/** Open a UIDocument stored in iCloud. If the document does not exist, a new blank document will be created using the documentName provided. You can use the doesFileExistInCloud: method to check if a file exists before calling this method.
 
 @discussion This method will attempt to open the specified document. If the file does not exist, a blank one will be created. The completion handler is called when the file is opened or created (either successfully or not). The completion handler contains a UIDocument, NSData, and NSError all of which contain information about the opened document.
 
    [[iCloud sharedCloud] retrieveCloudDocumentWithName:@"docName.ext" completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
        if (error == nil) {
            NSString *documentName = [cloudDocument.fileURL lastPathComponent];
            NSData *fileData = documentData;
        }
     }];
 
 @param documentName The name of the document in iCloud. This value must not be nil.
 @param handler Code block called when the document is successfully retrieved (opened or downloaded). The completion block passes UIDocument and NSData objects containing the opened document and it's contents in the form of NSData. If there is an error, the NSError object will have an error message (may be nil if there is no error). This value must not be nil. */
- (void)retrieveCloudDocumentWithName:(NSString *)documentName completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler __attribute__((nonnull));

/** Get the relevant iCloudDocument object for the specified file
 
 @discussion This method serves a very different purpose from the retrieveCloudDocumentWithName:completion: method. Understand the differences between both methods and ensure that you are using the correct one. This method does not open, create, or save any UIDocuments - it simply returns the iCloudDocument object which you can then use for various purposes.
 
 @param documentName The name of the UIDocument stored in iCloud. This value must not be nil.
 @return An iCloudDocument (UIDocument subclass) object. May return nil if iCloud is unavailable or if an error occurred */
- (iCloudDocument *)retrieveCloudDocumentObjectWithName:(NSString *)documentName __attribute__((nonnull));

/** Check if a file exists in iCloud
 
 @param documentName The name of the UIDocument in iCloud. This value must not be nil.
 @return BOOL value, YES if the file does exist in iCloud, NO if it does not. May return NO if iCloud is unavailable. */
- (BOOL)doesFileExistInCloud:(NSString *)documentName __attribute__((nonnull));

/** Get the size of a file stored in iCloud
 
 @param documentName The name of the file in iCloud. This value must not be nil.
 @return The number of bytes in an unsigned long long. Returns nil if the file does not exist. May return a nil value if iCloud is unavailable. */
- (NSNumber *)fileSize:(NSString *)documentName __attribute__((nonnull));

/** Get the last modified date of a file stored in iCloud
 
 @param documentName The name of the file in iCloud. This value must not be nil.
 @return The date that the file was last modified. Returns nil if the file does not exist. May return a nil value if iCloud is unavailable. */
- (NSDate *)fileModifiedDate:(NSString *)documentName __attribute__((nonnull));

/** Get the creation date of a file stored in iCloud
 
 @param documentName The name of the file in iCloud. This value must not be nil.
 @return The date that the file was created. Returns nil if the file does not exist. May return a nil value if iCloud is unavailable. */
- (NSDate *)fileCreatedDate:(NSString *)documentName __attribute__((nonnull));

/** Get a list of files stored in iCloud
 
 @return NSArray with a list of all the files currently stored in your app's iCloud Documents directory. May return a nil value if iCloud is unavailable. */
- (NSArray *)listCloudFiles;



/** @name Managing iCloud Content */

/** Rename a document in iCloud
 
 @param documentName The name of the document being renamed in iCloud. The file specified should exist, otherwise an error will occur. This value must not be nil.
 @param newName The new name which the document should be renamed with. The file specified should not exist, otherwise an error will occur. This value must not be nil.
 @param handler Code block called when the document renaming has completed. The completion block passes and NSError object which contains any error information if an error occurred, otherwise it will be nil. */
- (void)renameOriginalDocument:(NSString *)documentName withNewName:(NSString *)newName completion:(void (^)(NSError *error))handler __attribute__((nonnull));

/** Duplicate a document in iCloud
 
 @param documentName The name of the document being duplicated in iCloud. The file specified should exist, otherwise an error will occur. This value must not be nil.
 @param newName The new name which the document should be duplicated to (usually the same name with the word "copy" appended to the end). The file specified should not exist, otherwise an error will occur. This value must not be nil.
 @param handler Code block called when the document duplication has completed. The completion block passes and NSError object which contains any error information if an error occurred, otherwise it will be nil. */
- (void)duplicateOriginalDocument:(NSString *)documentName withNewName:(NSString *)newName completion:(void (^)(NSError *error))handler __attribute__((nonnull));



/** @name iCloud Document State */

/** Get the current document state of a file stored in iCloud
 
 @param documentName The name of the file in iCloud. This value must not be nil.
 @param handler Completion handler that passes three parameters, an NSError, NSString and a UIDocumentState. The documentState parameter represents the document state that the specified file is currently in (may be nil if the file does not exist). The userReadableDocumentState parameter is an NSString which succinctly describes the current document state; if the file does not exist, a non-scary error will be displayed. The NSError parameter will contain a 404 error if the file does not exist. */
- (void)documentStateForFile:(NSString *)documentName completion:(void (^)(UIDocumentState *documentState, NSString *userReadableDocumentState, NSError *error))handler __attribute__((nonnull));

/** Monitor changes in the state of a document stored in iCloud
 
 @param documentName The name of the file in iCloud. This value must not be nil.
 @param sender Object registering as an observer. This value must not be nil.
 @param selector Selector to be called when the document state changes. Must only have one argument, an instance of NSNotifcation whose object is an iCloudDocument (UIDocument subclass). This value must not be nil. 
 @return YES if the monitoring was successfully setup, NO if there was an issue setting up the monitoring. */
- (BOOL)monitorDocumentStateForFile:(NSString *)documentName onTarget:(id)sender withSelector:(SEL)selector __attribute__((nonnull));

/** Stop monitoring changes to the state of a document stored in iCloud
 
 @param documentName The name of the file in iCloud. This value must not be nil.
 @param sender Object registered as an observer that will no longer receive document state updates. This value must not be nil.
 @return YES if the monitoring was successfully setup, NO if there was an issue setting up the monitoring. */
- (BOOL)stopMonitoringDocumentStateChangesForFile:(NSString *)documentName onTarget:(id)sender __attribute__((nonnull));



/** @name Resolving iCloud Conflicts */

/** Find all the conflicting versions of a specified document
 
 @param documentName The name of the file in iCloud. This value must not be nil.
 @return An array of NSFileVersion objects, or nil if no such version object exists. */
- (NSArray *)findUnresolvedConflictingVersionsOfFile:(NSString *)documentName __attribute__((nonnull));

/** Resolve a document conflict for a file stored in iCloud
 
 @abstract Your application can follow one of three strategies for resolving document-version conflicts:
 
 * Merge the changes from the conflicting versions.
 * Choose one of the document versions based on some pertinent factor, such as the version with the latest modification date.
 * Enable the user to view conflicting versions of a document and select the one to use.
 
 @param documentName The name of the file in iCloud. This value must not be nil.
 @param documentVersion The version of the document which should be kept and saved. All other conflicting versions will be removed. */
- (void)resolveConflictForFile:(NSString *)documentName withSelectedFileVersion:(NSFileVersion *)documentVersion __attribute__((nonnull));



/** @name Deprecated Methods */

/** DEPRECATED. Use listCloudFiles instead. Get a list of files stored in iCloud
 
 @deprecated Deprecated in version 7.3. Use listCloudFiles instead.
 @return NSArray with a list of all the files currently stored in your app's iCloud Documents directory. May return a nil value if iCloud is unavailable. */
- (NSArray *)getListOfCloudFiles __attribute((deprecated(" use listCloudFiles instead.")));

/** DEPRECATED. Use saveAndCloseDocumentWithName:withContent:completion: instead. Record changes made to a document in iCloud. Changes are saved when the document is closed.
 
 @deprecated Deprecated beginning in version 7.1. Use saveAndCloseDocumentWithName:withContent:completion: instead. This method may become unavailable in a future version.
 
 @param documentName The name of the document being written to iCloud. This value must not be nil.
 @param content The data to write to the document
 @param handler Code block called when the document changes are recorded. The completion block passes UIDocument and NSData objects containing the saved document and it's contents in the form of NSData. The NSError object contains any error information if an error occurred, otherwise it will be nil. */
- (void)saveChangesToDocumentWithName:(NSString *)documentName withContent:(NSData *)content completion:(void (^)(UIDocument *cloudDocument, NSData *documentData, NSError *error))handler __attribute__((nonnull)) __deprecated;

/** DEPRECATED. Use uploadLocalOfflineDocuments instead, like so: [[iCloud sharedCloud] uploadLocalOfflineDocuments];
 
 @deprecated Deprecated in version 7.0. Use uploadLocalOfflineDocuments instead.
 @param delegate The iCloudDelegate object to be used for delegate notifications */
+ (void)uploadLocalOfflineDocumentsWithDelegate:(id<iCloudDelegate>)delegate __deprecated;

/** DEPRECATED. Use updateFiles instead, like so: [[iCloud sharedCloud] updateFiles];
 
 @deprecated Deprecated in version 7.0. Use updateFiles instead.
 @param delegate The iCloudDelegate object to be used for delegate notifications */
+ (void)updateFilesWithDelegate:(id<iCloudDelegate>)delegate __deprecated;

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


/** Called when the iCloud initiaization process is finished and the iCloud is available
 
 @param cloudToken An iCloud ubiquity token that represents the current iCloud identity. Can be used to determine if iCloud is available and if the iCloud account has been changed (ex. if the user logged out and then logged in with a different iCloud account). This object may be nil if iCloud is not available for any reason.
 @param ubiquityContainer The root URL path to the current application's ubiquity container. This URL may be nil until the ubiquity container is initialized. */
- (void)iCloudDidFinishInitializingWitUbiquityToken:(id)cloudToken withUbiquityContainer:(NSURL *)ubiquityContainer;



/** Called before creating an iCloud Query filter. Specify the type of file to be queried. 
 
 @discussion If this delegate is not implemented or returns nil, all files stored in the documents directory will be queried.
 
 @return An NSString with one file extension formatted like this: @"txt" */
- (NSString *)iCloudQueryLimitedToFileExtension;


/** Called before an iCloud Query begins.
 @discussion This may be useful to display interface updates. */
- (void)iCloudFileUpdateDidBegin;


/** Called when an iCloud Query ends.
 @discussion This may be useful to display interface updates. */
- (void)iCloudFileUpdateDidEnd;


/** Tells the delegate that the files in iCloud have been modified
 
 @param files A list of the files now in the app's iCloud documents directory - each NSMetadataItem in the array contains information such as file version, url, localized name, date, etc.
 @param fileNames A list of the file names (NSString) now in the app's iCloud documents directory */
- (void)iCloudFilesDidChange:(NSMutableArray *)files withNewFileNames:(NSMutableArray *)fileNames;


/** Sent to the delegate where there is a conflict between a local file and an iCloud file during an upload or download
 
 @discussion When both files have the same modification date and file content, iCloud Document Sync will not be able to automatically determine how to handle the conflict. As a result, this delegate method is called to pass the file information to the delegate which should be able to appropriately handle and resolve the conflict. The delegate should, if needed, present the user with a conflict resolution interface. iCloud Document Sync does not need to know the result of the attempted resolution, it will continue to upload all files which are not conflicting. 
 
 It is important to note that **this method may be called more than once in a very short period of time** - be prepared to handle the data appropriately.
 
 The delegate is only notified about conflicts during upload and download procedures with iCloud. This method does not monitor for document conflicts between documents which already exist in iCloud. There are other methods provided to you to detect document state and state changes / conflicts.
 
 @param cloudFile An NSDictionary with the cloud file and various other information. This parameter contains the fileContent as NSData, fileURL as NSURL, and modifiedDate as NSDate.
 @param localFile An NSDictionary with the local file and various other information. This parameter contains the fileContent as NSData, fileURL as NSURL, and modifiedDate as NSDate. */
- (void)iCloudFileConflictBetweenCloudFile:(NSDictionary *)cloudFile andLocalFile:(NSDictionary *)localFile;




/** @name Deprecated Delegate Methods */


/** DEPRECATED. Sent to the delegate where there is a conflict between a local file and an iCloud file during an upload
 
 @deprecated Deprecated in version 7.0. Use iCloudFileConflictBetweenCloudFile:andLocalFile: instead.
 
 @param cloudFile An NSDictionary with the cloud file and various other information. This parameter contains the fileContent as NSData, fileURL as NSURL, and modifiedDate as NSDate.
 @param localFile An NSDictionary with the local file and various other information. This parameter contains the fileContent as NSData, fileURL as NSURL, and modifiedDate as NSDate. */
- (void)iCloudFileUploadConflictWithCloudFile:(NSDictionary *)cloudFile andLocalFile:(NSDictionary *)localFile __deprecated;


/** DEPRECATED. Called when there is an error while performing an iCloud process
 
 @deprecated Deprecated in version 6.1. Use the NSError parameter available in corresponding methods' completion handlers.
 @param error An NSError with a message, error code, and information */
- (void)iCloudError:(NSError *)error __deprecated __unavailable;

/** DEPRECATED. Tells the delegate that there was an error while performing a process
 
 @deprecated Deprecated in version 6.0. Use the NSError parameter available in corresponding methods' completion handlers.
 @param error Returns the NSError that occurred */
- (void)cloudError:(NSError *)error __deprecated __unavailable;

/** DEPRECATED. Tells the delegate that the files in iCloud have been modified
 
 @deprecated Deprecated in version 6.0. Use iCloudFilesDidChange:withNewFileNames: instead.
 
 @param files Returns a list of the files now in the app's iCloud documents directory - each file in the array contains information such as file version, url, localized name, date, etc.
 @param fileNames Returns a list of the file names now in the app's iCloud documents directory */
- (void)fileListChangedWithFiles:(NSMutableArray *)files andFileNames:(NSMutableArray *)fileNames __deprecated __unavailable;

/** DEPRECATED. Tells the delegate that a document was successfully deleted.
 @deprecated Deprecated in version 6.0. To be removed in version 8.0. Use the completion handlers in deleteDocumentWithName:completion: instead. */
- (void)documentWasDeleted __deprecated __unavailable;

/** DEPRECATED. Tells the delegate that a document was successfully saved
 @deprecated Deprecated in version 6.0. To be removed in version 8.0. Use the completion handlers in saveDocumentWithName:withContent:completion: instead. */
- (void)documentWasSaved __deprecated __unavailable;

/** DEPRECATED. Tells the delegate that a document finished uploading
 @deprecated Deprecated in version 6.0. To be removed in version 8.0. Use the completion handlers in uploadLocalOfflineDocumentsWithDelegate:repeatingHandler:completion: instead. */
- (void)documentsFinishedUploading __deprecated __unavailable;

/** DEPRECATED. Tells the delegate that a document started uploading
 @deprecated Deprecated in version 6.0. To be removed in version 8.0. Delegate methods are no longer used to report method-specfic conditions and so this method is never called. Completion blocks are now used.  */
- (void)documentsStartedUploading __deprecated __unavailable;

/** DEPRECATED. Tells the delegate that a document started downloading
 @deprecated Deprecated in version 6.0. To be removed in version 8.0. Delegate methods are no longer used to report method-specfic conditions and so this method is never called. Completion blocks are now used.  */
- (void)documentsStartedDownloading __deprecated __unavailable;

/** DEPRECATED. Tells the delegate that a document finished downloading
 @deprecated Deprecated in version 6.0. To be removed in version 8.0. Delegate methods are no longer used to report method-specfic conditions and so this method is never called. Completion blocks are now used. */
- (void)documentsFinishedDownloading __deprecated __unavailable;



@end
