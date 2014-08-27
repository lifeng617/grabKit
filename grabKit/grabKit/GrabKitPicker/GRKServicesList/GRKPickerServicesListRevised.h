//
//  GRKPickerServicesListRevised.h
//  grabKit
//
//  Created by dragon on 8/14/14.
//
//

#import <UIKit/UIKit.h>
#import "GRKDeviceGrabber.h"
#import "GRKConstants.h"
#import "GRKPickerLoadMoreCell.h"
#import "GRKPickerServicesList.h"

@interface GRKPickerServicesListRevised : GRKPickerServicesList<GRKPickerLoadMoreCellDelegate>
{
    
    GRKDeviceGrabber * _grabber;
    
    NSMutableArray * _albums;        // array which will store the grabbed GRKAlbum objects
    NSUInteger _lastLoadedPageIndex; // index of the last loaded page. initialized at 0
    
    BOOL allAlbumsGrabbed;            // Set at YES if all albums have been loaded
    
    GRKPickerAlbumsListState state; // state of the controller
}

- (void) loadAssetAlbums;
- (void) unloadAssetAlbums;
@end
