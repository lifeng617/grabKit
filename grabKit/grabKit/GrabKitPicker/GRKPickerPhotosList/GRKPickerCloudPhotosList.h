//
//  GKPickerCloudPhotosList.h
//  grabKit
//
//  Created by dragon on 8/13/14.
//
//

#import <UIKit/UIKit.h>
#import "GRKServiceGrabber.h"


typedef NS_ENUM(NSUInteger, GRKPickerCloudPhotosListState) {
    GRKPickerCloudPhotosListStateInitial = 0,
    
    GRKPickerCloudPhotosListStateNeedToConnect,
    GRKPickerCloudPhotosListStateConnecting,
    GRKPickerCloudPhotosListStateConnected,
    GRKPickerCloudPhotosListStateDidNotConnect,
    GRKPickerCloudPhotosListStateConnectionFailed,
    
    GRKPickerCloudPhotosListStateGrabbing,
    GRKPickerCloudPhotosListStatePhotosGrabbed,
    GRKPickerCloudPhotosListStateGrabbingFailed,
    
    GRKPickerCloudPhotosListStateDisconnecting,
    GRKPickerCloudPhotosListStateDisconnected,
    
    GRKPickerCloudPhotosListStateError = 99
};

@interface GRKPickerCloudPhotosList : UIViewController
{
    
    IBOutlet UIView * _contentView;
    UICollectionView * _collectionView;
    UILabel *_tipLabel;
    
    UIBarButtonItem * _cancelButton;
    UIBarButtonItem * _doneButton;
    
    IBOutlet UIView * _needToConnectView;
    IBOutlet UILabel * _needToConnectLabel;
    IBOutlet UIButton * _connectButton;
    
    
    
    GRKServiceGrabber * _grabber; // grabber used to show the list of albums
    
    NSString * _serviceName; // Name of the service, for UI only.
    
    GRKPickerCloudPhotosListState state; // state of the controller
}


-(id) initWithGrabber:(id)grabber andServiceName:(NSString *)serviceName;
@end
