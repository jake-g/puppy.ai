#import "PAIResultLabels.h"

@implementation PAIResultLabels
const int n_labels = 1; // number of labels to show
const float colMargin = 0;
const float rowMargin = 0;
const float rowHeight = 26.0f;  // header, label and value height
const float entryMargin = rowMargin + rowHeight;
const float fontSize = 16.0f;
const float valueWidth = 100.0f;
const float labelWidth = 2000.0f;
NSString *defaultLabelFont = @"Helvetica Neue-Regular";
NSString *BoldLabelFont = @"Helvetica-Bold";
NSString *DogBreedColumnName = @"Dog Breed";
NSString *LikelihoodColumnName = @"Likelihood";
NSMutableArray *labelLayers;

-(id)init
{
    self = [super init];
    labelLayers = [[NSMutableArray alloc] init];
    _CleanedPredictions = [[NSMutableArray alloc] init];
    return self;
}

-(void) drawModelWith: (NSMutableArray*)Predictions
{
    if ([Predictions count] > 0) {
        [self removeAllLabelLayers];
        int labelCount = 0;
        [self drawPredictions:labelCount Predictions:Predictions];

    }
    else {    // No dog detected
        [self removeAllLabelLayers];
        [self addLabelToViewLeftCorner:self.ViewToDraw label:@"Point camera at a dog..."];
    }
}

- (void)removeAllLabelLayers {
    for (CATextLayer *layer in labelLayers) {
        [layer removeFromSuperlayer];
    }
    [labelLayers removeAllObjects];
}

-(void) drawModelForSharing
{
    if (self.CleanedPredictions.count==2) {
        [self addHeaderToView:self.ViewToDraw];
        [self addLabelsToView:self.ViewToDraw label:self.CleanedPredictions[0][0] value:self.CleanedPredictions[0][1]  count:0];
        [self addLabelsToView:self.ViewToDraw label:self.CleanedPredictions[1][0] value:self.CleanedPredictions[1][1]  count:1];
    } else {
        [self addLabelToViewLeftCorner:self.ViewToDraw label:@"There are no dog detected"];
    }
    [self addFooterToView:self.ViewToDraw value:@"You can do it too. Discover any dog's breed: https://puppyai.github.io"];
}

- (void)drawPredictions:(int)labelCount Predictions:(NSMutableArray *)Predictions
{
    for (NSDictionary *entry in Predictions) {
        
        // Add header
        if (labelCount == 0) {
            [self.CleanedPredictions removeAllObjects];
            [self addHeaderToView:self.ViewToDraw];
        }
        
        // Add label entry
        NSString *label = [entry objectForKey:@"label"];
        NSNumber *valueObject = [entry objectForKey:@"value"];
        const float value = [valueObject floatValue];
        
        const int valuePercentage = (int)roundf(value * 100.0f);
        if (valuePercentage == 100) {
          [self addPredictionToView:self.ViewToDraw label:label];
        } else {
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
    
    [self addLabelLayerWithText: DogBreedColumnName
                           font:BoldLabelFont
                        originX:breedOriginX
                        originY:rowMargin
                          width:labelWidth
                         height:rowHeight
                       fontSize:fontSize
                      alignment:kCAAlignmentLeft
                           view:view];
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

-(void)addPredictionToView:(UIView*) view
                 label:(NSString*) label

{
    [self addLabelLayerWithText:[label capitalizedString]
                           font:defaultLabelFont
                        originX:colMargin
                        originY:entryMargin + rowHeight
                          width:labelWidth
                         height:rowHeight
                       fontSize:20
                      alignment:kCAAlignmentCenter
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
