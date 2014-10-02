//
//  GRKPickerPhotosListRowCell.h
//  grabKit
//
//  Created by Dragon on 9/30/14.
//
//

#import <UIKit/UIKit.h>

@interface GRKPickerPhotosListRowCell : UICollectionViewCell
{
    UIImageView * imgView;
    UILabel * titleLabel;
}

- (void) setTitle:(NSString *)title;
- (void) setImage:(UIImage *)image;

@end
