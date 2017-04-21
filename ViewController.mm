// custom tf model
// jake g

#import <AssertMacros.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import "ViewController.h"
#import <Accelerate/Accelerate.h>
#include <sys/time.h>
#import <sys/utsname.h>

#include "tensorflow_utils.h"

// Config
static NSString* model_file_name = @"mmapped_graph";  // optimized tf model
static NSString* model_file_type = @"pb"; // input type
static NSString* labels_file_name = @"retrained_labels";  // labels file
static NSString* labels_file_type = @"txt";
static NSString *defaultLabelFont = @"Helvetica Neue-Regular";
const float colMargin = 0;
const float rowMargin = 0;
const float rowHeight = 26.0f;  // header, label and value height
const float entryMargin = rowMargin + rowHeight;
const float fontSize = 16.0f;
const float valueWidth = 100.0f;
const float labelWidth = 2000.0f;

const bool model_uses_memory_mapping = true;
// These dimensions need to match those the model was trained with.
const int wanted_input_width = 299;
const int wanted_input_height = 299;
const int wanted_input_channels = 3;
const float input_mean = 128.0f;
const float input_std = 128.0f;
const std::string input_layer_name = "Mul";
const std::string output_layer_name = "final_result";

static const NSString *AVCaptureStillImageIsCapturingStillImageContext =
    @"AVCaptureStillImageIsCapturingStillImageContext";

@interface ViewController (InternalMethods)
- (void)setupAVCapture;
- (void)teardownAVCapture;
@end

@implementation ViewController
CVPixelBufferRef currentImageBuffer = nullptr;
NSMutableArray *predictions = [NSMutableArray arrayWithCapacity:1];

- (void)setupAVCapture {
  NSError *error = nil;

  session = [AVCaptureSession new];
  if ([[UIDevice currentDevice] userInterfaceIdiom] ==
      UIUserInterfaceIdiomPhone)
    [session setSessionPreset:AVCaptureSessionPreset640x480];
  else
    [session setSessionPreset:AVCaptureSessionPresetPhoto];

  AVCaptureDevice *device =
      [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
  AVCaptureDeviceInput *deviceInput =
      [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
  assert(error == nil);

  isUsingFrontFacingCamera = NO;
  if ([session canAddInput:deviceInput]) [session addInput:deviceInput];

  stillImageOutput = [AVCaptureStillImageOutput new];
  [stillImageOutput
      addObserver:self
       forKeyPath:@"capturingStillImage"
          options:NSKeyValueObservingOptionNew
          context:(void *)(AVCaptureStillImageIsCapturingStillImageContext)];
  if ([session canAddOutput:stillImageOutput])
    [session addOutput:stillImageOutput];

  videoDataOutput = [AVCaptureVideoDataOutput new];

  NSDictionary *rgbOutputSettings = [NSDictionary
      dictionaryWithObject:[NSNumber numberWithInt:kCMPixelFormat_32BGRA]
                    forKey:(id)kCVPixelBufferPixelFormatTypeKey];
  [videoDataOutput setVideoSettings:rgbOutputSettings];
  [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
  videoDataOutputQueue =
      dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
  [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];

  if ([session canAddOutput:videoDataOutput])
    [session addOutput:videoDataOutput];
  [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];

  previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
  [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
  CALayer *rootLayer = [previewView layer];
  [rootLayer setMasksToBounds:YES];
  [previewLayer setFrame:[rootLayer bounds]];
  [rootLayer addSublayer:previewLayer];
  [session startRunning];

  [session release];
  if (error) {
    UIAlertView *alertView = [[UIAlertView alloc]
            initWithTitle:[NSString stringWithFormat:@"Failed with error %d",
                                                     (int)[error code]]
                  message:[error localizedDescription]
                 delegate:nil
        cancelButtonTitle:@"Dismiss"
        otherButtonTitles:nil];
    [alertView show];
    [alertView release];
    [self teardownAVCapture];
  }
}

- (void)teardownAVCapture {
  [videoDataOutput release];
  if (videoDataOutputQueue) dispatch_release(videoDataOutputQueue);
  [stillImageOutput removeObserver:self forKeyPath:@"isCapturingStillImage"];
  [stillImageOutput release];
  [previewLayer removeFromSuperlayer];
  [previewLayer release];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  if (context == AVCaptureStillImageIsCapturingStillImageContext) {
    BOOL isCapturingStillImage =
        [[change objectForKey:NSKeyValueChangeNewKey] boolValue];

    if (isCapturingStillImage) {
      // do flash bulb like animation
      flashView = [[UIView alloc] initWithFrame:[previewView frame]];
      [flashView setBackgroundColor:[UIColor whiteColor]];
      [flashView setAlpha:0.f];
      [[[self view] window] addSubview:flashView];

      [UIView animateWithDuration:.4f
                       animations:^{
                         [flashView setAlpha:1.f];
                       }];
    } else {
      [UIView animateWithDuration:.4f
          animations:^{
            [flashView setAlpha:0.f];
          }
          completion:^(BOOL finished) {
            [flashView removeFromSuperview];
            [flashView release];
            flashView = nil;
          }];
    }
  }
}




// Take Snap
- (IBAction)takePicture:(id)sender {
  if ([session isRunning]) {
    [session stopRunning];
    [sender setTitle:@"Continue" forState:UIControlStateNormal];

    flashView = [[UIView alloc] initWithFrame:[previewView frame]];
    [flashView setBackgroundColor:[UIColor whiteColor]];
    [flashView setAlpha:0.f];
    [[[self view] window] addSubview:flashView];
    
    swapCameraButton.hidden = TRUE;
    feedbackButton.hidden = FALSE;
      if (predictions.count>0) {
          shareButton.hidden = FALSE;
      }
      
    dogImageView.image = [self imageFromSampleBuffer:currentImageBuffer];
      
    [UIView animateWithDuration:.2f
        animations:^{
          [flashView setAlpha:1.f];
        }
        completion:^(BOOL finished) {
          [UIView animateWithDuration:.2f
              animations:^{
                [flashView setAlpha:0.f];
              }
              completion:^(BOOL finished) {
                [flashView removeFromSuperview];
                [flashView release];
                flashView = nil;
            }];
        }];
  } else {
    [session startRunning];
    [sender setTitle:@"Freeze" forState:UIControlStateNormal];
      swapCameraButton.hidden = FALSE;
      feedbackButton.hidden = TRUE;
      shareButton.hidden = TRUE;
  }
}

- (UIImage *) imageFromSampleBuffer:(CVImageBufferRef) imageBuffer
{
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    CGImageRelease(quartzImage);
    
    return (image);
}

- (UIImage *)snapshot:(UIView *)view
{
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, YES, 0);
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

+ (CGRect)videoPreviewBoxForGravity:(NSString *)gravity
                          frameSize:(CGSize)frameSize
                       apertureSize:(CGSize)apertureSize {
  CGFloat apertureRatio = apertureSize.height / apertureSize.width;
  CGFloat viewRatio = frameSize.width / frameSize.height;

  CGSize size = CGSizeZero;
  if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
    if (viewRatio > apertureRatio) {
      size.width = frameSize.width;
      size.height =
          apertureSize.width * (frameSize.width / apertureSize.height);
    } else {
      size.width =
          apertureSize.height * (frameSize.height / apertureSize.width);
      size.height = frameSize.height;
    }
  } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
    if (viewRatio > apertureRatio) {
      size.width =
          apertureSize.height * (frameSize.height / apertureSize.width);
      size.height = frameSize.height;
    } else {
      size.width = frameSize.width;
      size.height =
          apertureSize.width * (frameSize.width / apertureSize.height);
    }
  } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
    size.width = frameSize.width;
    size.height = frameSize.height;
  }

  CGRect videoBox;
  videoBox.size = size;
  if (size.width < frameSize.width)
    videoBox.origin.x = (frameSize.width - size.width) / 2;
  else
    videoBox.origin.x = (size.width - frameSize.width) / 2;

  if (size.height < frameSize.height)
    videoBox.origin.y = (frameSize.height - size.height) / 2;
  else
    videoBox.origin.y = (size.height - frameSize.height) / 2;

  return videoBox;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    [self setVideoOriantation:connection];
    
    currentImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferRef pixelBuffer = [self rotateBuffer:sampleBuffer withConstant:1]; //roate 90 degrees
    
    [self runCNNOnFrame:pixelBuffer];
}

-(void)setVideoOriantation:(AVCaptureConnection *)connection {
    UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
    AVCaptureVideoOrientation newOrientation = AVCaptureVideoOrientationPortrait;
    
    if (interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
        newOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
    
    if (interfaceOrientation == UIInterfaceOrientationPortrait)
        newOrientation = AVCaptureVideoOrientationPortrait;
    
    if (interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
        newOrientation = AVCaptureVideoOrientationLandscapeLeft;
    
    if (interfaceOrientation == UIInterfaceOrientationLandscapeRight)
        newOrientation = AVCaptureVideoOrientationLandscapeRight;
    connection.videoOrientation = newOrientation;

}

- (CVPixelBufferRef)rotateBuffer:(CMSampleBufferRef)sampleBuffer withConstant:(uint8_t)rotationConstant
{
    CVImageBufferRef imageBuffer        = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    OSType pixelFormatType              = CVPixelBufferGetPixelFormatType(imageBuffer);
    
    const size_t kAlignment             = 32;
    const size_t kBytesPerPixel         = 4;
    
    size_t bytesPerRow                  = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width                        = CVPixelBufferGetWidth(imageBuffer);
    size_t height                       = CVPixelBufferGetHeight(imageBuffer);
    
    BOOL rotatePerpendicular            = TRUE;
    const size_t outWidth               = rotatePerpendicular ? height : width;
    const size_t outHeight              = rotatePerpendicular ? width  : height;
    
    size_t bytesPerRowOut               = kBytesPerPixel * ceil(outWidth * 1.0 / kAlignment) * kAlignment;
    
    const size_t dstSize                = bytesPerRowOut * outHeight * sizeof(unsigned char);
    
    void *srcBuff                       = CVPixelBufferGetBaseAddress(imageBuffer);
    
    unsigned char *dstBuff              = (unsigned char *)malloc(dstSize);
    
    vImage_Buffer inbuff                = {srcBuff, height, width, bytesPerRow};
    vImage_Buffer outbuff               = {dstBuff, outHeight, outWidth, bytesPerRowOut};
    
    uint8_t bgColor[4]                  = {0, 0, 0, 0};
    
    vImage_Error err                    = vImageRotate90_ARGB8888(&inbuff, &outbuff, rotationConstant, bgColor, 0);
    if (err != kvImageNoError)
    {
        NSLog(@"%ld", err);
    }
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    CVPixelBufferRef rotatedBuffer      = NULL;
    CVPixelBufferCreateWithBytes(NULL,
                                 outWidth,
                                 outHeight,
                                 pixelFormatType,
                                 outbuff.data,
                                 bytesPerRowOut,
                                 freePixelBufferDataAfterRelease,
                                 NULL,
                                 NULL,
                                 &rotatedBuffer);
    
    return rotatedBuffer;
}

void freePixelBufferDataAfterRelease(void *releaseRefCon, const void *baseAddress)
{
    // Free the memory we malloced for the vImage rotation
    free((void *)baseAddress);
}
// Conv Net
- (void)runCNNOnFrame:(CVPixelBufferRef)pixelBuffer {
  assert(pixelBuffer != NULL);

  OSType sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
  int doReverseChannels;
  if (kCVPixelFormatType_32ARGB == sourcePixelFormat) {
    doReverseChannels = 1;
  } else if (kCVPixelFormatType_32BGRA == sourcePixelFormat) {
    doReverseChannels = 0;
  } else {
    assert(false);  // Unknown source format
  }

  const int sourceRowBytes = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
  const int image_width = (int)CVPixelBufferGetWidth(pixelBuffer);
  const int fullHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
  CVPixelBufferLockBaseAddress(pixelBuffer, 0);
  unsigned char *sourceBaseAddr =
      (unsigned char *)(CVPixelBufferGetBaseAddress(pixelBuffer));
  int image_height;
  unsigned char *sourceStartAddr;
  if (fullHeight <= image_width) {
    image_height = fullHeight;
    sourceStartAddr = sourceBaseAddr;
  } else {
    image_height = image_width;
    const int marginY = ((fullHeight - image_width) / 2);
    sourceStartAddr = (sourceBaseAddr + (marginY * sourceRowBytes));
  }
  const int image_channels = 4;

  assert(image_channels >= wanted_input_channels);
  tensorflow::Tensor image_tensor(
      tensorflow::DT_FLOAT,
      tensorflow::TensorShape(
          {1, wanted_input_height, wanted_input_width, wanted_input_channels}));
  auto image_tensor_mapped = image_tensor.tensor<float, 4>();
  tensorflow::uint8 *in = sourceStartAddr;
  float *out = image_tensor_mapped.data();
  for (int y = 0; y < wanted_input_height; ++y) {
    float *out_row = out + (y * wanted_input_width * wanted_input_channels);
    for (int x = 0; x < wanted_input_width; ++x) {
      const int in_x = (y * image_width) / wanted_input_width;
      const int in_y = (x * image_height) / wanted_input_height;
      tensorflow::uint8 *in_pixel =
          in + (in_y * image_width * image_channels) + (in_x * image_channels);
      float *out_pixel = out_row + (x * wanted_input_channels);
      for (int c = 0; c < wanted_input_channels; ++c) {
        out_pixel[c] = (in_pixel[c] - input_mean) / input_std;
      }
    }
  }
    
  
    
  if (tf_session.get()) {
    std::vector<tensorflow::Tensor> outputs;
    tensorflow::Status run_status = tf_session->Run(
        {{input_layer_name, image_tensor}}, {output_layer_name}, {}, &outputs);
    if (!run_status.ok()) {
      LOG(ERROR) << "Running model failed:" << run_status;
    } else {
      tensorflow::Tensor *output = &outputs[0];
      auto predictions = output->flat<float>();

      NSMutableDictionary *newValues = [NSMutableDictionary dictionary];
      for (int index = 0; index < predictions.size(); index += 1) {
        const float predictionValue = predictions(index);
        if (predictionValue > 0.05f) {
          std::string label = labels[index % predictions.size()];
          NSString *labelObject = [NSString stringWithCString:label.c_str()];
          NSNumber *valueObject = [NSNumber numberWithFloat:predictionValue];
          [newValues setObject:valueObject forKey:labelObject];
        }
      }
      dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self setPredictionValues:newValues];
      });
    }
  }
}

- (void)dealloc {
  [self teardownAVCapture];
  [square release];
  [swapCameraButton release];
  [feedbackButton release];
  [shareButton release];
  [super dealloc];
}

- (IBAction)showEmail:(id)sender {
    
    NSString *emailTitle = @"Puppy.ai user feedback";
    NSString *messageBody = @"";
    
    if (predictions.count==2) {
        messageBody = [self emailBody:predictions image: dogImageView.image];
    } else {
        messageBody = [self emailBody:dogImageView.image];
    }
    
    NSArray *toRecipents = [NSArray arrayWithObject:@"getpuppyai@gmail.com"];
    
    MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
    mc.mailComposeDelegate = self;
    [mc setSubject:emailTitle];
    [mc setMessageBody:messageBody isHTML:YES];
    [mc setToRecipients:toRecipents];
    [mc addAttachmentData:UIImageJPEGRepresentation(dogImageView.image, 1) mimeType:@"image/jpeg" fileName:@"dogImage.jpg"];
    
    [self presentViewController:mc animated:YES completion:NULL];
    
}

- (NSString *) emailBody:(NSMutableArray*) predictions
                   image:(UIImage*) image
{
    NSString *format = @"<html>"
    @"<body>"
    @"<p>Hi puppy.ai team,</p>"
    @"<p>I have used your app to determine the breed of the dog shown below.</p>"
    @"<p>puppy.ai thinks that it is a %@ with %@ certainty or %@ with %@ certainty, but actually the dog breed is ...</p>"
    @"<p>%@ | %@ version: %@ | puppy.ai version: %@ | build: %@</p>"
    @"</body>"
    @"</html>";
    //NSData *imageData = UIImagePNGRepresentation(image);
    UIDevice *currentDevice  = [UIDevice currentDevice];
    NSString *deviceModel = [self deviceName];
    NSString *OSName = currentDevice.systemName;
    NSString *OSVersion = currentDevice.systemVersion;
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *buildNumber = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    return [NSString stringWithFormat:format,predictions[0][0],predictions[0][1],
            predictions[1][0],predictions[1][1], deviceModel,OSName,OSVersion,appVersion,buildNumber]; //ugly, need to rewrite later
}

- (NSString *) emailBody:(UIImage*) image
{
    NSString *format = @"<html>"
    @"<body>"
    @"<p>Hi puppy.ai team,</p>"
    @"<p>I have used your app to determine the breed of the dog shown below.</p>"
    @"<p>puppy.ai thinks that it is not a dog, but actually the dog breed is ...</p>"
    @"<p>%@ | %@ version: %@ | puppy.ai version: %@ | build: %@</p>"
    @"</body>"
    @"</html>";
    
    //NSData *imageData = UIImageJPEGRepresentation(image, 1);
    UIDevice *currentDevice  = [UIDevice currentDevice];
    NSString *deviceModel = [self deviceName];
    NSString *OSName = currentDevice.systemName;
    NSString *OSVersion = currentDevice.systemVersion;
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *buildNumber = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    return [NSString stringWithFormat:format,deviceModel,OSName,OSVersion,appVersion,buildNumber]; //ugly, need to rewrite later
}

- (void) mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    switch (result)
    {
        case MFMailComposeResultCancelled:
            NSLog(@"Mail cancelled");
            break;
        case MFMailComposeResultSaved:
            NSLog(@"Mail saved");
            break;
        case MFMailComposeResultSent:
            NSLog(@"Mail sent");
            break;
        case MFMailComposeResultFailed:
            NSLog(@"Mail sent failure: %@", [error localizedDescription]);
            break;
        default:
            break;
    }

    [self dismissViewControllerAnimated:YES completion:NULL];
}

// use front/back camera
- (IBAction)switchCameras:(id)sender {
  AVCaptureDevicePosition desiredPosition;
  if (isUsingFrontFacingCamera)
    desiredPosition = AVCaptureDevicePositionBack;
  else
    desiredPosition = AVCaptureDevicePositionFront;

  for (AVCaptureDevice *d in
       [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
    if ([d position] == desiredPosition) {
      [[previewLayer session] beginConfiguration];
      AVCaptureDeviceInput *input =
          [AVCaptureDeviceInput deviceInputWithDevice:d error:nil];
      for (AVCaptureInput *oldInput in [[previewLayer session] inputs]) {
        [[previewLayer session] removeInput:oldInput];
      }
      [[previewLayer session] addInput:input];
      [[previewLayer session] commitConfiguration];
      break;
    }
  }
  isUsingFrontFacingCamera = !isUsingFrontFacingCamera;
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  square = [[UIImage imageNamed:@"squarePNG"] retain];
  synth = [[AVSpeechSynthesizer alloc] init];
  labelLayers = [[NSMutableArray alloc] init];
  oldPredictionValues = [[NSMutableDictionary alloc] init];
  
  tensorflow::Status load_status;
  if (model_uses_memory_mapping) {
    load_status = LoadMemoryMappedModel(
        model_file_name, model_file_type, &tf_session, &tf_memmapped_env);
  } else {
    load_status = LoadModel(model_file_name, model_file_type, &tf_session);
  }
  if (!load_status.ok()) {
    LOG(FATAL) << "Couldn't load model: " << load_status;
  }

  tensorflow::Status labels_status =
      LoadLabels(labels_file_name, labels_file_type, &labels);
  if (!labels_status.ok()) {
    LOG(FATAL) << "Couldn't load labels: " << labels_status;
  }
  [self setupAVCapture];
}

- (void)viewDidUnload {
  [super viewDidUnload];
  [oldPredictionValues release];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
    
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self setVideoOriantation:previewLayer.connection];
        CALayer *rootLayer = [previewView layer];
        [previewLayer setFrame:[rootLayer bounds]];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
    }];
}


- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:
    (UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}



// Write predictions
- (void)setPredictionValues:(NSDictionary *)newValues {
  const float decayValue = 0.75f;  // how fast predictions decay
  const float updateValue = 0.25f;
  const float minimumThreshold = 0.01f;

  NSMutableDictionary *decayedPredictionValues =
      [[NSMutableDictionary alloc] init];
  for (NSString *label in oldPredictionValues) {
    NSNumber *oldPredictionValueObject =
        [oldPredictionValues objectForKey:label];
    const float oldPredictionValue = [oldPredictionValueObject floatValue];
    const float decayedPredictionValue = (oldPredictionValue * decayValue);
    if (decayedPredictionValue > minimumThreshold) {
      NSNumber *decayedPredictionValueObject =
          [NSNumber numberWithFloat:decayedPredictionValue];
      [decayedPredictionValues setObject:decayedPredictionValueObject
                                  forKey:label];
    }
  }
  [oldPredictionValues release];
  oldPredictionValues = decayedPredictionValues;

  for (NSString *label in newValues) {
    NSNumber *newPredictionValueObject = [newValues objectForKey:label];
    NSNumber *oldPredictionValueObject =
        [oldPredictionValues objectForKey:label];
    if (!oldPredictionValueObject) {
      oldPredictionValueObject = [NSNumber numberWithFloat:0.0f];
    }
    const float newPredictionValue = [newPredictionValueObject floatValue];
    const float oldPredictionValue = [oldPredictionValueObject floatValue];
    const float updatedPredictionValue =
        (oldPredictionValue + (newPredictionValue * updateValue));
    NSNumber *updatedPredictionValueObject =
        [NSNumber numberWithFloat:updatedPredictionValue];
    [oldPredictionValues setObject:updatedPredictionValueObject forKey:label];
  }
  NSArray *candidateLabels = [NSMutableArray array];
  for (NSString *label in oldPredictionValues) {
    NSNumber *oldPredictionValueObject =
        [oldPredictionValues objectForKey:label];
    const float oldPredictionValue = [oldPredictionValueObject floatValue];
    if (oldPredictionValue > 0.05f) {
      NSDictionary *entry = @{
        @"label" : label,
        @"value" : oldPredictionValueObject
      };
      candidateLabels = [candidateLabels arrayByAddingObject:entry];
    }
  }
  NSSortDescriptor *sort =
      [NSSortDescriptor sortDescriptorWithKey:@"value" ascending:NO];
  NSArray *sortedLabels = [candidateLabels
      sortedArrayUsingDescriptors:[NSArray arrayWithObject:sort]];

//  const float headerValueWidth = 96.0f;
//  const float headerLabelWidth = 198.0f;
// use full width TODO get this from device
//  const float labelMarginX = 5.0f;

  if ([sortedLabels count] > 0) {
    [self removeAllLabelLayers];
  }
  else {    // No dog detected
    [self removeAllLabelLayers];
      [self addLabelToViewLeftCorner:self.view label:@"Point camera at a dog..."];
  }

  int labelCount = 0;

  for (NSDictionary *entry in sortedLabels) {
    
    // Add header
    if (labelCount == 0) {
        [predictions removeAllObjects];
        [self addHeaderToView:self.view];
    }
    
    // Add label entry
    NSString *label = [entry objectForKey:@"label"];
    NSNumber *valueObject = [entry objectForKey:@"value"];
    const float value = [valueObject floatValue];
    
      
    const int valuePercentage = (int)roundf(value * 100.0f);
    NSString *valueText = [NSString stringWithFormat:@"%d%%", valuePercentage];
    NSArray *prediction = [[NSArray alloc] initWithObjects:label,valueText,nil];
    [predictions addObject:prediction];
    
      [self addLabelsToView:self.view label:label value:valueText count:labelCount];
    // Speak if 50% confident
    if ((labelCount == 0) && (value > 0.5f)) {
      [self speak:[label capitalizedString]];
    }
    
    // Limit # labels to display
    labelCount += 1;
    if (labelCount > 1) {
      break;
    }
  }
}

-(void) addLabelToViewLeftCorner: (UIView*) view
                           label:(NSString*) labelText {
    [self addLabelLayerWithText:labelText
                           font:defaultLabelFont
                        originX:2*colMargin
                        originY:2*rowMargin
                          width:labelWidth
                         height:rowHeight
                       fontSize:fontSize
                      alignment:kCAAlignmentLeft
                           view:view];
}

-(void)addHeaderToView:(UIView*)view {
    [self addLabelLayerWithText:@"Likelihood"
                           font:@"Helvetica-Bold"
                        originX:colMargin
                        originY:rowMargin
                          width:valueWidth
                         height:rowHeight
                       fontSize:fontSize
                      alignment:kCAAlignmentRight
                           view:view];
    
    const float breedOriginX = (colMargin + valueWidth + colMargin);
    
    [self addLabelLayerWithText:@"Dog Breed"
                           font:@"Helvetica-Bold"
                        originX:breedOriginX
                        originY:rowMargin
                          width:labelWidth
                         height:rowHeight
                       fontSize:fontSize
                      alignment:kCAAlignmentLeft
                           view:view];
}

-(void)addLabelsToView:(UIView*) view
                 label:(NSString*) label
                 value: (NSString*) valueText
                 count: (int) labelCount
{
    
    const float originY =
    (entryMargin + (rowHeight * labelCount));
    
    [self addLabelLayerWithText:valueText
                           font:defaultLabelFont
                        originX:colMargin
                        originY:originY
                          width:valueWidth
                         height:rowHeight
                       fontSize:fontSize
                      alignment:kCAAlignmentRight
                           view:view];
    
    const float labelOriginX = (colMargin + valueWidth + colMargin);
    
    [self addLabelLayerWithText:[label capitalizedString]
                           font:defaultLabelFont
                        originX:labelOriginX
                        originY:originY
                          width:labelWidth
                         height:rowHeight
                       fontSize:fontSize
                      alignment:kCAAlignmentLeft
                           view:view];

}

-(void)addFooterToView:(UIView*) view
                 value: (NSString*) valueText
{
    
    [self addLabelLayerWithText:valueText
                           font:defaultLabelFont
                        originX: dogImageView.frame.size.width - 315.00f
                        originY: dogImageView.frame.size.height - rowHeight
                          width:labelWidth
                         height:18.00f
                       fontSize:10.00f
                      alignment:kCAAlignmentLeft
                           view:view];
    
}

- (void)removeAllLabelLayers {
  for (CATextLayer *layer in labelLayers) {
    [layer removeFromSuperlayer];
  }
  [labelLayers removeAllObjects];
}

- (void)addLabelLayerWithText:(NSString *)text
                      font: (NSString *const)font
                      originX:(float)originX
                      originY:(float)originY
                        width:(float)width
                       height:(float)height
                     fontSize:(float)fontSize
                    alignment:(NSString *)alignment
                         view:(UIView *) view {
//  NSString *const font = @"Helvetica Neue-Regular";


  const float marginSizeX = 5.0f;
  const float marginSizeY = 2.0f;

  const CGRect backgroundBounds = CGRectMake(originX, originY, width, height);

  const CGRect textBounds =
      CGRectMake((originX + marginSizeX), (originY + marginSizeY),
                 (width - (marginSizeX * 2)), (height - (marginSizeY * 2)));

  CATextLayer *background = [CATextLayer layer];
  [background setBackgroundColor:[UIColor blackColor].CGColor];
  [background setOpacity:0.15f];
  [background setFrame:backgroundBounds];
//  background.cornerRadius = 5.0f;

  [[view layer] addSublayer:background];
  [labelLayers addObject:background];

  CATextLayer *layer = [CATextLayer layer];
  [layer setForegroundColor:[UIColor whiteColor].CGColor];
  [layer setFrame:textBounds];
  [layer setAlignmentMode:alignment];
  [layer setWrapped:YES];
  [layer setFont:font];
  [layer setFontSize:fontSize];
  layer.contentsScale = [[UIScreen mainScreen] scale];
  [layer setString:text];

  [[view layer] addSublayer:layer];
  [labelLayers addObject:layer];
}



- (void)setPredictionText:(NSString *)text withDuration:(float)duration {
  if (duration > 0.0) {
    CABasicAnimation *colorAnimation =
        [CABasicAnimation animationWithKeyPath:@"foregroundColor"];
    colorAnimation.duration = duration;
    colorAnimation.fillMode = kCAFillModeForwards;
    colorAnimation.removedOnCompletion = NO;
    colorAnimation.fromValue = (id)[UIColor darkGrayColor].CGColor;
    colorAnimation.toValue = (id)[UIColor whiteColor].CGColor;
    colorAnimation.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [self.predictionTextLayer addAnimation:colorAnimation
                                    forKey:@"colorAnimation"];
  } else {
    self.predictionTextLayer.foregroundColor = [UIColor whiteColor].CGColor;
  }

  [self.predictionTextLayer removeFromSuperlayer];
  [[self.view layer] addSublayer:self.predictionTextLayer];
  [self.predictionTextLayer setString:text];
}


// Speak dog breed
- (void)speak:(NSString *)words {
  if ([synth isSpeaking]) {
    return;
  }
  AVSpeechUtterance *utterance =
      [AVSpeechUtterance speechUtteranceWithString:words];
  utterance.voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"en-US"];
  utterance.rate = 0.75 * AVSpeechUtteranceDefaultSpeechRate;
  [synth speakUtterance:utterance];
}

- (IBAction)share:(id)sender {
    
    for (UIView *subview in [dogImageView subviews]) {
        [subview removeFromSuperview];
    }

    if (predictions.count==2) {
        [self addHeaderToView:dogImageView];
        [self addLabelsToView:dogImageView label:predictions[0][0] value:predictions[0][1]  count:0]; //ugly, need to rewrite
        [self addLabelsToView:dogImageView label:predictions[1][0] value:predictions[1][1]  count:1];
    } else {
        [self addLabelToViewLeftCorner:dogImageView label:@"There are no dog detected"];
    }
    [self addFooterToView:dogImageView value:@"You can do it too. Discover any dog's breed: https://puppyai.github.io"];
    dogImageView.hidden = FALSE;
    
    UIImage *imageToShare = [self snapshot:dogImageView];
    dogImageView.hidden = TRUE;
    NSURL *urlToShare = [[NSURL alloc] initWithString:@"https://puppyai.github.io"];
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
    [self presentViewController:controller animated:YES completion:^{
    }];
}

- (NSString*) deviceName
{
    struct utsname systemInfo;
    
    uname(&systemInfo);
    
    NSString* code = [NSString stringWithCString:systemInfo.machine
                                        encoding:NSUTF8StringEncoding];
    
    static NSDictionary* deviceNamesByCode = nil;
    
    if (!deviceNamesByCode) {
        
        deviceNamesByCode = @{@"i386"      :@"Simulator",
                              @"x86_64"    :@"Simulator",
                              @"iPod1,1"   :@"iPod Touch",        // (Original)
                              @"iPod2,1"   :@"iPod Touch",        // (Second Generation)
                              @"iPod3,1"   :@"iPod Touch",        // (Third Generation)
                              @"iPod4,1"   :@"iPod Touch",        // (Fourth Generation)
                              @"iPod7,1"   :@"iPod Touch",        // (6th Generation)
                              @"iPhone1,1" :@"iPhone",            // (Original)
                              @"iPhone1,2" :@"iPhone",            // (3G)
                              @"iPhone2,1" :@"iPhone",            // (3GS)
                              @"iPad1,1"   :@"iPad",              // (Original)
                              @"iPad2,1"   :@"iPad 2",            //
                              @"iPad3,1"   :@"iPad",              // (3rd Generation)
                              @"iPhone3,1" :@"iPhone 4",          // (GSM)
                              @"iPhone3,3" :@"iPhone 4",          // (CDMA/Verizon/Sprint)
                              @"iPhone4,1" :@"iPhone 4S",         //
                              @"iPhone5,1" :@"iPhone 5",          // (model A1428, AT&T/Canada)
                              @"iPhone5,2" :@"iPhone 5",          // (model A1429, everything else)
                              @"iPad3,4"   :@"iPad",              // (4th Generation)
                              @"iPad2,5"   :@"iPad Mini",         // (Original)
                              @"iPhone5,3" :@"iPhone 5c",         // (model A1456, A1532 | GSM)
                              @"iPhone5,4" :@"iPhone 5c",         // (model A1507, A1516, A1526 (China), A1529 | Global)
                              @"iPhone6,1" :@"iPhone 5s",         // (model A1433, A1533 | GSM)
                              @"iPhone6,2" :@"iPhone 5s",         // (model A1457, A1518, A1528 (China), A1530 | Global)
                              @"iPhone7,1" :@"iPhone 6 Plus",     //
                              @"iPhone7,2" :@"iPhone 6",          //
                              @"iPhone8,1" :@"iPhone 6S",         //
                              @"iPhone8,2" :@"iPhone 6S Plus",    //
                              @"iPhone8,4" :@"iPhone SE",         //
                              @"iPhone9,1" :@"iPhone 7",          //
                              @"iPhone9,3" :@"iPhone 7",          //
                              @"iPhone9,2" :@"iPhone 7 Plus",     //
                              @"iPhone9,4" :@"iPhone 7 Plus",     //
                              
                              @"iPad4,1"   :@"iPad Air",          // 5th Generation iPad (iPad Air) - Wifi
                              @"iPad4,2"   :@"iPad Air",          // 5th Generation iPad (iPad Air) - Cellular
                              @"iPad4,4"   :@"iPad Mini",         // (2nd Generation iPad Mini - Wifi)
                              @"iPad4,5"   :@"iPad Mini",         // (2nd Generation iPad Mini - Cellular)
                              @"iPad4,7"   :@"iPad Mini",         // (3rd Generation iPad Mini - Wifi (model A1599))
                              @"iPad6,7"   :@"iPad Pro (12.9\")", // iPad Pro 12.9 inches - (model A1584)
                              @"iPad6,8"   :@"iPad Pro (12.9\")", // iPad Pro 12.9 inches - (model A1652)
                              @"iPad6,3"   :@"iPad Pro (9.7\")",  // iPad Pro 9.7 inches - (model A1673)
                              @"iPad6,4"   :@"iPad Pro (9.7\")"   // iPad Pro 9.7 inches - (models A1674 and A1675)
                              };
    }
    
    NSString* deviceName = [deviceNamesByCode objectForKey:code];
    
    if (!deviceName) {
        
        if ([code rangeOfString:@"iPod"].location != NSNotFound) {
            deviceName = @"iPod Touch";
        }
        else if([code rangeOfString:@"iPad"].location != NSNotFound) {
            deviceName = @"iPad";
        }
        else if([code rangeOfString:@"iPhone"].location != NSNotFound){
            deviceName = @"iPhone";
        }
        else {
            deviceName = @"Unknown";
        }
    }
    
    return deviceName;
}


@end
