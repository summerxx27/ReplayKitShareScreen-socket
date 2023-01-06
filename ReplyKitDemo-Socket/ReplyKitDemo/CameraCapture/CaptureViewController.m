//
//  CaptureViewController.m
//  ReplyKitDemo
//
//  Created by summerxx on 2022/12/30.
//

#import "CaptureViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "VideoH264EnCode.h"
#import "VideoDisplayLayer.h"
#import "VideoH264Decoder.h"

@interface CaptureViewController ()
<
AVCaptureVideoDataOutputSampleBufferDelegate,
AVCaptureAudioDataOutputSampleBufferDelegate,
VideoH264DecoderDelegate
>
{
    CGFloat _height;
}

// 数据采集以及编码
@property (nonatomic, strong) VideoH264EnCode *h264code;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput *currentVideoDeviceInput;
@property (nonatomic, strong) AVCaptureDeviceInput *currentaudioDeviceInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, weak)   AVCaptureVideoPreviewLayer *previedLayer;
@property (nonatomic, weak)   AVCaptureConnection *videoConnection;
@property (nonatomic, weak)   UIImageView *focusCursorImageView;

// 解码以及播放
@property (nonatomic, strong) VideoDisplayLayer *playLayer;
@property (nonatomic, strong) VideoH264Decoder *h264Decoder;

@end

@implementation CaptureViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    _height = 300;

    self.title = @"上采集/下解码播放";

    self.view.backgroundColor = [UIColor whiteColor];

    UIButton *toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    toggleButton.frame = CGRectMake(0, 0, 100, 100);
    toggleButton.backgroundColor = UIColor.cyanColor;
    [toggleButton setTitle:@"切换镜头" forState:UIControlStateNormal];
    [toggleButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [toggleButton addTarget:self action:@selector(toggleCapture) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:toggleButton];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    closeButton.frame = CGRectMake(UIScreen.mainScreen.bounds.size.width - 100, 0, 100, 100);
    closeButton.backgroundColor = UIColor.cyanColor;
    [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    [closeButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(closeAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeButton];

    [self setupCaputureVideo];

    [self setupDeCoder];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [_captureSession stopRunning];
    [_h264code endEncode];
}

#pragma 视频捕捉以及编码-------
// 捕获音视频
- (void)setupCaputureVideo
{

    // 1.创建捕获会话,必须要强引用，否则会被释放
    AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
    _captureSession = captureSession;

    // 1.1设置采集质量
    if ([captureSession canSetSessionPreset:AVCaptureSessionPresetiFrame1280x720]) {
        captureSession.sessionPreset = AVCaptureSessionPresetiFrame1280x720;
    }

    // 2.获取摄像头设备，默认是后置摄像头
    AVCaptureDevice *videoDevice = [self getVideoDevice:AVCaptureDevicePositionBack];

    // 3.获取声音设备
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];

    // 4.创建对应视频设备输入对象
    AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
    _currentVideoDeviceInput = videoDeviceInput;

    // 5.创建对应音频设备输入对象
    AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
    _currentaudioDeviceInput = audioDeviceInput;

    // 6.添加到会话中
    // 注意“最好要判断是否能添加输入，会话不能添加空的
    // 6.1 添加视频
    if ([captureSession canAddInput:videoDeviceInput]) {
        [captureSession addInput:videoDeviceInput];
    }
    // 6.2 添加音频
    if ([captureSession canAddInput:audioDeviceInput]) {
        [captureSession addInput:audioDeviceInput];
    }

    // 7.获取视频数据输出设备
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    _videoOutput = videoOutput;

    //  是否抛弃延迟的帧
    [videoOutput setAlwaysDiscardsLateVideoFrames: YES];

    // 7.1 设置代理，捕获视频样品数据
    // 注意：队列必须是串行队列，才能获取到数据，而且不能为空
    dispatch_queue_t videoQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
    [videoOutput setSampleBufferDelegate:self queue:videoQueue];
    if ([captureSession canAddOutput:videoOutput]) {
        [captureSession addOutput:videoOutput];
    }
    //  7.2设置采集格式
    videoOutput.videoSettings = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey];

    // 8.获取音频数据输出设备
    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    // 8.2 设置代理，捕获视频样品数据
    // 注意：队列必须是串行队列，才能获取到数据，而且不能为空
    dispatch_queue_t audioQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
    [audioOutput setSampleBufferDelegate:self queue:audioQueue];
    if ([captureSession canAddOutput:audioOutput]) {
        [captureSession addOutput:audioOutput];
    }

    // 9.获取视频输入与输出连接，用于分辨音视频数据
    _videoConnection = [videoOutput connectionWithMediaType:AVMediaTypeVideo];

    // 10. 设置方向
    [_videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];

    // 11.添加视频预览图层
    AVCaptureVideoPreviewLayer *previedLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];

    previedLayer.frame = CGRectMake(0, 100, self.view.bounds.size.width, _height);
    previedLayer.backgroundColor = [[UIColor blackColor] CGColor];
    [self.view.layer insertSublayer:previedLayer atIndex:0];
    _previedLayer = previedLayer;

    // 12.启动会话
    [captureSession startRunning];
}

// 指定摄像头方向获取摄像头
- (AVCaptureDevice *)getVideoDevice:(AVCaptureDevicePosition)position
{
    NSArray<AVCaptureDeviceType> *deviceTypes = @[
        AVCaptureDeviceTypeBuiltInWideAngleCamera,
        AVCaptureDeviceTypeBuiltInTrueDepthCamera,
        AVCaptureDeviceTypeBuiltInTelephotoCamera,
        AVCaptureDeviceTypeBuiltInDualCamera,
        AVCaptureDeviceTypeBuiltInMicrophone
    ];

    AVCaptureDeviceDiscoverySession *myDiscoverySesion = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes mediaType:AVMediaTypeVideo position:position];

    for (AVCaptureDevice *device in myDiscoverySesion.devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
// 获取输入设备数据，有可能是音频有可能是视频
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (_videoConnection == connection) {

        NSLog(@"采集到视频数据");

        // 进行视频编码
        __weak __typeof(self)weakSelf = self;
        [self.h264code encodeSampleBuffer:sampleBuffer H264DataBlock:^(NSData * data) {

            // 调用解码器解码,进行播放
            [weakSelf didReadData:data];
        }];

    } else {
        NSLog(@"采集到音频数据,暂不做处理");
    }
}

// 点击屏幕，出现聚焦视图
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    // 获取点击位置
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self.view];

    // 把当前位置转换为摄像头点上的位置
    CGPoint cameraPoint = [_previedLayer captureDevicePointOfInterestForPoint:point];

    // 设置聚焦点光标位置
    [self setFocusCursorWithPoint:point];

    // 设置聚焦
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}

/// 设置聚焦光标位置
/// - Parameter point: 光标位置
- (void)setFocusCursorWithPoint:(CGPoint)point
{
    self.focusCursorImageView.center = point;
    self.focusCursorImageView.transform = CGAffineTransformMakeScale(1.5, 1.5);
    self.focusCursorImageView.alpha = 1.0;
    [UIView animateWithDuration:1.0 animations:^{
        self.focusCursorImageView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self.focusCursorImageView.alpha = 0;
    }];
}

// 设置聚焦
-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point
{

    AVCaptureDevice *captureDevice = _currentVideoDeviceInput.device;
    // 锁定配置
    [captureDevice lockForConfiguration:nil];

    // 设置聚焦
    if ([captureDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
    }
    if ([captureDevice isFocusPointOfInterestSupported]) {
        [captureDevice setFocusPointOfInterest:point];
    }

    // 设置曝光
    if ([captureDevice isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
        [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
    }
    if ([captureDevice isExposurePointOfInterestSupported]) {
        [captureDevice setExposurePointOfInterest:point];
    }

    // 解锁配置
    [captureDevice unlockForConfiguration];
}

#pragma mark - 解码以及播放操作
- (void)setupDeCoder
{
    // 初始化解码器
    self.h264Decoder = [[VideoH264Decoder alloc]init];
    self.h264Decoder.delegate = self;
    [self setupDisplayLayer];
}

- (void)setupDisplayLayer
{
    self.playLayer = [[VideoDisplayLayer alloc] initWithFrame:CGRectMake(0, _height + 120, self.view.bounds.size.width, _height)];
    self.playLayer.backgroundColor = self.view.backgroundColor.CGColor;
    [self.view.layer addSublayer:self.playLayer];
}


#pragma mark - 获取数据进行解码
- (void)didReadData:(NSData *)data
{
    [self.h264Decoder decodeNalu:(uint8_t *)[data bytes] size:(uint32_t)data.length];
}

#pragma mark - VideoH264DecoderDelegate
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

#pragma mark - Action
// 切换摄像头
- (void)toggleCapture
{

    // 获取当前设备方向
    AVCaptureDevicePosition curPosition = _currentVideoDeviceInput.device.position;

    // 获取需要改变的方向
    AVCaptureDevicePosition togglePosition = curPosition == AVCaptureDevicePositionFront?AVCaptureDevicePositionBack:AVCaptureDevicePositionFront;

    // 获取改变的摄像头设备
    AVCaptureDevice *toggleDevice = [self getVideoDevice:togglePosition];

    // 获取改变的摄像头输入设备
    AVCaptureDeviceInput *toggleDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:toggleDevice error:nil];

    // 移除之前摄像头输入设备
    [_captureSession removeInput:_currentVideoDeviceInput];

    // 添加新的摄像头输入设备
    [_captureSession addInput:toggleDeviceInput];

    // 记录当前摄像头输入设备
    _currentVideoDeviceInput = toggleDeviceInput;

    // 9.获取视频输入与输出连接，用于分辨音视频数据
    _videoConnection = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];

    // 10. 设置方向
    [_videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
}

- (void)closeAction
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -

// 懒加载聚焦视图
- (UIImageView *)focusCursorImageView
{
    if (!_focusCursorImageView) {
        UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"focus"]];
        _focusCursorImageView = imageView;
        [self.view addSubview:_focusCursorImageView];
    }
    return _focusCursorImageView;
}

- (VideoH264EnCode *)h264code
{
    if (!_h264code) {
        _h264code = [[VideoH264EnCode alloc]init];
    }
    return _h264code;
}
@end

