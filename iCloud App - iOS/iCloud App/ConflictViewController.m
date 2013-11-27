//
//  ConflictViewController.m
//  iCloud App
//
//  Created by iRare Media on 11/26/13.
//  Copyright (c) 2013 iRare Media. All rights reserved.
//

#import "ConflictViewController.h"

@interface ConflictViewController ()

@end

@implementation ConflictViewController
@synthesize documentName, documentVersions;

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    documentVersions = [[iCloud sharedCloud] findUnresolvedConflictingVersionsOfFile:documentName];
    return [documentVersions count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"versionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSFileVersion *fileVersion = [documentVersions objectAtIndex:indexPath.row];
    
    NSNumber *filesize = [[iCloud sharedCloud] fileSize:documentName];
    NSDate *updated = [[iCloud sharedCloud] fileModifiedDate:documentName];
    
    NSString *fileDetail = [NSString stringWithFormat:@"%@ bytes, updated %@.\nVersion %@", filesize, [MHPrettyDate prettyDateFromDate:updated withFormat:MHPrettyDateFormatWithTime], fileVersion];
    
    // Configure the cell...
    cell.textLabel.text = documentName;
    cell.detailTextLabel.text = fileDetail;
    cell.detailTextLabel.numberOfLines = 2;
    cell.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[iCloud sharedCloud] resolveConflictForFile:documentName withSelectedFileVersion:[documentVersions objectAtIndex:indexPath.row]];
    [[iCloud sharedCloud] updateFiles];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)cancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
