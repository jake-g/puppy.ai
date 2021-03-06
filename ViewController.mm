#import "ViewController.h"

@interface ViewController (InternalMethods)
- (void)setupAVCapture;
- (void)teardownAVCapture;
@end

@implementation ViewController
UIImage* currentImage = nil;

//start video pipeline
- (void)setupAVCapture {
    [videoPRocessing StartAVCapture];
}

//take snap
- (IBAction)takePicture:(id)sender {
   if ([videoPRocessing isRunning])
   {
       [videoPRocessing PauseAVCapture];
       
       [self enableSharing];

   }
   else
   {
       [sender setTitle:@"Stop" forState:UIControlStateNormal];
       swapCameraButton.hidden = FALSE;
       feedbackButton.hidden = TRUE;
       shareButton.hidden = TRUE;
       refreshButton.hidden = FALSE;
       if ([resultsLabels isFinalPredictions]) {
           [self restartCNN];
           resultsLabels.isFinalPredictions = NO;
       }
       
       [videoPRocessing ResumeAVCapture];
   }
}

-(void) enableSharing
{
    [freezeButton setTitle:@"Restart" forState:UIControlStateNormal];
    swapCameraButton.hidden = TRUE;
    feedbackButton.hidden = FALSE;
    refreshButton.hidden = TRUE;
    
    if (resultsLabels.CleanedPredictions.count>0) {
        shareButton.hidden = FALSE;
    }
    dogImageView.image = currentImage;
}

//run convnet on given frame
- (void)runCNNOnFrameWith:(CVPixelBufferRef)RotatedPixelBuffer AndWith: (UIImage*)Image
{
    currentImage = Image;
    [cNNRunner RunCNNWith:RotatedPixelBuffer AndCompletionHandler:^(NSArray *candidateLabels) {
        NSSortDescriptor *sort =
        [NSSortDescriptor sortDescriptorWithKey:@"value" ascending:NO];
        NSArray *sortedLabels = [candidateLabels
                                 sortedArrayUsingDescriptors:[NSArray arrayWithObject:sort]];
        resultsLabels.ViewToDraw = self.view;
        
        if ([sortedLabels count] > 0) {
            float certainityValue = [[sortedLabels[0] objectForKey:@"value"] floatValue];
            if (certainityValue == 1.0) {
                [videoPRocessing PauseAVCapture];
                resultsLabels.isFinalPredictions = YES;
                [self enableSharing];
                [resultsLabels drawFinalView:[sortedLabels[0] objectForKey:@"label"]];
                } else {
                [resultsLabels drawModelWith:sortedLabels];
            }
        } else {
            [resultsLabels drawModelWith:sortedLabels];
        }
    }];
}

// use front/back camera
- (IBAction)switchCameras:(id)sender {
    [videoPRocessing SwitchCamera];
}

//email feedback
- (IBAction)showEmail:(id)sender {
    
    PAIFeedback *feedbackModule = [[PAIFeedback alloc] init];
    feedbackModule.EmailSubject = @"Puppy.ai user feedback";
    feedbackModule.Email = @"getpuppyai@gmail.com";
    feedbackModule.ModelPredictions = resultsLabels.CleanedPredictions;
    feedbackModule.DogImage = dogImageView.image;
    feedbackModule.parentViewConstroller = self;
    if (resultsLabels.CleanedPredictions.count>1) {
        feedbackModule.ReportTemplate =
        @"<html>"
        @"<body>"
        @"<p>Hi puppy.ai team,</p>"
        @"<p>I have used your app to determine the breed of the dog shown below.</p>"
        @"<p>puppy.ai thinks that it is a %@ with %@ certainty or %@ with %@ certainty, but actually the dog breed is ...</p>"
        @"<p>%@ | %@ version: %@ | puppy.ai version: %@ | build: %@</p>"
        @"</body>"
        @"</html>";
        
    }
    else if (resultsLabels.CleanedPredictions.count==1) {
        feedbackModule.ReportTemplate =
        @"<html>"
        @"<body>"
        @"<p>Hi puppy.ai team,</p>"
        @"<p>I have used your app to determine the breed of the dog shown below.</p>"
        @"<p>puppy.ai thinks that it is a %@ with %@ certainty, but actually the dog breed is ...</p>"
        @"<p>%@ | %@ version: %@ | puppy.ai version: %@ | build: %@</p>"
        @"</body>"
        @"</html>";
    }
    else {
        feedbackModule.ReportTemplate =  @"<html>"
        @"<body>"
        @"<p>Hi puppy.ai team,</p>"
        @"<p>I have used your app to determine the breed of the dog shown below.</p>"
        @"<p>puppy.ai thinks that it is not a dog, but actually the dog breed is ...</p>"
        @"<p>%@ | %@ version: %@ | puppy.ai version: %@ | build: %@</p>"
        @"</body>"
        @"</html>";
    }
    
    [feedbackModule SendReport];
}

//sharing is caring
- (IBAction)share:(id)sender {
    
    for (UIView *subview in [dogImageView subviews]) {
        [subview removeFromSuperview];
    }

    resultsLabels.ViewToDraw = dogImageView;
    [resultsLabels drawModelForSharing];
    dogImageView.hidden = FALSE;
    PAIShare *sharingModule = [[PAIShare alloc] init];
    sharingModule.ParentViewController = self;
    sharingModule.ImageToShare = (UIImageView*)resultsLabels.ViewToDraw;
    sharingModule.Url = [[NSURL alloc] initWithString:@"https://puppyai.github.io"];
    [sharingModule share];
    dogImageView.hidden = TRUE;
}

//restart CNN and clean labels
- (IBAction)refresh:(id)sender {
    [videoPRocessing PauseAVCapture];
    [resultsLabels cleanAllLabels];
    [self restartCNN];
    [videoPRocessing ResumeAVCapture];
}

-(void) restartCNN {
    cNNRunner = nil;
    cNNRunner = [[PAICNNRunner alloc] init];
}

//standart overiddes
- (void)viewDidLoad {
    [super viewDidLoad];
    square = [[UIImage imageNamed:@"squarePNG"] retain];
    cNNRunner = [[PAICNNRunner alloc] init];
    resultsLabels = [[PAIResultLabels alloc] init];
    videoPRocessing = [[PAIVideoPRocessing alloc] init];
    videoPRocessing.ParentView = previewView;
    videoPRocessing.ParentViewController = self;
    [self setupAVCapture];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [videoPRocessing SetOrientation];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
    }];
}

- (void)dealloc {
    [self teardownAVCapture];
    [square release];
    [swapCameraButton release];
    [feedbackButton release];
    [shareButton release];
    [super dealloc];
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

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
}

@end
