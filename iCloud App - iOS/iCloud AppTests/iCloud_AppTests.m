//
//  iCloud_AppTests.m
//  iCloud AppTests
//
//  Created by iRare Media on 11/8/13.
//  Copyright (c) 2013 iRare Media. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <iCloud/iCloud.h>

@interface iCloud_AppTests : XCTestCase

@end

@implementation iCloud_AppTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSavingCreatesFile {
    iCloud *cloud = [iCloud sharedCloud];
    [cloud setVerboseAvailabilityLogging:YES];
    [cloud checkCloudUbiquityContainer];
    [cloud checkCloudAvailability];
    
    NSURL *url = [[[iCloud sharedCloud] ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:@"WEASLEEEEEE.txt"];
    iCloudDocument *objUnderTest = [[iCloudDocument alloc] initWithFileURL:url];
    
    // when we call saveToURL:forSaveOperation:completionHandler:
    __block BOOL blockSuccess = NO;
    
    [objUnderTest saveToURL:url forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
         blockSuccess = success;
        
        // then the operation should succeed and a file should be created
        XCTAssertTrue(blockSuccess, @"Not Successful");
     }];
}

@end
