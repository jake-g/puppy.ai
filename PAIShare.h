#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PAIShare : NSObject
@property (retain) UIImageView* ImageToShare;
@property (retain) NSURL* Url;
@property (retain) UIViewController* ParentViewController;
-(void)share;
@end
