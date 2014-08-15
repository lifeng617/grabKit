//
//  GKPickerCloudPhotosList.m
//  grabKit
//
//  Created by dragon on 8/13/14.
//
//

#import "GRKPickerCloudPhotosList.h"
#import "GRKPickerPhotoViewer.h"
#import "GRKPickerPhotosList.h"
#import "GRKPickerPhotosListThumbnail.h"
#import "GRKPickerThumbnailManager.h"
#import "GRKPickerViewController.h"
#import "GRKPickerViewController+privateMethods.h"
#import "GRKServiceGrabberConnectionProtocol.h"

#import "MBProgressHUD.h"

@interface GRKPickerCloudPhotosList ()<UICollectionViewDataSource, UICollectionViewDelegate, GRKPickerPhotoListThumbailDelegate>

@property (nonatomic, strong) NSArray *photos;
@end




@implementation GRKPickerCloudPhotosList

-(id) initWithGrabber:(id)grabber andServiceName:(NSString *)serviceName{
    
    
    self = [super initWithNibName:@"GRKPickerCloudPhotosList" bundle:GRK_BUNDLE];
    if ( self ){
        
        
        _grabber = grabber;
        _serviceName = serviceName;
        
        _doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(didTouchDoneButton)];
        _cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(didTouchCancelButton)];
        
        [self setState:GRKPickerCloudPhotosListStateInitial];
    }
    
    
    return self;
}

/*
 
 This state design-pattern must be used to update UI only.
 
 */
-(void) setState:(GRKPickerCloudPhotosListState)newState {
    
    
    state = newState;
    
    switch (newState) {
            
        case GRKPickerCloudPhotosListStateConnecting:
        {
            _needToConnectView.hidden = YES;
            [self showHUD];
            
            INCREASE_OPERATIONS_COUNT
        }
            break;
            
            
        case GRKPickerCloudPhotosListStateNeedToConnect:
        {
            
            DECREASE_OPERATIONS_COUNT
            
            _needToConnectView.alpha = 0;
            _needToConnectView.hidden = NO;
            
            NSString * needToConnectString = GRK_i18n(@"GRK_ALBUMS_LIST_NEED_TO_CONNECT", @"You need to connect to %serviceName%");
            _needToConnectLabel.text = [needToConnectString stringByReplacingOccurrencesOfString:@"%serviceName%" withString:_grabber.serviceName];
            
            [_connectButton setTitle:GRK_i18n(@"GRK_ALBUMS_LIST_CONNECT_BUTTON",@"Login") forState:UIControlStateNormal];
            
            [UIView animateWithDuration:0.33 animations:^{
                
                _needToConnectView.alpha = 1;
                [self hideHUD];
                
            }];
            
        }
            break;
            
        case GRKPickerCloudPhotosListStateConnected:
        {
            DECREASE_OPERATIONS_COUNT
            
        }
            break;
            
            
        case GRKPickerCloudPhotosListStateDidNotConnect:
        {
            DECREASE_OPERATIONS_COUNT
            
            [self.navigationController popViewControllerAnimated:YES];
            
        }
            break;
            
        case GRKPickerCloudPhotosListStateGrabbingFailed:
        case GRKPickerCloudPhotosListStateConnectionFailed:
        {
            
            DECREASE_OPERATIONS_COUNT
            
            _needToConnectView.alpha = 0;
            _needToConnectView.hidden = NO;
            
            _needToConnectLabel.text = GRK_i18n(@"GRK_ALBUMS_LIST_ERROR_RETRY", @"An error occured. Please try again.");
            [_connectButton setTitle:GRK_i18n(@"GRK_ALBUMS_LIST_RETRY_BUTTON",@"Retry") forState:UIControlStateNormal];
            
            [UIView animateWithDuration:0.33 animations:^{
                
                _needToConnectView.alpha = 1;
                [self hideHUD];
                
            }];
            
            
        }
            break;
            
            
            
            
        case GRKPickerCloudPhotosListStateGrabbing:
        {
            INCREASE_OPERATIONS_COUNT
            
            _needToConnectView.hidden = YES;
            
            if ( [MBProgressHUD HUDForView:self.view] == nil ){
                [self showHUD];
                
            }
            
        }
            
            break;
            
            
            // When some albums are grabbed, reload the tableView
        case GRKPickerCloudPhotosListStatePhotosGrabbed:
        {
            DECREASE_OPERATIONS_COUNT
            
            // If that's the first grab, then the tableView has not been added to the view yet.
            if ( _contentView.hidden  ){
                
                //First Let's make the table view invisible
                _contentView.alpha = 0;
                _contentView.hidden = NO;
                
                // And animate the have a nice transition between the HUD and the tableView
                [UIView animateWithDuration:0.33 animations:^{
                    
                    _contentView.alpha = 1;
                    [self hideHUD];
                    
                }];
                
            } else {
                // else, just hide the HUD
                [self hideHUD];
                
            }
            
            [_collectionView reloadData];
            
            
        }
            break;
            
        case GRKPickerCloudPhotosListStateDisconnecting:
        {
            INCREASE_OPERATIONS_COUNT
            
            [self showHUD];
            
        }
            break;
            
            
        case GRKPickerCloudPhotosListStateDisconnected:
        {
            DECREASE_OPERATIONS_COUNT
            
            [self hideHUD];
            
            [self.navigationController popToRootViewControllerAnimated:YES];
            
        }
            break;
            
            
        case GRKPickerCloudPhotosListStateError:
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

-(IBAction)didTouchConnectButton {
    
    
    [(id<GRKServiceGrabberConnectionProtocol>)_grabber isConnected:^(BOOL connected) {
        
        if ( ! connected ){
            
            [self connectToService];
            
        } else {
            
            dispatch_async(dispatch_get_main_queue(), ^(void){
                
                [self setState:GRKPickerCloudPhotosListStateConnected];
                // start grabbing albums
                [self loadAllPhotos];
                
            });
            
        }
        
    } errorBlock:^(NSError *error) {
        
        NSLog(@" an error occured trying to check if the grabber is connected : %@", error);
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            
            [self setState:GRKPickerCloudPhotosListStateConnectionFailed];
            
        });
        
    }];
    
}

-(void) didTouchDoneButton {
    
    [[GRKPickerViewController sharedInstance] done];
    
}

-(void) didTouchCancelButton {
    
    [[GRKPickerViewController sharedInstance] dismiss];
    
}

-(void)connectToService {
    
    
    [self setState:GRKPickerCloudPhotosListStateConnecting];
    
    [(id<GRKServiceGrabberConnectionProtocol>)_grabber connectWithConnectionIsCompleteBlock:^(BOOL connected) {
        
        if ( connected ) {
            
            [self setState:GRKPickerCloudPhotosListStateConnected];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [self loadAllPhotos];
                
            });
            
        } else {
            
            [self setState:GRKPickerCloudPhotosListStateDidNotConnect];
            
        }
        
    } andErrorBlock:^(NSError *error) {
        
        [self setState:GRKPickerCloudPhotosListStateConnectionFailed];
        NSLog(@" an error occured trying to connect the grabber : %@", error);
        
        
    }];
    
    
    
}

#pragma mark - Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    CGSize screenSz = _contentView.bounds.size;
    _tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, screenSz.width, 40)];
    _tipLabel.font = [UIFont systemFontOfSize:14];
    _tipLabel.textAlignment = NSTextAlignmentCenter;
    _tipLabel.textColor = [UIColor darkGrayColor];
    
    GRKPickerViewController *parent = [GRKPickerViewController sharedInstance];
    if ([[parent selectedPhotos] count] == 0) {
        if ([parent minimumSelectionAllowed] == 1) {
            _tipLabel.text = @"Pick 1 photo for your card.";
        } else {
            _tipLabel.text = [NSString stringWithFormat:@"Pick %d photos for your card.", [parent minimumSelectionAllowed]];
        }
    } else {
        _tipLabel.text = [NSString stringWithFormat:@"%d of %d photos selected.", [[parent selectedPhotos] count], [parent minimumSelectionAllowed]];
    }
    [_contentView addSubview:_tipLabel];
    
    
    
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    [flowLayout setItemSize:CGSizeMake(75, 75)];
    [flowLayout setMinimumInteritemSpacing:1.0f];
    [flowLayout setMinimumLineSpacing:4.0f];
    [flowLayout setSectionInset:UIEdgeInsetsMake(4, 4, 4, 4)];
    
    
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 40, screenSz.width, screenSz.height - 40)
                                         collectionViewLayout:flowLayout];
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    
    
    // set multipleSelection according to configuration of [GRKPickerViewController sharedInstance]
    _collectionView.allowsSelection = [GRKPickerViewController sharedInstance].allowsSelection;
    _collectionView.allowsMultipleSelection = [GRKPickerViewController sharedInstance].allowsMultipleSelection;
    
    
    _collectionView.backgroundColor = [UIColor whiteColor];
    _collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_collectionView registerClass:[GRKPickerPhotosListThumbnail class] forCellWithReuseIdentifier:@"pickerPhotosCell"];
    
    
    
    // If the navigation bar is translucent, it'll recover the top part of the tableView
    // Let's add some inset to the tableView to avoid this
    // Nevertheless, we don't need to do it when the picker is in a popover, because the navigationBar is not visible
    if ( ! [[GRKPickerViewController sharedInstance] isPresentedInPopover] && self.navigationController.navigationBar.translucent ){
        
        _collectionView.contentInset = UIEdgeInsetsMake(self.navigationController.navigationBar.frame.size.height, 0, 0, 0);
        
    }
    
    
    [_contentView addSubview:_collectionView];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self updateRightBarButtonItem];
    
}



- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.title = _serviceName;
    
    if ( state != GRKPickerCloudPhotosListStateInitial )
        return;
    
    
    [self updateRightBarButtonItem];
    
    
    // If the grabber needs to connect
    if ( _grabber.requiresConnection ){
        
        
        [(id<GRKServiceGrabberConnectionProtocol>)_grabber isConnected:^(BOOL connected) {
            
            if ( ! connected ){
                
                [self connectToService];
                
            } else {
                
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    
                    [self setState:GRKPickerCloudPhotosListStateConnected];
                    // start grabbing albums
                    [self loadAllPhotos];
                    
                });
                
            }
            
        } errorBlock:^(NSError *error) {
            
            NSLog(@" an error occured trying to check if the grabber is connected : %@", error);
            
            dispatch_async(dispatch_get_main_queue(), ^(void){
                
                [self setState:GRKPickerCloudPhotosListStateConnectionFailed];
                
            });
            
        }];
        
    } else {
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            
            [self setState:GRKPickerCloudPhotosListStateConnected];
            // start grabbing albums ( we don't need to add the "log out" button, as the grabber doesn't need to connect ...)
            [self loadAllPhotos];
            
        });
        
    }
    
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    
    // stop all operations of the grabber
    [_grabber cancelAll];
    
    // stop all loads of thumbnails
    [[GRKPickerThumbnailManager sharedInstance] removeAllURLsOfThumbnailsToDownload];
    [[GRKPickerThumbnailManager sharedInstance] removeAllURLsOfPhotosToDownload];
    [[GRKPickerThumbnailManager sharedInstance] cancelAllConnections];
    // stop all operations of the grabber
    [_grabber cancelAll];
    
    // stop all loads of thumbnails
    [[GRKPickerThumbnailManager sharedInstance] removeAllURLsOfThumbnailsToDownload];
    [[GRKPickerThumbnailManager sharedInstance] removeAllURLsOfPhotosToDownload];
    [[GRKPickerThumbnailManager sharedInstance] cancelAllConnections];
    
    // Reset the operations count.
    // If the view disappears while something is (i.e. after a INCREASE_OPERATIONS_COUNT),
    //  the corresponding DECREASE_OPERATIONS_COUNT is not called, and the activity indicator remains spinning...
    RESET_OPERATIONS_COUNT
    
}

-(void) updateRightBarButtonItem {
    
    // Update the right bar button from "cancel" to "done" or vice-versa, if needed, according to the count of selected photos
    
    if ( state != GRKPickerCloudPhotosListStatePhotosGrabbed && self.navigationItem.rightBarButtonItem != _cancelButton) {
        
        self.navigationItem.rightBarButtonItem = _cancelButton;
        
        return;
        
    }
    
    NSUInteger minimumSeletion = [[GRKPickerViewController sharedInstance] minimumSelectionAllowed];
    NSUInteger maximumSelection = [[GRKPickerViewController sharedInstance] maximumSelectionAllowed];
    NSUInteger currentSelection = [[[GRKPickerViewController sharedInstance] selectedPhotos] count];
    
    _tipLabel.text = [NSString stringWithFormat:@"%lu of %lu photos selected.", (unsigned long)currentSelection, (unsigned long)minimumSeletion];
    
    
    if ( currentSelection >= minimumSeletion && currentSelection <= maximumSelection &&
        (self.navigationItem.rightBarButtonItem == _cancelButton || self.navigationItem.rightBarButtonItem == nil ) ){
        
        self.navigationItem.rightBarButtonItem = _doneButton;
        
        
    } else if ( (currentSelection < minimumSeletion || currentSelection > maximumSelection) &&
               (self.navigationItem.rightBarButtonItem == _doneButton || self.navigationItem.rightBarButtonItem == nil ) ){
        
        self.navigationItem.rightBarButtonItem = _cancelButton;
        
    }
    
}

-(void) loadAllPhotos {
    
    
    if ( state == GRKPickerCloudPhotosListStateGrabbing)
        return;
    
    [self setState:GRKPickerCloudPhotosListStateGrabbing];
    
    __weak GRKPickerCloudPhotosList *wself = self;
    
    [_grabber fillAlbum:nil withPhotosAtPageIndex:0 withNumberOfPhotosPerPage:0 andCompleteBlock:^(id result) {
        
        
        __strong GRKPickerCloudPhotosList *sself = wself;
        
        if (sself) {
            
            sself.photos = result;
            
            [sself setState:GRKPickerCloudPhotosListStatePhotosGrabbed];
        }
        
        
    } andErrorBlock:^(NSError *error) {
        
        __strong GRKPickerCloudPhotosList *sself = wself;
        
        if (sself) {
            
            sself.photos = nil;
            
            [sself setState:GRKPickerCloudPhotosListStateGrabbingFailed];
            
        }
        
    }];
    
}

#pragma mark - Helpers


-(GRKPhoto*) photoForCellAtIndexPath:(NSIndexPath*)indexPath {
    
    return [self photoForCellAtIndex:indexPath.row];
}

-(GRKPhoto*) photoForCellAtIndex:(NSUInteger)index {
    
    /*
     As there is only one section in the collectionView, we can rely on the indexPath.row value without further calculations
     */
    
    if (index < [self.photos count]) {
        
        return self.photos[index];
        
    }
    
    return nil;
}

- (void)zoomPhotoListThumbnail:(GRKPickerPhotosListThumbnail *)cell
{
    
    NSUInteger index = cell.index;
    
    GRKPhoto *photo = [self photoForCellAtIndex:index];
    
    if ( photo ) {
        
        GRKPickerPhotoViewer * photoViewer = [[GRKPickerPhotoViewer alloc] initWithPhoto:photo];
        
        [self.navigationController pushViewController:photoViewer animated:YES];
    }
}

#pragma mark - UICollectionViewDataSource methods

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    
    return [self.photos count];
    
}

-(void) prepareCell:(GRKPickerPhotosListThumbnail *)cell fromCollectionView:(UICollectionView*)collectionView atIndexPath:(NSIndexPath*)indexPath withPhoto:(GRKPhoto*)photo  {
    
    NSURL * thumbnailURL = nil;
    
    GRKImage *image = [[photo images] firstObject];
    
    if (!image)
        return;
    
    thumbnailURL = image.URL;
    
    // Try to retreive the thumbnail from the cache first ...
    UIImage * cachedThumbnail = [[GRKPickerThumbnailManager sharedInstance] cachedThumbnailForURL:thumbnailURL andSize:CGSizeMake(150, 150)];
    
    if ( cachedThumbnail == nil ) {
        
        // If it hasn't been downloaded yet, let's do it
        [[GRKPickerThumbnailManager sharedInstance] downloadThumbnailAtURL:thumbnailURL
                                                          forThumbnailSize:CGSizeMake(150, 150)
                                                         withCompleteBlock:^( UIImage *image, BOOL retrievedFromCache ) {
                                                             
                                                             if ( image != nil ){
                                                                 
                                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                                     
                                                                     /* do not do that :
                                                                      [cell updateThumbnailWithImage:image animated:NO];
                                                                      
                                                                      This block is performed asynchronously.
                                                                      During the download of the image, the given cell may have been dequeued and reused, so we would be updating the wrong cell.
                                                                      Do this instead :
                                                                      */
                                                                     
                                                                     GRKPickerPhotosListThumbnail * cellToUpdate = (GRKPickerPhotosListThumbnail *)[collectionView cellForItemAtIndexPath:indexPath];
                                                                     [cellToUpdate updateThumbnailWithImage:image animated: ! retrievedFromCache ];
                                                                     
                                                                 });
                                                                 
                                                             }
                                                             
                                                             
                                                         } andErrorBlock:^(NSError *error) {
                                                             
                                                             // nothing to do, fail silently
                                                             
                                                         }];
        
        
    }else {
        
        // else, just update it
        [cell updateThumbnailWithImage:cachedThumbnail animated:NO];
    }
    
    
    
    
}


- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    
    GRKPickerPhotosListThumbnail * cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"pickerPhotosCell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor whiteColor];
    cell.index = indexPath.row;
    cell.delegate = self;
    
    GRKPhoto * photo = [self photoForCellAtIndexPath:indexPath];
    if ( photo != nil ) {
        
        [self prepareCell:cell fromCollectionView:collectionView atIndexPath:indexPath withPhoto:photo];
        
        if ( ! cell.selected && [[[GRKPickerViewController sharedInstance] selectedPhotosIds] containsObject:photo.photoId]) {
            //[collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
            [collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
            cell.selected = YES;
        }
        
        
    } else {
        
        
        
    }
    
    
    return cell;
    
    
}


#pragma mark - UICollectionViewDelegate methods


-(void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    
    
    GRKPhoto * highlightedPhoto = [self photoForCellAtIndexPath:indexPath];
    
    [[GRKPickerViewController sharedInstance] didHighlightPhoto:highlightedPhoto];
    
}

-(void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    
    GRKPhoto * unhighlightedPhoto = [self photoForCellAtIndexPath:indexPath];
    
    [[GRKPickerViewController sharedInstance] didUnhighlightPhoto:unhighlightedPhoto];
    
    
}


-(BOOL) collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
	GRKPhoto * selectedPhoto =  [self photoForCellAtIndexPath:indexPath];
    
    // Only allow selection of items for already-loaded photos.
    if ( selectedPhoto == nil || [selectedPhoto originalImage] == nil){
        return NO;
    }
    
    NSUInteger maximumSelection = [GRKPickerViewController sharedInstance].maximumSelectionAllowed;
    NSUInteger currentSelectin = [[[GRKPickerViewController sharedInstance] selectedPhotosIds] count];
    if (currentSelectin >= maximumSelection) {
        
        NSString *title = @"More photos won’t fit!";
        NSString *message;
        
        if (maximumSelection > 1) {
            message = [NSString stringWithFormat:@"The layout you chose has room for %lu photos. Please choose your favorite %lu photos.", (unsigned long)maximumSelection, (unsigned long)maximumSelection];
        } else {
            message = @"The layout you chose has room for 1 photo. Please choose your favorite photo.";
        }
        [[[UIAlertView alloc] initWithTitle:title
                                    message:message
                                   delegate:nil
                          cancelButtonTitle:nil
                          otherButtonTitles:@"OK", nil] show];
        
        return NO;
    }
    
    
    // if the photo is already loaded, then ask the Picker if it can select the photo or not
    return [[GRKPickerViewController sharedInstance] shouldSelectPhoto:selectedPhoto];
}



-(BOOL) collectionView:(UICollectionView *)collectionView shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    
	GRKPhoto * deselectedPhoto =  [self photoForCellAtIndexPath:indexPath];
    
    // Ask the Picker if it can deselect the photo or not
    return [[GRKPickerViewController sharedInstance] shouldDeselectPhoto:deselectedPhoto];
    
}


-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    GRKPhoto * selectedPhoto = [self photoForCellAtIndexPath:indexPath];
    
    /*
     In single-selection mode, when the user selects an already-selected item, the item must be deselected.
     */
    // In single-selection mode
    if ( collectionView.allowsSelection && ! collectionView.allowsMultipleSelection ){
        
        // If the selected item has already been selected
        if ( [[[GRKPickerViewController sharedInstance] selectedPhotosIds] containsObject:selectedPhoto.photoId] ){
            
            // it must be deselected
            [collectionView deselectItemAtIndexPath:indexPath animated:NO];
            [[GRKPickerViewController sharedInstance] didDeselectPhoto:selectedPhoto];
            [self updateRightBarButtonItem];
            return;
            
        }
        
    }
    
    [[GRKPickerViewController sharedInstance] didSelectPhoto:selectedPhoto];
    
    [self updateRightBarButtonItem];
    
}

-(void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    
    GRKPhoto * selectedPhoto = [self photoForCellAtIndexPath:indexPath];
    
    //    if ( [[GRKPickerViewController sharedInstance] shouldDeselectPhoto:selectedPhoto] ){
    
    [[GRKPickerViewController sharedInstance] didDeselectPhoto:selectedPhoto];
    [self updateRightBarButtonItem];
    
    //    }
    
    
}


@end
