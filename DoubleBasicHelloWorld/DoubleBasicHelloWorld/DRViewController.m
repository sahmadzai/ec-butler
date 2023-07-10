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
@end

@implementation DRViewController

bool autostatus = NO;

- (void)viewDidLoad {
	[super viewDidLoad];
    self.theDouble = [DRDouble sharedDouble];
    self.theDouble.delegate = self;
	NSLog(@"SDK Version: %@", kDoubleBasicSDKVersion);
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
    float constantSpeed = 2.0;  // Adjust the speed value as desired (in inches per second)
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


- (void)doubleTravelDataDidUpdate:(DRDouble *)theDouble {
	leftEncoderLabel.text = [NSString stringWithFormat:@"%.02f", [DRDouble sharedDouble].leftEncoderDeltaInches];
	rightEncoderLabel.text = [NSString stringWithFormat:@"%.02f", [DRDouble sharedDouble].rightEncoderDeltaInches];
	NSLog(@"Left Encoder: %f, Right Encoder: %f", theDouble.leftEncoderDeltaInches, theDouble.rightEncoderDeltaInches);
}

@end
