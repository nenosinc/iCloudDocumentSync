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
    
    if (self.fileName != nil || [self.fileName isEqualToString:@""] == NO) {
        self.title = self.fileName;
        self.textView.text = self.fileText;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated {
    if ([self.title isEqualToString:@"iCloud Document"] || self.fileName == nil || [self.fileName isEqualToString:@""] == YES) {
        NSString *newFileName = [self generateFileNameWithExtension:@"txt"];
        NSData *fileData = [self.textView.text dataUsingEncoding:NSUTF8StringEncoding];
        
        [[iCloud sharedCloud] saveAndCloseDocumentWithName:newFileName withContent:fileData completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
            if (!error) {
                NSLog(@"iCloud Document, %@, saved with text: %@", cloudDocument.fileURL.lastPathComponent, [[NSString alloc] initWithData:documentData encoding:NSUTF8StringEncoding]);
            } else {
                NSLog(@"iCloud Document save error: %@", error);
            }
        }];
    } else {
        NSData *fileData = [self.textView.text dataUsingEncoding:NSUTF8StringEncoding];
        
        [[iCloud sharedCloud] saveAndCloseDocumentWithName:self.fileName withContent:fileData completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
            if (!error) {
                NSLog(@"iCloud Document, %@, saved with text: %@", cloudDocument.fileURL.lastPathComponent, [[NSString alloc] initWithData:documentData encoding:NSUTF8StringEncoding]);
            } else {
                NSLog(@"iCloud Document save error: %@", error);
            }
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
                    } else {
                        NSLog(@"iCloud Document share error: %@", error);
                    }
                }];
            } else {
                NSLog(@"iCloud Document save error: %@", error);
            }
        }];
    } else {
        NSData *fileData = [self.textView.text dataUsingEncoding:NSUTF8StringEncoding];
        
        [[iCloud sharedCloud] saveAndCloseDocumentWithName:self.fileName withContent:fileData completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
            if (!error) {
                NSLog(@"iCloud Document, %@, saved with text: %@", cloudDocument.fileURL.lastPathComponent, documentData);
                
                [[iCloud sharedCloud] shareDocumentWithName:self.fileName completion:^(NSURL *sharedURL, NSDate *expirationDate, NSError *error) {
                    if (!error) {
                        NSLog(@"iCloud Document, %@, shared to public URL: %@ until expiration date: %@", cloudDocument.fileURL.lastPathComponent, sharedURL, expirationDate);
                    } else {
                        NSLog(@"iCloud Document share error: %@", error);
                    }
                }];
            } else {
                NSLog(@"iCloud Document save error: %@", error);
            }
        }];
    }
}

- (void)textViewDidChange:(UITextView *)textView {
    
}

@end
