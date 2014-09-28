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

#import "GRKPickerViewController+privateMethods.h"
#import "GRKPickerThumbnailManager.h"
#import "MBProgressHUD.h"

#import "GRKPickerServicesListRevised.h"

@implementation GRKPickerViewController (privateMethods)


-(BOOL)isPresentedInPopover; {
    
    return ( _pickerPresentingPopover != nil );
}




-(NSArray *) selectedPhotos{
    
    return [_selectedPhotos allValues];
}

-(NSArray *) selectedPhotosIds {
    return [_selectedPhotos allKeys];
}


-(void)didHighlightPhoto:(GRKPhoto*)highlightedPhoto {
    
    
    if ( self.pickerDelegate != nil && [self.pickerDelegate respondsToSelector:@selector(picker:didHighlightPhoto:)]){
        
        [(id<GRKPickerViewControllerDelegate>)self.pickerDelegate picker:self didHighlightPhoto:highlightedPhoto];
        
    }

}



-(void)didUnhighlightPhoto:(GRKPhoto*)unhighlightedPhoto;
{
    
    if ( self.pickerDelegate != nil && [self.pickerDelegate respondsToSelector:@selector(picker:didUnhighlightPhoto:)]){
        
        [(id<GRKPickerViewControllerDelegate>)self.pickerDelegate picker:self didUnhighlightPhoto:unhighlightedPhoto];
        
    }

    
}


-(BOOL) shouldSelectPhoto:(GRKPhoto*)selectedPhoto {
    
    BOOL shouldSelectPhoto = YES;
    
    // Should the photo be selected ?
    if ( self.pickerDelegate != nil && [self.pickerDelegate respondsToSelector:@selector(picker:shouldSelectPhoto:)]){
        
        shouldSelectPhoto = [(id<GRKPickerViewControllerDelegate>)self.pickerDelegate picker:self shouldSelectPhoto:selectedPhoto];
        
    }
    
	return shouldSelectPhoto;
    
}

-(void) didSelectPhoto:(GRKPhoto*)selectedPhoto {
    
    if ( selectedPhoto != nil && selectedPhoto.photoId != nil && ! [selectedPhoto.photoId isEqualToString:@""] ){
        [_selectedPhotos setObject:selectedPhoto forKey:selectedPhoto.photoId];
    }
    
    
    if ( self.pickerDelegate != nil && [self.pickerDelegate respondsToSelector:@selector(picker:didSelectPhoto:)]){
        
        [(id<GRKPickerViewControllerDelegate>)self.pickerDelegate picker:self didSelectPhoto:selectedPhoto];
        
    }
    
}




-(BOOL) shouldDeselectPhoto:(GRKPhoto*)deselectedPhoto {
    
    BOOL shouldDeselectPhoto = YES;
    
    if ( self.pickerDelegate != nil && [self.pickerDelegate respondsToSelector:@selector(picker:shouldSelectPhoto:)]){
        shouldDeselectPhoto = [(id<GRKPickerViewControllerDelegate>)self.pickerDelegate picker:self shouldDeselectPhoto:deselectedPhoto];
    }
    
 	return shouldDeselectPhoto;
    
}

-(void) didDeselectPhoto:(GRKPhoto*)deselectedPhoto {
    
    
    [_selectedPhotos removeObjectForKey:deselectedPhoto.photoId];
    
    
    if ( self.pickerDelegate != nil && [self.pickerDelegate respondsToSelector:@selector(picker:didDeselectPhoto:)]){
        
        [(id<GRKPickerViewControllerDelegate>)self.pickerDelegate picker:self didDeselectPhoto:deselectedPhoto];
        
    }
    
    
}




-(void) updateNetworkActivityIndicator {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication sharedApplication].networkActivityIndicatorVisible = runningOperations > 0;
    });
    
    
}


-(void)increaseOperationsCount {
    
    runningOperations++;
    [self updateNetworkActivityIndicator];
}

-(void)decreaseOperationsCount {
    
    if ( runningOperations >0 )
        runningOperations--;
    
    [self updateNetworkActivityIndicator];
}


-(void)resetOperationsCount {
    runningOperations = 0;
    [self updateNetworkActivityIndicator];
}

-(void)showHUD {
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeIndeterminate;
    
    hud.labelText = GRK_i18n(@"GRK_ALBUMS_LIST_HUD_LOADING", @"Loading ...");
    
}

-(void)hideHUD {
    [MBProgressHUD  hideHUDForView:self.view animated:YES];
    
}

-(void) done {
    
    [[GRKPickerThumbnailManager sharedInstance] removeAllURLsOfThumbnailsToDownload];
    [[GRKPickerThumbnailManager sharedInstance] removeAllURLsOfPhotosToDownload];
    [[GRKPickerThumbnailManager sharedInstance] cancelAllConnections];
    
    [self.navigationController popToRootViewControllerAnimated:NO];
    
    [self showHUD];
    
    __weak GRKPickerViewController *wself = self;
    
    [self extractMediasFromSelectionWithCompletionHandler:^( void ) {
        
        __strong GRKPickerViewController *sself = wself;
        
        if ( !sself )
            return;
        
        [sself hideHUD];
        
        if ( [sself isPresentedInPopover] ){
            
            [_pickerPresentingPopover dismissPopoverAnimated:YES];
            
            if ( sself.pickerDelegate != nil && [sself.pickerDelegate respondsToSelector:@selector(picker:didDismissWithSelectedPhotos:)]){
                
                [(id<GRKPickerViewControllerDelegate>)sself.pickerDelegate picker:sself didDismissWithSelectedPhotos:self.selectedPhotos];
                
            }
            
            
            if ( ! sself.keepsSelection ){
                
                [_selectedPhotos removeAllObjects];
                
            }
            
            
        } else {
            
            [sself dismissViewControllerAnimated:YES completion:^{
                
                [sself popToRootViewControllerAnimated:NO];
                
                if ( sself.pickerDelegate != nil && [sself.pickerDelegate respondsToSelector:@selector(picker:didDismissWithSelectedPhotos:)]){
                    
                    [(id<GRKPickerViewControllerDelegate>)sself.pickerDelegate picker:self didDismissWithSelectedPhotos:self.selectedPhotos];
                    
                }
                
                if ( ! sself.keepsSelection ){
                    
                    [_selectedPhotos removeAllObjects];
                    
                }
                
            }];
            
        }
        
    }];
}

-(void) dismiss {
    
    [self.navigationController popToRootViewControllerAnimated:NO];
    
    if ( [self isPresentedInPopover] ){
        
        [_pickerPresentingPopover dismissPopoverAnimated:YES];
        
        if ( self.pickerDelegate != nil && [self.pickerDelegate respondsToSelector:@selector(pickerDidCancel:)]){
            
            [(id<GRKPickerViewControllerDelegate>)self.pickerDelegate pickerDidCancel:self];
            
        }
        
        
        if ( ! self.keepsSelection ){
            
            [_selectedPhotos removeAllObjects];
            
        }
        
        
    } else {
        
        [self dismissViewControllerAnimated:YES completion:^{
            
            [self popToRootViewControllerAnimated:NO];
            
            if ( self.pickerDelegate != nil && [self.pickerDelegate respondsToSelector:@selector(pickerDidCancel:)]){
                
                [(id<GRKPickerViewControllerDelegate>)self.pickerDelegate pickerDidCancel:self];
                
            }
            
            if ( ! self.keepsSelection ){
                
                [_selectedPhotos removeAllObjects];
                
            }
            
        }];
        
    }
    
    
}


-(void) extractMediasFromSelectionWithCompletionHandler:(void (^) ())handler
{
    [self downloadMediaAtIndex:0 withCompletionHandler:handler];
}

-(void) downloadMediaAtIndex:(NSUInteger) index withCompletionHandler:(void (^) ())handler
{
    
    while ( index < [self.selectedPhotos count] ) {
        
        GRKPhoto *photo = self.selectedPhotos[index];
        GRKImage *image = [photo originalImage];
        
        if (image == nil) {
            index ++;
            continue;
        }
        
        [[GRKPickerThumbnailManager sharedInstance] downloadPhotoWithGRKImage:image withCompleteBlock:^(UIImage *thumbnail, BOOL retrievedFromCache) {
            
            
            image.image = thumbnail;
            
            [self downloadMediaAtIndex:index + 1 withCompletionHandler:handler];
            
            
        } andErrorBlock:^(NSError *error) {
            
            [self downloadMediaAtIndex:index + 1 withCompletionHandler:handler];
            
        }];
        
        return;
        
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        handler();
    });
}

@end
