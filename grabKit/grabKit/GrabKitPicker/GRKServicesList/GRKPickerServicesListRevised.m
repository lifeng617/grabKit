//
//  GRKPickerServicesListRevised.m
//  grabKit
//
//  Created by dragon on 8/14/14.
//
//

#import "GrabKit.h"
#import "GRKPickerViewController.h"
#import "GRKPickerViewController+privateMethods.h"
#import "GRKPickerServicesListRevised.h"
#import "GRKServiceGrabberConnectionProtocol.h"
#import "GRKPickerAlbumsList.h"
#import "GRKPickerCloudPhotosList.h"
#import "GRKPickerPhotosList.h"
#import "GRKPickerAlbumsListCell.h"
#import "GRKPickerServiceListCell.h"

#import "MBProgressHUD.h"

#import "GRKServiceGrabber+usernameAndProfilePicture.h"
#import "GRKDeviceGrabber.h"

#import "GRKPickerThumbnailManager.h"

#import <FacebookSDK/FacebookSDK.h>

#import "AsyncURLConnection.h"

#import "GRKAlbum+modify.h"


static NSString *loadMoreCellIdentifier = @"loadMoreCell";

@interface GRKPickerServicesListRevised()<GRKPickerServiceListCellDelegate>
-(void)loadMoreAlbums;
-(void)setState:(GRKPickerAlbumsListState)newState;
-(void)showHUD;
-(void)hideHUD;
@end


@implementation GRKPickerServicesListRevised


-(void) dealloc {
    
    for( GRKAlbum * album in _albums ){
        [album removeObserver:self forKeyPath:@"count"];
    }
    
}

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if ( self ){
        
        // build the array of services
        services = [NSMutableArray array];
        
        
        // build a dictionary per service
#if GRK_FACEBOOK_SERVICE
        NSDictionary * facebook = [NSDictionary dictionaryWithObjectsAndKeys:@"GRKFacebookGrabber", @"class",
                                   @"Facebook", @"title",
                                   nil];
        [services addObject:facebook];
#endif
        
#if GRK_FLICKR_SERVICE
        NSDictionary * flickr = [NSDictionary dictionaryWithObjectsAndKeys:@"GRKFlickrGrabber", @"class",
                                 @"FlickR", @"title",
                                 nil];
        [services addObject:flickr];
#endif
        
#if GRK_INSTAGRAM_SERVICE
        NSDictionary * instagram = [NSDictionary dictionaryWithObjectsAndKeys:@"GRKInstagramGrabber", @"class",
                                    @"Instagram", @"title",
                                    nil];
        [services addObject:instagram];
#endif
        
#if GRK_PICASA_SERVICE
        NSDictionary * picasa = [NSDictionary dictionaryWithObjectsAndKeys:@"GRKPicasaGrabber", @"class",
                                 @"Picasa", @"title",
                                 nil];
        [services addObject:picasa];
#endif
        
#if GRK_DROPBOX_SERVICE
        NSDictionary * dropbox = [NSDictionary dictionaryWithObjectsAndKeys:@"GRKDropboxGrabber", @"class",
                                  @"Dropbox", @"title",
                                  nil];
        [services addObject:dropbox];
#endif
        
        _grabber = nil;
        _albums = [[NSMutableArray alloc] init];
        _lastLoadedPageIndex = 0;
        allAlbumsGrabbed = NO;
        [self setState:GRKPickerAlbumsListStateInitial];
        
    }
    
    return self;
}

/*
 
 This state design-pattern must be used to update UI only.
 
 */
-(void) setState:(GRKPickerAlbumsListState)newState {
    
    
    state = newState;
    
    switch (newState) {
            
        case GRKPickerAlbumsListStateConnecting:
        {
            
            [self showHUD];
            
            INCREASE_OPERATIONS_COUNT
        }
            break;
            
            
        case GRKPickerAlbumsListStateNeedToConnect:
        {
            
            DECREASE_OPERATIONS_COUNT
            
            [self hideHUD];
            
            
        }
            break;
            
        case GRKPickerAlbumsListStateConnected:
        {
            DECREASE_OPERATIONS_COUNT
            
        }
            break;
            
            
        case GRKPickerAlbumsListStateDidNotConnect:
        {
            DECREASE_OPERATIONS_COUNT
            
            [self.navigationController popViewControllerAnimated:YES];
            
        }
            break;
            
        case GRKPickerAlbumsListStateConnectionFailed:
        {
            
            DECREASE_OPERATIONS_COUNT
            
            [self hideHUD];
            
            
        }
            break;
            
            
            
            
        case GRKPickerAlbumsListStateGrabbing:
        {
            INCREASE_OPERATIONS_COUNT
            
            if ( [MBProgressHUD HUDForView:self.view] == nil ){
                [self showHUD];
                
            }
            
        }
            
            break;
            
            
            // When some albums are grabbed, reload the tableView
        case GRKPickerAlbumsListStateAlbumsGrabbed:
        case GRKPickerAlbumsListStateAllAlbumsGrabbed:
        {
            DECREASE_OPERATIONS_COUNT
            
            // If that's the first grab, then the tableView has not been added to the view yet.
            if ( self.tableView.hidden  ){
                
                //First Let's make the table view invisible
                self.tableView.alpha = 0;
                self.tableView.hidden = NO;
                
                // And animate the have a nice transition between the HUD and the tableView
                [UIView animateWithDuration:0.33 animations:^{
                    
                    self.tableView.alpha = 1;
                    [self hideHUD];
                    
                }];
                
            } else {
                // else, just hide the HUD
                [self hideHUD];
                
            }
            
            [self.tableView reloadData];
            
            
        }
            break;
            
        case GRKPickerAlbumsListStateGrabbingFailed:
        {
            DECREASE_OPERATIONS_COUNT
            
            NSIndexPath * loadMoreCellIndexPath = [NSIndexPath indexPathForRow:[_albums count] inSection:0];
            UITableViewCell * loadMoreCell = [self.tableView cellForRowAtIndexPath:loadMoreCellIndexPath];
            
            if ( [loadMoreCell isKindOfClass:[GRKPickerLoadMoreCell class]] ){
                
                [(GRKPickerLoadMoreCell*)loadMoreCell setToRetry];
            }
            
            [self hideHUD];
            
        }
            break;
            
        case GRKPickerAlbumsListStateDisconnecting:
        {
            INCREASE_OPERATIONS_COUNT
            
            [self showHUD];
            
        }
            break;
            
            
        case GRKPickerAlbumsListStateDisconnected:
        {
            DECREASE_OPERATIONS_COUNT
            
            [self hideHUD];
            
            [self.navigationController popToRootViewControllerAnimated:YES];
            
        }
            break;
            
            
        case GRKPickerAlbumsListStateError:
        {
            DECREASE_OPERATIONS_COUNT
            
            [self hideHUD];
            
        }
            break;
            
        default:
            break;
    }
    
    
}

-(void)showHUD {
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeIndeterminate;
    
    hud.labelText = GRK_i18n(@"GRK_ALBUMS_LIST_HUD_LOADING", @"Loading ...");
    
}

-(void)hideHUD {
    [MBProgressHUD  hideHUDForView:self.view animated:YES];
    
}


#pragma mark GRKPickerLoadMoreCellDelegate

-(void)cellDidReceiveTouchOnLoadMoreButton:(GRKPickerLoadMoreCell *)cell {
    
    if ( state == GRKPickerAlbumsListStateGrabbing ){
        return;
    }
    
    if ( ! allAlbumsGrabbed ){
        [self loadMoreAlbums];
        
    } else {
        [self.tableView reloadData];
        
    }
    
}


-(void) didTouchCancelButton {
    
    [[GRKPickerViewController sharedInstance] dismiss];
    
}

-(IBAction)didTouchConnectButton {
    
    
    [self setState:GRKPickerAlbumsListStateConnecting];
    
    [(id<GRKServiceGrabberConnectionProtocol>)_grabber connectWithConnectionIsCompleteBlock:^(BOOL connected) {
        
        if ( connected ) {
            
            [self setState:GRKPickerAlbumsListStateConnected];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [self loadMoreAlbums];
                
            });
            
        } else {
            
            [self setState:GRKPickerAlbumsListStateDidNotConnect];
            
        }
        
    } andErrorBlock:^(NSError *error) {
        
        [self setState:GRKPickerAlbumsListStateConnectionFailed];
        NSLog(@" an error occured trying to connect the grabber : %@", error);
        
        
    }];
    
    
    
}



- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.rowHeight = 80.0;
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // If the navigation bar is translucent, it'll recover the top part of the tableView
    // Let's add some inset to the tableView to avoid this
    // Nevertheless, we don't need to do it when the picker is in a popover, because the navigationBar is not visible
    if ( ! [[GRKPickerViewController sharedInstance] isPresentedInPopover] && self.navigationController.navigationBar.translucent ){
        
        self.tableView.contentInset = UIEdgeInsetsMake(self.navigationController.navigationBar.frame.size.height, 0, 0, 0);
        
    }
    
    
    [self.tableView reloadData];
}



- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(didTouchCancelButton)];
    
}

- (void) unloadAssetAlbums
{
    [_grabber cancelAll];
    _grabber = nil;
    
    for (GRKAlbum *album in _albums) {
        [album removeObserver:self forKeyPath:@"count"];
        [album clear];
    }
    
    [_albums removeAllObjects];
    [self.tableView reloadData];
    
    [self setState:GRKPickerAlbumsListStateInitial];
    
    RESET_OPERATIONS_COUNT
}

- (void) loadAssetAlbums
{
    _lastLoadedPageIndex = 0;
    allAlbumsGrabbed = NO;
    
    for (GRKAlbum *album in _albums) {
        [album removeObserver:self forKeyPath:@"count"];
    }
    [_albums removeAllObjects];
    
    [self.tableView reloadData];
    
    
    if (!_grabber)
        _grabber = [[GRKDeviceGrabber alloc] init];
    
    [self setState:GRKPickerAlbumsListStateConnecting];
    
    
    // If the grabber needs to connect
    if ( _grabber.requiresConnection ){
        
        
        [(id<GRKServiceGrabberConnectionProtocol>)_grabber isConnected:^(BOOL connected) {
            
            if ( ! connected ){
                [self setState:GRKPickerAlbumsListStateNeedToConnect];
                
            } else {
                
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    
                    [self setState:GRKPickerAlbumsListStateConnected];
                    // start grabbing albums
                    [self loadMoreAlbums];
                    
                });
                
            }
            
        } errorBlock:^(NSError *error) {
            
            NSLog(@" an error occured trying to check if the grabber is connected : %@", error);
            
            dispatch_async(dispatch_get_main_queue(), ^(void){
                
                [self setState:GRKPickerAlbumsListStateConnectionFailed];
                
            });
            
        }];
        
    } else {
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            
            [self setState:GRKPickerAlbumsListStateConnected];
            // start grabbing albums ( we don't need to add the "log out" button, as the grabber doesn't need to connect ...)
            [self loadMoreAlbums];
            
        });
        
    }
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [_grabber cancelAll];
    
    // Reset the operations count.
    // If the view disappears while something is (i.e. after a INCREASE_OPERATIONS_COUNT),
    //  the corresponding DECREASE_OPERATIONS_COUNT is not called, and the activity indicator remains spinning...
    RESET_OPERATIONS_COUNT
    
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return ( interfaceOrientation == UIInterfaceOrientationPortrait || UIInterfaceOrientationIsLandscape(interfaceOrientation) );
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    /* If the navigation bar is not translucent, then we don't need to animate anything during rotation
     If you don't understand why :
     _ comment the test below
     _ go to GRKPickerViewController.m
     _ set the navigationBar.translucent to NO,
     _ Build and run the Demo app, select a service, and wait for the albums list to load
     _ Now, rotate from portrait to landscape, and scroll ...
     */
    if ( [[GRKPickerViewController sharedInstance] isPresentedInPopover] || ! self.navigationController.navigationBar.translucent ){
        return;
    }
    
    /* In order to have a beautiful rotation effect, we want :
     _ That the space reserved for the header view fits the header view ( i.e. update the tableView's contentInset to the navigationBar's height )
     _ If the tableView is scrolled at the top BEFORE the rotation begins, we want it to still be scrolled at the top AFTER the rotation.
     
     */
    
    CGFloat top; // The top value of the content inset
    BOOL shouldScrollToTop = NO;
    
    CGFloat navigationBarHeightLandscape = 32;
    CGFloat navigationBarHeightPortrait = 44;
    
    // If we are rotating to Landscape ...
    if (  UIInterfaceOrientationIsLandscape(toInterfaceOrientation)   ){
        top = navigationBarHeightLandscape;
        shouldScrollToTop = ( self.tableView.contentOffset.y ==  - navigationBarHeightPortrait );
        
    } else {
        top = navigationBarHeightPortrait;
        shouldScrollToTop = ( self.tableView.contentOffset.y ==  - navigationBarHeightLandscape );
        
    }
    
    [UIView animateWithDuration:duration animations:^{
        
        self.tableView.contentInset = UIEdgeInsetsMake(top, 0, 0, 0);
        if ( shouldScrollToTop ){
            self.tableView.contentOffset = CGPointMake(0, - top);
        }
        
    }];
    
    
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    
    // retrieve the loadMoreCell to update it
    NSIndexPath * loadMoreCellIndexPath = [NSIndexPath indexPathForRow:[_albums count] inSection:0];
    UITableViewCell * loadMoreCell = [self.tableView cellForRowAtIndexPath:loadMoreCellIndexPath];
    
    
    if ( [loadMoreCell isKindOfClass:[GRKPickerLoadMoreCell class]] ){
        [(GRKPickerLoadMoreCell*)loadMoreCell updateButtonFrame];
        
    }
    
}





-(void) prepareCell:(GRKPickerAlbumsListCell *)cell fromTableView:(UITableView*)tableView atIndexPath:(NSIndexPath*)indexPath withAlbum:(GRKAlbum*)album  {
    
    // This just sets the album name and the photos count.
    [cell setAlbum:album];
    
    
    if ( album.coverPhoto == nil && [album.coverPhoto.images count] == 0 )
        return;
    
    if (album.coverPhoto.thumbnail != nil) {
        [cell updateThumbnailWithImage:album.coverPhoto.thumbnail animated:NO];
        return;
    }
    
    
    NSURL * thumbnailURL = nil;
    
    // Pick a GRKImage of the cover photo that fits the thumbnail.
    // The imageView for thumbnails is 75px wide, so we need images with both dimensions greater or equal to 2*75px, for a perfect result on retina displays
    NSUInteger minWidth = cell.thumbnail.frame.size.width * 2;
    NSUInteger minHeight = cell.thumbnail.frame.size.height * 2;
    
    NSArray * imagesSortedByHeight = [album.coverPhoto imagesSortedByHeight];
    for( GRKImage * image in imagesSortedByHeight ){
        
        if ( image.width >= minWidth && image.height >= minHeight ) {
            
            thumbnailURL = image.URL;
            // Once we have found the first thumbnail bigger than the thumbnail, break the loop
            break;
        }
    }
    
    // At this point, if the thumbnail is nil, it means the photo doesn't have an image bigger than 150x150 px
    // Then, take the biggest image of the photo instead.
    if ( thumbnailURL == nil ){
        thumbnailURL = ((GRKImage*)[imagesSortedByHeight lastObject]).URL;
    }
    
    
    // Try to retreive the thumbnail from the cache first ...
    UIImage * cachedThumbnail = [[GRKPickerThumbnailManager sharedInstance] cachedThumbnailForURL:thumbnailURL andSize:CGSizeMake(minWidth, minHeight)];
    
    if ( cachedThumbnail == nil ) {
        
        // If it hasn't been downloaded yet, let's do it
        [[GRKPickerThumbnailManager sharedInstance] downloadThumbnailAtURL:thumbnailURL
                                                          forThumbnailSize:CGSizeMake(minWidth, minHeight)
                                                         withCompleteBlock:^( UIImage *image, BOOL retrievedFromCache ) {
                                                             
                                                             if ( image != nil ){
                                                                 
                                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                                     
                                                                     /* do not do that :
                                                                      [cell updateThumbnailWithImage:image animated:NO];
                                                                      
                                                                      This block is performed asynchronously.
                                                                      During the download of the image, the given cell may have been dequeued and reused, so we would be updating the wrong cell.
                                                                      Do this instead :
                                                                      */
                                                                     
                                                                     GRKPickerAlbumsListCell * cellToUpdate = (GRKPickerAlbumsListCell *)[tableView cellForRowAtIndexPath:indexPath];
                                                                     [cellToUpdate updateThumbnailWithImage:image animated: ! retrievedFromCache ];
                                                                     
                                                                 });
                                                                 
                                                             }
                                                             
                                                             
                                                         } andErrorBlock:^(NSError *error) {
                                                             
                                                             // Nothing to do, fail silently
                                                         }];
        
        
    }else {
        
        // else, just update it
        [cell updateThumbnailWithImage:cachedThumbnail animated:NO];
    }
    
    
    
    
}

- (GRKServiceGrabber *)grabberForService:(NSDictionary *)service
{
    NSString * grabberClassName = [service objectForKey:@"class"];
    
    
    Class grabberClass = NSClassFromString(grabberClassName);
    
    id grabber = nil;
    @try {
        grabber = [[grabberClass alloc] init];
    }
    @catch (NSException *exception) {
        
        NSLog(@" exception : %@", exception);
    }
    
    return grabber;
}

- (void)logoutForServiceListCell:(GRKPickerServiceListCell *)cell
{
    
    NSUInteger index = cell.index;
    GRKServiceGrabber *grabber = [self grabberForService:services[index]];
    
    
    __weak GRKPickerServicesListRevised *wself = self;
    
    [self showHUD];
    
    [grabber cancelAllWithCompleteBlock:^(NSArray *results) {
        
        [(GRKServiceGrabber<GRKServiceGrabberConnectionProtocol> *)grabber disconnectWithDisconnectionIsCompleteBlock:^(BOOL disconnected) {
            
            [GRKServiceGrabber setConnectionState:GRKServiceStateDisconnected
                                        andUserId:nil
                                       forService:grabber.serviceName];
            
            __strong GRKPickerServicesListRevised *sself = wself;
            
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:1];
            [sself.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            [sself hideHUD];
            
        } andErrorBlock:^(NSError *error) {
            
            [GRKServiceGrabber setConnectionState:GRKServiceStateUnknown
                                        andUserId:nil
                                       forService:grabber.serviceName];
            
            __strong GRKPickerServicesListRevised *sself = wself;
            
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:1];
            [sself.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            [sself hideHUD];
        }];
        
    }];
    
}

#pragma mark - Table view data source

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
        return @"";
    else
        return @"Social Media";
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    
    if (section == 0) {
        
        NSUInteger res = [_albums count];
        
        // If some albums have been grabbed, show an extra cell for "N albums - Load More"
        if ( state == GRKPickerAlbumsListStateAlbumsGrabbed ) res++;
        
        // If all albums have been grabbed, show an extra cell for "N Albums"
        //  if ( state == GRKPickerAlbumsListStateAllAlbumsGrabbed ) res++;
        
        return res;
    }
    
    return [services count];
    
}



- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    UITableViewCell *cell = nil;
    
    if (indexPath.section == 0) {
        
        // Device's Albums
        
        // Handle the extra cell
        if ( indexPath.row >= [_albums count] ){
            
            if ( ! allAlbumsGrabbed ){
                
                cell = [tableView dequeueReusableCellWithIdentifier:loadMoreCellIdentifier];
                cell = [[GRK_BUNDLE loadNibNamed:@"GRKPickerLoadMoreCell" owner:nil options:nil] objectAtIndex:0];
                ((GRKPickerLoadMoreCell*)cell).delegate = self;
                [(GRKPickerLoadMoreCell*)cell setToLoadMore];
                
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            
        } else {
            
            static NSString *CellIdentifier = @"AlbumCell";
            
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) {
                
                cell = [[GRK_BUNDLE loadNibNamed:@"GRKPickerAlbumsListCell" owner:nil options:nil] objectAtIndex:0];
            }
            
            GRKAlbum * albumAtIndexPath = (GRKAlbum*)[_albums objectAtIndex:indexPath.row];
            
            [self prepareCell:(GRKPickerAlbumsListCell*)cell fromTableView:tableView atIndexPath:indexPath withAlbum:albumAtIndexPath];
            
            if ( albumAtIndexPath.count > 0 ){
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleGray;
                
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            
            
            
        }
        
        cell.selected = NO;
        
    }
    else
    {
        static NSString *CellIdentifier = @"ServiceCell";
        
        GRKPickerServiceListCell *serviceCell;
        
        serviceCell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (serviceCell == nil) {
            serviceCell = [[GRK_BUNDLE loadNibNamed:@"GRKPickerServiceListCell" owner:nil options:nil] objectAtIndex:0];
        }
        
        NSDictionary *service = services[indexPath.row];
        NSString *serviceName = [service objectForKey:@"title"];
        NSString * path = [GRK_BUNDLE pathForResource:[serviceName lowercaseString] ofType:@"png"];
        
        GRKServiceState serviceState = [GRKServiceGrabber connectionStateForService:serviceName];
        NSString *userId = [GRKServiceGrabber userIdForService:serviceName];
        
        serviceCell.titleLabel.text = userId ? userId : serviceName;
        serviceCell.imgView.image = [UIImage imageWithContentsOfFile:path];
        serviceCell.delegate = self;
        serviceCell.index = indexPath.row;
        serviceCell.logoutButton.hidden = serviceState != GRKServiceStateConnected;
        
        if ( serviceState == GRKServiceStateUnknown )
            [serviceCell loadUserProfileWithGrabber:[self grabberForService:service]];
        
        cell = serviceCell;
    }
    
    
    return cell;
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if ( [cell isKindOfClass:[GRKPickerLoadMoreCell class]]) {
        [(GRKPickerLoadMoreCell*)cell updateButtonFrame];
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    [[tableView cellForRowAtIndexPath:indexPath] setSelected:NO];
    
    if (indexPath.section == 0) {
        
        if ( indexPath.row <= [_albums count] -1 ) {
            
            GRKAlbum * albumAtIndexPath = [_albums objectAtIndex:indexPath.row];
            
            if ( albumAtIndexPath.count  > 0 ){
                
                GRKPickerPhotosList * photosList = [[GRKPickerPhotosList alloc] initWithNibName:@"GRKPickerPhotosList" bundle:GRK_BUNDLE andGrabber:_grabber andAlbum:albumAtIndexPath];
                [self.navigationController pushViewController:photosList animated:YES];
            }
            
        }
        
    }
    else
    {
        
        GRKServiceGrabber *grabber = [self grabberForService:[services objectAtIndex:indexPath.row]];
        
        if ( grabber == nil ){
            
            
            NSString * grabberNotAvailableMessage = [NSString stringWithFormat:@"The grabber class %@ doesn't exist.", grabber];
            UIAlertView * grabberNotAvailableAlertView = [[UIAlertView alloc] initWithTitle:@"Error" message:grabberNotAvailableMessage delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] ;
            
            [grabberNotAvailableAlertView show];
            
            return;
        }
        
        
        UIViewController *albumsList;
        
        if ([grabber.serviceName isEqualToString:@"Dropbox"]) {
            
            albumsList = [[GRKPickerCloudPhotosList alloc] initWithGrabber:grabber andServiceName:grabber.serviceName];
            
        } else {
            
            albumsList = [[GRKPickerAlbumsList alloc] initWithGrabber:grabber andServiceName:grabber.serviceName];
            
        }
        
        [self.navigationController pushViewController:albumsList animated:YES];
    }
    
    
}


#pragma mark -


-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    
    if ( [keyPath isEqualToString:@"count"] ){
        
        NSInteger indexOfAlbum = [_albums indexOfObject:object];
        
        if ( indexOfAlbum != NSNotFound ){
            
            NSArray * indexPathsToReload = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:indexOfAlbum inSection:0]];
            [self.tableView reloadRowsAtIndexPaths:indexPathsToReload withRowAnimation:UITableViewRowAnimationNone];
        }
        
    }
    
}

-(void) loadCoverPhotoForAlbums:(NSArray*)albums {
    
    // First, filter to retreive only the albums without cover
    NSMutableArray * albumsWithoutCover = [NSMutableArray array];
    for( GRKAlbum * album in albums ){
        if ( album.coverPhoto == nil ){
            [albumsWithoutCover addObject:album];
        }
    }
    
    
    INCREASE_OPERATIONS_COUNT
    
    // Fill these albums with their cover photo
    [_grabber fillCoverPhotoOfAlbums:albumsWithoutCover withCompleteBlock:^(id result) {
        
        
        DECREASE_OPERATIONS_COUNT
        
        if ( state == GRKPickerAlbumsListStateGrabbing ){
            
            // Do no reload rows during a grab of data. 2 reloads on the tableView could generate a crash
            return;
        }
        
        
        // for each album filled, find its index in the _albums array, and build an NSIndexPath to reload the tableView
        
        NSMutableArray * indexPathsToReload = [NSMutableArray array];
        
        for( GRKAlbum * a in result ) {
            
            NSUInteger indexOfFilledAlbum = [_albums indexOfObject:a];
            if ( indexOfFilledAlbum != NSNotFound ){
                [indexPathsToReload addObject:[NSIndexPath indexPathForRow:indexOfFilledAlbum inSection:0]];
                
            }
            
        }
        
        [self.tableView reloadRowsAtIndexPaths:indexPathsToReload withRowAnimation:UITableViewRowAnimationNone];
        
        
    } andErrorBlock:^(NSError *error) {
        
        // Do nothing, fail silently.
        DECREASE_OPERATIONS_COUNT
        
    }];
    
    
}



-(void) loadMoreAlbums {
    
    if ( state == GRKPickerAlbumsListStateGrabbing)
        return;
    
    
//    [self loadAlbumsAtPageIndex:_lastLoadedPageIndex withNumberOfAlbumsPerPage:kNumberOfAlbumsPerPage andNumberOfAllowedRetries:kMaximumRetriesCount];
    [self loadAlbumsAtPageIndex:_lastLoadedPageIndex withNumberOfAlbumsPerPage:kGRKMaximumNumberOfAlbumsPerPage - 1 andNumberOfAllowedRetries:kMaximumRetriesCount];
    
    
}

-(void) loadAlbumsAtPageIndex:(NSUInteger)pageIndex withNumberOfAlbumsPerPage:(NSUInteger)numberOfAlbumsPerPage andNumberOfAllowedRetries:(NSUInteger)allowedRetriesCount {
    
    if ( state != GRKPickerAlbumsListStateGrabbing)
        [self setState:GRKPickerAlbumsListStateGrabbing];
    
    [_grabber albumsOfCurrentUserAtPageIndex:pageIndex
                   withNumberOfAlbumsPerPage:numberOfAlbumsPerPage
                            andCompleteBlock:^(NSArray *results) {
                                
                                _lastLoadedPageIndex+=1;
                                [_albums addObjectsFromArray:results];
                                
                                for( GRKAlbum * newAlbum in results ){
                                    
                                    [newAlbum addObserver:self forKeyPath:@"count" options:NSKeyValueObservingOptionNew context:nil];
                                    
                                }
                                
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self loadCoverPhotoForAlbums:results];
                                });
                                
                                
                                // Update the state. the tableView is reloaded in this method.
//                                if ( [results count] < kNumberOfAlbumsPerPage ){
                                if ( [results count] < kGRKMaximumNumberOfAlbumsPerPage - 1 ) {
                                    allAlbumsGrabbed = YES;
                                    [self setState:GRKPickerAlbumsListStateAllAlbumsGrabbed];
                                } else {
                                    [self setState:GRKPickerAlbumsListStateAlbumsGrabbed];
                                    
                                }
                                
                                
                            } andErrorBlock:^(NSError *error) {
                                
                                NSLog(@" error ! %@", error);
                                
                                if ( allowedRetriesCount > 0 ){
                                    
                                    [self loadAlbumsAtPageIndex:pageIndex withNumberOfAlbumsPerPage:numberOfAlbumsPerPage andNumberOfAllowedRetries:allowedRetriesCount-1];
                                    
                                    return;
                                    
                                } else {
                                    
                                    [self setState:GRKPickerAlbumsListStateGrabbingFailed];
                                    
                                }
                                
                            }];
    
}

@end
