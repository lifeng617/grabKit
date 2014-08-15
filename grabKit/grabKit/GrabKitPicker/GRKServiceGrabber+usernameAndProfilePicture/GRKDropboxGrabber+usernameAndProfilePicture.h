//
//  GRKDropboxGrabber+usernameAndProfilePicture.h
//  grabKit
//
//  Created by dragon on 8/14/14.
//
//

#import "GRKDropboxGrabber.h"

@interface GRKDropboxGrabber (usernameAndProfilePicture)

-(void)loadUsernameAndProfilePictureOfCurrentUserWithCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock andErrorBlock:(GRKErrorBlock)errorBlock;

@end
