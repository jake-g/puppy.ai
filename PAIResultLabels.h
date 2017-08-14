#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PAIResultLabels : NSObject
@property (retain) UIView* ViewToDraw;
@property (copy) NSMutableArray *CleanedPredictions;
-(void) drawModelWith: (NSArray*)Predictions;
-(void) drawModelForSharing;
@end
