#import "PAIResultLabels.h"

@implementation PAIResultLabels
const int n_labels = 3; // number of labels to show
const float colMargin = 0;
const float rowMargin = 0;
const float rowHeight = 26.0f;  // header, label and value height
const float entryMargin = rowMargin + rowHeight;
const float fontSize = 16.0f;
const float valueWidth = 100.0f;
float labelWidth;

const float finalFontSize = 2*fontSize;  // larger
const float finalValueMargin = 0.5f; // more room for label
const float finalRowHeight = 2*rowHeight;  // header, label and value height

NSString *defaultLabelFont = @"Helvetica Neue-Regular";
NSString *BoldLabelFont = @"Helvetica-Bold";
NSString *DogBreedColumnName = @"Dog Breed";
NSString *LikelihoodColumnName = @"Likelihood";

NSString *pointCamera = @"Point camera at a dog...";
NSMutableArray *labelLayers;

-(id)init
{
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    labelWidth = screenRect.size.width;
    self = [super init];
    labelLayers = [[NSMutableArray alloc] init];
    _CleanedPredictions = [[NSMutableArray alloc] init];
    return self;
}


-(void) drawModelWith: (NSMutableArray*)Predictions
{
    if (self.isFinalPredictions == NO) {
        if ([Predictions count] > 0) {
            [self removeAllLabelLayers];
            int labelCount = 0;
            [self drawPredictions:labelCount Predictions:Predictions];
        }
        else {    // No dog detected
            [self removeAllLabelLayers];
            [self addLabelToViewLeftCorner:self.ViewToDraw label:pointCamera];
        }
    }
}

- (void)removeAllLabelLayers {
    for (CATextLayer *layer in labelLayers) {
        [layer removeFromSuperlayer];
    }
    [labelLayers removeAllObjects];
}

-(void) cleanAllLabels
{
    [self.CleanedPredictions removeAllObjects];
    [self removeAllLabelLayers];
    [self addLabelToViewLeftCorner:self.ViewToDraw label:pointCamera];
}

-(void) drawModelForSharing
{
    if (self.isFinalPredictions) {
        [self addFinalPredictionToView:self.ViewToDraw label:self.CleanedPredictions[0][0]];
    } else if (self.CleanedPredictions.count>0) {
        [self addHeaderToView:self.ViewToDraw];
        int labelCounter = 0;
        for (NSArray *entry in self.CleanedPredictions) {
            [self addLabelsToView:self.ViewToDraw label: entry[0] value: entry[1]  count:labelCounter];
            ++labelCounter;
        }
    } else {
        [self addLabelToViewLeftCorner:self.ViewToDraw label:@"There are no dog detected"];
    }
    [self addFooterToView:self.ViewToDraw value:@"You can do it too. Discover any dog's breed: https://puppyai.github.io"];
}

-(void) drawFinalView: (NSString*)Prediction
{
    [self removeAllLabelLayers];
    [self addFinalPredictionToView:self.ViewToDraw label:Prediction];
}

- (void)drawPredictions:(int)labelCount Predictions:(NSMutableArray *)Predictions
{
    for (NSDictionary *entry in Predictions) {
      
      
        // Get label entry
        NSString *label = [entry objectForKey:@"label"];
        NSNumber *valueObject = [entry objectForKey:@"value"];
        const float value = [valueObject floatValue];
        const int valuePercentage = (int)roundf(value * 100.0f);
      
        // Display current prediction
        // Add header
        if (labelCount == 0) {
            [self.CleanedPredictions removeAllObjects];
            [self addHeaderToView:self.ViewToDraw];
        }

        NSString *valueText = [NSString stringWithFormat:@"%d%%", valuePercentage];
        NSArray *prediction = [[NSArray alloc] initWithObjects:label,valueText,nil];
        [self.CleanedPredictions addObject:prediction];
        [self addLabelsToView:self.ViewToDraw label:label value:valueText count:labelCount];
        
        // Limit # labels to display
        labelCount += 1;
        if (labelCount > n_labels) {
            break;
        }
    }
}

-(void)addHeaderToView:(UIView*)view {
    [self addLabelLayerWithText: LikelihoodColumnName
                           font:BoldLabelFont
                        originX:colMargin
                        originY:rowMargin
                          width:valueWidth
                         height:rowHeight
                       fontSize:fontSize
                      alignment:kCAAlignmentRight
                           view:view];
    
    const float breedOriginX = (colMargin + valueWidth + colMargin);
    
    [self addLabelLayerWithText:DogBreedColumnName
                           font:BoldLabelFont
                        originX:breedOriginX
                        originY:rowMargin
                          width:labelWidth
                         height:rowHeight
                       fontSize:fontSize
                      alignment:kCAAlignmentLeft
                           view:view];
}

-(void)addFinalPredictionToView:(UIView*)view
                          label:(NSString*) label
{   // Displays when final prediction is decided
    // Spacer...TODO better way to do this
    [self addLabelLayerWithText:[label capitalizedString]
                           font:BoldLabelFont
                        originX:finalValueMargin
                        originY:rowMargin
                          width:labelWidth
                         height:finalRowHeight
                       fontSize:finalFontSize
                      alignment:kCAAlignmentCenter
                           view:view];
}

-(void) addLabelToViewLeftCorner:(UIView*) view
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
                        originX: view.frame.size.width - 315.00f
                        originY: view.frame.size.height - rowHeight
                          width:labelWidth
                         height:18.00f
                       fontSize:10.00f
                      alignment:kCAAlignmentLeft
                           view:view];
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

@end
