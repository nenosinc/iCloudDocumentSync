//
//  DocumentViewController.m
//  iCloud App
//
//  Created by iRare Media on 11/8/13.
//  Copyright (c) 2013 iRare Media. All rights reserved.
//

#import "DocumentViewController.h"

@interface DocumentViewController ()

@end

@implementation DocumentViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    if (self.fileName == nil || [self.fileName isEqualToString:@""]) {
        NSString *newFileName = [self generateFileNameWithExtension:@"txt"];
        self.title = newFileName;
        self.fileName = newFileName;
        self.textView.text = @"Document text";
    } else {
        self.title = self.fileName;
        self.textView.text = self.fileText;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    if ([self.title isEqualToString:@"iCloud Document"] || self.fileName == nil || [self.fileName isEqualToString:@""]) {
        NSString *newFileName = [self generateFileNameWithExtension:@"txt"];
        NSData *fileData = [self.textView.text dataUsingEncoding:NSUTF8StringEncoding];
        
        [[iCloud sharedCloud] saveAndCloseDocumentWithName:newFileName withContent:fileData completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
            if (!error) {
                NSLog(@"iCloud Document, %@, saved with text: %@", cloudDocument.fileURL.lastPathComponent, [[NSString alloc] initWithData:documentData encoding:NSUTF8StringEncoding]);
            } else {
                NSLog(@"iCloud Document save error: %@", error);
            }
            
            [super viewWillDisappear:YES];
        }];
    } else {
        NSData *fileData = [self.textView.text dataUsingEncoding:NSUTF8StringEncoding];
        
        [[iCloud sharedCloud] saveAndCloseDocumentWithName:self.fileName withContent:fileData completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
            if (!error) {
                NSLog(@"iCloud Document, %@, saved with text: %@", cloudDocument.fileURL.lastPathComponent, [[NSString alloc] initWithData:documentData encoding:NSUTF8StringEncoding]);
            } else {
                NSLog(@"iCloud Document save error: %@", error);
            }
            
            [super viewWillDisappear:YES];
        }];
    }
}

- (NSString *)generateFileNameWithExtension:(NSString *)extensionString {
    NSDate *time = [NSDate date];
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateFormat:@"dd-MM-yyyy-hh-mm-ss"];
    NSString *timeString = [dateFormatter stringFromDate:time];
    
    NSString *fileName = [NSString stringWithFormat:@"%@.%@", timeString, extensionString];
    
    return fileName;
}

- (IBAction)shareDocument:(id)sender {
    if ([self.title isEqualToString:@"iCloud Document"] || self.fileName == nil || [self.fileName isEqualToString:@""] == YES) {
        NSString *newFileName = [self generateFileNameWithExtension:@"txt"];
        NSData *fileData = [self.textView.text dataUsingEncoding:NSUTF8StringEncoding];
        
        self.title = newFileName;
        self.fileName = newFileName;
        
        [[iCloud sharedCloud] saveAndCloseDocumentWithName:newFileName withContent:fileData completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
            if (!error) {
                NSLog(@"iCloud Document, %@, saved with text: %@", cloudDocument.fileURL.lastPathComponent, documentData);
                
                [[iCloud sharedCloud] shareDocumentWithName:newFileName completion:^(NSURL *sharedURL, NSDate *expirationDate, NSError *error) {
                    if (!error) {
                        NSLog(@"iCloud Document, %@, shared to public URL: %@ until expiration date: %@", cloudDocument.fileURL.lastPathComponent, sharedURL, expirationDate);
                        self.fileLink = [sharedURL absoluteString];
                        
                        NSString *formatString = [NSDateFormatter dateFormatFromTemplate:@"EdMMM" options:0 locale:[NSLocale currentLocale]];
                        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                        [dateFormatter setDateFormat:formatString];
                        NSString *dateString = [dateFormatter stringFromDate:expirationDate];
                        self.fileExpirationDate = dateString;
                        
                        [self performSegueWithIdentifier:@"share" sender:self];
                    } else {
                        NSLog(@"iCloud Document share error: %@", error);
                    }
                }];
            } else {
                NSLog(@"iCloud Document save error: %@", error);
            }
        }];
    } else {
        [[iCloud sharedCloud] shareDocumentWithName:self.fileName completion:^(NSURL *sharedURL, NSDate *expirationDate, NSError *error) {
            if (!error) {
                NSLog(@"iCloud Document, %@, shared to public URL: %@ until expiration date: %@", self.fileName, sharedURL, expirationDate);
                self.fileLink = [sharedURL absoluteString];
                
                NSString *formatString = [NSDateFormatter dateFormatFromTemplate:@"EdMMM" options:0 locale:[NSLocale currentLocale]];
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:formatString];
                NSString *dateString = [dateFormatter stringFromDate:expirationDate];
                self.fileExpirationDate = dateString;
                
                [self performSegueWithIdentifier:@"share" sender:self];
            } else {
                NSLog(@"iCloud Document share error: %@", error);
            }
        }];
    }
}

- (void)textViewDidChange:(UITextView *)textView {
    if ([self.title isEqualToString:@"iCloud Document"] || self.fileName == nil || [self.fileName isEqualToString:@""]) {
        NSString *newFileName = [self generateFileNameWithExtension:@"txt"];
        NSData *fileData = [self.textView.text dataUsingEncoding:NSUTF8StringEncoding];
        [[iCloud sharedCloud] saveAndCloseDocumentWithName:newFileName withContent:fileData completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
            NSLog(@"Saved changes to %@: %@", [cloudDocument.fileURL lastPathComponent], documentData);
        }];
    } else {
        NSData *fileData = [self.textView.text dataUsingEncoding:NSUTF8StringEncoding];
        [[iCloud sharedCloud] saveAndCloseDocumentWithName:self.fileName withContent:fileData completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
            NSLog(@"Saved changes to %@: %@", [cloudDocument.fileURL lastPathComponent], documentData);
        }];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"share"]) {
        [super prepareForSegue:segue sender:sender];
        
        // Get reference to the destination view controller
        ShareViewController *viewController = [segue destinationViewController];
        
        NSLog(@"%@ available until %@ at %@", self.fileName, self.fileExpirationDate, self.fileLink);
        
        // Pass any objects to the view controller here
        [viewController setDateText:[NSString stringWithFormat:@"%@ available until %@", self.fileName, self.fileExpirationDate]];
        [viewController setLinkText:self.fileLink];
    
        viewController.transitioningDelegate = self;
        viewController.modalPresentationStyle = UIModalPresentationCustom;
    }
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source {
    
    TLTransitionAnimator *animator = [TLTransitionAnimator new];
    animator.presenting = YES;
    
    return animator;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    TLTransitionAnimator *animator = [TLTransitionAnimator new];
    
    return animator;
}

@end
