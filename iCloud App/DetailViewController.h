//
//  DetailViewController.h
//  iCloud
//
//  Created by The Spencer Family on 6/27/13.
//  Copyright (c) 2013 iRare Media. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "iCloud.h"

@interface DetailViewController : UIViewController

@property (weak, nonatomic) IBOutlet UINavigationItem *fileTitleBar;
@property (strong, nonatomic) IBOutlet UITextView *fileContent;
@property (strong, nonatomic) NSString *fileContentString;
@property (strong, nonatomic) UIDocument *document;

@end
