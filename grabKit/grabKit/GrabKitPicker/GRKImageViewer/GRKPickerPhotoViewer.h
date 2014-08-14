//
//  GRKPickerPhotoViewer.h
//  grabKit
//
//  Created by dragon on 8/14/14.
//
//

#import <UIKit/UIKit.h>



@class GRKPhoto;


@interface GRKPickerPhotoViewer : UIViewController


@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;

@property (strong, nonatomic) IBOutlet UIView *container;

@property (strong, nonatomic) IBOutlet UIImageView *imageView;



- (id)initWithPhoto:(GRKPhoto *)photo;

@end
