//
//  GRKPickerPhotosListRowCell.m
//  grabKit
//
//  Created by Dragon on 9/30/14.
//
//

#import "GRKPickerPhotosListRowCell.h"
#import "GRKPickerViewController.h"

@implementation GRKPickerPhotosListRowCell

-(id)initWithCoder:(NSCoder *)aDecoder {
    
    self = [super initWithCoder:aDecoder];
    if (self) {
        
        [self buildViews];
        
    }
    
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        [self buildViews];
        
    }
    
    return self;
}

-(void) buildViews {
    
    UIView *view = [[UIView alloc] initWithFrame:self.bounds];
    view.backgroundColor = [UIColor whiteColor];
    self.backgroundView = view;
    
    view = [[UIView alloc] initWithFrame:self.bounds];
    view.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1];
    self.selectedBackgroundView = view;
    
    
    
    
    UILabel *label = [[UILabel alloc] initWithFrame:(CGRect) {44, 0, self.bounds.size.width - 44, self.bounds.size.height}];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    label.font = [UIFont systemFontOfSize:16];
    [self.contentView addSubview:label];
    
    titleLabel = label;
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:(CGRect) {6, 6, 32, self.bounds.size.height - 12}];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self.contentView addSubview:imageView];
    
    view = [[UIView alloc] initWithFrame:(CGRect){44,self.bounds.size.height - 0.5, self.bounds.size.width - 44, 0.5}];
    view.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.contentView addSubview:view];
    
    imgView = imageView;
    
}

- (void) setTitle:(NSString *)title
{
    titleLabel.text = title;
}

- (void) setImage:(UIImage *)image
{
    imgView.image = image;
}

@end
