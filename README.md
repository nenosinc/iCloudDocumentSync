iCloudDocumentSync
==================

iCloud Document Sync helps integrate iCloud into iOS (OS X coming soon) Objective-C document projects with one-line code methods. Sync, upload, manage, and remove documents to and from iCloud with only  few lines of code (compared to the 400+ lines that it usually takes).

## Integration
Adding iCloud Document Sync to your project is easy. Follow these steps to get everything up and running:  
1. Drag the iCloud Framework into your project  
2. Add `#import <iCloud/iCloud.h>` to the header file of any class with which you wish to use iCloud Document Sync  
3. Add the `<iCloudDelegate>` delegate to all of the files that import `<iCloud/iCloud.h>`.
4. In your `viewDidLoad` or `viewDidAppear` make sure to call the following functions to setup iCloud:  

    iCloud *cloud = [[iCloud alloc] init];
    [cloud setDelegate:self];  
It is important that you set the iCloud delegate, otherwise some methods may not be called. Calling `init` on iCloud will also help to begin the sync process and register for document updates.   
5. Add the following **required** delegate methods: 
	-  `- (void)iCloudFilesDidChange:(NSMutableArray *)files withNewFileNames:(NSMutableArray *)fileNames`   
	- `- (void)iCloudError:(NSError *)error`

## Checking for iCloud Availability
To check if iCloud is available use `[iCloud checkCloudAvailability];`. This method will return a boolean value; YES if iCloud is available, and NO if it not. Check the log for details on why it may not be available. You can retrieve the value like this:

    BOOL cloudIsAvailable = [iCloud checkCloudAvailability];
    if (cloudIsAvailable) {
        //YES
    }

## Syncing Documents
To get iCloud Sync to initialize for the first time, and continue to update when there are changes call `[[iCloud alloc] init];` to start syncing with iCloud for the first time and in the future.  To manually fetch changes from iCloud, just call `[iCloud updateFilesWithDelegate:]`. 

iCloud Document Sync will automatically sync all documents stored in the documents folder whenever there are changes in those documents. When something changes the following delegate method will be called and will return an NSMutableArray of all the files (and their names) that are stored in iCloud: `[iCloudFilesDidChange: withNewFileNames:]`.

## Uploading Documents
iCloud Document Sync uses UIDocument and NSData to store and manage files - no worries though, you don't have to even think about UIDocument. You only need to deal with the content of the file - NSData. You can also access the UIDocument if you'd like.

The `[iCloud saveDocumentWithName: withContent: withDelegate: completion:]` method will either create a new document or save an existing one using UIDocument. Specify the name of the document with the desired extension, the NSData content,  the delegate, and use the completion handler. The `iCloudError` delegate method is called if there is an error creating or saving the document. The completion handler will be called when the document is successfully saved or created. The completion handler has a UIDocument and NSData parameter that contain the document and it's contents.

To upload any documents created while offline, or locally just call `[iCloud uploadLocalOfflineDocumentsWithDelegate: completion:]`. Files in the local documents directory that do not already exist in iCloud will be **moved** into iCloud one by one. This process involves lots of file manipulation and as a result it may take a long time. This process will be performed on the background thread to avoid any lag or memory problems. When the upload processes end, the completion block is called on the main thread.

## Removing Documents
Documents can be deleted from iCloud by using the following method: `[iCloud deleteDocumentWithName: withDelegate: completion:]`. The completion block is called when the file is successfully deleted.

## Retrieving Documents and Data
You can open and retrieve a document stored in your iCloud documents directory with the following method: `[iCloud retrieveCloudDocumentWithName: completion:]`. This method will attempt to open the specified document - if it is not open a blank one will be created. The completion handler is called when the file is opened or created (either successfully or not). The completion handler contains a UIDocument, NSData, and NSError all of which contain information about the opened document. Here's an example:

    [iCloud retrieveCloudDocumentWithName:@"docName.ext" completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
    	if (!error) {
    		NSString *fileName = [cloudDocument.fileURL lastPathComponent];
    		NSData *fileData = documentData;
    	}
    }];

First check if there was an error retrieving or creating the file, if there wasn't you can proceed to get the file's contents and metadata.

## Other Details
It may provide a little peace of mind to read this section. Although this project is a work in progress, we have gone to great lengths to prevent lag, unresponsiveness, unhandled exceptions, and crashes.   
  -  Every bit of memory intensive code (pretty much anything related to iCloud) is performed on a separate background thread to prevent clogs in the UI.  
  -  Each method is prepared to continue execution even when the user sends the app into the background.  
  -  iCloud Document Sync uses `NSLog` , delegate methods, and completion handlers, to show you what is happening.

## Change Log
**iCloud Document Sync is a work in progress**. Please help us get all features working and working well. We believe that this project will help many developers by easing the burden of iCloud. Below are the changes for each major commit:

Version 6.0 - Huge UIDocument improvements. iCloud Document Sync now uses UIDocument to open, save, and maintain files. All methods are more stable. Fetching files is faster and more efficient. Many delegate methods have been replaced with completion blocks.

Version 5.0 - All methods have been completely revised and improved. Code is much cleaner. Now uses more efficient UIDocument structure than NSFileManager. Project now also includes a Framework which can be used for easy addition to projects. Better documentation, new methods, and more!

Version 4.3.1 - License Update. Readme Update.  
Version 4.3 - New delegate methods for error reporting and file downloading. File downloading introduced but not implemented. Updated Readme.  
Version 4.2 - Fixed errors when uploading files  
Version 4.1 - Updated Readme  
Version 4.0 - Upload and retrieve files with greater ease  

Version 3.0 - iCloud Syncing now allows for the uploading of all files in the local directory with one call. Gets changes every time iCloud notifies of a change

Version 2.1 - Changed the File List to an `NSMutableArray` for better flexibility  
Version 2.0 - New delegate methods  

Version 1.1 - Add ability to remove documents from iCloud and local directory  
Version 1.0 - Initial Commit

## License
The MIT License (MIT)

Copyright (c) 2013 iRare Media

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.