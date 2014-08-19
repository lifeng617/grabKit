//
//  GRKPickerServiceListCell.m
//  grabKit
//
//  Created by dragon on 8/14/14.
//
//

#import "GRKPickerServiceListCell.h"
#import "GRKServiceGrabber.h"

#import "GRKServiceGrabberConnectionProtocol.h"
#import "GRKServiceGrabber+usernameAndProfilePicture.h"

@implementation GRKPickerServiceListCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)awakeFromNib
{
    // Initialization code
    [super awakeFromNib];
    
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)loadUserProfileWithGrabber:(GRKServiceGrabber *)grabber
{
    
    NSUInteger index = self.index;
    
    __weak GRKPickerServiceListCell *wself = self;
    
    [(id<GRKServiceGrabberConnectionProtocol>)grabber isConnected:^(BOOL connected) {
        
        if ( connected ){
            
            [grabber loadUsernameAndProfilePictureOfCurrentUserWithCompleteBlock:^(id result) {
                
                __strong GRKPickerServiceListCell *sself = wself;
                
                NSString *userId = [result objectForKey:kGRKUsernameKey];
                
                if (grabber) {
                    
                    [GRKServiceGrabber setConnectionState:GRKServiceStateConnected
                                                andUserId:userId
                                               forService:grabber.serviceName];
                    
                }
                
                if (sself && sself.index == index) {
                    
                    sself.titleLabel.text = userId;
                    
                    sself.logoutButton.hidden = NO;
                    
                }
                
            } andErrorBlock:^(NSError *error) {
                
                __strong GRKPickerServiceListCell *sself = wself;
                
                if (sself && sself.index == index) {
                    sself.logoutButton.hidden = NO;
                }
                
            }];
            
        } else {
            
            __strong GRKPickerServiceListCell *sself = wself;
            
            if (grabber) {
                
                [GRKServiceGrabber setConnectionState:GRKServiceStateDisconnected
                                            andUserId:nil
                                           forService:grabber.serviceName];
                
            }
            
            
            if (sself && sself.index == index) {
                sself.logoutButton.hidden = YES;
            }
        }
        
    } errorBlock:^(NSError *error) {
        
        __strong GRKPickerServiceListCell *sself = wself;
        
        if (sself && sself.index == index) {
            sself.logoutButton.hidden = YES;
        }
        
    }];
    
}

- (IBAction)onLogout:(id)sender
{
    [self.delegate logoutForServiceListCell:self];
}

@end
