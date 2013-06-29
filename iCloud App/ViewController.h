//
//  ViewController.h
//  iCloud App
//
//  Created by The Spencer Family on 6/27/13.
//  Copyright (c) 2013 iRare Media. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "iCloud.h"
#import "DetailViewController.h"

@interface ViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate, iCloudDelegate>

@property (weak, nonatomic) IBOutlet UITableView *documentsTableView;
@property (weak, nonatomic) IBOutlet UIImageView *noFilesImage;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *createDocumentButton;

@property (strong, nonatomic) NSMutableArray *fileNameList;
@property (strong, nonatomic) NSMutableArray *fileDateList;
@property (strong, nonatomic) NSString *selectedFileName;
@property (strong, nonatomic) NSString *selectedFileContent;

@property (strong, nonatomic) UIRefreshControl *refreshControl;

- (IBAction)createNewDocument:(id)sender;

@end
