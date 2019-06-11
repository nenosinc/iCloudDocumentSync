//
//  ConflictViewController.h
//  iCloud App
//
//  Created by iRare Media on 11/26/13.
//  Copyright (c) 2014 iRare Media. All rights reserved.
//

@import UIKit;
@import CloudDocumentSync;
#import "MHPrettyDate.h"

@interface ConflictViewController : UITableViewController

- (IBAction)cancel:(id)sender;

@property (strong) NSString *documentName;
@property (strong) NSArray *documentVersions;

@end
