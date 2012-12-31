iCloudDocumentSync
==================

iCloud Document Sync allows developers to integrate iCloud into their document projects with one-line code methods. Sync, download, save, and remove documents to and from iCloud with only three lines of code.

## Integration
Adding iCloud Document sync to your project is easy. Follow these steps to get everything up and running:  
1. Drag `iCloud.h` and `iCloud.m` to your project  
2. Add `#import "iCloud.h"` to the header file of any class with which you wish to use iCloud Document Sync  
3. Add the `'iCloudDelegate` delegate and add the iCloud class to all of the files that import "iCloud.h". Here's what your document should look like:

    #import "iCloud.h"
    @class iCloud
    @interface ViewController : UIViewController < iCloudDelegate >  
Steps three and four are very important! Don't skip them!  
4. In your `viewDidLoad` or `viewDidAppear` make sure to call `[[iCloud alloc] init];` to start syncing with iCloud.  
5. Add the following **required** delegate method: `- (void)fileList:(NSArray *)files`  
6. If you like, you can add the following optional methods. The **first** method `documentWasSaved` will tell you when iCloud Document Sync has finished uploading a single file after calling the `createDocumentWithData` method. The **second** method `documentWasDeleted` will tell you when iCloud Document Sync has finished deleting a single document after calling the `removeDocumentWithName` method.

## Checking for iCloud Availability
To check if iCloud is available, simply add the following method call anywhere in your code where you'd like to know if iCloud is available: `[iCloud checkCloudAvailability];`. This method will return a boolean value (YES / NO). You can retrieve the value like this:

    BOOL cloudIsAvailable = [iCloud checkCloudAvailability];
    if (cloudIsAvailable) {
        //YES
    } else {
        //NO
    }

## Syncing Documents
iCloud Document Sync will automatically sync all documents stored in the documents folder whenever there are changes in those documents. When things do change, the following delegate method will be called and will return an NSMutableArray of all the files that are now stored both in iCloud and locally. Here's the method (it's the only required one): 

    - (void)fileList:(NSMutableArray *)files

## Saving Documents
Documents can be saved / uploaded / moved to iCloud by using the following line: `[iCloud createDocumentWithData:NSDATA withName:@"DOCUMENT_NAME" withDelegate:self];`.  Make sure to replace NSDATA with your own NSData, and make sure to replace DOCUMENT_NAME with your own document name. All documents are saved to the local documents directory inside of your application's sandbox / directory and then uploaded to your application's iCloud folder and placed in a directory titled "Documents".

## Removing Documents
Documents can be deleted from iCloud and the local documents directory by using the following line: `[iCloud removeDocumentWithName:@"DOCUMENT_NAME" withDelegate:self];`.  Make sure to replace DOCUMENT_NAME with the name of a document that exists in both iCloud and the local directory. If it only exists in one location, it will only be deleted from that location.

## Work in Progress
**iCloud Document Sync is a work in progress**. It should be noted that the code provided with this particular commit is NOT stable and may not work as is. This software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement of third party rights. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.