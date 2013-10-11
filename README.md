iCloud Document Sync
==================

iCloud Document Sync helps integrate iCloud into iOS (OS X coming soon) Objective-C document projects with one-line code methods. Sync, upload, manage, and remove documents to and from iCloud with only  a few lines of code (compared to the hundreds of lines that it usually takes).

If you like the project, please [star it](https://github.com/iRareMedia/iCloudDocumentSync) on GitHub!

Setup
-----
Adding iCloud Document Sync to your project is easy. Follow these steps below to get everything up and running.
  
  1. Drag the iCloud Framework into your project  
  2. Add `#import <iCloud/iCloud.h>` to your header file(s)   
  3. Subscribe to the `<iCloudDelegate>` delegate.  
  4. Call the following methods to setup iCloud when your app starts:  

	    iCloud *cloud = [[iCloud alloc] init]; // This will help to begin the sync process and register for document updates.
	    [cloud setDelegate:self];  // Only set this if you plan to use the delegate

Documentation
-----
All methods, properties, types, and delegate methods available on the iCloud class are documented below. If you're using [Xcode 5](https://developer.apple.com/technologies/tools/whats-new.html) with iCloud Document Sync, documentation is available directly within Xcode (just Option-Click any method for Quick Help). For more advanced documentation in Xcode 4.0+ please install the docset included with this project. This will allow you to view iCloud Document Sync documentation inside of Xcode's Organizer Window.

### Checking for iCloud Availability
You should always check if iCloud is available before performing any iCloud operations. Additionally, you may want to check if your users want to opt-in to iCloud on a per-app basis.

    BOOL cloudIsAvailable = [iCloud checkCloudAvailability];
    if (cloudIsAvailable) {
        //YES
    }

This checks if iCloud is available. It returns a boolean value; YES if iCloud is available, and NO if it is not. Check the log for details on why it may not be available.

### Syncing Documents
To get iCloud Document Sync to initialize for the first time, and continue to update when there are changes you'll need to initialize iCloud. By initializing iCloud, it will start syncing with iCloud for the first time and in the future.  

    [[iCloud alloc] init];

You can manually fetch changes from iCloud too:

    [iCloud updateFilesWithDelegate:self]

iCloud Document Sync will automatically detect changes in iCloud documents. When something changes the delegate method below is fired and will pass an NSMutableArray of all the files (and their names) stored in iCloud.

    - (void)iCloudFilesDidChange:(NSMutableArray *)files withNewFileNames:(NSMutableArray *)fileNames

### Uploading Documents
iCloud Document Sync uses UIDocument and NSData to store and manage files. All of the heavy lifting with NSData and UIDocument is handled for you. There's no need to actually create or manage any files, just give iCloud Document Sync your data, and the rest is done for you.

To create a new document or save an existing one (close the document), use the method below.

    [iCloud saveDocumentWithName:@"Name.ext" withContent:[NSData data] completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
        if (error == nil) {
            // Code here to use the UIDocument or NSData objects which have been passed with the completion handler
        }
    }];

The completion handler will be called when a document is saved or created. The completion handler has a UIDocument and NSData parameter that contain the document and it's contents. The third parameter is an NSError that will contain an error if one occurs, otherwise it will be `nil`.

You can also upload any documents created while offline, or locally.  Files in the local documents directory that do not already exist in iCloud will be **moved** into iCloud one by one. This process involves lots of file manipulation and as a result it may take a long time. This process will be performed on the background thread to avoid any lag or memory problems. When the upload processes end, the completion block is called on the main thread.

    [iCloud uploadLocalOfflineDocumentsWithDelegate:self  repeatingHandler:^(NSString *fileName, NSError *error) {
        if (error == nil) {
            // This code block is called repeatedly until all files have been uploaded (or an upload has at least been attempted). Code here to use the NSString (the name of the uploaded file) which have been passed with the repeating handler
        }
    } completion:^{
        // Completion handler could be used to tell the user that the upload has completed
    }];

Note the `repeatingHandler` block. This block is called every-time a local file is uploaded, therefore it may be called multiple times in a short period. The NSError object contains any error information if an error occurred, otherwise it will be nil.

### Removing Documents
You can delete documents from iCloud by using the method below. The completion block is called when the file is successfully deleted.

    [iCloud deleteDocumentWithName:@"docName.ext" completion:^(NSError *error) {
        // Completion handler could be used to update your UI and tell the user that the document was deleted
    }];

### Retrieving Documents and Data
You can open and retrieve a document stored in your iCloud documents directory with the method below. This method will attempt to open the specified document. If the file does not exist, a blank one will be created. The completion handler is called when the file is opened or created (either successfully or not). The completion handler contains a UIDocument, NSData, and NSError all of which contain information about the opened document.

    [iCloud retrieveCloudDocumentWithName:@"docName.ext" completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
    	if (!error) {
    		NSString *fileName = [cloudDocument.fileURL lastPathComponent];
    		NSData *fileData = documentData;
    	}
    }];

First check if there was an error retrieving or creating the file, if there wasn't you can proceed to get the file's contents and metadata.

You can also check whether or not a file actually exists in iCloud or not by using the method below.

    BOOL fileExists = [iCloud doesFileExistInCloud:@"docName.ext"];
    if (fileExists == YES) {
    	// File Exists in iCloud
    }

### Sharing Documents
You can upload an iCloud document to a public URL by using the method below. The completion block is called when the public URL is created.

    NSURL *publicURL = [iCloud shareDocumentWithName:@"docName.ext" completion:^(NSURL *sharedURL, NSDate *expirationDate, NSError *error) {
        // Completion handler that passes the public URL created, the expiration date of the URL, and any errors. Could be used to update your UI and tell the user that the document was uploaded
    }];


Delegates
-----
iCloud Document Sync delegate methods notify you of the status of iCloud and your documents stored in iCloud. There are no required delegate method for iOS, however it is recommended that you utilize all available delegate methods. 

<table>
  <tr><th colspan="2" style="text-align:center;">Optional Delegate Methods</th></tr>
  <tr>
    <td>iCloud Files Changed</td>
    <td>When the files stored in your app's iCloud Document's directory change, this delegate method is called.  
     <br /><br />
           <tt> - (void)iCloudFilesDidChange:(NSMutableArray *)files withNewFileNames:(NSMutableArray *)fileNames</tt></td>
  </tr>
  <tr>
    <td>iCloud File Upload Conflict</td>
    <td>When uploading multiple files to iCloud there is a possibility that files may exist both locally and in iCloud - causing a conflict. iCloud Document Sync can handle most conflict cases and will report the action taken in the log. When iCloud Document Sync can't figure out how to resolve the file conflict (this happens when both the modified date and contents are the same), it will pass the files and relevant information to you using this delegate method.  The delegate method contains two NSDictionaries, one which contains information about the iCloud file, and the other about the local file. Both dictionaries contain the same keys with the same types of objects stored at each key:
    <ul>
   <li><tt>fileContent</tt> contains the NSData of the file. </li>
    <li><tt>fileURL</tt> contains the NSURL pointing to the file. This could possibly be used to gather more information about the file. </li>
    <li><tt>modifiedDate</tt> contains the NSDate representing the last modified date of the file. </li>
    </ul>
     <br />
           <tt> - (void)iCloudFileUploadConflictWithCloudFile:(NSDictionary *)cloudFile andLocalFile:(NSDictionary *)localFile;</tt></td>
  </tr>
</table>

Extra Features
-----
Although this project is a work in progress, we have gone to great lengths to prevent lag, unresponsiveness, unhandled exceptions, and crashes.   
   -  Every bit of memory intensive code (pretty much anything related to iCloud) is performed on a separate background thread to prevent clogs in the UI.  
   -  Each method is prepared to continue execution even when the user sends the app into the background.  
   -  iCloud Document Sync uses `NSLog` , delegate methods, and completion handlers, to show you what is happening.  
