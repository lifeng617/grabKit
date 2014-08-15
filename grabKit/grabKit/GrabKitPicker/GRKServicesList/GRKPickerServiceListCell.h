//
//  GRKPickerServiceListCell.h
//  grabKit
//
//  Created by dragon on 8/14/14.
//
//

#import <UIKit/UIKit.h>

@class GRKPickerServiceListCell;
@class GRKServiceGrabber;
@protocol GRKPickerServiceListCellDelegate <NSObject>

- (void)logoutForServiceListCell:(GRKPickerServiceListCell *)cell;

@end

@interface GRKPickerServiceListCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UIImageView * imgView;
@property (nonatomic, strong) IBOutlet UILabel * titleLabel;
@property (nonatomic, strong) IBOutlet UIButton * logoutButton;

@property (nonatomic, weak) id<GRKPickerServiceListCellDelegate> delegate;
@property (nonatomic) NSUInteger index;

- (void)loadUserProfileWithGrabber:(GRKServiceGrabber *)grabber;
@end
