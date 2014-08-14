/*
 */

#import <UIKit/UIKit.h>
#import "GRKServiceGrabber.h"
#import "GRKServiceGrabberProtocol.h"
#import "GRKServiceGrabberConnectionProtocol.h"


/** GRKDropboxGrabber is a subclass of GRKServiceGrabber specific for Dropbox, conforming to GRKServiceGrabberProtocol.
 *
 *
 * @see Example Reference : https://github.com/danielbierwirth/Dropboxbrowser
 *
 */
@interface GRKDropboxGrabber : GRKServiceGrabber <GRKServiceGrabberProtocol, GRKServiceGrabberConnectionProtocol> {
}

@end
