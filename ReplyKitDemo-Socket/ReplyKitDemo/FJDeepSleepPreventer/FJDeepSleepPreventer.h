//
//  FJDeepSleepPreventer.h
//  PlaySilentMusicInBackgroundMode
//
//  Created by FJ on 2020/1/22.
//  Copyright © 2020 FJ. All rights reserved.
//  进入后台模式调用start方法开始播放无声音乐,返回前台调用stop方法停止播放(这种方法需要一直播放无声音乐保持后台,比较耗电)

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FJDeepSleepPreventer : NSObject
+ (instancetype)sharedInstance;
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
