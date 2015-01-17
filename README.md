<img width=725 src="https://raw.githubusercontent.com/iRareMedia/iCloudDocumentSync/master/iCloud%20App%20-%20iOS/CloudBanner.png"/>

iCloud Document Sync makes it easy for developers to integrate the iCloud document storage APIs into iOS applications. This is how iCloud document-storage and management should've been out of the box from Apple. Integrate iCloud into iOS (OS X coming soon) Objective-C document projects with one-line code methods. Sync, upload, manage, and remove documents to and from iCloud with only  a few lines of code (compared to the hundreds of lines and hours that it usually takes). Get iCloud up and running in your iOS app in only a few minutes.

If you like the project, please [star it](https://github.com/iRareMedia/iCloudDocumentSync) on GitHub! Watch the project on GitHub for updates. If you use iCloud Document Sync in your app, send an email to contact[at]iraremedia.com or let us know on Twitter @iRareMedia.

# Project Features
iCloud Document Sync is a great way to use iCloud document storage in your iOS app. Below are a few key project features and highlights.
* Sync, Upload, Read, Write, Share, Save, Remove, and Edit any iCloud document in only one line of code.  
* Just drag and drop the iCloud Framework (`iCloud.framework`) into your project and you can begin using iCloud - no complicated setup  
* Access in-depth documentation with docsets, code comments, and verbose logging  
* Useful delegate methods and properties let you access and manage advanced iCloud features
* Manage any kind of file with iCloud through use of NSData  
* iOS Sample-app to illustrate how easy it is to use iCloud Document Sync
* Frequent updates to the project based on user issues and requests  
* Easily contribute to the project

## Table of Contents

* [**Project Information**](#project-information)
  * [Requirements](#requirements)
  * [License](#license)
  * [Contributions](#contributions)
  * [Sample App](#sample-app)
* [**Installation**](#installation)
  * [Cocoapods](#cocoapods-setup)
  * [Framework](#frameworks-setup)
  * [Traditional](#traditional-setup)
  * [Swift Projects](#swift-projects-setup)
* [**Setup**](#setup)
* [**Documentation**](#documentation)
  * [Methods](#methods)
  * [Delegate](#delegate)

# Project Information
Learn more about the project requirements, licensing, and contributions.

## Requirements
Requires Xcode 5.0.1+ for use in any iOS Project. Requires a minimum of iOS 6.0 as the deployment target. 

| Current Build Target 	| Earliest Supported Build Target 	| Earliest Compatible Build Target 	|
|:--------------------:	|:-------------------------------:	|:--------------------------------:	|
|       iOS 8.1        	|            iOS 7.0              	|             iOS 6.0              	|
|     Xcode 6.1.1      	|          Xcode 5.1.1            	|           Xcode 5.0.1            	|
|      LLVM 6.0        	|             LLVM 5.0            	|             LLVM 5.0             	|

> REQUIREMENTS NOTE  
*Supported* means that the library has been tested with this version. *Compatible* means that the library should work on this OS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.

## License 
This project is licensed under the MIT License. See the [full iCloud Document Sync license here](https://github.com/iRareMedia/iCloudDocumentSync/blob/master/LICENSE.md).

Attribution is not required, but it appreciated. We have spent a lot of time, energy, and resources working on this project - so a little *Thanks!* (or something to that affect) would be much appreciated. If you use iCloud Document Sync in your app, send an email to contact@iraremedia.com or let us know on Twitter @iRareMedia.

## Contributions
Any contribution is more than welcome! You can contribute through pull requests and issues on GitHub. Learn more [about contributing to the project here](https://github.com/iRareMedia/iCloudDocumentSync/blob/master/CONTRIBUTING.md).

## Sample App
The iOS Sample App included with this project demonstrates how to use many of the features in iCloud Document Sync. You can refer to the sample app for an understanding of how to use and setup iCloud Document Sync. The app should work with iCloud as-is (you may need to provide your own Bundle ID though).

<img width=700 src="https://raw.github.com/iRareMedia/iCloudDocumentSync/master/iCloud%20App%20-%20iOS/AppBanner.png"/>

# Installation
Adding iCloud Document Sync to your project is easy. There are multiple ways to add iCloud Document Sync to your project. Choose the process below which best suits your needs. Follow the steps to get everything up and running in only a few minutes.

### Cocoapods Setup
The easiest way to install iCloud Document Sync is to use CocoaPods. To do so, simply add the following line to your Podfile:

    pod iCloudDocumentSync

### Framework Setup
The iCloud.framework can be retrieved in two different ways:  
 1. Clone the project to your computer and build the *Framework* target. The `iCloud.framework` file will be copied to the project directory. Drag and drop the `.framework` file into your project.  
 2. Download your preferred iCloud Document Sync Framework release from the [Project Releases](https://github.com/iRareMedia/iCloudDocumentSync/releases) section. Frameworks are available as far back as version 7.0. Unzip then drag and drop the `.framework` file into your project.   

### Traditional Setup
Drag and drop the *iCloud* folder into your Xcode project. When you do so, check the "Copy items into destination group's folder" box. Delete the `iCloud-Prefix.pch` file. 

### Swift Project Setup
To use iCloud Document Sync in a Swift project, you must create a [bridging header](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/BuildingCocoaApps/MixandMatch.html). 

If you already have a bridging header, simply import `iCloud.h` (use the `#import <iCloud/iCloud.h>` syntax when importing the framework, otherwise use `#import "iCloud.h"`). 

If you do not already have a bridging header, install iCloud Document Sync into your project using any of the above processes. When adding the files to Xcode, you will be prompted to create a bridging header - create one. Then, import iCloud Document Sync (see paragraph above).

# Setup
After installing iCloud Document Sync, it only takes a few lines of code to get it up an running.  
  1. Import iCloud (see relevant install instructions above) to your header file(s).  
  2. Subscribe to the `<iCloudDelegate>` delegate.  
  3. Set the delegate and optionally enable verbose logging:  
   
        [[iCloud sharedCloud] setDelegate:self]; // Set this if you plan to use the delegate
        [[iCloud sharedCloud] setVerboseLogging:YES]; // We want detailed feedback about what's going on with iCloud, this is OFF by default
  4. Setup iCloud when your app starts. It is crucial that you call this method before doing any document handling operations. You can either pass a specific Ubiquity Container ID (see your entitlements file) or `nil` to use the first Ubiquity Container ID in your entitlements.  

        [[iCloud sharedCloud] setupiCloudDocumentSyncWithUbiquityContainer:nil];   
  5. It is recommended that the first call to `iCloud` is `setDelegate`, this way all subsequent operations and method calls can interact with the delegate and provide appropriate information.

# Documentation
Key methods, properties, types, and delegate methods available on the iCloud class are documented below. If you're using [Xcode 5](https://developer.apple.com/technologies/tools/whats-new.html) with iCloud Document Sync, documentation is available directly within Xcode (just Option-Click any method for Quick Help). For more advanced documentation please install the docset included with this project. This will allow you to view iCloud Document Sync documentation inside of Xcode's Organizer Window. Additional documentation can also be found on the Wiki page (including how to register your app for iCloud, iCloud fundamentals, etc.).   

## Methods
There are many methods available on iCloud Document Sync. The most important / highlight methods are documented below. All other methods are documented in the docset and with in-code comments.

### Checking for iCloud Availability
iCloud Document Sync checks for iCloud availability before performing any iCloud-related operations. Any iCloud Document Sync methods may return prematurely and without warning if iCloud is unavailable. Therefore, you should always check if iCloud is available before performing any iCloud operations.

    BOOL cloudIsAvailable = [[iCloud sharedCloud] checkCloudAvailability];
    if (cloudIsAvailable) {
        //YES
    }

This checks if iCloud is available by looking for the application's ubiquity token. It returns a boolean value; YES if iCloud is available, and NO if it is not. Check the log / documentation for details on why it may not be available. You can also check for the availability of the iCloud ubiquity *container* by calling the following method:

    BOOL cloudContainerIsAvailable = [[iCloud sharedCloud] checkCloudUbiquityContainer];

The `checkCloudAvailability` method will call the `iCloudAvailabilityDidChangeToState: withUbiquityToken: withUbiquityContainer:` delegate method. 

### Syncing Documents
To get iCloud Document Sync to initialize for the first time, and continue to update when there are changes you'll need to initialize iCloud. By initializing iCloud, it will start syncing with iCloud for the first time and in the future.  

    [[iCloud sharedCloud] init];

You can manually fetch changes from iCloud too:

    [[iCloud sharedCloud] updateFiles];

iCloud Document Sync will automatically detect changes in iCloud documents. When something changes the delegate method below is fired and will pass an NSMutableArray of all the files (NSMetadata Items) and their names (NSStrings) stored in iCloud.

    - (void)iCloudFilesDidChange:(NSMutableArray *)files withNewFileNames:(NSMutableArray *)fileNames

### Uploading Documents
iCloud Document Sync uses UIDocument and NSData to store and manage files. All of the heavy lifting with NSData and UIDocument is handled for you. There's no need to actually create or manage any files, just give iCloud Document Sync your data, and the rest is done for you.

To create a new document or save and close an existing one, use the method below.

    [[iCloud sharedCloud] saveAndCloseDocumentWithName:@"Name.ext" withContent:[NSData data] completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
        if (error == nil) {
            // Code here to use the UIDocument or NSData objects which have been passed with the completion handler
        }
    }];

The completion handler will be called when a document is saved or created. The completion handler has a UIDocument and NSData parameter that contain the document and it's contents. The third parameter is an NSError that will contain an error if one occurs, otherwise it will be `nil`.

You can also upload any documents created while offline, or locally.  Files in the local documents directory that do not already exist in iCloud will be **moved** into iCloud one by one. This process involves lots of file manipulation and as a result it may take a long time. This process will be performed on the background thread to avoid any lag or memory problems. When the upload processes end, the completion block is called on the main thread.

    [[iCloud sharedCloud] uploadLocalOfflineDocumentsWithRepeatingHandler:^(NSString *fileName, NSError *error) {
        if (error == nil) {
            // This code block is called repeatedly until all files have been uploaded (or an upload has at least been attempted). Code here to use the NSString (the name of the uploaded file) which have been passed with the repeating handler
        }
    } completion:^{
        // Completion handler could be used to tell the user that the upload has completed
    }];

Note the `repeatingHandler` block. This block is called every-time a local file is uploaded, therefore it may be called multiple times in a short period. The NSError object contains any error information if an error occurred, otherwise it will be nil.

### Removing Documents
You can delete documents from iCloud by using the method below. The completion block is called when the file is successfully deleted.

    [[iCloud sharedCloud] deleteDocumentWithName:@"docName.ext" completion:^(NSError *error) {
        // Completion handler could be used to update your UI and tell the user that the document was deleted
    }];

### Retrieving Documents and Data
You can open and retrieve a document stored in your iCloud documents directory with the method below. This method will attempt to open the specified document. If the file does not exist, a blank one will be created. The completion handler is called when the file is opened or created (either successfully or not). The completion handler contains a UIDocument, NSData, and NSError all of which contain information about the opened document.

    [[iCloud sharedCloud] retrieveCloudDocumentWithName:@"docName.ext" completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
    	if (!error) {
    		NSString *fileName = [cloudDocument.fileURL lastPathComponent];
    		NSData *fileData = documentData;
    	}
    }];

First check if there was an error retrieving or creating the file, if there wasn't you can proceed to get the file's contents and metadata.

You can also check whether or not a file actually exists in iCloud or not by using the method below.

    BOOL fileExists = [[iCloud sharedCloud] doesFileExistInCloud:@"docName.ext"];
    if (fileExists == YES) {
    	// File Exists in iCloud
    }

### Sharing Documents
You can upload an iCloud document to a public URL by using the method below. The completion block is called when the public URL is created.

    NSURL *publicURL = [[iCloud sharedCloud] shareDocumentWithName:@"docName.ext" completion:^(NSURL *sharedURL, NSDate *expirationDate, NSError *error) {
        // Completion handler that passes the public URL created, the expiration date of the URL, and any errors. Could be used to update your UI and tell the user that the document was uploaded
    }];

### Renaming and Duplicating Documents
Rename a document stored in iCloud

    [[iCloud sharedCloud] renameOriginalDocument:@"oldName.ext" withNewName:@"newName.ext" completion:^(NSError *error) {
        // Called when renaming is complete
    }];

Duplicating a document stored in iCloud

    [[iCloud sharedCloud] duplicateOriginalDocument:@"docName.ext" withNewName:@"docName copy.ext" completion:^(NSError *error) {
        // Called when duplication is complete
    }];

### Monitoring Document State
iCloud tracks the state of a document when stored in iCloud. Document states include: Normal / Open, Closed, In Conflict, Saving Error, and Editing Disabled (learn more about [UIDocumentState](https://developer.apple.com/library/ios/documentation/uikit/reference/UIDocument_Class/UIDocument/UIDocument.html#//apple_ref/doc/c_ref/UIDocumentState)). Get the current document state of a file stored in iCloud with this method:

    [[iCloud sharedCloud] documentStateForFile:@"oldName.ext" completion:^(UIDocumentState *documentState, NSString *userReadableDocumentState, NSError *error) {
        // Completion handler that passes two parameters, an NSError and a UIDocumentState. The documentState parameter represents the document state that the specified file is currently in (may be nil if the file does not exist). The NSError parameter will contain a 404 error if the file does not exist.
    }];

Monitor changes in a document's state by subscribing a specific target / selector / method.

    BOOL success = [[iCloud sharedCloud] monitorDocumentStateForFile:@"docName.ext" onTarget:self withSelector:@selector(methodName:)];

Stop monitoring changes in a document's state by removing notifications for a specific target.

    BOOL success = [[iCloud sharedCloud] stopMonitoringDocumentStateChangesForFile:@"docName.ext" onTarget:self];
    
### File Conflict Handling
When a document's state changes to *in conflict*, your application should take the appropriate action by resolving the conflict or letting the user resolve the conflict. You can monitor for document state changes with the `monitorDocumentStateForFile:onTarget:withSelector:` method. iCloud Document Sync provides two methods that help handle a conflict with a document stored in iCloud. The first method lets you find all conflicting versions of a file:

    NSArray *documentVersions = [[iCloud sharedCloud] findUnresolvedConflictingVersionsOfFile:documentName];

The array returned contains a list of NSFileVersion objects for the specified file. You can then use this list of file versions to either automatically merge changes or have the user select the correct version. Use the following method to resolve the conflict by submitting the "correct" version of the file.

    [[iCloud sharedCloud] resolveConflictForFile:@"docName.ext" withSelectedFileVersion:[NSFileVersion object]];


## Delegate
iCloud Document Sync delegate methods notify you of the status of iCloud and your documents stored in iCloud. To use the iCloud delegate, subscribe to the `iCloudDelegate` protocol and then set the `delegate` property. To use the iCloudDocument delegate, subscribe to the `iCloudDocumentDelegate` protocol and then set the `delegate` property.

### iCloud Availability Changed
Called (automatically by iOS) when the availability of iCloud changes.  The first parameter, `cloudIsAvailable`, is a boolean value that is YES if iCloud is available and NO if iCloud is not available. The second parameter, `ubiquityToken`, is an iCloud ubiquity token that represents the current iCloud identity. Can be used to determine if iCloud is available and if the iCloud account has been changed (ex. if the user logged out and then logged in with a different iCloud account). This object may be nil if iCloud is not available for any reason. The third parameter, `ubiquityContainer`, is the root URL path to the current application's ubiquity container. This URL may be nil until the ubiquity container is initialized.

    - (void)iCloudAvailabilityDidChangeToState:(BOOL)cloudIsAvailable withUbiquityToken:(id)ubiquityToken withUbiquityContainer:(NSURL *)ubiquityContainer

### iCloud Files Changed
When the files stored in your app's iCloud Document's directory change, this delegate method is called.  The first parameter, `files`, contains an array of NSMetadataItems which can be used to gather information about a file (ex. URL, Name, Dates, etc). The second parameter, `fileNames`, contains an array of the name of each file as NSStrings.

    - (void)iCloudFilesDidChange:(NSMutableArray *)files withNewFileNames:(NSMutableArray *)fileNames

### iCloud File Conflict
When uploading multiple files to iCloud there is a possibility that files may exist both locally and in iCloud - causing a conflict. iCloud Document Sync can handle most conflict cases and will report the action taken in the log. When iCloud Document Sync can't figure out how to resolve the file conflict (this happens when both the modified date and contents are the same), it will pass the files and relevant information to you using this delegate method.  The delegate method contains two NSDictionaries, one which contains information about the iCloud file, and the other about the local file. Both dictionaries contain the same keys with the same types of objects stored at each key:  
* `fileContent` contains the NSData of the file.
* `fileURL` contains the NSURL pointing to the file. This could possibly be used to gather more information about the file.
* `modifiedDate` contains the NSDate representing the last modified date of the file.

Below is the delegate method to be used

    - (void)iCloudFileConflictBetweenCloudFile:(NSDictionary *)cloudFile andLocalFile:(NSDictionary *)localFile;

### iCloud Query Parameter
Called before creating an iCloud Query filter. Specify the type of file to be queried. If this delegate method is not implemented or returns nil, all files stored in the documents directory will be queried. Should return a single file extension formatted (as an NSString) like this: `@"txt"`

    - (NSString *)iCloudQueryLimitedToFileExtension

### iCloud Document Error
Delegate method fired when an error occurs during an attempt to read, save, or revert a document. This delegate method is only available on the `iCloudDocumentDelegate` with the `iCloudDocument` class. If you implement the iCloudDocument delegate, then you *must* implement this method - it is required.

    - (void)iCloudDocumentErrorOccured:(NSError *)error
