//
//  ClientTunnelConnection.m
//  PacketTunnel
//
//  Created by yangshengfu on 08/12/2017.
//  Copyright © 2017 Minivision. All rights reserved.
//

#import "ClientTunnelConnection.h"

@implementation ClientTunnelConnection

- (instancetype)initWithTunnel:(ClientTunnel *)tunnel clientPacketFlow:(NEPacketTunnelFlow *)packetFlow delegate:(id<ClientTunnelConnectionDelegate>)delegate {
    
    _delegate = delegate;
    _packetFlow = packetFlow;
    NSInteger newConnectionIdentifier = arc4random();
    
    if (self = [super initWithConnectionIdentifier:newConnectionIdentifier parentTunnel:tunnel]) {
        

    }
    
    return self;
}

- (void)open {
    if (![self.tunnel isKindOfClass:[ClientTunnel class]]) {
        return;
    }
    
    ClientTunnel *clientTunnel = (ClientTunnel *)self.tunnel;
    NSString *tmkTunnelTypeKey = [util stringWithTunnelMessageKey:TMKTunnelType];
    
    NSDictionary *properties = [util createMessagePropertiesForConnection:self.identifier cmd:TCOpen extraProperties:@{tmkTunnelTypeKey : @(1)}];
    
    [clientTunnel sendMessage:properties completionHandler:^(NSError *error) {
        if (error) {
            [self.delegate tunnelConnectionDidClose:self error:error];
        }
    }];
}

- (void)handlePackets:(NSArray *)packets protocols:(NSArray *)protocols {
    
    if ([self.tunnel isKindOfClass:[ClientTunnel class]]) {
        ClientTunnel *clientTunnel = (ClientTunnel *)self.tunnel;
        
        NSString *tmkPacketsKey = [util stringWithTunnelMessageKey:TMKPackets];
        NSString *tmkProtocolsKey = [util stringWithTunnelMessageKey:TMKProtocols];
    
        NSDictionary *properties = [util createMessagePropertiesForConnection:self.identifier cmd:TCPackets extraProperties:@{tmkPacketsKey : packets, tmkProtocolsKey : protocols}];
        
        [clientTunnel sendMessage:properties completionHandler:^(NSError *error) {
            if (error) {
                [self.delegate tunnelConnectionDidClose:self error:error];
                return;
            }
        }];
        
        [self.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * _Nonnull packets, NSArray<NSNumber *> * _Nonnull protocols) {
            [self handlePackets:packets protocols:protocols];
        }];
    }
}

- (void)startHandlingPacket {
    [self.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * _Nonnull packets, NSArray<NSNumber *> * _Nonnull protocols) {
        [self handlePackets:packets protocols:protocols];
    }];
}

- (void)handleOpenCompleted:(TunnelConnectionOpenResult)resultCode properties:(NSDictionary *)properties {
    if (resultCode != TCORSuccess) {
        [self.delegate tunnelConnectionDidClose:self error:[NSError errorWithDomain:@"SimpleTunnelError" code:STEBadConnection userInfo:nil]];
        return;
    }
    
    NSString *tmkConfigurationKey = [util stringWithTunnelMessageKey:TMKConfiguration];
    
    NSDictionary *configuration = properties[tmkConfigurationKey];
    
    if (configuration) {
        [self.delegate tunnelConnectionDidOpen:self configuration:configuration];
    } else {
        [self.delegate tunnelConnectionDidOpen:self configuration:@{}];
    }
}

- (void)sendPackets:(NSArray *)packets protocols:(NSArray *)protocols {
    [self.packetFlow writePackets:packets withProtocols:protocols];
}


@end
