iCloudDocumentSync
==================

iCloud Document Sync allows developers to integrate iCloud into their document projects with one-line code methods. Sync, upload, manage, and remove documents to and from iCloud with only ten lines of code.

## Integration
Adding iCloud Document sync to your project is easy. Follow these steps to get everything up and running:  
1. Drag the iCloud Framework into your project  
2. Add `#import <iCloud/iCloud.h>` to the header file of any class with which you wish to use iCloud Document Sync  
3. Add the `<iCloudDelegate>` delegate to all of the files that import `<iCloud/iCloud.h>` Here's what your document should look like:

    #import <iCloud/iCloud.h>
    @interface ViewController : UIViewController < iCloudDelegate >  
This next step is very important. Don't skip it!  
4. In your `viewDidLoad` or `viewDidAppear` make sure to call the following functions to setup iCloud:  

    iCloud *cloud = [[iCloud alloc] init];
    [cloud setDelegate:self];  
It is important that you set the iCloud delegate, otherwise some methods may not be called. This also help to begin the sync process.   
5. Add the following **required** delegate methods: `- (void)fileListChangedWithFiles:(NSMutableArray *)files andFileNames:(NSMutableArray *)fileNames`   and `- (void)cloudError:(NSError *)error`. If you like, you can add other optional delegate methods. Check the documentation that comes with iCloud Document Sync for more information.

## Checking for iCloud Availability
To check if iCloud is available use `[iCloud checkCloudAvailability];`. This method will return a boolean value (YES / NO). You can retrieve the value like this:

    BOOL cloudIsAvailable = [iCloud checkCloudAvailability];
    if (cloudIsAvailable) {
        //YES
    } else {
        //NO
    }

## Syncing Documents
To get iCloud Sync to initialize for the first time, and continue to update when there are changes call `[[iCloud alloc] init];` to start syncing with iCloud for the first time and in the future. 

To manually fetch changes from iCloud, just call `[iCloud updateFileListWithDelegate:]`. Please refer to the next paragraph about how to get the file list and file data.

 iCloud Document Sync will automatically sync all documents stored in the documents folder whenever there are changes in those documents. When something changes the following delegate method will be called and will return an NSMutableArray of all the files (and their names) that are stored in iCloud: `[fileListChangedWithFiles: andFileNames:]`.

## Uploading Documents
iCloud Document Sync uses UIDocument and NSData to store and manage files - no worries though, you don't have to even think about UIDocument. You can create documents filled with NSData directly in iCloud or offline. 

To create a document in iCloud, call `[iCloud createDocumentNamed: withContent: withDelegate:]`. Specify the name of the document with the desired extension, specify the NSData content, and set the delegate. The `documentWasSaved` delegate method is called after the document is successfully created in iCloud.

To upload any documents created while offline, or locally just call `[iCloud uploadLocalOfflineDocumentsWithDelegate:]`. Files in the local documents directory that do not already exist in iCloud will be *moved* into iCloud one by one. This process involves lots of file manipulation and as a result it may take a long time. This process will be performed on the background thread to avoid any lag or memory problems. Two delegate methods: `documentsStartedUploading` and `documentsFinishedUploading` will be called when the upload process starts and when all uploads end.

## Removing Documents
Documents can be deleted from iCloud by using the following method: `[iCloud removeDocumentNamed: withDelegate:]`. The `documentWasDeleted` delegate method is called when the file is successfully deleted.

## Retrieving Documents and Data
You can get a UIDocument stored in your iCloud documents directory with the following method: `[iCloud openDocumentNamed:]`. This method will return a UIDocument from the specified file (make sure to specify the extension). You can retrieve the value like this:

    UIDocument  *document = [iCloud openDocumentNamed:@"DocumentName.ext"];

You can get the NSData contained in the UIDocument with this method: `[iCloud getDataFromDocumentNamed];`. This method will return NSData from the specified file (make sure to specify the extension). You can retrieve the value like this:

      NSData *documentData = [iCloud getDataFromDocumentNamed:@"DocumentName.ext"];   
      
Files retrieved are always searched for in your iCloud app's documents directory. If a file does not exist it will return a `nil` value instead of actual data.

## Other Details
It may provide a little peace of mind to read this section. Although this project is a work in progress, we have gone to great lengths to prevent lag, unresponsiveness, unhandled exceptions, and crashes.   
  -  Every bit of memory intensive code (pretty much anything related to iCloud) is performed on a separate background thread to prevent clogs in the UI.  
  -  Each method is prepared to continue execution even when the user sends the app into the background.  
  -  Most methods are wrapped in `Try / Catch` statements. If something goes wrong iCloud Document Sync will try to handle the error gracefully by calling the `[cloudError:]` delegate method. This method will give you an `NSError ` object containing the error that occurred.  
  -  iCloud Document Sync uses `NSLog` and a variety of delegate methods to show you what is happening

## Change Log
**iCloud Document Sync is a work in progress**. Please help us get all features working and working well. We believe that this project will help many developers by easing the burden of iCloud. Below are the changes for each major commit:

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

##Attribution
This project uses and is a derivative work of <a href="https://github.com/lichtschlag/iCloudPlayground">iCloudPlayground</a>.

## License
<a rel="license" href="http://creativecommons.org/licenses/by/3.0/"><img alt="Creative Commons License" style="border-width:0" src="http://i.creativecommons.org/l/by/3.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by/3.0/">Creative Commons Attribution 3.0 Unported License</a>. You are free to share, remix, and make commercial use of this work. You must attribute this work. For any reuse or distribution, you must make clear to others the license terms of this work and the original author (attribution).