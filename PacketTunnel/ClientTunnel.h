//
//  ClientTunnel.h
//  PacketTunnel
//
//  Created by yangshengfu on 07/12/2017.
//  Copyright © 2017 Minivision. All rights reserved.
//

#import "Tunnel.h"
#import "util.h"
@import NetworkExtension;

@interface ClientTunnel : Tunnel

@property (nonatomic, strong) NWTCPConnection *connection;

@property (nonatomic, strong) NSError *lastError;

@property (nonatomic, strong) NSMutableData *previousData;

@property (nonatomic, strong) NSString *remoteHost;

- (void)startTunnel:(NETunnelProvider *)provider withError:(NSError **)error;

- (void)closeTunnelWithError:(NSError *)error;

- (void)readNextPacket;

- (void)sendMessage:(NSDictionary *)messageProperties completionHandler:(void (^)(NSError *error))completionBlock;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context;

- (void)closeTunnel;

- (NSInteger)writeDataToTunnel:(NSData *)data startingAtOffset:(NSInteger)offset;

- (BOOL)handleMessage:(TunnelCommand)cmd properties:(NSDictionary *)properties connection:(Connection *)connection;

- (void)sendFetchConfiguration;




@end
