#import "VideoWatermark.h"
#import <AVFoundation/AVFoundation.h>

@implementation VideoWatermark

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(convert:(NSString *)videoUri imageUri:(nonnull NSString *)imageUri markerScale:(CGFloat)markerScale callback:(RCTResponseSenderBlock)callback)
{
    [self watermarkVideoWithImage:videoUri imageUri:imageUri markerScale:markerScale callback:callback];
}

-(void)watermarkVideoWithImage:(NSString *)videoUri imageUri:(NSString *)imageUri markerScale:(CGFloat)markerScale callback:(RCTResponseSenderBlock)callback
{
    AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:[NSURL fileURLWithPath:videoUri] options:nil];
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVAssetTrack *clipVideoTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    AVMutableCompositionTrack *compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    AVAssetTrack *clipAudioTrack = [[videoAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) ofTrack:clipVideoTrack atTime:kCMTimeZero error:nil];
    [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) ofTrack:clipAudioTrack atTime:kCMTimeZero error:nil];
    
    CGSize sizeOfVideo = CGSizeApplyAffineTransform(clipVideoTrack.naturalSize, clipVideoTrack.preferredTransform);
    sizeOfVideo.width = fabs(sizeOfVideo.width);
    sizeOfVideo.height = fabs(sizeOfVideo.height);
    
    // Adjust the orientation of the watermark image
    UIImage *myImage=[UIImage imageWithContentsOfFile:imageUri];
    
    CALayer *layerCa = [CALayer layer];
    layerCa.contents = (id)myImage.CGImage;
    layerCa.opacity = 1.0;
    
    CALayer *parentLayer = [CALayer layer];
    CALayer *videoLayer = [CALayer layer];
    [parentLayer addSublayer:videoLayer];
    [parentLayer addSublayer:layerCa];
    
    layerCa.frame = CGRectMake(0, 0, sizeOfVideo.width, sizeOfVideo.height);
    parentLayer.frame = CGRectMake(0, 0, sizeOfVideo.width, sizeOfVideo.height);
    videoLayer.frame = CGRectMake(0, 0, sizeOfVideo.width, sizeOfVideo.height);
    
    // Apply transformations directly to the video
    CGAffineTransform videoTransform = CGAffineTransformIdentity;
    CGAffineTransform trackTransform = clipVideoTrack.preferredTransform;

    // Identify the video orientation and apply the appropriate rotation
    if (trackTransform.a == 0 && trackTransform.b == -1.0 && trackTransform.c == 1.0 && trackTransform.d == 0) {
        // 90 degrees clockwise rotation
        videoTransform = CGAffineTransformMakeRotation(-M_PI_2);
        videoTransform = CGAffineTransformTranslate(videoTransform, -sizeOfVideo.height, 0);
    } else if (trackTransform.a == -1.0 && trackTransform.b == 0 && trackTransform.c == 0 && trackTransform.d == -1.0) {
        // 180 degrees rotation
        videoTransform = CGAffineTransformMakeRotation(M_PI);
        videoTransform = CGAffineTransformTranslate(videoTransform, -sizeOfVideo.width, -sizeOfVideo.height);
    } else if (trackTransform.a == 0 && trackTransform.b == 1.0 && trackTransform.c == -1.0 && trackTransform.d == 0) {
        // 90 degrees counterclockwise rotation
        videoTransform = CGAffineTransformMakeRotation(M_PI_2);
        videoTransform = CGAffineTransformTranslate(videoTransform, 0, -sizeOfVideo.width);
    }

    // Create the instruction to apply the transformation to the video
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, [mixComposition duration]);

    AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTrack];
    [layerInstruction setTransform:videoTransform atTime:kCMTimeZero];
    instruction.layerInstructions = @[layerInstruction];
    
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.instructions = @[instruction];
    videoComposition.frameDuration = CMTimeMake(1, 30);
    
    videoComposition.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
    videoComposition.renderSize = sizeOfVideo;

    // Export the video with the applied rotation
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
    NSString *destinationPath = [documentsDirectory stringByAppendingFormat:@"/output_%@.mp4", [dateFormatter stringFromDate:[NSDate date]]];
    
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    exportSession.videoComposition = videoComposition;
    exportSession.outputURL = [NSURL fileURLWithPath:destinationPath];
    exportSession.outputFileType = AVFileTypeMPEG4;
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        switch (exportSession.status) {
            case AVAssetExportSessionStatusCompleted:
                NSLog(@"Export OK");
                callback(@[destinationPath]);
                break;
            case AVAssetExportSessionStatusFailed:
                NSLog(@"AVAssetExportSessionStatusFailed: %@", exportSession.error);
                break;
            case AVAssetExportSessionStatusCancelled:
                NSLog(@"Export Cancelled");
                break;
            default:
                break;
        }
    }];
}


@end
