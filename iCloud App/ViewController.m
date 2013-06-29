//
//  ViewController.m
//  iCloud App
//
//  Created by The Spencer Family on 6/27/13.
//  Copyright (c) 2013 iRare Media. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController
@synthesize documentsTableView, noFilesImage, createDocumentButton;
@synthesize selectedFileContent, selectedFileName;
@synthesize fileNameList, fileDateList;
@synthesize refreshControl;

//----------------------------------------------------------------------------------------------------------------//
// View Lifecycle ------------------------------------------------------------------------------------------------//
//----------------------------------------------------------------------------------------------------------------//
#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    //Setup iCloud
    iCloud *cloud = [[iCloud alloc] init];
    [cloud setDelegate:self];
    
    //Setup File List
    fileNameList = [[NSMutableArray alloc] init];
    fileDateList = [[NSMutableArray alloc] init];
    
    //Setup Refresh Control
    refreshControl = [[UIRefreshControl alloc] init];
    refreshControl.tintColor = [UIColor colorWithRed:50.0/255.0 green:79.0/255.0 blue:133.0/255.0 alpha:1.0];
    [refreshControl addTarget:self action:@selector(updateContent) forControlEvents:UIControlEventValueChanged];
    [documentsTableView addSubview:refreshControl];
}

- (void)viewDidAppear:(BOOL)animated {
    //Setup iCloud and check for it's availability every time the user see's the ViewController
    [self checkCloud];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//----------------------------------------------------------------------------------------------------------------//
// Documents -----------------------------------------------------------------------------------------------------//
//----------------------------------------------------------------------------------------------------------------//
#pragma mark - Documents

- (IBAction)createNewDocument:(id)sender {
    UIAlertView *messageName = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Name File", nil)
                                                          message:NSLocalizedString(@"Please type a name for your new document", nil)
                                                         delegate:self
                                                cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                otherButtonTitles:NSLocalizedString(@"Save", nil), nil];
    
    [messageName setAlertViewStyle:UIAlertViewStylePlainTextInput];
    [messageName show];
}

- (void)createEmptyDocumentWithName:(NSString *)fileName {
    //Disable the add document button while the document is being created
    createDocumentButton.enabled = NO;
    
    //Create a generic NSData object with a string
    NSData *data = [@"Empty Document" dataUsingEncoding:NSUTF8StringEncoding];
    
    //Create the document
    [iCloud createDocumentNamed:fileName withContent:data withDelegate:self completion:^{
        NSLog(@"File Created Successfully");
    }];
    
    //The add document button is re-enabled after creation
    createDocumentButton.enabled = YES;
}

//----------------------------------------------------------------------------------------------------------------//
// iCloud --------------------------------------------------------------------------------------------------------//
//----------------------------------------------------------------------------------------------------------------//
#pragma mark - iCloud

- (void)updateContent {
    [iCloud updateFileListWithDelegate:self];
}

- (void)checkCloud {
    BOOL cloudIsAvailable = [iCloud checkCloudAvailability];
    if (cloudIsAvailable) {
        //iCloud is Available
        self.navigationItem.leftBarButtonItem = self.editButtonItem;
        documentsTableView.hidden = NO;
        noFilesImage.hidden = YES;
        createDocumentButton.enabled = YES;
    } else {
        //iCloud is not available - display an error message
        self.navigationItem.leftBarButtonItem = nil;
        documentsTableView.hidden = YES;
        noFilesImage.hidden = NO;
        createDocumentButton.enabled = NO;
        #if TARGET_IPHONE_SIMULATOR
            //Simulator
            noFilesImage.image = [UIImage imageNamed:@"NoSimulator"];
        #else
            //Device
            noFilesImage.image = [UIImage imageNamed:@"Unavailable"];
        #endif
    }
}

//----------------------------------------------------------------------------------------------------------------//
// iCloud Delegate -----------------------------------------------------------------------------------------------//
//----------------------------------------------------------------------------------------------------------------//
#pragma mark - iCloud Delegate

- (void)iCloudFilesDidChange:(NSMutableArray *)files withNewFileNames:(NSMutableArray *)fileNames {
    [fileNameList setArray:fileNames];
    [fileDateList setArray:files];
    NSLog(@"Files: %@", fileNameList);
    [documentsTableView reloadData];
    [refreshControl endRefreshing];
}

- (void)iCloudError:(NSError *)error {
    NSLog(@"Error: %@", error);
    [documentsTableView reloadData];
}

- (void)documentsStartedUploading {
    [refreshControl beginRefreshing];
}

- (void)documentsFinishedUploading {
    [refreshControl endRefreshing];
}

//----------------------------------------------------------------------------------------------------------------//
// Table View ----------------------------------------------------------------------------------------------------//
//----------------------------------------------------------------------------------------------------------------//
#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([fileNameList count] == 0) {
        //No iCloud documents - display an error message
        noFilesImage.image = [UIImage imageNamed:@"NoDocuments"];
        documentsTableView.hidden = YES;
        noFilesImage.hidden = NO;
        return 0;
    } else {
        return [fileNameList count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([fileNameList count] != 0) {
        static NSString *cellID = @"documentCell";
    
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        }
    
        NSString *fileName = [fileNameList objectAtIndex:[indexPath row]];
        //NSString *fileDate = [fileDateList objectAtIndex:[indexPath row]];
        cell.textLabel.text = fileName;
        //cell.detailTextLabel.text = fileDate;
    
        return cell;
    } else {
        return nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    //Get the file name
    NSString *fileName = [fileNameList objectAtIndex:indexPath.row];
    selectedFileName = fileName;
    
    //Retrieve the document
    [iCloud retrieveCloudDocumentWithName:fileName completion:^(UIDocument *cloudDocument, NSData *documentData) {
        //Pass the file content and name to the Detail View Controller
        selectedFileContent = [[NSString alloc] initWithData:documentData encoding:NSUTF8StringEncoding];
        selectedFileName = [[cloudDocument.fileURL lastPathComponent] stringByDeletingPathExtension];
        //NSLog(@"Completion BLOCK Content: %@", selectedFileContent);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:selectedFileName message:selectedFileContent delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil];
        [alert show];
        [self performSegueWithIdentifier:@"showDocumentDetails" sender:self];
    }];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        //Get the File name
        NSString *fileName = [fileNameList objectAtIndex:[indexPath row]];
        
        //Remove the file
        [iCloud removeDocumentNamed:fileName withDelegate:self completion:^{
            NSLog(@"Document Removed");
        }];
        
        //Remove the URL from the documents array.
        [fileNameList removeObjectAtIndex:[indexPath row]];
        
        //Update the table UI. This must happen after updating the documents array.
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if ([segue.identifier isEqualToString:@"showDocumentDetails"]) {
        DetailViewController *controller = (DetailViewController *)segue.destinationViewController;;
        controller.fileTitleBar.title = selectedFileName;
        controller.fileContentString = selectedFileContent;
    }
}

//----------------------------------------------------------------------------------------------------------------//
// Alert View ----------------------------------------------------------------------------------------------------//
//----------------------------------------------------------------------------------------------------------------//
#pragma mark - Alert View

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    //Get Button Index
    NSString *title = [alertView buttonTitleAtIndex:buttonIndex];
    if ([title isEqualToString:@"Save"]) {
        //Get File Name
        UITextField *fileName = [alertView textFieldAtIndex:0];
        NSString *filetitle = [NSString stringWithFormat:@"%@.txt", fileName.text];
        
        [self createEmptyDocumentWithName:filetitle];
    }
}

@end
