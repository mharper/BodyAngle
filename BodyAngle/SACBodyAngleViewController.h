//
//  SACViewController.h
//  BodyAngle
//
//  Created by Michael Harper on 12/23/13.
//  Copyright (c) 2013 Standalone Code LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface SACBodyAngleViewController : UIViewController<CBCentralManagerDelegate, CBPeripheralDelegate>

@end
