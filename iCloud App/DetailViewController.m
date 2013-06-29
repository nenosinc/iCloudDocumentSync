//
//  DetailViewController.m
//  iCloud
//
//  Created by The Spencer Family on 6/27/13.
//  Copyright (c) 2013 iRare Media. All rights reserved.
//

#import "DetailViewController.h"

@interface DetailViewController ()
@end

@implementation DetailViewController
@synthesize fileContent, fileTitleBar, fileContentString;
@synthesize document;

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:YES];
    
    //Setup Document Content
    fileContent.text = @"";
    NSLog(@"File Content: %@", fileContentString);
    fileContent.text = fileContentString;
    
    //Register for the keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    //Save the document
    NSString *documentText = self.fileContent.text;
    NSData *documentData = [documentText dataUsingEncoding:NSUTF8StringEncoding];
    [iCloud createDocumentNamed:[document.fileURL lastPathComponent] withContent:documentData withDelegate:nil completion:^{
        NSLog(@"Saved Document");
    }];
    
    //Unregister for the keyboard notifications.
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)keyboardWillShow:(NSNotification*)aNotification {
    NSDictionary *info = [aNotification userInfo];
    CGRect kbSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    double duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    UIEdgeInsets insets = self.fileContent.contentInset;
    insets.bottom += kbSize.size.height;
    
    [UIView animateWithDuration:duration animations:^{
        self.fileContent.contentInset = insets;
    }];
}

- (void)keyboardWillHide:(NSNotification*)aNotification {
    NSDictionary* info = [aNotification userInfo];
    double duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    // Reset the text view's bottom content inset.
    UIEdgeInsets insets = self.fileContent.contentInset;
    insets.bottom = 0;
    
    [UIView animateWithDuration:duration animations:^{
        self.fileContent.contentInset = insets;
    }];
}

@end
