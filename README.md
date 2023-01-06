# ReplayKitShareScreen-socket
使用replayKit iOS12 之后相关 api 完成系统/app 内 屏幕采集直播视频数据, 采用 socket进行进程间Broadcast Unload Extension 向 宿主 app 传输数据, 后台保活持续采集屏幕数据, 摄像头采集, 数据编码解码

编译环境 Xcode14.2, iOS12

- 系统屏幕数据采集
- app 内屏幕共享
- 使用socket 由 Broadcast Unload Extension 向宿主 app 传输数据
- 视频解码
- 程序永久保活
- 创建 framework 供 Broadcast Unload Extension 和宿主 app 调用共用类

[TOC]

### 1. 第一步创建 Broadcast Unload Extension

步骤:  File -> new -> Target

![截屏2023-01-06 17.39.39](https://p.ipic.vip/hq1jyl.png)

创建好之后生成 一个扩展 App, 自动生成如图的一个 sampleHandr类

![截屏2023-01-06 17.41.55](https://p.ipic.vip/pai0gm.png)

```objective-c
- (void)broadcastStartedWithSetupInfo:(NSDictionary<NSString *,NSObject *> *)setupInfo {
    // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
  	// 宿主 app开始直播屏幕的时候这里会走一次
  	// 设置 socket
  	// 其中 FIAgoraSampleHandlerSocketManager这个类可以看 Demo 的实现
    [[FIAgoraSampleHandlerSocketManager sharedManager] setUpSocket];
}

- (void)broadcastPaused {
    // User has requested to pause the broadcast. Samples will stop being delivered.
}

- (void)broadcastResumed {
    // User has requested to resume the broadcast. Samples delivery will resume.
}

- (void)broadcastFinished {
    // User has requested to finish the broadcast.
}

// 实时采集数据
- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(RPSampleBufferType)sampleBufferType {

    switch (sampleBufferType) {
        case RPSampleBufferTypeVideo:
            // Handle video sample buffer
        		// 发送视频数据导宿主 App
            [[FIAgoraSampleHandlerSocketManager sharedManager] sendVideoBufferToHostApp:sampleBuffer];
            break;
        case RPSampleBufferTypeAudioApp:
            // Handle audio sample buffer for app audio
            break;
        case RPSampleBufferTypeAudioMic:
            // Handle audio sample buffer for mic audio
            break;

        default:
            break;
    }
}

```

### 2.  FIAgoraSampleHandlerSocketManager 关于数据传输的类 都放到一个framework 当中

- 步骤:  File -> new -> Target 创建 framework, 如图 1
- 创建好之后在宿主 app 和 extension 分别引用, 如图 2



![截屏2023-01-06 17.46.46](https://p.ipic.vip/e860da.png)

![1672998592654](https://p.ipic.vip/14zjj6.jpg)

### 3. 宿主 App 

- 手动启动直播
- 需要永久保活
- 监测数据回调
- 编码
- 推流

1. 初始化开启直播的按钮

```objective-c
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
		// 改变系统提供的按钮的 UI, 这里有个风险, 以后可能会失效, 暂时用没有什么问题
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeCustom];
    startButton.frame = CGRectMake(50, 310, 100, 100);
    startButton.backgroundColor = UIColor.cyanColor;
    [startButton setTitle:@"开启摄像头" forState:UIControlStateNormal];
    [startButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(startAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:startButton];
}
```

2. 保活

![截屏2023-01-06 17.57.10](https://p.ipic.vip/cw7kcy.png)

```objective-c
监听
[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(didEnterBackGround) name:UIApplicationDidEnterBackgroundNotification object:nil];
[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(willEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];

- (void)willEnterForeground
{
  	// 这里具体可看 Demo
    [[FJDeepSleepPreventerPlus sharedInstance] stop];
}

- (void)didEnterBackGround
{
    [[FJDeepSleepPreventerPlus sharedInstance] start];
}
```

3. 数据回调

```objective-c
    __weak __typeof(self) weakSelf = self;
    [FIAgoraClientBufferSocketManager sharedManager].testBlock = ^(NSString * testText, CMSampleBufferRef sampleBuffer) {
        
        // 进行视频编码
        [weakSelf.h264code encodeSampleBuffer:sampleBuffer H264DataBlock:^(NSData * data) {
            NSLog(@"%@", data);
          	// 编码后可进行推流流程
        }];
    };
```

