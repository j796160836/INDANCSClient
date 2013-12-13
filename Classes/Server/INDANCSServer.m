//
//  INDANCSServer.m
//  INDANCSClient
//
//  Created by Indragie Karunaratne on 12/11/2013.
//  Copyright (c) 2013 Indragie Karunaratne. All rights reserved.
//

#import "INDANCSServer.h"
#import "INDANCSDefines.h"

static NSString * const INDANCSServerRestorationKey = @"INDANCSServer";

@interface INDANCSServer () <CBPeripheralManagerDelegate>
@property (nonatomic, strong) CBPeripheralManager *manager;
@property (nonatomic, strong) CBMutableService *NAMEService;
@property (nonatomic) dispatch_queue_t delegateQueue;
@property (nonatomic, assign, readwrite) CBPeripheralManagerState state;
@property (nonatomic, assign) BOOL shouldAdvertise;
@end

@implementation INDANCSServer {
	struct {
		unsigned int didStartAdvertising:1;
	} _delegateFlags;
}

#pragma mark - Initialization

- (id)initWithUID:(NSString *)UID
{
	if ((self = [super init])) {
		_delegateQueue = dispatch_queue_create("com.indragie.INDANCSServer.DelegateQueue", DISPATCH_QUEUE_SERIAL);
		NSMutableDictionary *options = [@{CBPeripheralManagerOptionShowPowerAlertKey : @YES} mutableCopy];
		if (UID.length) {
			options[CBPeripheralManagerOptionRestoreIdentifierKey] = UID;
		}
		_manager = [[CBPeripheralManager alloc] initWithDelegate:self queue:_delegateQueue options:options];
	}
	return self;
}

#pragma mark - Advertising

- (void)startAdvertising
{
	self.shouldAdvertise = YES;
	if (self.manager.state == CBCentralManagerStatePoweredOn && self.manager.isAdvertising == NO) {
		NSDictionary *advertisementData = @{CBAdvertisementDataServiceUUIDsKey : @[IND_ANCS_SV_UUID, IND_NAME_SV_UUID], CBAdvertisementDataLocalNameKey : UIDevice.currentDevice.name};
		[self.manager startAdvertising:advertisementData];
	}
}

- (void)stopAdvertising
{
	self.shouldAdvertise = NO;
	if (self.manager.isAdvertising == YES) {
		[self.manager stopAdvertising];
	}
}

#pragma mark - Accessors

- (void)setDelegate:(id<INDANCSServerDelegate>)delegate
{
	if (_delegate != delegate) {
		_delegate = delegate;
		_delegateFlags.didStartAdvertising = [delegate respondsToSelector:@selector(ANCSServer:didStartAdvertisingWithError:)];
	}
}

- (BOOL)isAdvertising
{
	return self.manager.isAdvertising;
}

+ (NSSet *)keyPathsForValuesAffectingAdvertising
{
	return [NSSet setWithObject:@"manager.isAdvertising"];
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
	self.state = peripheral.state;
	if (self.state == CBPeripheralManagerStatePoweredOn) {
		if (self.NAMEService == nil) {
			self.NAMEService = [self newNAMEService];
			[_manager addService:self.NAMEService];
		}
		if (self.shouldAdvertise) {
			[self startAdvertising];
		}
	} else {
		[self stopAdvertising];
	}
}

- (CBMutableService *)newNAMEService
{
	CBMutableService *service = [[CBMutableService alloc] initWithType:IND_NAME_SV_UUID primary:YES];
	NSData *nameData = [UIDevice.currentDevice.name dataUsingEncoding:NSUTF8StringEncoding];
	CBMutableCharacteristic *nameCharacteristic = [[CBMutableCharacteristic alloc] initWithType:IND_NAME_CH_UUID properties:CBCharacteristicPropertyRead value:nameData permissions:CBAttributePermissionsReadable];
	service.characteristics = @[nameCharacteristic];
	return service;
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
	if (_delegateFlags.didStartAdvertising) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.delegate ANCSServer:self didStartAdvertisingWithError:error];
		});
	}
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral willRestoreState:(NSDictionary *)dict
{
	NSLog(@"%@", dict);
}

@end