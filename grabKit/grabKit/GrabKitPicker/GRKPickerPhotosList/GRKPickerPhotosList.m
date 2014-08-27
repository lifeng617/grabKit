/*
 * This file is part of the GrabKit package.
 * Copyright (c) 2013 Pierre-Olivier Simonard <pierre.olivier.simonard@gmail.com>
 *  
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and 
 * associated documentation files (the "Software"), to deal in the Software without restriction, including 
 * without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
 * copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the 
 * following conditions:
 *  
 * The above copyright notice and this permission notice shall be included in all copies or substantial 
 * portions of the Software.
 *  
 * The Software is provided "as is", without warranty of any kind, express or implied, including but not 
 * limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no
 * event shall the authors or copyright holders be liable for any claim, damages or other liability, whether
 * in an action of contract, tort or otherwise, arising from, out of or in connection with the Software or the 
 * use or other dealings in the Software.
 *
 * Except as contained in this notice, the name(s) of (the) Author shall not be used in advertising or otherwise
 * to promote the sale, use or other dealings in this Software without prior written authorization from (the )Author.
 */

#import "GRKPickerPhotosList.h"
#import "GRKPickerPhotoViewer.h"
#import "GRKPickerPhotosListThumbnail.h"
#import "GRKPickerThumbnailManager.h"
#import "GRKPickerViewController.h"
#import "GRKPickerViewController+privateMethods.h"
#import "MBProgressHUD.h"


// How many photos the grabber can load at a time
// We don't need kNumberofPhotosPerPage anymore.
// this value is variant for each service grabbers.
// NSUInteger kNumberOfPhotosPerPage = 32;
NSUInteger kMaximumNumberOfPhotosToLoadAtSameTime = 5;

NSUInteger kCellWidth = 75;
NSUInteger kCellHeight = 75;

@interface GRKPickerPhotosList()<GRKPickerPhotoListThumbailDelegate>

{
    
    BOOL _viewLoaded;
    
}
    -(void) setState:(GRKPickerPhotosListState)newState;
    -(void) loadPage:(NSUInteger)pageIndex;
    -(void) markPageIndexAsLoading:(NSUInteger)pageIndex;
    -(void) markPageIndexAsLoaded:(NSUInteger)pageIndex;
    -(GRKPhoto*) photoForCellAtIndexPath:(NSIndexPath*)indexPath;
@end

@implementation GRKPickerPhotosList

@synthesize album = _album;

-(void)dealloc{
    
    [_album removeObserver:self forKeyPath:@"count"];
}


-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil andGrabber:(GRKServiceGrabber*)grabber  andAlbum:(GRKAlbum*)album{
    
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if ( self != nil ){
        
        _grabber = grabber;
        _album = album;

        _indexesOfLoadingPages = [NSMutableArray array];
        _indexesOfLoadedPages = [NSMutableArray array];
        _indexesOfPagesToLoad = [NSMutableArray array];
        
        _doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(didTouchDoneButton)];
        _cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(didTouchCancelButton)];
        

        // Sometimes, the grabbers return an erroneous number of photos for a given album.
        // This bug can be related to cache, to privacy settings, etc ...
        // But the datasource of the collectionView relies on the property _album.count to return the number of items.
        // SO this is why we need to observe the count property : if it's updated, then we need to reload the collectionView.
        [_album addObserver:self forKeyPath:@"count" options:NSKeyValueObservingOptionNew context:nil];
        _needToReloadDataBecauseAlbumCountChanged = NO;
        
        [self setState:GRKPickerPhotosListStateInitial];
        
    }
    
    return self;
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
    
    CGSize screenSz = self.view.bounds.size;
    _tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, screenSz.width, 40)];
    _tipLabel.font = [UIFont systemFontOfSize:14];
    _tipLabel.textAlignment = NSTextAlignmentCenter;
    _tipLabel.textColor = [UIColor darkGrayColor];
    
    GRKPickerViewController *parent = [GRKPickerViewController sharedInstance];
    if ([[parent selectedPhotos] count] == 0) {
        if ([parent minimumSelectionAllowed] == 1) {
            _tipLabel.text = @"Pick 1 photo for your card.";
        } else {
            _tipLabel.text = [NSString stringWithFormat:@"Pick %d photos for your card.", (int)[parent minimumSelectionAllowed]];
        }
    } else {
        _tipLabel.text = [NSString stringWithFormat:@"%d of %d photos selected.", (int)[[parent selectedPhotos] count], (int)[parent minimumSelectionAllowed]];
    }
    [self.view addSubview:_tipLabel];
    
    

    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    [flowLayout setItemSize:CGSizeMake(kCellWidth, kCellHeight)];
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
    

    [self.view addSubview:_collectionView];
    
    _viewLoaded = NO;
    
    
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

    self.navigationItem.title = _album.name;
    
    [self updateRightBarButtonItem];
    
    
    if ( !_viewLoaded  && _album.count > 0) {
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:_album.count - 1 inSection:0];
        
        [_collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionBottom animated:NO];
        
//        [_collectionView setContentOffset:CGPointMake(0, CGFLOAT_MAX)];
        
        _viewLoaded = YES;
        
    }

}

-(void) loadPage:(NSUInteger)pageIndex; {

    if ( [_indexesOfLoadingPages containsObject:[NSNumber numberWithUnsignedInteger:pageIndex]] )
        return;
    
    
    if ( [_indexesOfLoadedPages containsObject:[NSNumber numberWithUnsignedInteger:pageIndex]] )
        return;

    
    // if the grabber can't load the pages discontinuously, let's check if the previous page has been loaded, or not.
    if ( ! _grabber.canLoadPhotosPagesDiscontinuously && pageIndex > 0){
        
        
        // If the previous page has not been loaded,
        if ( ! [_indexesOfLoadedPages containsObject:[NSNumber numberWithUnsignedInteger:pageIndex-1]] ) {
            
            
                // mark pageIndex to load
                [self markPageIndexToLoad:pageIndex];
            
                // load previous page
                [self loadPage:pageIndex-1];
            
            return;
            
        }
    }
    
    if ([_indexesOfLoadingPages count] > kMaximumNumberOfPhotosToLoadAtSameTime) {
        [self markPageIndexToLoad:pageIndex];
        return;
    }
    
    
    
    [self markPageIndexAsLoading:pageIndex];
    
    NSUInteger numberOfPhotosPerPage = [_grabber numberOfPhotosPerPage];
        
    [_grabber fillAlbum:_album
  withPhotosAtPageIndex:pageIndex
withNumberOfPhotosPerPage:numberOfPhotosPerPage
       andCompleteBlock:^(NSArray *results) {
           

           [self markPageIndexAsLoaded:pageIndex];
           
           // If the grabber returned less photos than expected, we can consider that all photos have been grabbed.
//           if ( [results count] < kNumberOfPhotosPerPage ){
//               [self setState:GRKPickerPhotosListStateAllPhotosGrabbed];
//               
//           } else {
               [self setState:GRKPickerPhotosListStatePhotosGrabbed];
               
//           }
           
           
           // if we must reload the whole collectionView because the property album.count changed
           if ( _needToReloadDataBecauseAlbumCountChanged ){

               _needToReloadDataBecauseAlbumCountChanged = NO;

               
               // First, keep the indexPaths of the selected items
               NSArray * selectedItems = [_collectionView indexPathsForSelectedItems];
               
               // Then, reload the collectionView
               [_collectionView reloadData];
               
//               // sometimes, we have to reload the items manually.
//               NSMutableArray * indexPathsToReload = [NSMutableArray array];
//               
//               for ( int i = (pageIndex * kNumberOfPhotosPerPage);
//                    i <= (pageIndex+1) * kNumberOfPhotosPerPage -1 && i <= _album.count - 1;
//                    i++ ){
//                   
//                   [indexPathsToReload addObject:[NSIndexPath indexPathForItem:i inSection:0]];
//                   
//               }
//               
//               [_collectionView reloadItemsAtIndexPaths:indexPathsToReload];

               // Then, set the selected items again
               for ( NSIndexPath * indexPathOfSelectedItem in selectedItems ){
                   [_collectionView selectItemAtIndexPath:indexPathOfSelectedItem animated:NO scrollPosition:UICollectionViewScrollPositionNone];
               }

               
           } else {
           
               // Else, only reload items for the given indexPaths (not the whole collectionView)
               
               NSMutableArray * indexPathsToReload = [NSMutableArray array];
               
               NSUInteger start = pageIndex * numberOfPhotosPerPage;
               NSUInteger end = (pageIndex+1) * numberOfPhotosPerPage;
               
           
//               for ( int i = start; i < end && i < _album.count; i++ ){
//           
//                   [indexPathsToReload addObject:[NSIndexPath indexPathForItem:i inSection:0]];
//           
//               }
               
               NSArray *visibleIndexPaths = [_collectionView indexPathsForVisibleItems];
               
               for (NSIndexPath *indexPath in visibleIndexPaths) {
                   if (indexPath.item >= start && indexPath.item < end)
                       [indexPathsToReload addObject:indexPath];
               }
               
               [_collectionView reloadItemsAtIndexPaths:indexPathsToReload];
           
           }
           
           // if there are other pages to load, load the first one
            if( [_indexesOfPagesToLoad count] > 0 ){
                
                [self loadPage:[[_indexesOfPagesToLoad objectAtIndex:0] intValue]];
                
            }
         
           
       } andErrorBlock:^(NSError *error) {
           NSLog(@" error for page %d : %@", (int)pageIndex,  error);
           
           [_indexesOfLoadingPages removeObject:[NSNumber numberWithInt:(int)pageIndex]];
           [self setState:GRKPickerPhotosListStateGrabbingFailed];
           
       }];
    
}

-(void) updateRightBarButtonItem {
    
    // Update the right bar button from "cancel" to "done" or vice-versa, if needed, according to the count of selected photos
    
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

-(void) didTouchDoneButton {
    
    // stop all operations of the grabber
    [_grabber cancelAll];
    
    // stop all loads of thumbnails
    [[GRKPickerThumbnailManager sharedInstance] removeAllURLsOfThumbnailsToDownload];
    [[GRKPickerThumbnailManager sharedInstance] cancelAllConnections];
    
    // Reset the operations count.
    // If the view disappears while something is loading (i.e. after an INCREASE_OPERATIONS_COUNT),
    //  the corresponding DECREASE_OPERATIONS_COUNT is not called, and the activity indicator remains spinning...
    RESET_OPERATIONS_COUNT

    [[GRKPickerViewController sharedInstance] done];
    
}

-(void) didTouchCancelButton {
    
    // stop all operations of the grabber
    [_grabber cancelAll];
    
    // stop all loads of thumbnails
    [[GRKPickerThumbnailManager sharedInstance] removeAllURLsOfThumbnailsToDownload];
    [[GRKPickerThumbnailManager sharedInstance] cancelAllConnections];
    
    // Reset the operations count.
    // If the view disappears while something is loading (i.e. after an INCREASE_OPERATIONS_COUNT),
    //  the corresponding DECREASE_OPERATIONS_COUNT is not called, and the activity indicator remains spinning...
    RESET_OPERATIONS_COUNT
    
    [[GRKPickerViewController sharedInstance] dismiss];
    
}


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
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


-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if ( [keyPath isEqualToString:@"count"] && object == _album ){
        
        _needToReloadDataBecauseAlbumCountChanged = YES;
        
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

-(void) setState:(GRKPickerPhotosListState)newState {
 
 state = newState;
 
 switch (newState) {

     case GRKPickerPhotosListStateInitial:{
         
         
         
     }
     break;
         
     case GRKPickerPhotosListStateGrabbing:{
         
         INCREASE_OPERATIONS_COUNT
         
     }
     break;
         
     // When some photos are grabbed, reload the collectionView
     case GRKPickerPhotosListStateAllPhotosGrabbed:
     case GRKPickerPhotosListStatePhotosGrabbed:{

         DECREASE_OPERATIONS_COUNT
         
     }
     break;            
 
        
     case GRKPickerPhotosListStateGrabbingFailed:
         
         DECREASE_OPERATIONS_COUNT
         
         break;
         
     
     default:
         break;
 }
 
 
}

-(void) markPageIndexAsLoading:(NSUInteger)pageIndex;{
    
    [self setState:GRKPickerPhotosListStateGrabbing];
    
    if ( [_indexesOfLoadingPages indexOfObject:[NSNumber numberWithInt:(int)pageIndex]] == NSNotFound ){
        
        [_indexesOfLoadingPages addObject:[NSNumber numberWithInt:(int)pageIndex]];
        //NSLog(@" page %d marked as LOADING", pageIndex);
    }
    
    [_indexesOfPagesToLoad removeObject:[NSNumber numberWithInt:(int)pageIndex]];
    
    if (pageIndex == 0 && [_grabber.serviceName isEqualToString:@"device"])
        [self showHUD];
    
}

-(void) markPageIndexAsLoaded:(NSUInteger)pageIndex;{
    
    //NSLog(@" page %d marked as LOADED", pageIndex);
    
    [_indexesOfLoadedPages addObject:[NSNumber numberWithInt:(int)pageIndex]];
    [_indexesOfLoadingPages removeObject:[NSNumber numberWithInt:(int)pageIndex]];
    [_indexesOfPagesToLoad removeObject:[NSNumber numberWithInt:(int)pageIndex]];
    
    if (pageIndex == 0 && [_grabber.serviceName isEqualToString:@"device"])
        [self hideHUD];
}


-(void) markPageIndexToLoad:(NSUInteger)pageIndex;{
    
    @synchronized(_indexesOfPagesToLoad) {
        
        NSUInteger index = [_indexesOfPagesToLoad indexOfObject:[NSNumber numberWithInt:(int)pageIndex]];
        if ( index == NSNotFound ){
            [_indexesOfPagesToLoad addObject:[NSNumber numberWithInt:(int)pageIndex]];
            
            //NSLog(@" page %d marked as TO LOAD", pageIndex);
        }
        else if ( index > 0 ) {
            
            [_indexesOfPagesToLoad removeObjectAtIndex:index];
            [_indexesOfPagesToLoad insertObject:[NSNumber numberWithInt:(int)pageIndex] atIndex:0];
        }
        
    }
}




#pragma mark - Helpers


-(GRKPhoto*) photoForCellAtIndexPath:(NSIndexPath*)indexPath {
    
    return [self photoForCellAtIndex:indexPath.row];
    
}

-(GRKPhoto*) photoForCellAtIndex:(NSUInteger)index {
    
    /*
     As there is only one section in the collectionView, we can rely on the indexPath.row value without further calculations
     */
    NSArray * photos = [_album photosAtPageIndex:index withNumberOfPhotosPerPage:1];
    if ( [photos count] > 0 ){
        
        id expectedPhoto = [photos objectAtIndex:0];
        if ( expectedPhoto == [NSNull null] ){
            return nil;
        }
        
        return expectedPhoto;
        
    } else return nil;
    
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
 
    return _album.count;
    
}

-(void) prepareCell:(GRKPickerPhotosListThumbnail *)cell fromCollectionView:(UICollectionView*)collectionView atIndexPath:(NSIndexPath*)indexPath withPhoto:(GRKPhoto*)photo  {
    
    if (photo.thumbnail) {
        [cell updateThumbnailWithImage:photo.thumbnail animated:NO];
        return;
    }
    
    NSURL * thumbnailURL = nil;
    
    for( GRKImage * image in [photo imagesSortedByHeight] ){
        
        // If the imageView for thumbnails is 75px wide, we need images with both dimensions greater or equal to 2*75px, for a perfect result on retina displays
        if ( image.width >= kCellWidth*2 && image.height >= kCellHeight*2 ) {
            
            thumbnailURL = image.URL;
            
            // Once we have found the first image bigger than the thumbnail, break the loop
            break;
        }
    }
    
    
    if (thumbnailURL == nil) {
        
        [cell updateThumbnailWithImage:nil animated:NO];
        
    }
    
    // Try to retreive the thumbnail from the cache first ...
    UIImage * cachedThumbnail = [[GRKPickerThumbnailManager sharedInstance] cachedThumbnailForURL:thumbnailURL andSize:CGSizeMake(150, 150)];
    
    if ( cachedThumbnail == nil ) {
        
        // If it hasn't been downloaded yet, let's do it
        [[GRKPickerThumbnailManager sharedInstance] downloadThumbnailAtURL:thumbnailURL forThumbnailSize:CGSizeMake(150, 150) withCompleteBlock:^( UIImage *image, BOOL retrievedFromCache ) {
            
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
        
        
    } else {
        
        // else, just update it
        [cell updateThumbnailWithImage:cachedThumbnail animated:NO];
    }
}


- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    
    
    
//    NSLog(@"loading : %d", indexPath.item);
    
    
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
        
//        NSLog(@"load : %d", indexPath.item);
        
        
    } else {
        
        int pageOfThisCell = ceil( indexPath.row / [_grabber numberOfPhotosPerPage] );
        
//        NSLog(@"nil : %d", indexPath.item);
        
        [self loadPage:pageOfThisCell];

        
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
    if ( selectedPhoto == nil  || [selectedPhoto originalImage] == nil){
        return NO;
    }
    
    NSUInteger maximumSelection = [GRKPickerViewController sharedInstance].maximumSelectionAllowed;
    NSUInteger currentSelectin = [[[GRKPickerViewController sharedInstance] selectedPhotosIds] count];
    if (currentSelectin >= maximumSelection) {
        
        NSString *title = @"More photos won’t fit!";
        NSString *message;
        
        if (maximumSelection > 1) {
            message = [NSString stringWithFormat:@"The layout you chose has room for %d photos. Please choose your favorite %d photos.", (int)maximumSelection, (int)maximumSelection];
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
