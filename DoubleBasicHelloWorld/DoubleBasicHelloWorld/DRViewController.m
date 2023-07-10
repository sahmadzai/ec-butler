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

@interface DRViewController () <DRDoubleDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) DRDouble *theDouble;
// Instance variables for filtered encoder values
@property (nonatomic, assign) CGFloat filteredLeftEncoder;
@property (nonatomic, assign) CGFloat filteredRightEncoder;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
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
    [self startCameraCapture];
    
    self.filteredLeftEncoder = kInitialEncoderValue;
    self.filteredRightEncoder = kInitialEncoderValue;
	NSLog(@"SDK Version: %@", kDoubleBasicSDKVersion);
}

- (void)startCameraCapture {
    // Create an AVCaptureSession
    self.captureSession = [[AVCaptureSession alloc] init];
    
    // Configure the session for high-quality video output
    self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    
    // Find the appropriate AVCaptureDevice for video
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
                // Add the video input to the session
                [self.captureSession addInput:videoInput];
                
                // Create an AVCaptureVideoDataOutput to receive video frames
                AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
                [videoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
                
                if ([self.captureSession canAddOutput:videoOutput]) {
                    // Add the video output to the session
                    [self.captureSession addOutput:videoOutput];
                    
                    // Create a UIImageView to display the camera feed
                    cameraView = [[UIImageView alloc] initWithFrame:imageView.bounds];
                    cameraView.contentMode = UIViewContentModeScaleAspectFit;
                    [imageView addSubview:cameraView]; // Replace "imageView" with the actual IBOutlet name of your image view
                    
                    // Start the capture session
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

//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
//	return UIInterfaceOrientationIsPortrait(toInterfaceOrientation);
//}

- (BOOL)shouldAutorotate {
    return YES;  // Return YES if you want the view controller to support all interface orientations.
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;  // Adjust the return value to support the desired interface orientations.
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
    // Retract the kickstands before moving
    if (self.theDouble.kickstandState == 1) {
        // Retract the kickstands
        [self.theDouble retractKickstands];
    }
    
    autostatus = YES;
    
    // Set the desired distance for forward movement (in inches)
    float desiredDistance = 32.0;
    
    // Calculate the duration based on a constant speed (adjust as needed)
    float constantSpeed = 12;  // Adjust the speed value as desired (in inches per second)
    NSTimeInterval duration = desiredDistance / constantSpeed;
    
    // Start the forward movement
    [self.theDouble drive:kDRDriveDirectionForward turn:0.0];
    
    // Schedule a timer to stop the forward movement after the desired duration
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:duration target:self selector:@selector(stopMovingForward:) userInfo:@{@"duration": @(duration)} repeats:YES];
    
    // Print the timer countdown
    [self printTimerCountdown:timer];
}


- (IBAction)stopAutoMode:(id)sender {
    [self.theDouble drive:kDRDriveDirectionStop turn:0.0];
    autostatus = NO;
}

#pragma mark - DRDoubleDelegate

- (void)stopMovingForward:(NSTimer *)timer {
    [self.theDouble drive:kDRDriveDirectionStop turn:0.0];
    [timer invalidate]; // Stop the timer
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
//	float drive = (driveForwardButton.highlighted) ? kDRDriveDirectionForward : ((driveBackwardButton.highlighted) ? kDRDriveDirectionBackward : kDRDriveDirectionStop);
//	float turn = (driveRightButton.highlighted) ? 1.0 : ((driveLeftButton.highlighted) ? -1.0 : 0.0);
//	[theDouble drive:drive turn:turn];
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
//	leftEncoderLabel.text = [NSString stringWithFormat:@"%.02f", [DRDouble sharedDouble].leftEncoderDeltaInches];
//	rightEncoderLabel.text = [NSString stringWithFormat:@"%.02f", [DRDouble sharedDouble].rightEncoderDeltaInches];
//	NSLog(@"Left Encoder: %f, Right Encoder: %f", theDouble.leftEncoderDeltaInches, theDouble.rightEncoderDeltaInches);
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
    // Get the video frame as a UIImage
    UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
    
    // Update the cameraImageView with the captured image
    cameraView.image = image;
}

- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    // Get the CVImageBuffer from the sample buffer
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // Create a CIImage from the image buffer
    CIImage *ciImage = [CIImage imageWithCVImageBuffer:imageBuffer];
    
    // Create a CIContext
    CIContext *context = [[CIContext alloc] initWithOptions:nil];
    
    // Convert CIImage to CGImage
    CGImageRef cgImage = [context createCGImage:ciImage fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(imageBuffer), CVPixelBufferGetHeight(imageBuffer))];
    
    // Create a UIImage from the CGImage
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    
    // Rotate the image by 90 degrees clockwise
    UIImage *rotatedImage = [UIImage imageWithCGImage:image.CGImage scale:image.scale orientation:UIImageOrientationRight];
    
    // Release the CGImage
    CGImageRelease(cgImage);
    
    return rotatedImage;
}

@end
