//
//  WelcomeViewController.h
//  iCloud App
//
//  Created by iRare Media on 11/8/13.
//  Copyright (c) 2013 iRare Media. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <iCloud/iCloud.h>

@interface WelcomeViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIButton *startCloudButton;
@property (weak, nonatomic) IBOutlet UIButton *setupCloudButton;

- (IBAction)startCloud:(id)sender;
- (IBAction)setupCloud:(id)sender;

@end
