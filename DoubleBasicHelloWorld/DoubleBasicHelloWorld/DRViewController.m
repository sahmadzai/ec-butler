//
//  DRViewController.m
//  DoubleBasicHelloWorld
//
//  Created by David Cann on 8/3/13.
//  Copyright (c) 2013 Double Robotics, Inc. All rights reserved.
//

#import "DRViewController.h"
#import <DoubleControlSDK/DoubleControlSDK.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreML/CoreML.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Vision/Vision.h>

#import "MobileNetV2FP16.h"

@interface DRViewController () <DRDoubleDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) DRDouble *theDouble;
@property (nonatomic, assign) CGFloat filteredLeftEncoder;
@property (nonatomic, assign) CGFloat filteredRightEncoder;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) VNCoreMLRequest *objectDetectionRequest;
@property (nonatomic, strong) VNImageRequestHandler *objectDetectionRequestHandler;
@property (nonatomic, assign) NSTimeInterval lastClassificationTimestamp;
@property (nonatomic, strong) MobileNetV2FP16 *model;

@end

@implementation DRViewController

// Constants for filter adjustment (tweak as needed)
static const CGFloat kFilterFactor = 0.8;
static const CGFloat kInitialEncoderValue = 0.0;

bool autostatus = NO;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.theDouble = [DRDouble sharedDouble];
    self.theDouble.delegate = self;
    
    self.lastClassificationTimestamp = 0;
    
    self.model = [[MobileNetV2FP16 alloc] init];

    VNCoreMLModel *coreMLModel = [VNCoreMLModel modelForMLModel:self.model.model error:nil];

    VNCoreMLRequest *objectDetectionRequest = [[VNCoreMLRequest alloc] initWithModel:coreMLModel completionHandler:^(VNRequest *request, NSError *error) {
        [self handleObjectDetectionResults:request.results];
    }];
    objectDetectionRequest.imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop;
    
    // Create a new CVPixelBuffer
    CVPixelBufferRef pixelBuffer;
    
    // Create the pixel buffer pool attributes
     NSDictionary *pixelBufferPoolAttributes = @{
         (NSString *)kCVPixelBufferPoolMinimumBufferCountKey: @(1)
     };
    
    // Create the pixel buffer pool
    CVPixelBufferPoolRef pixelBufferPool;
    CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef)pixelBufferPoolAttributes, &pixelBufferPool);

    // Create the pixel buffer from the pixel buffer pool
    CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBuffer);

    // Release the pixel buffer pool
    CVPixelBufferPoolRelease(pixelBufferPool);

    // Set the pixel buffer to the object detection request handler
    self.objectDetectionRequestHandler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer options:@{}];

    self.objectDetectionRequest = objectDetectionRequest;

    self.filteredLeftEncoder = kInitialEncoderValue;
    self.filteredRightEncoder = kInitialEncoderValue;
    NSLog(@"SDK Version: %@", kDoubleBasicSDKVersion);
    NSLog(@"Starting camera capture...");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startCameraCapture];
}

- (void)startCameraCapture {
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;

    AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                                                                                                              mediaType:AVMediaTypeVideo
                                                                                                               position:AVCaptureDevicePositionFront];
    NSArray *devices = discoverySession.devices;

    if (devices.count > 0) {
        AVCaptureDevice *videoDevice = devices.firstObject;
        NSError *error;
        AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];

        if (!error) {
            if ([self.captureSession canAddInput:videoInput]) {
                [self.captureSession addInput:videoInput];

                AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
                [videoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];

                if ([self.captureSession canAddOutput:videoOutput]) {
                    [self.captureSession addOutput:videoOutput];
                    NSLog(@"Camera capture started successfully.");

                    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
                    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
                    self.previewLayer.frame = imageView.bounds;

                    CALayer *imageViewLayer = imageView.layer;
                    [imageViewLayer insertSublayer:self.previewLayer atIndex:0];

                    [self.captureSession startRunning];
                }
            }
        } else {
            NSLog(@"Error creating video input: %@", error.localizedDescription);
        }
    } else {
        NSLog(@"Front video device not found");
    }
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - Actions

- (IBAction)poleUp:(id)sender {
    [[DRDouble sharedDouble] poleUp];
}

- (IBAction)poleStop:(id)sender {
    [[DRDouble sharedDouble] poleStop];
}

- (IBAction)poleDown:(id)sender {
    [[DRDouble sharedDouble] poleDown];
}

- (IBAction)kickstandsRetract:(id)sender {
    [[DRDouble sharedDouble] retractKickstands];
}

- (IBAction)kickstandsDeploy:(id)sender {
    [[DRDouble sharedDouble] deployKickstands];
}

- (IBAction)startTravelData:(id)sender {
    [[DRDouble sharedDouble] startTravelData];
}

- (IBAction)stopTravelData:(id)sender {
    [[DRDouble sharedDouble] stopTravelData];
}

- (IBAction)headPowerOn:(id)sender {
    [[DRDouble sharedDouble] headPowerOn];
}

- (IBAction)headPowerOff:(id)sender {
    [[DRDouble sharedDouble] headPowerOff];
}

- (IBAction)startAutoMode:(id)sender {
    if (self.theDouble.kickstandState == 1) {
        [self.theDouble retractKickstands];
    }
    
    autostatus = YES;
    
    float desiredDistance = 32.0;
    float constantSpeed = 12;
    NSTimeInterval duration = desiredDistance / constantSpeed;
    
    [self.theDouble drive:kDRDriveDirectionForward turn:0.0];
    
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:duration target:self selector:@selector(stopMovingForward:) userInfo:@{@"duration": @(duration)} repeats:YES];
    
    [self printTimerCountdown:timer];
}

- (IBAction)stopAutoMode:(id)sender {
    [self.theDouble drive:kDRDriveDirectionStop turn:0.0];
    autostatus = NO;
}

#pragma mark - DRDoubleDelegate

- (void)stopMovingForward:(NSTimer *)timer {
    [self.theDouble drive:kDRDriveDirectionStop turn:0.0];
    [timer invalidate];
    autostatus = NO;
}

- (void)printTimerCountdown:(NSTimer *)timer {
    NSTimeInterval duration = [timer.userInfo[@"duration"] doubleValue];
    NSTimeInterval remainingTime = timer.fireDate.timeIntervalSinceNow;
    NSLog(@"Timer Countdown: %.1f seconds remaining (out of %.1f seconds)", remainingTime, duration);
}

- (void)doubleDidConnect:(DRDouble *)theDouble {
    statusLabel.text = @"Connected";
}

- (void)doubleDidDisconnect:(DRDouble *)theDouble {
    statusLabel.text = @"Not Connected";
}

- (void)doubleStatusDidUpdate:(DRDouble *)theDouble {
    poleHeightPercentLabel.text = [NSString stringWithFormat:@"%f", [DRDouble sharedDouble].poleHeightPercent];
    kickstandStateLabel.text = [NSString stringWithFormat:@"%d", [DRDouble sharedDouble].kickstandState];
    batteryPercentLabel.text = [NSString stringWithFormat:@"%f", [DRDouble sharedDouble].batteryPercent];
    batteryIsFullyChargedLabel.text = [NSString stringWithFormat:@"%d", [DRDouble sharedDouble].batteryIsFullyCharged];
    firmwareVersionLabel.text = [DRDouble sharedDouble].firmwareVersion;
    serialLabel.text = [DRDouble sharedDouble].serial;
}

//- (void)doubleDriveShouldUpdate:(DRDouble *)theDouble {
//    float drive = (driveForwardButton.highlighted) ? kDRDriveDirectionForward : ((driveBackwardButton.highlighted) ? kDRDriveDirectionBackward : kDRDriveDirectionStop);
//    float turn = (driveRightButton.highlighted) ? 1.0 : ((driveLeftButton.highlighted) ? -1.0 : 0.0);
//    [theDouble drive:drive turn:turn];
//}

- (void)doubleDriveShouldUpdate:(DRDouble *)theDouble {
    // Check if the robot is in auto mode
    if ([self isAutoModeActive]) {
        // Ignore button presses while in auto mode
        [theDouble drive:kDRDriveDirectionForward turn:0.0];
        
        // Calculate the remaining distance to stop the robot
        float desiredDistance = 32.0; // Set the desired distance (in inches)
        float traveledDistance = theDouble.leftEncoderDeltaInches; // Update with appropriate encoder value

        if (traveledDistance >= desiredDistance) {
           // Stop the robot if the desired distance is reached
           [theDouble drive:kDRDriveDirectionStop turn:0.0];
           autostatus = NO;
        }
        
        return;
    }

    float drive = (driveForwardButton.highlighted) ? kDRDriveDirectionForward : ((driveBackwardButton.highlighted) ? kDRDriveDirectionBackward : kDRDriveDirectionStop);
    float turn = (driveRightButton.highlighted) ? 1.0 : ((driveLeftButton.highlighted) ? -1.0 : 0.0);
    [theDouble drive:drive turn:turn];
}

- (BOOL)isAutoModeActive {
    // Return YES if auto mode is active, otherwise return NO
    if (autostatus)
        return YES;
    return NO;
}


//- (void)doubleTravelDataDidUpdate:(DRDouble *)theDouble {
//    leftEncoderLabel.text = [NSString stringWithFormat:@"%.02f", [DRDouble sharedDouble].leftEncoderDeltaInches];
//    rightEncoderLabel.text = [NSString stringWithFormat:@"%.02f", [DRDouble sharedDouble].rightEncoderDeltaInches];
//    NSLog(@"Left Encoder: %f, Right Encoder: %f", theDouble.leftEncoderDeltaInches, theDouble.rightEncoderDeltaInches);
//}

- (void)doubleTravelDataDidUpdate:(DRDouble *)theDouble {
    // Update the raw encoder values
    CGFloat rawLeftEncoder = theDouble.leftEncoderDeltaInches;
    CGFloat rawRightEncoder = theDouble.rightEncoderDeltaInches;

    // Apply a low-pass filter to smooth the encoder values
    self.filteredLeftEncoder = (kFilterFactor * rawLeftEncoder) + ((1.0 - kFilterFactor) * self.filteredLeftEncoder);
    self.filteredRightEncoder = (kFilterFactor * rawRightEncoder) + ((1.0 - kFilterFactor) * self.filteredRightEncoder);

    // Update the displayed encoder labels with the filtered values
    leftEncoderLabel.text = [NSString stringWithFormat:@"%.02f", self.filteredLeftEncoder];
    rightEncoderLabel.text = [NSString stringWithFormat:@"%.02f", self.filteredRightEncoder];

    // Log the filtered encoder values for debugging
    NSLog(@"Filtered Left Encoder: %.02f, Filtered Right Encoder: %.02f", self.filteredLeftEncoder, self.filteredRightEncoder);
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
    [self performObjectDetectionOnImage:image];
}

- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *ciImage = [CIImage imageWithCVImageBuffer:imageBuffer];
    CIContext *context = [[CIContext alloc] initWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:ciImage fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(imageBuffer), CVPixelBufferGetHeight(imageBuffer))];
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    return image;
}

- (void)performObjectDetectionOnImage:(UIImage *)image {
    VNImageRequestHandler *requestHandler = [[VNImageRequestHandler alloc] initWithCGImage:image.CGImage options:@{}];
    NSError *error;
    [requestHandler performRequests:@[self.objectDetectionRequest] error:&error];
    if (error) {
        NSLog(@"Error performing object detection request: %@", error);
    }
}

- (void)handleObjectDetectionResults:(NSArray<VNClassificationObservation *> *)results {
    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval timeSinceLastClassification = currentTimestamp - self.lastClassificationTimestamp;
    
    // Adjust the classification frequency by changing the throttle interval (in seconds)
    NSTimeInterval throttleInterval = 1.0; // Set the desired interval between classifications
    
    if (timeSinceLastClassification >= throttleInterval) {
        // Perform the classification since the throttle interval has passed
        self.lastClassificationTimestamp = currentTimestamp;
        
        NSLog(@"Object detection results received: %lu", (unsigned long)results.count);
        
        if (results.count > 0) {
            VNClassificationObservation *observation = results.firstObject;
            NSString *className = observation.identifier;
            CGFloat confidence = observation.confidence;
            NSString *classificationText = [NSString stringWithFormat:@"%@ (%.2f)", className, confidence];
            
            NSLog(classificationText);
            
            // Update the classification label on the storyboard
            classificationLabel.text = classificationText;
        }
    }
}

@end
