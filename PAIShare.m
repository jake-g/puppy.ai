#import "PAIShare.h"

@implementation PAIShare
- (UIImage *)snapshot:(UIView *)view
{
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, YES, 0);
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}
-(void)share
{
    UIImage *imageToShare = [self snapshot:self.ImageToShare];
    NSArray *items = @[imageToShare];
    
    
    UIActivityViewController *controller = [[UIActivityViewController alloc]initWithActivityItems:items applicationActivities:nil];
    
    NSArray *excluded = @[UIActivityTypePrint,
                          UIActivityTypeCopyToPasteboard,
                          UIActivityTypeAssignToContact,
                          UIActivityTypeSaveToCameraRoll,
                          UIActivityTypeAddToReadingList,
                          UIActivityTypeAirDrop,
                          UIActivityTypeMessage,
                          //UIActivityTypeMail,
                          //UIActivityTypePostToFacebook
                          //UIActivityTypePostToTwitter,
                          //UIActivityTypePostToFlickr,
                          UIActivityTypePostToVimeo,
                          UIActivityTypePostToTencentWeibo,
                          UIActivityTypePostToWeibo,
                          UIActivityTypeOpenInIBooks
                          ];
    controller.excludedActivityTypes = excluded;
    [self.ParentViewController presentViewController:controller animated:YES completion:^{
    }];
}
@end
