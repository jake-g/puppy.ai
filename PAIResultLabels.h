#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PAIVideoPRocessing.h"

@interface PAIResultLabels : NSObject
@property (retain) UIView* ViewToDraw;
@property (copy) NSMutableArray *CleanedPredictions;
@property (nonatomic) BOOL isFinalPredictions;

-(void) drawModelWith: (NSArray*)Predictions;
-(void) drawModelForSharing;
-(void) cleanAllLabels;
-(void) drawFinalView: (NSArray*)Predictions;
-(BOOL) isFinalPredictions;
@end
