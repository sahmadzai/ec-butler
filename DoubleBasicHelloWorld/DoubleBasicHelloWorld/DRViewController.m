//
//  DRViewController.m
//  DoubleBasicHelloWorld
//
//  Created by David Cann on 8/3/13.
//  Copyright (c) 2013 Double Robotics, Inc. All rights reserved.
//
#import "DRViewController.h"
#import <DoubleControlSDK/DoubleControlSDK.h>

@interface DRViewController () <DRDoubleDelegate>

@property (nonatomic, strong) DRDouble *theDouble;
@property (nonatomic, assign) CGFloat filteredLeftEncoder;
@property (nonatomic, assign) CGFloat filteredRightEncoder;
@property (nonatomic, assign) CGPoint currentPosition;


@end

@implementation DRViewController

// Constants for filter adjustment (tweak as needed)
static const CGFloat kFilterFactor = 0.8;

bool autostatus = NO;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.theDouble = [DRDouble sharedDouble];
    self.theDouble.delegate = self;
}


- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - Actions

- (IBAction)driveButtonPressed:(UIButton *)sender {
    BOOL driveForward = sender == driveForwardButton;
    [self.theDouble drive:driveForward ? kDRDriveDirectionForward : kDRDriveDirectionBackward turn:0.0];
}

- (IBAction)driveButtonReleased:(UIButton *)sender {
    [self.theDouble drive:kDRDriveDirectionStop turn:0.0];
}

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
}

- (void)doubleDriveShouldUpdate:(DRDouble *)theDouble {
    // Check if the robot is in auto mode
    if ([self isAutoModeActive]) {
        // Ignore button presses while in auto mode
        [theDouble drive:kDRDriveDirectionForward turn:0.0];
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

- (void)doubleTravelDataDidUpdate:(DRDouble *)theDouble {
    CGFloat rawLeftEncoder = theDouble.leftEncoderDeltaInches;
    CGFloat rawRightEncoder = theDouble.rightEncoderDeltaInches;

    self.filteredLeftEncoder = (kFilterFactor * rawLeftEncoder) + ((1.0 - kFilterFactor) * self.filteredLeftEncoder);
    self.filteredRightEncoder = (kFilterFactor * rawRightEncoder) + ((1.0 - kFilterFactor) * self.filteredRightEncoder);

    leftEncoderLabel.text = [NSString stringWithFormat:@"%.02f", self.filteredLeftEncoder];
    rightEncoderLabel.text = [NSString stringWithFormat:@"%.02f", self.filteredRightEncoder];
}

@end
