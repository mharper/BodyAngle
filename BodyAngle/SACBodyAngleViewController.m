//
//  SACViewController.m
//  BodyAngle
//
//  Created by Michael Harper on 12/23/13.
//  Copyright (c) 2013 Standalone Code LLC. All rights reserved.
//

#import "SACBodyAngleViewController.h"
#import "SACBodyAngleView.h"
#import <CoreMotion/CoreMotion.h>

@interface CBUUID (StringExtraction)

- (NSString *)representativeString;

@end

@implementation CBUUID (StringExtraction)

- (NSString *)representativeString;
{
  NSData *data = [self data];
  
  NSUInteger bytesToConvert = [data length];
  const unsigned char *uuidBytes = [data bytes];
  NSMutableString *outputString = [NSMutableString stringWithCapacity:16];
  
  for (NSUInteger currentByteIndex = 0; currentByteIndex < bytesToConvert; currentByteIndex++)
  {
    switch (currentByteIndex)
    {
      case 3:
      case 5:
      case 7:
      case 9:[outputString appendFormat:@"%02x-", uuidBytes[currentByteIndex]]; break;
      default:[outputString appendFormat:@"%02x", uuidBytes[currentByteIndex]];
    }
  }
  
  return outputString;
}

@end

enum SACDataSourceIndexEnum
{
  SACDataSourcePhoneIndex = 0,
  SACDataSourceSensorTagIndex = 1
};

@interface SACBodyAngleViewController ()

@property (strong, nonatomic) CBCentralManager *bluetoothManager;
@property (strong, nonatomic) NSMutableArray *bluetoothDevices;
@property (strong, nonatomic) CBPeripheral *sensorTag;
@property (strong, nonatomic) CMMotionManager *motionManager;
@property (weak, nonatomic) IBOutlet UILabel *angleLabel;
@property (weak, nonatomic) IBOutlet SACBodyAngleView *angleView;
@property (strong, nonatomic) IBOutletCollection(NSLayoutConstraint) NSArray *portraitAngleLabelViewConstraints;
@property (strong, nonatomic) IBOutletCollection(NSLayoutConstraint) NSArray *landscapeAngleLabelViewConstraints;

@end

@implementation SACBodyAngleViewController

-(void) viewDidLoad
{
  [super viewDidLoad];
  [self getAngleFromPhone];
}

-(void) awakeFromNib
{
  [super awakeFromNib];
  [self adjustLayoutConstraintsForOrientation:self.interfaceOrientation];
}

#pragma mark -
#pragma mark - Rotation/Layout methods

-(void) willRotateToInterfaceOrientation:(UIInterfaceOrientation) toInterfaceOrientation duration:(NSTimeInterval) duration
{
  [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
  [self adjustLayoutConstraintsForOrientation:toInterfaceOrientation];
}

-(void) adjustLayoutConstraintsForOrientation:(UIInterfaceOrientation) orientation
{
  [self.view removeConstraints:self.portraitAngleLabelViewConstraints];
  [self.view removeConstraints:self.landscapeAngleLabelViewConstraints];
  if (UIInterfaceOrientationIsPortrait(orientation))
  {
    [self.view addConstraints:self.portraitAngleLabelViewConstraints];
  }
  else
  {
    [self.view addConstraints:self.landscapeAngleLabelViewConstraints];
  }
}

#pragma mark -
#pragma mark - CoreLocation methods

-(void) getAngleFromPhone
{
  [self stopMonitoringSensorTag];
  self.motionManager = [[CMMotionManager alloc] init];
  self.motionManager.accelerometerUpdateInterval = 0.5;
  [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue]
                                           withHandler:^(CMAccelerometerData  *accelerometerData, NSError *error) {
                                             if (error == nil)
                                             {
                                               [self updateAccelerometerDisplay:accelerometerData];
                                             }
                                             else
                                             {
                                               NSLog(@"%@", error);
                                             }
                                           }];
}

-(void) stopMonitoringPhoneMotion
{
  if (self.motionManager != nil)
  {
    [self.motionManager stopAccelerometerUpdates];
  }
}

-(CGFloat) bodyAngleFromAccelerometer:(CMAccelerometerData *) accelerometerData
{
  return atan2(accelerometerData.acceleration.y, accelerometerData.acceleration.z);
}

-(NSString *) formattedBodyAngleFromAccelerometer:(CMAccelerometerData *) accelerometerData
{
  return [NSString stringWithFormat:@"%d°", (int) (([self bodyAngleFromAccelerometer:accelerometerData] / M_PI) * 180.0)];
}

-(void) updateAccelerometerDisplay:(CMAccelerometerData *) accelerometerData
{
  self.angleLabel.text = [self formattedBodyAngleFromAccelerometer:accelerometerData];
  [self.angleView addBodyAngle:[self bodyAngleFromAccelerometer:accelerometerData]];
}

#pragma mark -
#pragma mark - CBCentralManagerDelegate methods

-(void) getAngleFromSensorTag
{
  [self stopMonitoringPhoneMotion];
  self.bluetoothManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
  self.bluetoothDevices = [NSMutableArray array];
}

-(void) stopMonitoringSensorTag
{
  if (self.sensorTag != nil)
  {
    // TODO Stop monitor the accelerometer characteristics.
  }
  self.bluetoothManager.delegate = nil;
}

-(void) centralManagerDidUpdateState:(CBCentralManager *) central
{
  if (central.state == CBCentralManagerStatePoweredOn)
  {
    [central scanForPeripheralsWithServices:nil options:nil];
  }
}

-(void) centralManager:(CBCentralManager *) central didDiscoverPeripheral:(CBPeripheral *) peripheral advertisementData:(NSDictionary *) advertisementData RSSI:(NSNumber *) rssi
{
  NSLog(@"Found a BLE Device : %@", peripheral);
  peripheral.delegate = self;
  [central connectPeripheral:peripheral options:nil];
  [self.bluetoothDevices addObject:peripheral];
}

-(void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *) peripheral
{
  [peripheral discoverServices:nil];
}

-(void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
  BOOL found = NO;
  NSLog(@"Services scanned !");
  for (CBService *s in peripheral.services) {
    NSLog(@"Service found : %@",s.UUID);
    if ([s.UUID isEqual:[CBUUID UUIDWithString:@"F000AA00-0451-4000-B000-000000000000"]])  {
      NSLog(@"This is a SensorTag!");
      found = YES;
    }
  }
  if (found)
  {
    self.sensorTag = peripheral;
    [self releaseDevices];
    [self.bluetoothManager stopScan];
    [self startMonitoringAccelerometer:self.sensorTag];
  }
}

-(void) releaseDevices
{
  for (CBPeripheral *device in self.bluetoothDevices)
  {
    if (device != self.sensorTag)
    {
      [self.bluetoothManager cancelPeripheralConnection:device];
    }
  }
  self.bluetoothDevices = nil;
}

-(void) startMonitoringAccelerometer:(CBPeripheral *) peripheral
{
  CBUUID *accelerometerServiceId = [CBUUID UUIDWithString:@"F000AA10-0451-4000-B000-000000000000"];
  for (CBService *service in peripheral.services)
  {
    NSLog(@"Service UUID: %@", [service.UUID representativeString]);
    if ([service.UUID isEqual:accelerometerServiceId])
    {
      [peripheral discoverCharacteristics:nil forService:service];
    }
  }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
  CBUUID *accelerometerDataId = [CBUUID UUIDWithString:@"F000AA11-0451-4000-B000-000000000000"];
  CBUUID *accelerometerConfigId = [CBUUID UUIDWithString:@"F000AA12-0451-4000-B000-000000000000"] ;
  CBUUID *accelerometerPeriodId = [CBUUID UUIDWithString:@"F000AA13-0451-4000-B000-000000000000"] ;
  for (CBCharacteristic *characteristic in service.characteristics)
  {
    if ([characteristic.UUID isEqual:accelerometerDataId])
    {
      [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }
    else if ([characteristic.UUID isEqual:accelerometerConfigId])
    {
      [peripheral setNotifyValue:YES forCharacteristic:characteristic];
      uint8_t configData = 0x01;
      [peripheral writeValue:[NSData dataWithBytes:&configData length:1] forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    }
    else if ([characteristic.UUID isEqual:accelerometerPeriodId])
    {
      [peripheral setNotifyValue:YES forCharacteristic:characteristic];
      uint8_t periodData = 50;
      [peripheral writeValue:[NSData dataWithBytes:&periodData length:1] forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    }
  }
}

-(void) peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
  [self updateSensorTagDisplay:characteristic.value];
}

-(NSString *) NSStringFromAccelerometerData:(NSData *) accelerometerData
{
  char rawAccelerometerData[accelerometerData.length];
  [accelerometerData getBytes:&rawAccelerometerData length:3];
  float magicFactor = 256.0 / 4.0;
  float x = ((float) rawAccelerometerData[0]) / magicFactor;
  float y = ((float) rawAccelerometerData[1]) / magicFactor * -1.0;
  float z = ((float) rawAccelerometerData[2]) / magicFactor;
  
  return [NSString stringWithFormat:@"X: %f, Y: %f, Z: %f, angle: %f", x, y, z, atan2(y, z)];
}

-(CGFloat) bodyAngleFromSensorTag:(NSData *) accelerometerData
{
  char rawAccelerometerData[accelerometerData.length];
  [accelerometerData getBytes:&rawAccelerometerData length:3];
  float magicFactor = 256.0 / 4.0;
  float y = ((float) rawAccelerometerData[1]) / magicFactor * -1.0;
  float z = ((float) rawAccelerometerData[2]) / magicFactor;
  return atan2(y, z);
}

-(NSString *) formattedBodyAngleFromSensorTag:(NSData *) accelerometerData
{
  return [NSString stringWithFormat:@"%d°", (int) (([self bodyAngleFromSensorTag:accelerometerData] / M_PI) * 180.0)];
}

-(void) updateSensorTagDisplay:(NSData *) accelerometerData
{
  self.angleLabel.text = [self formattedBodyAngleFromSensorTag:accelerometerData];
  [self.angleView addBodyAngle:[self bodyAngleFromSensorTag:accelerometerData]];
}

#pragma mark -
#pragma mark IBActions

-(IBAction)dataSourceAction:(id) sender
{
  switch (((UISegmentedControl *) sender).selectedSegmentIndex) {
    case SACDataSourcePhoneIndex:
      [self getAngleFromPhone];
      break;
      
    case SACDataSourceSensorTagIndex:
      [self getAngleFromSensorTag];
      break;
      
    default:
      break;
  }
}

@end
