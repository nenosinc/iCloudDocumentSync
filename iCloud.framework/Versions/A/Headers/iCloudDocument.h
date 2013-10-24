//
//  iCloudDocument.h
//  iCloud Document Sync
//
//  Created by iRare Media on June 27, 2013
//  Copyright (c) 2013 iRare Media. All rights reserved.
//
//

#import <UIKit/UIKit.h>

/** Use the `iCloudDocument` class (a subclass of UIDocument) to read and write documents managed by the iCloud class. You should never directly interact with iCloudDocument. The iCloud class manages all interactions with iCloudDocument.
 
 Most iCloudDocument methods are encapsulated in GCD thread management blocks. By using GCD, most operations are performed on a background thread to avoid clogging-up the UI.
 
 iCloudDocument can read and write any files with the following exceptions:
 
 - Bundles
 - Packages
 - Aliases
 
 If you'd like support for the above faux files then please consider [filing an Issue on GitHub](https://github.com/iRareMedia/iCloudDocumentSync/issues/new) or [submitting a Pull Request](https://github.com/iRareMedia/iCloudDocumentSync/pulls) if you've figured out how.
 */
@class iCloudDocument;
@interface iCloudDocument : UIDocument

/** The data to read or write to a UIDocument */
@property (strong) NSData *contents;

/** Initialize a new UIDocument with the specified file path

 	@param	url	The path to the UIDocument file
 	@return	UIDocument object at the specified URL
 */
- (id)initWithFileURL:(NSURL *)url;

@end