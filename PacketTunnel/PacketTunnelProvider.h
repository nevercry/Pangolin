//
//  PacketTunnelProvider.h
//  PacketTunnel
//
//  Created by yangshengfu on 06/12/2017.
//  Copyright © 2017 Minivision. All rights reserved.
//

@import NetworkExtension;
#import "ClientTunnel.h"
#import "ClientTunnelConnection.h"

@interface PacketTunnelProvider : NEPacketTunnelProvider<TunnelDelegate,ClientTunnelConnectionDelegate>

@property (nonatomic, strong) ClientTunnel *tunnel;

@property (nonatomic, strong) ClientTunnelConnection *tunnelConnection;

@property (nonatomic, copy) void (^pendingStopCompletion)(void);

@property (nonatomic, copy) void (^pendingStartCompletion)(NSError *);


@end
