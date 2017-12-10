//
//  ClientTunnelConnection.h
//  PacketTunnel
//
//  Created by yangshengfu on 08/12/2017.
//  Copyright © 2017 Minivision. All rights reserved.
//

#import "Connection.h"
#import "ClientTunnel.h"
@import NetworkExtension;

@class ClientTunnelConnection;

@protocol ClientTunnelConnectionDelegate

- (void)tunnelConnectionDidOpen:(ClientTunnelConnection *)connection configuration:(NSDictionary *)configuration;
- (void)tunnelConnectionDidClose:(ClientTunnelConnection *)connection error:(NSError *)error;

@end



@interface ClientTunnelConnection : Connection

@property (nonatomic, strong) id<ClientTunnelConnectionDelegate>delegate;
@property (nonatomic, strong) NEPacketTunnelFlow *packetFlow;

- (instancetype)initWithTunnel:(ClientTunnel *)tunnel clientPacketFlow:(NEPacketTunnelFlow *)packetFlow delegate:(id<ClientTunnelConnectionDelegate>)delegate;

- (void)open;
- (void)handlePackets:(NSArray *)packets protocols:(NSArray *)protocols;
- (void)startHandlingPacket;
- (void)handleOpenCompleted:(TunnelConnectionOpenResult)resultCode properties:(NSDictionary *)properties;
- (void)sendPackets:(NSArray *)packets protocols:(NSArray *)protocols;

@end
