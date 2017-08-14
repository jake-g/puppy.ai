#import <Foundation/Foundation.h>
#import <sys/utsname.h>
#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>

@interface PAIFeedback : NSObject<MFMailComposeViewControllerDelegate>
@property (copy) NSString* Email;
@property (copy) NSString* EmailSubject;
@property (copy) NSString* ReportTemplate;
@property (copy) NSMutableArray* ModelPredictions;
@property (retain) UIViewController* parentViewConstroller;
@property (copy) UIImage* DogImage;

-(void)SendReport;
@end
