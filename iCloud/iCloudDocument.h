//
//  iCloudDocument.h
//  iCloud Document Sync
//
//  Created by iRare Media. Last updated November 2013.
//  Available on GitHub. Licensed under MIT with Attribution.
//

#import <UIKit/UIKit.h>

/** Use the iCloudDocument class (a subclass of UIDocument) to read and write documents managed by the iCloud class. You should rarely interact directly with iCloudDocument. The iCloud class manages all interactions with iCloudDocument. You can however retieve an iCloudDocument object by specifying its URL in the iCloud class.
 
 iCloudDocument can read and write any files with the following exceptions:
 
 - Bundles
 - Packages
 - Aliases
 
 If you'd like support for the above faux files then please consider [filing an Issue on GitHub](https://github.com/iRareMedia/iCloudDocumentSync/issues/new) or [submitting a Pull Request](https://github.com/iRareMedia/iCloudDocumentSync/pulls) if you've figured out how. This can be done using an NSFileWrapper. 
 
 You may want to consider subclassing iCloudDocument for custom implementations of many features. */
@class iCloudDocument;
@protocol iCloudDocumentDelegate;
@interface iCloudDocument : UIDocument



/** @name Methods */

/** Initialize a new UIDocument with the specified file path
 
 @param url	The path to the UIDocument file
 @return UIDocument object at the specified URL */
- (id)initWithFileURL:(NSURL *)url;




/** @name Delegate */

/** iCloud Delegate helps call methods when document processes begin or end */
@property (weak, nonatomic) id <iCloudDocumentDelegate> delegate;




/** @name Properties */

/** The file version of the UIDocument object, used for handling file conflicts */
NSFileVersion *laterVersion(NSFileVersion *first, NSFileVersion *second);

/** The data to read or write to a UIDocument */
@property (strong) NSData *contents;

/** Retrieve the localized name of the current document
 
 @return Name of document including file extension, as an NSString */
- (NSString *)localizedName;

/** Retrieve a user-readable form of the document state
 
 @return Current state of the document as a user-readable NSString */
- (NSString *)stateDescription;

@end


@class iCloudDocument;
/** The iCloudDocumentDelegate protocol defines the methods used to receive error notifications and allow for deeper control of document handling and management. */
@protocol iCloudDocumentDelegate <NSObject>


/** @name Required Delegate Methods */

@required

/** Delegate method fired when an error occurs during an attempt to read, save, or revert a document.
 
 @param error The error that occured during an attempt to read, save, or revert a document. */
- (void)iCloudDocumentErrorOccured:(NSError *)error;

@end
