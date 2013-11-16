//
//  WelcomeViewController.m
//  iCloud App
//
//  Created by iRare Media on 11/8/13.
//  Copyright (c) 2013 iRare Media. All rights reserved.
//

#import "WelcomeViewController.h"

@interface WelcomeViewController ()
@end

@implementation WelcomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    [[iCloud sharedCloud] setDelegate:self];
}

- (void)viewDidAppear:(BOOL)animated {
    BOOL cloudAvailable = [[iCloud sharedCloud] checkCloudAvailability];
    if (cloudAvailable) {
        self.startCloudButton.alpha = 1.0;
        self.setupCloudButton.alpha = 0.0;
        
        self.startCloudButton.userInteractionEnabled = YES;
        self.setupCloudButton.userInteractionEnabled = NO;
    } else {
        self.setupCloudButton.alpha = 1.0;
        self.startCloudButton.alpha = 0.0;
        
        self.setupCloudButton.userInteractionEnabled = YES;
        self.startCloudButton.userInteractionEnabled = NO;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)startCloud:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)setupCloud:(id)sender {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Setup iCloud" message:@"iCloud is not available. Sign into an iCloud account on this device and check that this app has valid entitlements." delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil];
    [alert show];
}

- (void)iCloudAvailabilityDidChangeToState:(BOOL)cloudIsAvailable withUbiquityToken:(id)ubiquityToken withUbiquityContainer:(NSURL *)ubiquityContainer {
    if (cloudIsAvailable) {
        self.startCloudButton.alpha = 1.0;
        self.setupCloudButton.alpha = 0.0;
        
        self.startCloudButton.userInteractionEnabled = YES;
        self.setupCloudButton.userInteractionEnabled = NO;
    } else {
        self.setupCloudButton.alpha = 1.0;
        self.startCloudButton.alpha = 0.0;
        
        self.setupCloudButton.userInteractionEnabled = YES;
        self.startCloudButton.userInteractionEnabled = NO;
    }
}

@end
