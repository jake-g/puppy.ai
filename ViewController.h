#import <UIKit/UIKit.h>
#import "PAIFeedback.h"
#import "PAIResultLabels.h"
#import "PAIShare.h"
#import "PAICNNRunner.h"
#import "PAIVideoPRocessing.h"

@interface ViewController
    : UIViewController<UIGestureRecognizerDelegate> {
  IBOutlet UIView *previewView;
  IBOutlet UISegmentedControl *camerasControl;
  IBOutlet UIButton *swapCameraButton;
  IBOutlet UIButton *feedbackButton;
  IBOutlet UIImageView *dogImageView;
  IBOutlet UIButton *shareButton;
  IBOutlet UIButton *refreshButton;
  IBOutlet UIButton *freezeButton;
  UIImage *square;

  PAICNNRunner *cNNRunner;
  PAIResultLabels *resultsLabels;
  PAIVideoPRocessing *videoPRocessing;
}
@property(retain, nonatomic) CATextLayer *predictionTextLayer;

- (IBAction)takePicture:(id)sender;
- (IBAction)switchCameras:(id)sender;
- (IBAction)showEmail:(id)sender;
- (IBAction)share:(id)sender;
- (void)runCNNOnFrameWith:(CVPixelBufferRef)RotatedPixelBuffer AndWith: (UIImage*)Image;

@end
