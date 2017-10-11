#import "PAIVideoPRocessing.h"

@implementation PAIVideoPRocessing
//TODO Video
static const NSString *AVCaptureStillImageIsCapturingStillImageContext =
@"AVCaptureStillImageIsCapturingStillImageContext";
BOOL isUsingFrontFacingCamera = NO;
- (void)StartAVCapture {
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
    
    previewLayer= [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    CALayer *rootLayer = [self.ParentView layer];
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

-(BOOL)isRunning
{
    return [session isRunning];
}

- (void)PauseAVCapture
{
    if ([session isRunning]) {
        [session stopRunning];
                
        flashView = [[UIView alloc] initWithFrame:[self.ParentView frame]];
        [flashView setBackgroundColor:[UIColor whiteColor]];
        [flashView setAlpha:0.f];
        [[[self ParentView] window] addSubview:flashView];
        
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
    }
}
    
- (void)ResumeAVCapture
{
    [session startRunning];
}

-(void)SwitchCamera
{
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

- (void)SetOrientation
{
    [self setVideoOriantation:previewLayer.connection];
    CALayer *rootLayer = [self.ParentView layer];
    [previewLayer setFrame:[rootLayer bounds]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ((NSString*)context == AVCaptureStillImageIsCapturingStillImageContext) {
        BOOL isCapturingStillImage =
        [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        
        if (isCapturingStillImage) {
            // do flash bulb like animation
            flashView = [[UIView alloc] initWithFrame:[self.ParentView frame]];
            [flashView setBackgroundColor:[UIColor whiteColor]];
            [flashView setAlpha:0.f];
            [[[self ParentView] window] addSubview:flashView];
            
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

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    [self setVideoOriantation:connection];
    
    CVPixelBufferRef currentImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    
    CVPixelBufferRef rotatedPixelBuffer = [self rotateBuffer:sampleBuffer withConstant:1]; //roate 90 degrees
    
    [self.ParentViewController runCNNOnFrameWith:rotatedPixelBuffer AndWith:[self imageFromSampleBuffer:currentImageBuffer]];
}


- (void)teardownAVCapture {
    [videoDataOutput release];
    if (videoDataOutputQueue) dispatch_release(videoDataOutputQueue);
    [stillImageOutput removeObserver:self forKeyPath:@"isCapturingStillImage"];
    [stillImageOutput release];
    [previewLayer removeFromSuperlayer];
    [previewLayer release];
}

-(CGRect)videoPreviewBoxForGravity:(NSString *)gravity
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

//Video Rotation
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
//TODO Video - teardown
void freePixelBufferDataAfterRelease(void *releaseRefCon, const void *baseAddress)
{
    // Free the memory we malloced for the vImage rotation
    free((void *)baseAddress);
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
@end
