//
//  Created by summerxx on 2022/12/30.
//

#import "VideoH264EnCode.h"
#import <VideoToolbox/VideoToolbox.h>
#import <UIKit/UIKit.h>

@interface VideoH264EnCode ()

// 编码会话
@property (nonatomic, assign) VTCompressionSessionRef compressionSession;

// 记录当前的帧数
@property (nonatomic, assign) NSInteger frameID;

// 编码回调
@property (nonatomic, copy) void (^h264DataBlock)(NSData *data);

@end

@implementation VideoH264EnCode

// 将 sampleBuffer(摄像头捕捉数据,原始帧数据) 编码为H.264
- (void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer H264DataBlock:(void (^)(NSData * _Nonnull))h264DataBlock
{
    
    if (!self.compressionSession) {
        return;
    }
    //  1.保存 block 块
    self.h264DataBlock = h264DataBlock;
    
    //  2.将sampleBuffer转成imageBuffer
    CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    
    //  3.根据当前的帧数,创建CMTime的时间
    CMTime presentationTimeStamp = CMTimeMake(self.frameID ++, 1000);

    VTEncodeInfoFlags flags;
    
    //  4.开始编码该帧数据
    OSStatus statusCode = VTCompressionSessionEncodeFrame(
                                                          self.compressionSession,
                                                          imageBuffer,
                                                          presentationTimeStamp,
                                                          kCMTimeInvalid,
                                                          NULL,
                                                          (__bridge void * _Nullable)(self),
                                                          &flags
                                                          );
    
    if (statusCode != noErr) {

        NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
//        VTCompressionSessionInvalidate(self.compressionSession);
//        CFRelease(self.compressionSession);
//        self.compressionSession = NULL;

        [self setupVideoSession];
        return;
    }
}

// 结束编码
- (void)endEncode
{
    VTCompressionSessionCompleteFrames(self.compressionSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(self.compressionSession);
    CFRelease(self.compressionSession);
    self.compressionSession = NULL;
}


- (instancetype)init
{
    if (self = [super init]) {
        // 初始化压缩编码的会话
        [self setupVideoSession];
    }
    return self;
}

// 初始化编码器
- (void)setupVideoSession {
    
    // 1.用于记录当前是第几帧数据
    self.frameID = 0;
    
    // 2.录制视频的宽度&高度,根据实际需求修改
    int width = 720;
    int height = 1280;
    
    // 3.创建CompressionSession对象,该对象用于对画面进行编码
    OSStatus status = VTCompressionSessionCreate(NULL,                   // 会话的分配器。传递NULL以使用默认分配器。
                                                 width,                  // 帧的宽度，以像素为单位。
                                                 height,                 // 帧的高度，以像素为单位。
                                                 kCMVideoCodecType_H264, // 编解码器的类型,表示使用h.264进行编码
                                                 NULL,                   // 指定必须使用的特定视频编码器。传递NULL让视频工具箱选择编码器。
                                                 NULL,                   // 源像素缓冲区所需的属性，用于创建像素缓冲池。如果不希望视频工具箱为您创建一个，请传递NULL
                                                 NULL,                   // 压缩数据的分配器。传递NULL以使用默认分配器。
                                                 didCompressH264,        // 当一次编码结束会在该函数进行回调,可以在该函数中将数据,写入文件中
                                                 (__bridge void *)(self),// outputCallbackRefCon
                                                 &_compressionSession);  // 指向一个变量以接收的压缩会话。
    if (status != 0){
        NSLog(@"H264: session 创建失败");
        return ;
    }
    
    // 4.设置实时编码输出（直播必然是实时输出,否则会有延迟）
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    
    // 5.设置关键帧（GOPsize)间隔
    int frameInterval = 60;
    CFNumberRef  frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
    
    // 6.设置期望帧率(每秒多少帧,如果帧率过低,会造成画面卡顿)
    int fps = 24;
    CFNumberRef fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
    
    // 7.设置码率(码率: 编码效率, 码率越高, 则画面越清晰, 如果码率较低会引起马赛克 --> 码率高有利于还原原始画面, 但是也不利于传输)
    int bitRate = width * height * 3 * 4 * 8;
    CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
    
    // 8.设置码率，均值，单位是byte 这是一个算法
    NSArray *limit = @[@(bitRate * 1.5 / 8), @(1)];
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
    
    // 9.基本设置结束, 准备进行编码
    VTCompressionSessionPrepareToEncodeFrames(_compressionSession);
}


// 编码完成回调
void didCompressH264(void *outputCallbackRefCon,
                     void *sourceFrameRefCon,
                     OSStatus status,
                     VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer)
{
    
    // 1.判断状态是否等于没有错误
    if (status != noErr) {
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    
    // 2.根据传入的参数获取对象
    VideoH264EnCode* encoder = (__bridge VideoH264EnCode*)outputCallbackRefCon;
    
    // 3.判断是否是关键帧
    bool isKeyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    // 判断当前帧是否为关键帧
    // 获取sps & pps数据
    if (isKeyframe) {
        // 获取编码后的信息（存储于CMFormatDescriptionRef中）
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        // 获取SPS信息
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        
        // 获取PPS信息
        size_t pparameterSetSize, pparameterSetCount;
        const uint8_t *pparameterSet;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
        
        // 装sps/pps转成NSData
        NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
        NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
        
        // 写入文件
        [encoder gotSpsPps:sps pps:pps];
    }
    
    // 获取数据块
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);

    if (statusCodeRet == noErr) {

        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4; // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        
        // 循环获取nalu数据
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            // Read the NAL unit length
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // 从大端转系统端
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            [encoder gotEncodedData:data isKeyFrame:isKeyframe];
            
            // 移动到写一个块，转成NALU单元
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}

// 获取 sps 以及 pps, 并进行StartCode
- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps
{
    
    // 拼接NALU的 StartCode,默认规定使用 00000001
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1;
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];

    NSMutableData *h264Data = [[NSMutableData alloc] init];
    [h264Data appendData:ByteHeader];
    [h264Data appendData:sps];

    if (self.h264DataBlock) {
        self.h264DataBlock(h264Data);
    }
    
    [h264Data resetBytesInRange:NSMakeRange(0, [h264Data length])];
    [h264Data setLength:0];
    [h264Data appendData:ByteHeader];
    [h264Data appendData:pps];

    if (self.h264DataBlock) {
        self.h264DataBlock(h264Data);
    }
}

- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
    const char bytes[] = "\x00\x00\x00\x01";
    // string literals have implicit trailing '\0'
    size_t length = (sizeof bytes) - 1;
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    
    NSMutableData *h264Data = [[NSMutableData alloc] init];
    [h264Data appendData:ByteHeader];
    [h264Data appendData:data];
    
    if (self.h264DataBlock) {
        self.h264DataBlock(h264Data);
    }
}

// 释放编码器
- (void)dealloc
{
    if (self.compressionSession) {
        VTCompressionSessionInvalidate(self.compressionSession);
        CFRelease(self.compressionSession);
        self.compressionSession = NULL;
    }
}

@end

