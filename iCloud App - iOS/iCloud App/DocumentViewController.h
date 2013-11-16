//
//  DocumentViewController.h
//  iCloud App
//
//  Created by iRare Media on 11/8/13.
//  Copyright (c) 2013 iRare Media. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <iCloud/iCloud.h>

@interface DocumentViewController : UIViewController <UITextViewDelegate>

- (IBAction)shareDocument:(id)sender;

@property (weak, nonatomic) IBOutlet UITextView *textView;

@property (strong, nonatomic) NSString *fileText;
@property (strong, nonatomic) NSString *fileName;

@end
