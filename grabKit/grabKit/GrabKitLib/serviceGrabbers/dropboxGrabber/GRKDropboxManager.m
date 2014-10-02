/*
 *
 */


#import "GRKConstants.h"
#import "GRKDropboxManager.h"
#import "GRKConnectorsDispatcher.h"
#import "GRKServiceGrabber.h"
#import "GRKServiceGrabber+usernameAndProfilePicture.h"
#import "GRKPickerThumbnailManager.h"
#import <DropboxSDK/DropboxSDK.h>
#import <DropboxSDK/NSString+URLEscapingAdditions.h>
#import <DropboxSDK/NSString+Dropbox.h>


#define kThumbnailRequestMaxAge  5 // Max age of a request is 5 secs
#define kPhotoRequestMaxAge  10 // Max age of a request is 10 secs
#define kMaxRequestCount 5

typedef void (^GRKDropboxOpenSessionBlock)(BOOL success);

@interface GRKDropboxManager()<DBRestClientDelegate>
{
    GRKServiceGrabberCompleteBlock _fetchPhotosCompleteBlock;
    GRKErrorBlock   _fetchPhotosErrorBlock;
    
    GRKServiceGrabberCompleteBlock _profileCompleteBlock;
    GRKErrorBlock _profileErrorBlock;
    
    BOOL _fetchCompletionCalled;
    
    NSString *_curentPathFetching;
}

@property (nonatomic, strong) DBRestClient *restClient;
@property (nonatomic, strong) NSMutableDictionary *thumbnailReqDictionary;
@property (nonatomic, strong) NSMutableArray *thumbnailReqQueue;

@property (nonatomic, strong) NSMutableDictionary *photoReqDictionary;
@property (nonatomic, strong) NSMutableArray *photoReqQueue;

@property (nonatomic, strong) NSMutableDictionary *pathReqDictionary;
@property (nonatomic, strong) NSMutableArray *pathReqQueue;


@end


@implementation GRKDropboxManager

+ (GRKDropboxManager *)manager
{
    static dispatch_once_t once;
    static GRKDropboxManager *sharedInstance;
    
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

-(id) init
{
    
    if ((self = [super initWithGrabberType:@"Dropbox"]) != nil){
        
        connectionIsCompleteBlock = nil;
        connectionDidFailBlock = nil;
        
        _fetchPhotosCompleteBlock = nil;
        _fetchPhotosErrorBlock = nil;
        
        _profileCompleteBlock = nil;
        _profileErrorBlock = nil;
        
        _isConnecting = NO;
        
        self.pathReqDictionary = [NSMutableDictionary dictionary];
        self.pathReqQueue = [NSMutableArray array];
        
        self.thumbnailReqDictionary = [NSMutableDictionary dictionary];
        self.thumbnailReqQueue = [NSMutableArray array];
        
        self.photoReqDictionary = [NSMutableDictionary dictionary];
        self.photoReqQueue = [NSMutableArray array];
        
    }     
    
    return self;
}
- (DBSession *) dropboxSession
{
    if ([DBSession sharedSession] == nil) {
        DBSession *dbSession = [[DBSession alloc] initWithAppKey:[GRKCONFIG dropboxAppKey] appSecret:[GRKCONFIG dropboxAppSecret] root:kDBRootDropbox];
        [DBSession setSharedSession:dbSession];
    }
    
    return [DBSession sharedSession];
}

- (NSString *) userId
{
    NSString *res = [[[self dropboxSession] userIds] firstObject];
    
    return res ? res : @"unknown";
}

#pragma mark - Internal

- (DBRestClient *)restClientWithResetFlag:(BOOL)reset
{
    if ((!_restClient || reset) && [self dropboxSession]) {
        
        _restClient = [[DBRestClient alloc] initWithSession:[self dropboxSession]];
        _restClient.delegate = self;
    }
    
    return _restClient;
}

- (void) resetRestClient
{
    [_restClient setDelegate:nil];
    [_restClient cancelAllRequests];
    _curentPathFetching = nil;
    _fetchPhotosCompleteBlock = nil;
    _fetchPhotosErrorBlock = nil;
    _restClient = nil;
}

- (DBRestClient *)restClient
{
    if (!_restClient && [self dropboxSession]) {
        
        self.pathReqDictionary = [NSMutableDictionary dictionary];
        self.pathReqQueue = [NSMutableArray array];
        
        self.thumbnailReqDictionary = [NSMutableDictionary dictionary];
        self.thumbnailReqQueue = [NSMutableArray array];
        
        self.photoReqDictionary = [NSMutableDictionary dictionary];
        self.photoReqQueue = [NSMutableArray array];
        
        _restClient = [[DBRestClient alloc] initWithSession:[self dropboxSession]];
        _restClient.delegate = self;
    }
    
    return _restClient;
}

- (UIViewController *)topViewController
{
    
    return [self topViewController:[UIApplication sharedApplication].keyWindow.rootViewController];
    
}

- (UIViewController *)topViewController:(UIViewController *)rootViewController
{
    
    if (rootViewController.presentedViewController == nil) {
        
        return rootViewController;
        
    }
    
    if ([rootViewController.presentedViewController isMemberOfClass:[UINavigationController class]]) {
        
        UINavigationController *navigationController = (UINavigationController *)rootViewController.presentedViewController;
        UIViewController *lastViewController = [[navigationController viewControllers] lastObject];
        
        return [self topViewController:lastViewController];
    }
    
    
    UIViewController *presentedViewController = (UIViewController *)rootViewController.presentedViewController;
    
    return [self topViewController:presentedViewController];
}

-(id) grkObjectWithMetaData:(DBMetadata *)metaData
{
    
    id res = nil;
    
    if ([metaData isDirectory])
    {
        GRKAlbum *album = [GRKAlbum albumWithId:[metaData path]
                                        andName:[metaData filename]
                                       andCount:0
                                       andDates:@{@"created_time":[metaData lastModifiedDate]}];
        album.albumType = metaData.icon;
        album.data = [[metaData path] normalizedDropboxPath];
        res = album;
    }
    else
    {
        res = [self photoWithRawPhoto:metaData];
    }
    
    return res;
}

/** Build and return a GRKPhoto from the given dictionary.
 
 @param rawPhoto a NSDictionary representing the photo to build, as returned by Facebook's API
 @return a GRKPhoto
 */
-(GRKPhoto *) photoWithRawPhoto:(DBMetadata*)rawPhoto;
{
    
    NSString *url = [NSString stringWithFormat:@"dropbox://%@%@", [self userId], [rawPhoto path]];
    NSString * photoId = [rawPhoto path];
    
	// on Facebook, the "name" value of a photo is its caption
    NSString * photoCaption = [rawPhoto filename]  ;
    
    NSMutableDictionary * dates = [NSMutableDictionary dictionary];
    [dates setObject:[rawPhoto lastModifiedDate] forKey:kGRKPhotoDatePropertyDateUpdated];
    
    GRKImage *image = [GRKImage imageWithURL:[NSURL URLWithString:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]
                                    andWidth:320
                                   andHeight:320
                                  isOriginal:YES];
    
    GRKPhoto * photo = [GRKPhoto photoWithId:photoId andCaption:photoCaption andName:nil andImages:@[image] andDates:dates];
    
    return photo;
}

#pragma mark - GRKServiceGrabberConnectionProtocol methods

/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void) connectWithConnectionIsCompleteBlock:(GRKGrabberConnectionIsCompleteBlock)completeBlock andErrorBlock:(GRKErrorBlock)errorBlock;
{
    
    
    
    DBSession *session = [self dropboxSession];
    
    if (! session.isLinked) {
        
        [self cancelAll];
        
        connectionIsCompleteBlock = completeBlock;
        connectionDidFailBlock = errorBlock;
        
        [[GRKConnectorsDispatcher sharedInstance] registerServiceConnectorAsConnecting:self];
        _applicationDidEnterBackground = NO;
        
        
        // The "_isConnecting" flag is usefull to use the DBSession object in a different purpose than it was built for.
        //   The completionHandler below is executed each times the session changes, at any time.
        //   We only want to open the session once, we don't want to be notified all the time. this is what this flag is made for.
        _isConnecting = YES;
        
        [session linkFromController:[self topViewController]];
        
    } else  {
        
        dispatch_async_on_main_queue(completeBlock, YES);
    }
    
}

/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void)disconnectWithDisconnectionIsCompleteBlock:(GRKGrabberDisconnectionIsCompleteBlock)completeBlock andErrorBlock:(GRKErrorBlock)errorBlock;
{
    [self cancelAll];
    [[self dropboxSession] unlinkAll];
    
    dispatch_async_on_main_queue(completeBlock, ![[self dropboxSession] isLinked]);
}

-(void) cancelAll {
    
    if (_restClient)
        [_restClient cancelAllRequests];
    
    _curentPathFetching = nil;
    [self.pathReqDictionary removeAllObjects];
    [self.pathReqQueue removeAllObjects];
    [self.photoReqDictionary removeAllObjects];
    [self.photoReqQueue removeAllObjects];
    [self.thumbnailReqDictionary removeAllObjects];
    [self.thumbnailReqQueue removeAllObjects];
}


/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void) isConnected:(GRKGrabberConnectionIsCompleteBlock)connectedBlock errorBlock:(GRKErrorBlock)errorBlock;
{
    
    DBSession *session = [self dropboxSession];
    
    BOOL connected = [session isLinked];
    
    dispatch_async_on_main_queue(connectedBlock, connected);
}

-(void) applicationDidEnterBackground {
    
    _applicationDidEnterBackground = YES;
    
}

/*  @see refer to GRKServiceConnectorProtocol documentation
 */
-(void) didNotCompleteConnection;{
   
    /*
        this method is called when the app becomes active.
        this code below needs to be performed only if the app entered background first.
        The app can "become active" without entering background first in one peculiar case :
            When de FB sdk attempts to log in from ACAccountStore, an UIAlertView is displayed 
            to ask the user if he allows to give access to his FB account.
            Whether the users allows or refuses, the [UIApplicationDelegate applicationDidBecomeActive] 
            method is called when the UIAlertView dissmisses.
     
    */

    if ( _applicationDidEnterBackground ){
    
        dispatch_async(dispatch_get_main_queue(), ^{
            connectionIsCompleteBlock ? connectionIsCompleteBlock(NO) : nil;
            connectionIsCompleteBlock = nil;
        });
    }
    
}

/*  @see refer to GRKServiceConnectorProtocol documentation
 */
-(BOOL) canHandleURL:(NSURL*)url;
{
    
    return ( [[url scheme] isEqualToString:[NSString stringWithFormat:@"db-%@",[GRKCONFIG dropboxAppKey]]] ) ;
    
}

/*  @see refer to GRKServiceConnectorProtocol documentation
 */
-(void) handleOpenURL:(NSURL*)url; 
{
    
    if ([[self dropboxSession] handleOpenURL:url]) {
        
        [[GRKConnectorsDispatcher sharedInstance] unregisterServiceConnectorAsConnecting:self];
        
        if (_isConnecting)
            _isConnecting = NO;
        
        BOOL connnected = [[self dropboxSession] isLinked];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            connectionIsCompleteBlock ? connectionIsCompleteBlock(connnected) : nil;
            connectionIsCompleteBlock = nil;
        });
    }
}


#pragma mark - Rest API Backend

- (void) loadUsernameAndProfilePictureOfCurrentUserWithCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock andErrorBlock:(GRKErrorBlock)errorBlock
{
    
    if ( [[self dropboxSession] isLinked] ) {
        
        _profileCompleteBlock = completeBlock;
        _profileErrorBlock = errorBlock;
        [self.restClient loadAccountInfo];
    }
    
    
}

- (void) fetchRootDirectoryWithCompletionBlock:(GRKServiceGrabberCompleteBlock)completeBlock andErrorBlock:(GRKErrorBlock)errorBlock
{
    if ([[self dropboxSession] isLinked]) {
        
        if ([self.restClient requestCount] > 0)
        {
            [self resetRestClient];
        }
        
        [self fetchPath:@"/" withCompleteBlock:completeBlock andErrorBlock:errorBlock];
        
    }
    else
    {
        dispatch_async_on_main_queue(errorBlock, [GRKServiceGrabber errorForBadConnectionForService:@"dropbox"]);
    }
}

- (NSInteger)processNextPhotoRequestsInQueueWithLimit:(NSInteger)limit
{
    
    NSInteger procceedCount = 0;
    
    @synchronized(self.photoReqQueue) {
        
        NSInteger index = 0;
        
        while ([self.restClient requestCount] < kMaxRequestCount && index < limit) {
            
            NSDictionary *request = [self.photoReqQueue lastObject];
            
            if (request == nil)
                break;
            
            NSLog(@"Downloading Photo : %@", request[@"path"]);
            
            [self downloadPhotoAtPath:request[@"path"] withCompletionBlock:request[@"completion"]];
            
            [self.photoReqQueue removeObject:request];
            
            procceedCount ++;
        }
        
    }
    
    return procceedCount;
}

- (NSInteger)processNextThumanilRequestsInQueueWithLimit:(NSInteger)limit
{
    
    NSInteger procceedCount = 0;
    
    @synchronized(self.thumbnailReqQueue) {
        
        NSInteger index = 0;
        
        while ([self.restClient requestCount] < kMaxRequestCount && index < limit) {
            
            NSDictionary *request = [self.thumbnailReqQueue lastObject];
            
            if (request == nil)
                break;
            
            NSLog(@"Downloading Thumbnail : %@", request[@"path"]);
            
            [self downloadThumbnailAtPath:request[@"path"] withCompletionBlock:request[@"completion"]];
            
            [self.thumbnailReqQueue removeObject:request];
            
            procceedCount ++;
        }
        
    }
    
    return procceedCount;
}

- (NSInteger) processNextPathRequestWithLimit:(NSInteger)limit
{
    
    NSInteger procceedCount = 0;
    
    @synchronized(self.pathReqQueue) {
        
        NSInteger index = 0;
        
        while ([self.restClient requestCount] < kMaxRequestCount && index < limit) {
            
            NSDictionary *request = [self.pathReqQueue lastObject];
            
            if (request == nil)
                break;
            
            NSLog(@"Fetching Path : %@", request[@"path"]);
            
            if (![self internalFetchPath:request[@"path"] withCompletionBlock:request[@"completion"] andErrorBlock:request[@"error"]])
                break;
            
            [self.pathReqQueue removeObject:request];
            
            procceedCount ++;
        }
        
    }
    
    return procceedCount;
}


- (void) processNextRequest
{
    if ([self.restClient requestCount] <= kMaxRequestCount - 2)
    {
        NSInteger fetchCount = kMaxRequestCount - [self.restClient requestCount];
        NSInteger reqCountForPathFetch = [self.pathReqQueue count];
        NSInteger reqCountForPhotoDownload = [self.photoReqQueue count];
        NSInteger reqCountForThumbnailDownload = [self.thumbnailReqQueue count];
        
        
        if (reqCountForPhotoDownload == 0 && reqCountForThumbnailDownload == 0)
            reqCountForPathFetch = fetchCount;
        else
            reqCountForPathFetch = MAX(1, fetchCount - reqCountForPhotoDownload - reqCountForThumbnailDownload);
        
        reqCountForPhotoDownload = fetchCount - [self processNextPathRequestWithLimit:reqCountForPathFetch];
        NSInteger proceedCount = [self processNextPhotoRequestsInQueueWithLimit:reqCountForPhotoDownload];
        
        if (proceedCount < reqCountForPhotoDownload)
            [self processNextThumanilRequestsInQueueWithLimit:reqCountForPhotoDownload - proceedCount];
        
    }
}

#pragma mark Path

- (void) fetchPath:(NSString *)Path withCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock andErrorBlock:(GRKErrorBlock)errorBlock
{
    NSString *path = [Path normalizedDropboxPath];
    
    if ([self.restClient requestCount] >= kMaxRequestCount || ![self internalFetchPath:path withCompletionBlock:completeBlock andErrorBlock:errorBlock]) {
        
        NSDictionary *request = @{@"path":path,
                                  @"completion":completeBlock,
                                  @"error":errorBlock,
                                  @"date":[NSDate date]};
        
        [self queueFetchPathRequest:request];
        
    }
}


- (BOOL)internalFetchPath:(NSString *)path withCompletionBlock:(GRKServiceGrabberCompleteBlock)completeBlock andErrorBlock:(GRKErrorBlock)errorBlock
{
    
    if (_curentPathFetching == nil)
    {
        _curentPathFetching = [path normalizedDropboxPath];
        
        NSDictionary *blocks = @{@"completion":completeBlock,
                                 @"error":errorBlock};
        
        [self.pathReqDictionary setObject:blocks forKey:path];
        
        [self.restClient loadMetadata:path];
        
        return YES;
    }
    
    return NO;
}

- (void)queueFetchPathRequest:(NSDictionary *)request
{
    
    @synchronized(self.pathReqQueue) {
        
        NSInteger index = 0;
        
        NSDate *now = [NSDate date];
        
        while (index < [self.pathReqQueue count]) {
            
            NSDictionary *req = self.pathReqQueue[index];
            
            if ([req[@"path"] isEqualToString:request[@"path"]] ||
                [now timeIntervalSinceDate:req[@"date"]] > kThumbnailRequestMaxAge)
            {
                [self.pathReqQueue removeObjectAtIndex:index];
                continue;
            }
            
            index ++;
            
        }
        
        [self.pathReqQueue addObject:request];
    }
}

#pragma mark Photo

- (void) downloadPhotoAtURL:(NSURL *)photoURL withCompleteBlock:(GRKDropboxDownloadCompleteBlock)completeBlock
{
    
    NSString *path = [[photoURL absoluteString] stringByReplacingOccurrencesOfString:@"dropbox://" withString:@""];
    path = [[path substringFromIndex:[path rangeOfString:@"/"].location] stringByRemovingPercentEncoding];
    
    
    if ([self.restClient requestCount] < kMaxRequestCount) {
        
        [self downloadPhotoAtPath:path withCompletionBlock:completeBlock];
        
    } else {
        
        NSDictionary *request = @{@"path":path,
                                  @"size":@"xl",
                                  @"completion":completeBlock,
                                  @"date":[NSDate date]};
        
        if ([path hasSuffix:@".png"] || [path hasSuffix:@".jpg"])
        {
            [self queuePhotoDownloadRequest:request];
        }
        else
        {
            [self queueThumbnailDownloadRequest:request];
        }
    }
    
}


- (void)downloadPhotoAtPath:(NSString *)path withCompletionBlock:(GRKDropboxDownloadCompleteBlock)completeBlock
{
    
    CFUUIDRef newUniqueId = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef newUniqueIdString = CFUUIDCreateString(kCFAllocatorDefault, newUniqueId);
    
#if !__has_feature(objc_arc)
    NSString *uuid = [NSString stringWithString:(NSString *)newUniqueIdString];
#else
    NSString *uuid = [NSString stringWithString:(__bridge NSString *)newUniqueIdString];
#endif
    CFRelease(newUniqueId);
    CFRelease(newUniqueIdString);
    
    NSString *photoPath = [NSTemporaryDirectory() stringByAppendingPathComponent:uuid];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:photoPath])
        [[NSFileManager defaultManager] removeItemAtPath:photoPath error:nil];
    
    if ([path hasSuffix:@".png"] || [path hasSuffix:@".jpg"])
    {
        
        [self.photoReqDictionary setObject:completeBlock forKey:photoPath];
        [self.restClient loadFile:path intoPath:photoPath];
    }
    else
    {
        [self.thumbnailReqDictionary setObject:completeBlock forKey:photoPath];
        [self.restClient loadThumbnail:path ofSize:@"xl" intoPath:photoPath];
    }
}

- (void)queuePhotoDownloadRequest:(NSDictionary *)request
{
    
    @synchronized(self.photoReqQueue) {
        
        NSInteger index = 0;
        
        NSDate *now = [NSDate date];
        
        while (index < [self.photoReqQueue count]) {
            
            NSDictionary *req = self.photoReqQueue[index];
            
            if ([now timeIntervalSinceDate:req[@"date"]] > kPhotoRequestMaxAge) {
                
                [self.photoReqQueue removeObjectAtIndex:index];
                
                continue;
                
            }
            
            index ++;
            
        }
        
        [self.photoReqQueue addObject:request];
    }
}

#pragma mark Thumbnail

- (void)downloadThumbnailAtURL:(NSURL*)thumbnailURL forThumbnailSize:(CGSize)thumbnailSize withCompleteBlock:(GRKDropboxDownloadCompleteBlock)completeBlock
{
    
    NSString *path = [[thumbnailURL absoluteString] stringByReplacingOccurrencesOfString:@"dropbox://" withString:@""];
    path = [[path substringFromIndex:[path rangeOfString:@"/"].location] stringByRemovingPercentEncoding];
    
    
    if ([self.restClient requestCount] < kMaxRequestCount) {
        
        [self downloadThumbnailAtPath:path withCompletionBlock:completeBlock];
        
    } else {
        
        NSDictionary *request = @{@"path":path,
                                  @"size":@"m",
                                  @"completion":completeBlock,
                                  @"date":[NSDate date]};
        
        [self queueThumbnailDownloadRequest:request];
    }
}

- (void)downloadThumbnailAtPath:(NSString *)path withCompletionBlock:(GRKDropboxDownloadCompleteBlock)completeBlock
{
    
    CFUUIDRef newUniqueId = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef newUniqueIdString = CFUUIDCreateString(kCFAllocatorDefault, newUniqueId);
    
#if !__has_feature(objc_arc)
    NSString *uuid = [NSString stringWithString:(NSString *)newUniqueIdString];
#else
    NSString *uuid = [NSString stringWithString:(__bridge NSString *)newUniqueIdString];
#endif
    CFRelease(newUniqueId);
    CFRelease(newUniqueIdString);
    
    NSString *thumbnailPath = [NSTemporaryDirectory() stringByAppendingPathComponent:uuid];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:thumbnailPath])
        [[NSFileManager defaultManager] removeItemAtPath:thumbnailPath error:nil];
    
    
    [self.thumbnailReqDictionary setObject:completeBlock forKey:thumbnailPath];
    [self.restClient loadThumbnail:path ofSize:@"m" intoPath:thumbnailPath];
}


- (void)queueThumbnailDownloadRequest:(NSDictionary *)request
{
    
    @synchronized(self.thumbnailReqQueue) {
        
        NSInteger index = 0;
        
        NSDate *now = [NSDate date];
        
        while (index < [self.thumbnailReqQueue count]) {
            
            NSDictionary *req = self.thumbnailReqQueue[index];
            
            if ([req[@"path"] isEqualToString:request[@"path"]] &&
                [req[@"size"] isEqualToString:request[@"size"]])
            {
                [self.thumbnailReqQueue removeObjectAtIndex:index];
                continue;
            }
            else if ([now timeIntervalSinceDate:req[@"date"]] > kThumbnailRequestMaxAge)
            {
                [self.thumbnailReqQueue removeObjectAtIndex:index];
                continue;
            }
            
            index ++;
            
        }
        
        [self.thumbnailReqQueue addObject:request];
    }
}

#pragma mark DBRestClient Delegate

- (void)restClient:(DBRestClient*)client loadedAccountInfo:(DBAccountInfo*)info
{
    
    NSDictionary * blockResult = [NSDictionary dictionaryWithObjectsAndKeys:[info displayName], kGRKUsernameKey,
                                  [info referralLink], kGRKProfilePictureKey,
                                  nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        _profileCompleteBlock ? _profileCompleteBlock(blockResult) : nil;
        
        _profileCompleteBlock = nil;
        
    });
    
    _profileErrorBlock = nil;
}

- (void)restClient:(DBRestClient*)client loadAccountInfoFailedWithError:(NSError*)error
{
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        _profileErrorBlock ? _profileErrorBlock(error) : nil;
        
        _profileErrorBlock = nil;
        
    });
    
    _profileCompleteBlock = nil;
}

- (void)restClient:(DBRestClient *)client loadedMetadata:(DBMetadata *)metadata
{
    
    if ([metadata isDirectory])
    {
        
        NSString *path = [[metadata path] normalizedDropboxPath];
        
        if ([path isEqualToString:_curentPathFetching])
        {
            _curentPathFetching = nil;
        }
        else
        {
            NSLog(@"Unexpected error !!!");
        }
        
        NSDictionary *blocks = [self.pathReqDictionary objectForKey:path];
        
        GRKServiceGrabberCompleteBlock completion = (GRKServiceGrabberCompleteBlock)[blocks objectForKey:@"completion"];
        
        if (completion)
        {
            NSMutableArray *array = [NSMutableArray arrayWithCapacity:[metadata.contents count]];
            
            for (NSInteger index = 0; index < [metadata.contents count]; index ++)
            {
                DBMetadata *item = metadata.contents[index];
                [array addObject:[self grkObjectWithMetaData:item]];
            }
            
            [array sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                if ([obj1 isKindOfClass:[GRKAlbum class]])
                    return NSOrderedAscending;
                
                if ([obj2 isKindOfClass:[GRKAlbum class]])
                    return NSOrderedDescending;
                
                return NSOrderedSame;
            }];
            
            dispatch_async_on_main_queue(completion,array);
            
            [self.pathReqDictionary removeObjectForKey:path];
        }
    }
    else
    {
        
    }
    
    [self processNextRequest];
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error
{
    if (_curentPathFetching)
    {
        
        NSDictionary *blocks = [self.pathReqDictionary objectForKey:_curentPathFetching];
        GRKErrorBlock errorBlock = (GRKErrorBlock)[blocks objectForKey:@"error"];
        
        if (error)
        {
            NSError *err = [GRKServiceGrabber errorForBadFormatResultForAlbumsOperationWithOriginalError:error forService:@"dropbox"];
            dispatch_async_on_main_queue(errorBlock, err);
            [self.pathReqDictionary removeObjectForKey:_curentPathFetching];
        }
        
        _curentPathFetching = nil;
    }
    
    [self processNextRequest];
}

- (void)restClient:(DBRestClient*)restClient loadedSearchResults:(NSArray*)results
           forPath:(NSString*)path keyword:(NSString*)keyword
{
    
    
    if ([keyword isEqualToString:@"."]) {
        
        
        NSMutableArray *array = [NSMutableArray array];
        
        for (DBMetadata *metaData in results) {
            
            if ( ![metaData isDirectory] ) {
                
                [array addObject:[self photoWithRawPhoto:metaData]];
                
            }
            
        }
        
        NSArray *res = [NSArray arrayWithArray:array];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            _fetchPhotosCompleteBlock ? _fetchPhotosCompleteBlock(res) : nil;
            
            _fetchPhotosCompleteBlock = nil;
            
        });
        
        
        _fetchPhotosErrorBlock = nil;
        
    }
}

- (void)restClient:(DBRestClient*)restClient searchFailedWithError:(NSError*)error
{
    
    _fetchPhotosCompleteBlock = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        _fetchPhotosErrorBlock ? _fetchPhotosErrorBlock(error) : nil;
        
        _fetchPhotosErrorBlock = nil;
        
    });
    
}

- (void)restClient:(DBRestClient *)client loadedFile:(NSString *)destPath
{
    @synchronized(self.photoReqDictionary) {
        
        GRKDropboxDownloadCompleteBlock completeBlock = [self.photoReqDictionary objectForKey:destPath];
        
        if (completeBlock) {
            
            UIImage *image = [UIImage imageWithContentsOfFile:destPath];
            
            dispatch_async_on_main_queue(completeBlock, image);
            
            [self.photoReqDictionary removeObjectForKey:destPath];
            
        }
    }
    
    [self processNextRequest];
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error
{
    NSLog(@"Dropbox error : %@", error);
    
    [self processNextRequest];
}

- (void)restClient:(DBRestClient*)client loadedThumbnail:(NSString*)destPath metadata:(DBMetadata*)metadata
{
    
    @synchronized(self.thumbnailReqDictionary) {
        
        GRKDropboxDownloadCompleteBlock completeBlock = [self.thumbnailReqDictionary objectForKey:destPath];
        
        if (completeBlock) {
            
            UIImage *image = [UIImage imageWithContentsOfFile:destPath];
            
            dispatch_async_on_main_queue(completeBlock, image);
            
            [self.thumbnailReqDictionary removeObjectForKey:destPath];
            
        }
    }
    
    [self processNextRequest];
}

- (void)restClient:(DBRestClient*)client loadThumbnailFailedWithError:(NSError*)error
{
    NSLog(@"Dropbox error : %@", error);
    
    [self processNextRequest];
}



@end
