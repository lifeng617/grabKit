//
//  GRKPickerPhotoViewer.m
//  grabKit
//
//  Created by dragon on 8/14/14.
//
//

#import "GRKPickerPhotoViewer.h"
#import "GRKPickerViewController.h"
#import "GRKPickerViewController+privateMethods.h"
#import "GRKPickerThumbnailManager.h"

#import "GRKPhoto.h"
#import "GRKImage.h"

#import "MBProgressHUD.h"

@interface GRKPickerPhotoViewer ()<UIScrollViewDelegate>
{
    
    CGPoint _contentOffset;
    
    BOOL _calledOnce;
    
    BOOL _menuHidden;
    
    CGSize _scrollSize;
    
    BOOL _initialized;
    
    CGRect hiddenFrame;
    CGRect shownFrame;
    
}


@property (nonatomic, strong) GRKPhoto *photo;

@end



@implementation GRKPickerPhotoViewer


@synthesize scrollView;

@synthesize container;

@synthesize imageView;



- (id)initWithPhoto:(GRKPhoto *)photo
{
    
    self = [super initWithNibName:@"GRKPickerPhotoViewer" bundle:GRK_BUNDLE];
    
    if ( self ){
        
        self.photo = photo;
    }
    
    
    return self;
}



- (void) dealloc
{
    
    self.photo = nil;
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _initialized = NO;
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
}

- (void) viewWillAppear:(BOOL)animated
{
    
    [super viewWillAppear:animated];
    
}

- (void) viewDidAppear:(BOOL)animated
{
    
    [super viewDidAppear:animated];
    
    
    if ( !_initialized ) {
        
        _initialized = YES;
        
        CGRect frame = self.navigationController.view.bounds;
        frame = [self.view convertRect:frame fromView:self.navigationController.view];
        shownFrame = frame;
        hiddenFrame = frame; hiddenFrame.origin.y = 0;
        
        self.scrollView.frame = frame;
        
        
        self.title = [[self.photo caption] length] > 0 ? [self.photo caption] : @"Photo";
        
        
        _scrollSize = CGSizeZero;
        
        [self loadPhoto];
        
    }
}


- (void)viewWillDisappear:(BOOL)animated
{
    
    [super viewWillDisappear:animated];
    
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    self.navigationController.navigationBarHidden = NO;
    self.navigationController.navigationBar.alpha = 1;
}

#pragma mark Internal

-(void)showHUD {
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeIndeterminate;
    
    hud.labelText = GRK_i18n(@"GRK_ALBUMS_LIST_HUD_LOADING", @"Loading ...");
    
}

-(void)hideHUD {
    
    
    [MBProgressHUD  hideHUDForView:self.view animated:YES];
    
}

- (void) loadPhoto
{
    
    GRKImage *grkImage = [self.photo originalImage];
    
    if ( !grkImage || !grkImage.URL )
        return;
    
    
    [self showHUD];
    
    __weak GRKPickerPhotoViewer *wself = self;
    
    [[GRKPickerThumbnailManager sharedInstance] downloadPhotoAtURL:grkImage.URL withCompleteBlock:^(UIImage *thumbnail, BOOL retrievedFromCache) {
        
        
        __strong GRKPickerPhotoViewer *sself = wself;
        
        if ( !sself )
            return;
        
        
        [sself hideHUD];
        
        [sself imageLoaded:thumbnail];
        
        
    } andErrorBlock:^(NSError *error) {
        
        
        __strong GRKPickerPhotoViewer *sself = wself;
        
        if ( !sself )
            return;
        
        
        [sself hideHUD];
        
    }];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    if (self.imageView.image)
        [self saveContext:nil];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    if (self.imageView.image) {
        
        CGSize imvBounds = self.container.bounds.size;
        CGSize contentSize = self.scrollView.contentSize;
        
        CGFloat scaleX = imvBounds.width / contentSize.width;
        CGFloat scaleY = imvBounds.height / contentSize.height;
        
        if (scaleX == scaleY)
            return;
        
        if (self.scrollView.zoomScale == 1)
        {
            
            [self layoutImageView];
        }
        else
        {
            CGFloat zoomScale = self.scrollView.zoomScale;
            CGPoint contentOffset = _contentOffset;
            
            imvBounds = self.scrollView.contentSize;
            
            
            CGFloat w = MIN(_scrollSize.width, imvBounds.width);
            CGFloat h = MIN(_scrollSize.height, imvBounds.height);
            
            //get identity center {0..1, 0..1}
            CGPoint center;
            
            center.x = (contentOffset.x + w * 0.5) / imvBounds.width;
            center.y = (contentOffset.y + h * 0.5) / imvBounds.height;
            
            //new content size
            CGFloat scale1 = contentSize.width / self.scrollView.frame.size.width;
            CGFloat scale2 = contentSize.height / self.scrollView.frame.size.height;
            
            CGFloat scale = MAX(scale1, scale2);
            
            CGSize nContentSize = CGSizeMake(contentSize.width / scale, contentSize.height / scale);
            
            //new center
            center.x = center.x * nContentSize.width;
            center.y = center.y * nContentSize.height;
            w = self.scrollView.frame.size.width / zoomScale;
            h = self.scrollView.frame.size.height / zoomScale;
            
            
            self.scrollView.zoomScale = 1;
            self.scrollView.contentOffset = CGPointZero;
            self.scrollView.contentSize = nContentSize;
            CGRect rectToZoomTo = CGRectMake(center.x - w * 0.5, center.y - h * 0.5, w, h);
            
            [self layoutImageView];
            [self.scrollView zoomToRect:rectToZoomTo animated:YES];
        }
        
    }
}

- (void)imageLoaded:(UIImage *)image
{
    
    if (image == nil)
        return;
    
    
    self.imageView.image = image;
    
    
    UITapGestureRecognizer *oneTapGesture;
    
    oneTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onToggleZoom:)];
    oneTapGesture.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:oneTapGesture];
    
    
    
    
    UITapGestureRecognizer *doubleTapGesutre;
    
    doubleTapGesutre = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onToggleMenu:)];
    doubleTapGesutre.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:doubleTapGesutre];
    
    
    [oneTapGesture requireGestureRecognizerToFail:doubleTapGesutre];
    
    [self layoutImageView];
    
}

- (void) layoutImageView
{
    if ( self.imageView.image != nil )
    {
        
        CGSize frameSz = [self.scrollView frame].size;
        CGSize imgSz = [self.imageView.image size];
        
        CGFloat scale1 = imgSz.width / frameSz.width;
        CGFloat scale2 = imgSz.height / frameSz.height;
        
        CGFloat scale = MAX(scale1, scale2);
        
        self.container.transform = CGAffineTransformIdentity;
        self.container.frame = CGRectMake(0, 0, imgSz.width / scale, imgSz.height / scale);
        self.imageView.frame = CGRectMake(0, 0, imgSz.width / scale, imgSz.height / scale);
        
        self.scrollView.contentSize = self.container.frame.size;
        self.scrollView.delegate = self;
        self.scrollView.minimumZoomScale = 1;
        self.scrollView.maximumZoomScale = self.scrollView.minimumZoomScale * 3;
        self.scrollView.zoomScale = 1;
        
        CGPoint centerPoint = CGPointMake(CGRectGetMidX(self.scrollView.bounds), CGRectGetMidY(self.scrollView.bounds));
        [self view:self.container setCenter:centerPoint];
        
        _scrollSize = frameSz;
    }
}

- (void) view:(UIView *)view setCenter:(CGPoint)centerPoint
{
    
    CGRect vf = view.frame;
    
    CGPoint co = self.scrollView.contentOffset;
    
    CGFloat x = centerPoint.x - vf.size.width / 2.0;
    
    CGFloat y = centerPoint.y - vf.size.height / 2.0;
    
    
    if ( x < 0 )
    {
        co.x = -x;
        vf.origin.x = 0;
    }
    else
    {
        vf.origin.x = x;
    }
    
    if (y < 0)
    {
        co.y = -y;
        vf.origin.y = 0;
    }
    else
    {
        vf.origin.y = y;
    }
    
    
    view.frame = vf;
    
    self.scrollView.contentOffset = co;
    
}

#pragma mark Event

- (void) onToggleMenu:(id)sender
{
    
    _menuHidden = !_menuHidden;
    
    [[UIApplication sharedApplication] setStatusBarHidden:_menuHidden withAnimation:UIStatusBarAnimationFade];
    
    if (_menuHidden)
    {
        self.view.backgroundColor = [UIColor blackColor];
        
        if (self.navigationController) {
            
            
            [UIView beginAnimations:nil context:nil];
            [self.navigationController setNavigationBarHidden:YES animated:YES];
            [UIView setAnimationDuration:UINavigationControllerHideShowBarDuration];
            
            self.scrollView.frame = hiddenFrame;
            
            [UIView commitAnimations];
        }
    }
    else
    {
        self.view.backgroundColor = [UIColor whiteColor];
        
        if (self.navigationController) {
            
            [UIView beginAnimations:nil context:nil];
            [self.navigationController setNavigationBarHidden:NO animated:YES];
            [UIView setAnimationDuration:UINavigationControllerHideShowBarDuration];
            
            self.scrollView.frame = shownFrame;
            
            [UIView commitAnimations];
            
        }
    }
    
}

- (void) onToggleZoom:(id)sender
{
    
    UITapGestureRecognizer *gesture = sender;
    
    if ( self.scrollView.zoomScale == self.scrollView.minimumZoomScale )
    {
        
        CGPoint pointInView = [gesture locationInView:self.imageView];
        CGFloat newZoomScale = self.scrollView.maximumZoomScale;
        CGSize scrollViewSize = self.scrollView.bounds.size;
        
        CGFloat w = scrollViewSize.width / newZoomScale;
        CGFloat h = scrollViewSize.height / newZoomScale;
        CGFloat x = pointInView.x - (w / 2.0f);
        CGFloat y = pointInView.y - (h / 2.0f);
        
        CGRect rectToZoomTo = CGRectMake(x, y, w, h);
        
        [self.scrollView zoomToRect:rectToZoomTo animated:YES];
    }
    else
    {
        [self.scrollView setZoomScale:self.scrollView.minimumZoomScale animated:YES];
    }
}

#pragma mark Scroll View

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.container;
}

- (void) scrollViewDidZoom:(UIScrollView *)sv
{
    
    CGRect svBounds = sv.bounds;
    
    UIView *zoomView = [sv.delegate viewForZoomingInScrollView:sv];
    
    CGRect zvf = zoomView.frame;
    
    if ( zvf.size.width < svBounds.size.width )
    {
        zvf.origin.x = (svBounds.size.width - zvf.size.width) / 2.0;
    }
    else
    {
        zvf.origin.x = 0.0;
    }
    
    if ( zvf.size.height < svBounds.size.height )
    {
        zvf.origin.y = (svBounds.size.height - zvf.size.height) / 2.0;
    }
    else
    {
        zvf.origin.y = 0;
    }
    
//    zvf.origin.y += svBounds.origin.y;
    
    zoomView.frame = zvf;
}

- (void) saveContext:(id)sender
{
    _scrollSize = self.scrollView.frame.size;
    _contentOffset = self.scrollView.contentOffset;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
