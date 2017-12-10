//
//  Tunnel.h
//  PacketTunnel
//
//  Created by yangshengfu on 07/12/2017.
//  Copyright © 2017 Minivision. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Connection.h"
#import "util.h"


@protocol TunnelDelegate;


@interface Tunnel : NSObject

@property (nonatomic, weak) id<TunnelDelegate> delegate;
@property (nonatomic, strong) NSMutableDictionary *connections;
@property (nonatomic, strong) SavedData *savedData;
@property (nonatomic, copy, class) NSMutableArray *allTunnels;


+ (NSInteger)maximumMessageSize;
+ (NSInteger)packetSize;
+ (NSInteger)maximumPacketsPerMessage;

- (instancetype)init;

- (void)closeTunnel;
- (void)addConnection:(Connection *)connection;
- (void)dropConnection:(Connection *)connection;
- (void)closeAll;
- (NSInteger)writeDataToTunnel:(NSData *)data startingAtOffset:(NSInteger)offset;

- (NSData *)serializeMessage:(NSDictionary *)messageProperties;
- (BOOL)sendMessage:(NSDictionary *)messageProperties;
- (void)sendData:(NSData *)data forConnection:(NSInteger)connectionIdentifier;
- (void)sendDataWithEndPoint:(NSData *)data forConnection:(NSInteger)connectionIdentifier host:(NSString *)host port:(NSInteger)port;
- (void)sendSuspendForConnection:(NSInteger)connectionIdentifier;
- (void)sendResumeForConnection:(NSInteger)connectionIdentifier;
- (void)sendCloseType:(TunnelConnectionCloseDirection)type forConnection:(NSInteger)identifier;
- (void)sendPackets:(NSArray *)packets protocols:(NSArray *)protocols forConnection:(NSInteger)identifier;
- (BOOL)handlePacket:(NSData *)packet;
- (BOOL)handleMessage:(TunnelCommand)cmd properties:(NSDictionary *)properties connection:(Connection *)connection;

@end

@protocol TunnelDelegate

- (void)tunnelDidOpen:(Tunnel *)tunnel;

- (void)tunnelDidClose:(Tunnel *)tunnel;

- (void)tunnelDidSendConfiguration:(Tunnel *)tunnel configuration:(NSDictionary *)configs;


@end






