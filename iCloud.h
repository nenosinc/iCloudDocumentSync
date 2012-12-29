//
//  iCloud.h
//  iCloud Document Sync
//
//  Created by iRare Media on 12/29/12.
//
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@class iCloud;

@protocol iCloudDelegate <NSObject>
@optional
- (void)documentWasDeleted;
- (void)documentWasSaved;
@end

@interface iCloud : NSObject
{
    id <iCloudDelegate> delegate;
}

@property (retain) id delegate;

+ (void)createDocumentWithData:(NSData *)data withName:(NSString *)name;
+ (void)removeDocumentWithName:(NSString *)name;

@end