#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#include "tensorflow_utils.h"
#include <memory>
#include "tensorflow/core/public/session.h"
#include "tensorflow/core/util/memmapped_file_system.h"

@interface PAICNNRunner : NSObject
{
    std::unique_ptr<tensorflow::Session> tf_session;
    std::unique_ptr<tensorflow::MemmappedEnv> tf_memmapped_env;
    std::vector<std::string> labels;
    void (^_completionHandler)(NSArray* labels);
}

-(void)RunCNNWith:(CVPixelBufferRef)PixelBuffer AndCompletionHandler:(void(^)(NSArray*))handler;

@end
