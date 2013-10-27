## Change Log
**iCloud Document Sync is a work in progress**. If you have an issue, please submit an issue on GitHub. If you have a fix, enhancment, feature, etc. then please fork this on GitHub and submit a pull request.. We believe that this project will help many developers by easing the burden of iCloud. Below are the changes for each major commit.

<table>
<tr><th colspan="2" style="text-align:center;"><b>Version 6.5</b></th></tr>
  <tr>
    <td>Adds support for 64-bit Architecture. The iCloud Framework is now compiled for <tt>armv7</tt>, <tt>armv7s</tt>, <tt>armv64</tt>, and <tt>i386</tt>.
    </td>
  </tr>
<tr><th colspan="2" style="text-align:center;"><b>Version 6.4 & 6.4.1</b></th></tr>
  <tr>
    <td>Bug Fixes. Fixes Issue #15 and Issue #14. This is a simple bug fix update making changes to the retrieveDocument: method and the iCloudDocument.m / iCloudDocument.h files.
    </td>
  </tr>
<tr><th colspan="2" style="text-align:center;"><b>Version 6.3</b></th></tr>
  <tr>
    <td>Adds new methods. Fixes issues with documentation spelling, etc.
    <ul>
   <li>A new method, <tt>shareDocumentWithName: completion:</tt>, is now available. Share a file stored in iCloud by uploading it to a public URL. </li>
    <li>Fixed spelling issues with documentation</li>
    </ul>
    </td>
  </tr>
<tr><th colspan="2" style="text-align:center;"><b>Version 6.2</b></th></tr>
  <tr>
    <td>Adds new methods and improves other methods. Fixes issues with documentation spelling, etc.
    <ul>
   <li>A new method, <tt>getListOfCloudFiles</tt>, is now available. When called, it returns a list of files currently stored in your app's iCloud Documents directory. </li>
    <li>Improved the delete document method. Fixes an issue where the document would not properly close and then delete - resulting in random errors, false positives, and inabaility to delete documents. Now, the <tt>deleteDocumentWithName:</tt> method works properly.</li>
    <li>Fixed spelling issues with documentation</li>
    <li>Created Macro for Document Directory</li>
    </ul>
    </td>
  </tr>
<tr><th colspan="2" style="text-align:center;"><b>Version 6.1</b></th></tr>
  <tr>
    <td>The use of delegates has been tuned down in favor of completion handlers. Some methods have been deprecated and replaced as a result. Others have been improved.
    <ul>
   <li>The <tt>iCloudError</tt> delegate method has been replaced with completion blocks. Some completion blocks now contain an NSError parameter which will contain information about any errors that may occur during a file operation. </li>
   <li>A new delegate method has been added to handle file conflicts.</li>
    <li>Three methods have been deprecated in favor of newer methods that provide more information using completion handlers rather than delegates.</li>
    <li>The new method, uploadLocalOfflineDocumentsWithDelegate, has undergone numerous improvements. File conflict handling during upload is now supported - conflicts are automatically delt with. If a conflict cannot be resolved, the new <tt>iCloudFileUploadConflictWithCloudFile:andLocalFile:</tt> delegate method is called. This method no longer prevents <tt>sqlite</tt> files from being uploaded - now only hidden files aren't uploaded.</li>
    <li>Major documentation improvements to both the DocSet and the Readme.</li>
    </ul>
    </td>
  </tr>
<tr><th colspan="2" style="text-align:center;"><b>Version 6.0</b></th></tr>
  <tr>
    <td>Huge UIDocument improvements. iCloud Document Sync now uses UIDocument to open, save, and maintain files. All methods are more stable. Fetching files is faster and more efficient. Many delegate methods have been replaced with completion blocks.
    </td>
  </tr>
  <tr><th colspan="2" style="text-align:center;"><b>Version 5.0</b></th></tr>
  <tr>
    <td>All methods have been completely revised and improved. Code is much cleaner. Now uses more efficient UIDocument structure than NSFileManager. Project now also includes a Framework which can be used for easy addition to projects. Better documentation, new methods, and more!
    </td>
  </tr>
</table>

<table>
  <tr><th colspan="2" style="text-align:center;">Version 4.3.1</th></tr>
  <tr>
    <td>License Update. Readme Update.  </td>
  </tr>
  <tr><th colspan="2" style="text-align:center;">Version 4.3</th></tr>
  <tr>
    <td>New delegate methods for error reporting and file downloading. File downloading introduced but not implemented. Updated Readme.</td>
  </tr>
  <tr><th colspan="2" style="text-align:center;">Version 4.2</th></tr>
  <tr>
    <td>Fixed errors when uploading files</td>
  </tr>
  <tr><th colspan="2" style="text-align:center;">Version 4.1</th></tr>
  <tr>
    <td>Updated Readme</td>
  </tr>
  <tr><th colspan="2" style="text-align:center;"><b>Version 4.0</b></th></tr>
  <tr>
    <td>Upload and retrieve files with greater ease </td>
  </tr>
  <tr><th colspan="2" style="text-align:center;">Version 3.0</th></tr>
  <tr>
    <td>iCloud Syncing now allows for the uploading of all files in the local directory with one call. Gets changes every time iCloud notifies of a change</td>
  </tr>
  <tr><th colspan="2" style="text-align:center;">Version 2.1</th></tr>
  <tr>
    <td>Changed the File List to an `NSMutableArray` for better flexibility</td>
  </tr>
  <tr><th colspan="2" style="text-align:center;">Version 2.0</th></tr>
  <tr>
    <td>New delegate methods</td>
  </tr>
  <tr><th colspan="2" style="text-align:center;"><b>Version 1.1</b></th></tr>
  <tr>
    <td>Add ability to remove documents from iCloud and local directory</td>
  </tr>
  <tr><th colspan="2" style="text-align:center;"><b>Version 1.0</b></th></tr>
  <tr>
    <td>Initial Commit</td>
  </tr>
</table>