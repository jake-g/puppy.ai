#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>

#include <memory>
#include "tensorflow/core/public/session.h"
#include "tensorflow/core/util/memmapped_file_system.h"

@interface ViewController
    : UIViewController<UIGestureRecognizerDelegate,
                       AVCaptureVideoDataOutputSampleBufferDelegate,MFMailComposeViewControllerDelegate> {
  IBOutlet UIView *previewView;
  IBOutlet UISegmentedControl *camerasControl;
  IBOutlet UIButton *swapCameraButton;
  IBOutlet UIButton *feedbackButton;
  IBOutlet UIImageView *dogImageView;
  IBOutlet UIButton *shareButton;
  AVCaptureVideoPreviewLayer *previewLayer;
  AVCaptureVideoDataOutput *videoDataOutput;
  dispatch_queue_t videoDataOutputQueue;
  AVCaptureStillImageOutput *stillImageOutput;
  UIView *flashView;
  UIImage *square;
  BOOL isUsingFrontFacingCamera;
  AVSpeechSynthesizer *synth;
  NSMutableDictionary *oldPredictionValues;
  NSMutableArray *labelLayers;
  AVCaptureSession *session;
                           
  std::unique_ptr<tensorflow::Session> tf_session;
  std::unique_ptr<tensorflow::MemmappedEnv> tf_memmapped_env;
  std::vector<std::string> labels;
}
@property(retain, nonatomic) CATextLayer *predictionTextLayer;

- (IBAction)takePicture:(id)sender;
- (IBAction)switchCameras:(id)sender;
- (IBAction)showEmail:(id)sender;
- (IBAction)share:(id)sender;


@end
