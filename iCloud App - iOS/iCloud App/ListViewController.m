//
//  ListViewController.m
//  iCloud App
//
//  Created by iRare Media on 11/8/13.
//  Copyright (c) 2013 iRare Media. All rights reserved.
//

#import "ListViewController.h"

@interface ListViewController () {
    NSMutableArray *fileNameList;
    NSMutableArray *fileObjectList;
    UIRefreshControl *refreshControl;
    
    NSString *fileText;
    NSString *fileTitle;
} @end

@implementation ListViewController

#pragma mark - View Lifecycle

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Setup iCloud
    iCloud *cloud = [iCloud sharedCloud]; // This will help to begin the sync process and register for document updates
    [cloud setDelegate:self]; // Set this if you plan to use the delegate
    [cloud setVerboseLogging:YES]; // We want detailed feedback about what's going on with iCloud, this is OFF by default
    
    // Setup File List
    if (fileNameList == nil) fileNameList = [NSMutableArray array];
    if (fileObjectList == nil) fileObjectList = [NSMutableArray array];
 
    // Display an Edit button in the navigation bar for this view controller.
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // Create refresh control
    if (refreshControl == nil) refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refreshCloudList) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:refreshControl];
    
    // Present Welcome Screen
    if ([self appIsRunningForFirstTime] == YES || [cloud checkCloudAvailability] == NO) {
        [self performSegueWithIdentifier:@"showWelcome" sender:self];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    /* --- Force iCloud Update ---
     This is done automatically when changes are made, but we want to make sure the view is always updated when presented */
    //[iCloud updateFilesWithDelegate:self];
    [[iCloud sharedCloud] updateFiles];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)appIsRunningForFirstTime {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"HasLaunchedOnce"]) {
        // App already launched
        return NO;
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"HasLaunchedOnce"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        // This is the first launch ever
        return YES;
    }
}

#pragma mark - iCloud Methods

- (NSString *)iCloudQueryLimitedToFileExtension {
    // Returning the type of file we want to query for, if this delegate method is not implemented or returns nil then all files will be queried
    return @"txt";
}

- (void)iCloudFilesDidChange:(NSMutableArray *)files withNewFileNames:(NSMutableArray *)fileNames {
    // Get the query results
    NSLog(@"Files: %@", fileNames);
    
    fileNameList = fileNames; // A list of the file names
    fileObjectList = files; // A list of NSMetadata objects with detailed metadata
    
    [refreshControl endRefreshing];
    [self.tableView reloadData];
}

- (void)refreshCloudList {
    [[iCloud sharedCloud] updateFiles];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [fileNameList count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSString *fileName = [fileNameList objectAtIndex:indexPath.row];
    NSNumber *filesize = [[iCloud sharedCloud] fileSize:fileName];
    NSDate *updated = [[iCloud sharedCloud] fileModifiedDate:fileName];
    NSString *fileDetail = [NSString stringWithFormat:@"%@ bytes, updated %@", filesize, [MHPrettyDate prettyDateFromDate:updated withFormat:MHPrettyDateFormatWithTime]];
    
    // Configure the cell...
    cell.textLabel.text = fileName;
    cell.detailTextLabel.text = fileDetail;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [[iCloud sharedCloud] deleteDocumentWithName:[fileNameList objectAtIndex:indexPath.row] completion:^(NSError *error) {
            if (error) {
                NSLog(@"Error deleting document: %@", error);
            } else {
                [[iCloud sharedCloud] updateFiles];
                [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            }
        }];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[iCloud sharedCloud] retrieveCloudDocumentWithName:[fileNameList objectAtIndex:indexPath.row] completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
        if (!error) {
            fileText = [[NSString alloc] initWithData:documentData encoding:NSUTF8StringEncoding];
            fileTitle = cloudDocument.fileURL.lastPathComponent;
            
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            
            [self performSegueWithIdentifier:@"documentView" sender:nil];
        } else {
            NSLog(@"Error retrieveing document: %@", error);
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
    }];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    
    // Make sure your segue name in storyboard is the same as this line
    if ([[segue identifier] isEqualToString:@"documentView"]) {
        // Get reference to the destination view controller
        DocumentViewController *viewController = [segue destinationViewController];
        
        // Pass any objects to the view controller here, like...
        [viewController setFileText:fileText];
        [viewController setFileName:fileTitle];
    }
}

@end
