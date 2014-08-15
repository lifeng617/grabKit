/*
 *
 */


#import <Foundation/Foundation.h>
#import "GRKServiceConnectorProtocol.h"
#import "GRKServiceConnector.h"


typedef void (^GRKDropboxDownloadCompleteBlock)(UIImage * thumbnail);


/** a GRKDropboxConnector is an object responsible for authenticating the user on Dropbox.
*/
@interface GRKDropboxManager : GRKServiceConnector <GRKServiceConnectorProtocol> {
    
    GRKGrabberConnectionIsCompleteBlock connectionIsCompleteBlock;
    GRKErrorBlock connectionDidFailBlock;
    
    GRKGrabberDisconnectionIsCompleteBlock disconnectionIsCompleteBlock;
    
    BOOL _isConnecting;
    
    BOOL _applicationDidEnterBackground;
}

/** @name Cancel all */
+ (GRKDropboxManager *)manager;
- (void) cancelAll;

- (void) fetchAllPhotosWith:(GRKServiceGrabberCompleteBlock)completeBlock
              andErrorBlock:(GRKErrorBlock)errorBlock;

- (void) downloadThumbnailAtURL:(NSURL*)thumbnailURL forThumbnailSize:(CGSize)thumbnailSize withCompleteBlock:(GRKDropboxDownloadCompleteBlock)completeBlock;

- (void) downloadPhotoAtURL:(NSURL *)photoURL withCompleteBlock:(GRKDropboxDownloadCompleteBlock)completeBlock;

- (void) loadUsernameAndProfilePictureOfCurrentUserWithCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock andErrorBlock:(GRKErrorBlock)errorBlock;
@end
