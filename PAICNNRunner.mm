#import "PAICNNRunner.h"

@implementation PAICNNRunner
static NSString* model_file_name = @"mmapped_graph";  // optimized tf model
static NSString* model_file_type = @"pb"; // input type
static NSString* labels_file_name = @"retrained_labels";  // labels file
static NSString* labels_file_type = @"txt";


const bool model_uses_memory_mapping = true;
// These dimensions need to match those the model was trained with.
const int wanted_input_width = 299;
const int wanted_input_height = 299;
const int wanted_input_channels = 3;
const float input_mean = 128.0f;
const float input_std = 128.0f;
const std::string input_layer_name = "Mul";
const std::string output_layer_name = "final_result";
static NSMutableDictionary *oldPredictionValues = nil;
static NSMutableDictionary *labelCumSum = nil;
int missedFrames = 0; // n frames with low confidence



-(id)init
{
    self = [super init];
    oldPredictionValues = [[NSMutableDictionary alloc] init];
    labelCumSum = [[NSMutableDictionary alloc] init];

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

    
    return self;
}

-(void)dealloc
{
    [oldPredictionValues release];
    [labelCumSum release];
    [super dealloc];
}

- (void)redirectLogToDocuments 
{
     NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
     NSString *documentsDirectory = [allPaths objectAtIndex:0];
     NSString *pathForLog = [documentsDirectory stringByAppendingPathComponent:@"log.txt"];

     freopen([pathForLog cStringUsingEncoding:NSASCIIStringEncoding],"a+",stderr);
}

-(void)RunCNNWith:(CVPixelBufferRef)pixelBuffer AndCompletionHandler:(void(^)(NSArray*))handler
{
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
                _completionHandler = [handler copy];
                _completionHandler([self setPredictionValues:newValues]);
                
                // Clean up.
                [_completionHandler release];
                _completionHandler = nil;
            });
        }
    }
}

- (NSArray*)setPredictionValues:(NSDictionary *)newValues
{
        const int maxMissedFrames = 3;  // n consecutive frames with low
                                        // confidence to trigger reset
                                        // Note ~2.5 frames per second as of 8-2017
  
        // should sum to 1
        const float decayValue = 0.6f;  // low=fast decay
        const float updateValue = 0.4f; // low=slow increase
        const float minimumThreshold = 0.01f;
        const float minPredictionValue = 0.05f;
        
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
        bool DONE = false;
        NSArray *candidateLabels = [NSMutableArray array];
        for (NSString *label in oldPredictionValues) {
            NSNumber *oldPredictionValueObject =
            [oldPredictionValues objectForKey:label];
            float oldPredictionValue = [oldPredictionValueObject floatValue];
            if (oldPredictionValue > minPredictionValue) {
              
                // Track cumulative sum
                NSNumber *sumObj = [labelCumSum objectForKey:label];
                if (sumObj == nil) {
                  sumObj = [NSNumber numberWithFloat:0];
                  [labelCumSum setObject:oldPredictionValueObject forKey:label];
                } else if ([sumObj floatValue] > 2.5) {
                  oldPredictionValue = 1.0; // reset
                  oldPredictionValueObject = [NSNumber numberWithFloat:1.0];
//                  DONE = true;
                } else {
                  const float oldSum = [sumObj floatValue];
                  const float newSum = oldPredictionValue + oldSum;
                  sumObj = [NSNumber numberWithFloat:newSum];
                  [labelCumSum setObject:sumObj forKey:label];

                }
                NSLog(@", %@, %f, %@", label, oldPredictionValue, sumObj);
                NSDictionary *entry = @{
                                        @"label" : label,
                                        @"value" : oldPredictionValueObject
                                        };
                candidateLabels = [candidateLabels arrayByAddingObject:entry];
            }
        }
  
        // Reset sum if no labels are detected
        if ([candidateLabels count] == 0 && [labelCumSum count] > 0) {
          DONE = true;
        }
  
        if (DONE) {
          missedFrames += 1;
          NSLog(@"missed, %d, -1", missedFrames);
          if (missedFrames >= maxMissedFrames) { // reset cumSum
//            NSLog(@"\n\n\n------------------------------\nRESET\n\n\n\n");
            labelCumSum = [[NSMutableDictionary alloc] init];
            missedFrames = 0;
          }
        }
  
        // n_frames += 1
        return candidateLabels;
}

@end
