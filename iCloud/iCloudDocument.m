//
//  iCPDocument.m
//  iCloudPlayground
//
//  Created by Leonhard Lichtschlag (leonhard@lichtschlag.net) on 16/Nov/11.
//  Copyright (c) 2011 Leonhard Lichtschlag. All rights reserved.
//
//  Edited by iRare Media on March 23, 2013
//

#import "iCloudDocument.h"

@implementation iCloudDocument
@synthesize contents;

// ---------------------------------------------------------------------------------------------------------------//
// Document Life Cycle -------------------------------------------------------------------------------------------//
// ---------------------------------------------------------------------------------------------------------------//
#pragma mark - Document Life Cycle

- (id) initWithFileURL:(NSURL *)url
{
	self = [super initWithFileURL:url];
    
	if (self)  {
		self.contents = [[NSData alloc] init];
	}
    
	return self;
}


- (NSString *) localizedName
{
	return [self.fileURL lastPathComponent];
}


// ---------------------------------------------------------------------------------------------------------------//
// Loading and Saving --------------------------------------------------------------------------------------------//
// ---------------------------------------------------------------------------------------------------------------//
#pragma mark - Loading and Saving

- (id) contentsForType:(NSString *)typeName error:(NSError **)outError
{
	NSData *data = self.contents;
	return data;
}


- (BOOL) loadFromContents:(id)fileContents ofType:(NSString *)typeName error:(NSError **)outError
{
	self.contents = fileContents;
	return YES;
}


- (void) handleError:(NSError *)error userInteractionPermitted:(BOOL)userInteractionPermitted
{
	NSLog(@"%s %@", __PRETTY_FUNCTION__, error);
}


@end

