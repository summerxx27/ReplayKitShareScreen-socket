//
//  Created by summerxx on 2022/12/30.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

@class VideoH264Decoder;

@protocol VideoH264DecoderDelegate <NSObject>

@optional
- (void)decoder:(VideoH264Decoder *)decoder didDecodingFrame:(CVImageBufferRef)imageBuffer;

@end

@interface VideoH264Decoder : NSObject

@property (nonatomic, weak) id<VideoH264DecoderDelegate> delegate;

//  解码NALU
- (void)decodeNalu:(uint8_t *)frame size:(uint32_t)frameSize;

@end

