//
//  FJDeepSleepPreventer.m
//  PlaySilentMusicInBackgroundMode
//
//  Created by FJ on 2020/1/22.
//  Copyright © 2020 FJ. All rights reserved.
//

#import "FJDeepSleepPreventer.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIApplication.h>

@interface FJDeepSleepPreventer ()
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@end

@implementation FJDeepSleepPreventer

#pragma mark - life cycle

+ (instancetype)sharedInstance {
    static FJDeepSleepPreventer *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [FJDeepSleepPreventer new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    [self setupAudioSession];
    [self setupAudioPlayer];
}

- (void)setupAudioSession {
    // 新建AudioSession会话
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    // 设置后台播放
    NSError *error = nil;
    [audioSession setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&error];
    if (error) {
        NSLog(@"Error setCategory AVAudioSession: %@", error);
    }
    NSLog(@"%d", audioSession.isOtherAudioPlaying);
    NSError *activeSetError = nil;
    // 启动AudioSession，如果一个前台app正在播放音频则可能会启动失败
    [audioSession setActive:YES error:&activeSetError];
    if (activeSetError) {
        NSLog(@"Error activating AVAudioSession: %@", activeSetError);
    }
}

- (void)setupAudioPlayer {
    //静音文件
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Silence" ofType:@"wav"];
    NSURL *fileURL = [[NSURL alloc] initFileURLWithPath:filePath];
    
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:nil];
    //静音
    self.audioPlayer.volume = 0;
    //循环播放
    self.audioPlayer.numberOfLoops = -1;
    [self.audioPlayer prepareToPlay];
}

#pragma mark - public method

- (void)start {
    [self.audioPlayer play];
}

- (void)stop {
    [self.audioPlayer stop];
}

@end
