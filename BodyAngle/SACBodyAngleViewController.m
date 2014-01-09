//
//  SACViewController.m
//  BodyAngle
//
//  Created by Michael Harper on 12/23/13.
//  Copyright (c) 2013 Standalone Code LLC. All rights reserved.
//

#import "SACBodyAngleViewController.h"
#import "SACBodyAngleView.h"

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

@interface SACBodyAngleViewController ()

@property (strong, nonatomic) CBCentralManager *bluetoothManager;
@property (strong, nonatomic) NSMutableArray *bluetoothDevices;
@property (strong, nonatomic) CBPeripheral *sensorTag;
@property (weak, nonatomic) IBOutlet UILabel *angleLabel;
@property (weak, nonatomic) IBOutlet SACBodyAngleView *angleView;

@end

@implementation SACBodyAngleViewController

-(void) viewDidLoad
{
    [super viewDidLoad];
  self.bluetoothManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
  self.bluetoothDevices = [NSMutableArray array];
}

-(void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark -
#pragma mark - CBCentralManagerDelegate methods

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
  
  /* iOS 6.0 bug workaround : connect to device before displaying UUID !
   The reason for this is that the CFUUID .UUID property of CBPeripheral
   here is null the first time an unkown (never connected before in any app)
   peripheral is connected. So therefore we connect to all peripherals we find.
   */
  
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
      NSLog(@"This is a SensorTag !");
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
  [self updateAccelerometerDisplay:characteristic.value];
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

-(CGFloat) bodyAngleFromAccelerometer:(NSData *) accelerometerData
{
  char rawAccelerometerData[accelerometerData.length];
  [accelerometerData getBytes:&rawAccelerometerData length:3];
  float magicFactor = 256.0 / 4.0;
  float y = ((float) rawAccelerometerData[1]) / magicFactor * -1.0;
  float z = ((float) rawAccelerometerData[2]) / magicFactor;
  return atan2(y, z);
}

-(NSString *) formattedBodyAngleFromAccelerometer:(NSData *) accelerometerData
{
  return [NSString stringWithFormat:@"%d°", (int) (([self bodyAngleFromAccelerometer:accelerometerData] / M_PI) * 180.0)];
}

-(void) updateAccelerometerDisplay:(NSData *) accelerometerData
{
  self.angleLabel.text = [self formattedBodyAngleFromAccelerometer:accelerometerData];
  [self.angleView addBodyAngle:[self bodyAngleFromAccelerometer:accelerometerData]];
}

-(void) stopMonitoringGyros:(CBPeripheral *) peripheral
{
  
}

@end
