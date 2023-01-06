//
//  VideoDisplayLayer.h
//  InteractiveScreen
//
//  Created by 刘川 on 2018/12/5.
//  Copyright © 2018 王楠. All rights reserved.
//

#warning 用来测试的视频渲染 - iOS12 之后已经废弃了 openGL ES; so...

#import <Foundation/Foundation.h>
#include <QuartzCore/QuartzCore.h>
#include <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoDisplayLayer : CAEAGLLayer

@property CVPixelBufferRef pixelBuffer;

- (id)initWithFrame:(CGRect)frame;

- (void)resetRenderBuffer;

@end

NS_ASSUME_NONNULL_END
