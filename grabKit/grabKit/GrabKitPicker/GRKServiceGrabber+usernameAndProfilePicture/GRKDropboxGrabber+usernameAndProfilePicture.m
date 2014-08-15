//
//  GRKDropboxGrabber+usernameAndProfilePicture.m
//  grabKit
//
//  Created by dragon on 8/14/14.
//
//

#import "GRKDropboxGrabber+usernameAndProfilePicture.h"
#import "GRKDropboxManager.h"

@implementation GRKDropboxGrabber (usernameAndProfilePicture)

-(void)loadUsernameAndProfilePictureOfCurrentUserWithCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock andErrorBlock:(GRKErrorBlock)errorBlock
{
    
    [[GRKDropboxManager manager] loadUsernameAndProfilePictureOfCurrentUserWithCompleteBlock:completeBlock andErrorBlock:errorBlock];
}

@end
