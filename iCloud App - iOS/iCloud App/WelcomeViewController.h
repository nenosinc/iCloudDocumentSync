//
//  WelcomeViewController.h
//  iCloud App
//
//  Created by iRare Media on 11/8/13.
//  Copyright (c) 2014 iRare Media. All rights reserved.
//

@import UIKit;
@import CloudDocumentSync;

@interface WelcomeViewController : UIViewController <iCloudDelegate, UIAlertViewDelegate>

@property (weak, nonatomic) IBOutlet UIButton *startCloudButton;
@property (weak, nonatomic) IBOutlet UIButton *setupCloudButton;

- (IBAction)startCloud:(id)sender;
- (IBAction)setupCloud:(id)sender;

@end
