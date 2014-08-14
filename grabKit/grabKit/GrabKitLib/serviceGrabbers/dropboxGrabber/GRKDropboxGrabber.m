/*
 *
 */


#import "GRKDropboxGrabber.h"
#import "GRKConnectorsDispatcher.h"
#import "GRKDropboxManager.h"
#import "GRKConstants.h"
#import <DropboxSDK/DropboxSDK.h>

@interface GRKDropboxGrabber()<DBRestClientDelegate>

@end



@implementation GRKDropboxGrabber

-(id) init {
    
    if ((self = [super initWithServiceName:@"Dropbox"]) != nil){
        
    }
    
    return self;
}


#pragma mark - GRKServiceGrabberConnectionProtocol methods


/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void) connectWithConnectionIsCompleteBlock:(GRKGrabberConnectionIsCompleteBlock)connectionIsCompleteBlock andErrorBlock:(GRKErrorBlock)errorBlock;
{
    
    [[GRKDropboxManager manager] connectWithConnectionIsCompleteBlock:connectionIsCompleteBlock andErrorBlock:errorBlock];
}

/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void)disconnectWithDisconnectionIsCompleteBlock:(GRKGrabberDisconnectionIsCompleteBlock)disconnectionIsCompleteBlock andErrorBlock:(GRKErrorBlock)errorBlock;
{
    [[GRKDropboxManager manager] disconnectWithDisconnectionIsCompleteBlock:disconnectionIsCompleteBlock andErrorBlock:errorBlock];
    
}

-(void) isConnected:(GRKGrabberConnectionIsCompleteBlock)connectedBlock;{
    
    @throw NSInvalidArgumentException;
}

/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void) isConnected:(GRKGrabberConnectionIsCompleteBlock)connectedBlock errorBlock:(GRKErrorBlock)errorBlock {
    
    if ( connectedBlock == nil ) @throw NSInvalidArgumentException;
    
    [[GRKDropboxManager manager] isConnected:connectedBlock errorBlock:errorBlock];
}

#pragma mark GRKServiceGrabberProtocol methods

/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) albumsOfCurrentUserAtPageIndex:(NSUInteger)pageIndex
             withNumberOfAlbumsPerPage:(NSUInteger)numberOfAlbumsPerPage
                      andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock
                         andErrorBlock:(GRKErrorBlock)errorBlock;
{
    
    // we don't define 'Album' for dropbox service
    
    
    dispatch_async_on_main_queue(completeBlock, nil);
    
}



/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) fillAlbum:(GRKAlbum *)album
withPhotosAtPageIndex:(NSUInteger)pageIndex
withNumberOfPhotosPerPage:(NSUInteger)numberOfPhotosPerPage
 andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock
    andErrorBlock:(GRKErrorBlock)errorBlock;
{
    
    // we don't define 'Album' for dropbox service
    // discard all parameters except for completeBlock
    
    // This function just fetch all photos saved in your dropbox
    
    [[GRKDropboxManager manager] fetchAllPhotosWith:completeBlock andErrorBlock:errorBlock];
}


-(void) fillCoverPhotoOfAlbums:(NSArray *)albums
             withCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock
                 andErrorBlock:(GRKErrorBlock)errorBlock {
    
    // we don't define 'Album' for dropbox service
    
    dispatch_async_on_main_queue(completeBlock, nil);
    
}


/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) fillCoverPhotoOfAlbum:(GRKAlbum *)album
             andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock
                andErrorBlock:(GRKErrorBlock)errorBlock {
    
    [self fillCoverPhotoOfAlbums:[NSArray arrayWithObject:album]
               withCompleteBlock:completeBlock
                   andErrorBlock:errorBlock];
}


/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) cancelAll {
    
    [[GRKDropboxManager manager] cancelAll];
    
}

/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) cancelAllWithCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock;
{
    
    [self cancelAll];
    
    dispatch_async_on_main_queue(completeBlock, nil);
    
}


@end
