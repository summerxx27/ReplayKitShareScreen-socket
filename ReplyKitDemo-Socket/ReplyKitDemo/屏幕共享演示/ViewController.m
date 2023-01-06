//
//  ViewController.m
//  screen-share-ios
//
//  Created by summerxx on 2022/12/28.
//

#import "ViewController.h"
#import <ReplayKit/ReplayKit.h>
#import "FIAgoraClientBufferSocketManager.h"
#import <VideoToolbox/VideoToolbox.h>
#import "CaptureViewController.h"
#import "VideoH264EnCode.h"
#import "VideoH264Decoder.h"
#import "VideoDisplayLayer.h"
#import "FJDeepSleepPreventer.h"
#import "FJDeepSleepPreventerPlus.h"

@interface ViewController ()<VideoH264DecoderDelegate>

@property (nonatomic, strong) RPSystemBroadcastPickerView *broadcastPickerView;

// 编码
@property (nonatomic, strong) VideoH264EnCode *h264code;

// 解码以及播放
@property (nonatomic, strong) VideoDisplayLayer *playLayer;
@property (nonatomic, strong) VideoH264Decoder *h264Decoder;

@property (nonatomic, assign) UIBackgroundTaskIdentifier backIden;

@end

@implementation ViewController

- (void)viewDidLoad
{
    self.navigationItem.title = @"DEMO";
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor orangeColor];
    [self setupSocket];
    [self setupDeCoder];
    [self setupSystemBroadcastPickerView];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(didEnterBackGround) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(willEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)willEnterForeground
{
    [[FJDeepSleepPreventerPlus sharedInstance] stop];
}

- (void)didEnterBackGround
{
    [[FJDeepSleepPreventerPlus sharedInstance] start];
}

- (void)setupSocket
{
    [[FIAgoraClientBufferSocketManager sharedManager] setupSocket];

    UILabel *label = [UILabel new];
    label.backgroundColor = UIColor.cyanColor;
    label.frame = CGRectMake(0, 100, [UIScreen mainScreen].bounds.size.width, 30);
    label.textColor = [UIColor blackColor];
    [self.view addSubview:label];

    __weak __typeof(self)weakSelf = self;
    [FIAgoraClientBufferSocketManager sharedManager].testBlock = ^(NSString * testText, CMSampleBufferRef sampleBuffer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [label setText:testText];
        });

        // 进行视频编码
        [weakSelf.h264code encodeSampleBuffer:sampleBuffer H264DataBlock:^(NSData * data) {
            NSLog(@"%@", data);
//            [weakSelf didReadData:data];
        }];
    };
}

// 设置系统的广播 Picker 视图
- (void)setupSystemBroadcastPickerView
{
    // 兼容 iOS12 或更高的版本
    if (@available(iOS 12.0, *)) {
        self.broadcastPickerView = [[RPSystemBroadcastPickerView alloc] initWithFrame:CGRectMake(50, 200, 100, 100)];
        self.broadcastPickerView.preferredExtension = @"summerxx.com.screen-share-ios.broadcast-extension";
        self.broadcastPickerView.backgroundColor = UIColor.cyanColor;
        self.broadcastPickerView.showsMicrophoneButton = NO;
        [self.view addSubview:self.broadcastPickerView];
    }

    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeCustom];
    startButton.frame = CGRectMake(50, 310, 100, 100);
    startButton.backgroundColor = UIColor.cyanColor;
    [startButton setTitle:@"开启摄像头" forState:UIControlStateNormal];
    [startButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(startAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:startButton];
}

- (void)startAction
{
    CaptureViewController *vc =  [CaptureViewController new];
    [self presentViewController:vc animated:YES completion:nil];
}

#pragma mark - 编码
- (VideoH264EnCode *)h264code
{
    if (!_h264code) {
        _h264code = [[VideoH264EnCode alloc]init];
    }
    return _h264code;
}

#pragma 解码以及播放操作--------------------
- (void)setupDeCoder
{
    // 初始化解码器
    self.h264Decoder = [[VideoH264Decoder alloc]init];
    self.h264Decoder.delegate = self;
    [self setupDisplayLayer];
}

- (void)setupDisplayLayer
{
    self.playLayer = [[VideoDisplayLayer alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 300, self.view.bounds.size.width, 300)];
    self.playLayer.backgroundColor = self.view.backgroundColor.CGColor;
    [self.view.layer addSublayer:self.playLayer];
}

// 获取数据进行解码
- (void)didReadData:(NSData *)data
{
    [self.h264Decoder decodeNalu:(uint8_t *)[data bytes] size:(uint32_t)data.length];
}

// 解码完成回调
- (void)decoder:(VideoH264Decoder *)decoder didDecodingFrame:(CVImageBufferRef)imageBuffer
{
    if (!imageBuffer) {
        return;
    }
    // 回主线程给 layer 进行展示
    dispatch_async(dispatch_get_main_queue(), ^{
        self.playLayer.pixelBuffer = imageBuffer;
        CVPixelBufferRelease(imageBuffer);
    });
}

@end
