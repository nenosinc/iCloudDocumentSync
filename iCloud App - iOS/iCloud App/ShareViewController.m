//
//  ShareViewController.m
//  iCloud App
//
//  Created by The Spencer Family on 11/24/13.
//  Copyright (c) 2013 iRare Media. All rights reserved.
//

#import "ShareViewController.h"

@interface ShareViewController ()

@end

@implementation ShareViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.link.text = self.linkText;
    self.date.text = self.dateText;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)shareLink {
    NSArray *itemsToShare = @[self.linkText];
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
    [self presentViewController:activityViewController animated:YES completion:nil];
}

- (IBAction)done {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
