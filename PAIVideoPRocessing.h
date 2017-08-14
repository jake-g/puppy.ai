#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <Accelerate/Accelerate.h>
#import <ImageIO/ImageIO.h>
#import <UIKit/UIKit.h>

@interface PAIVideoPRocessing : NSObject<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    
    AVCaptureVideoDataOutput *videoDataOutput;
    dispatch_queue_t videoDataOutputQueue;
    AVCaptureStillImageOutput *stillImageOutput;
    AVSpeechSynthesizer *synth;
    AVCaptureSession *session;
    UIView *flashView;
    //UIView *previewView;
    AVCaptureVideoPreviewLayer *previewLayer;
}
- (void)StartAVCapture;
- (void)PauseAVCapture;
- (void)ResumeAVCapture;
- (BOOL)isRunning;
- (void)SetOrientation;
- (void)SwitchCamera;
@property (retain) UIViewController* ParentViewController;
@property (retain) UIView* ParentView;

@end
