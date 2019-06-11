//
//  DocumentViewController.h
//  iCloud App
//
//  Created by iRare Media on 11/8/13.
//  Copyright (c) 2014 iRare Media. All rights reserved.
//

@import UIKit;
@import CloudDocumentSync;
#import "TLTransitionAnimator.h"
#import "ShareViewController.h"

@interface DocumentViewController : UIViewController <UITextViewDelegate, UIViewControllerTransitioningDelegate>

- (IBAction)shareDocument:(id)sender;

@property (weak, nonatomic) IBOutlet UITextView *textView;

@property (strong, nonatomic) NSString *fileText;
@property (strong, nonatomic) NSString *fileName;

@property (strong, nonatomic) NSString *fileLink;
@property (strong, nonatomic) NSString *fileExpirationDate;


@end
