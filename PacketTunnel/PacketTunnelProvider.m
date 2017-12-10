//
//  PacketTunnelProvider.m
//  PacketTunnel
//
//  Created by yangshengfu on 06/12/2017.
//  Copyright © 2017 Minivision. All rights reserved.
//

#import "PacketTunnelProvider.h"

@implementation PacketTunnelProvider

- (void)startTunnelWithOptions:(NSDictionary *)options completionHandler:(void (^)(NSError *))completionHandler {
	// Add code here to start the process of connecting the tunnel.
    ClientTunnel *newTunnel = [[ClientTunnel alloc] init];
    newTunnel.delegate = self;
    
    NSError *error;
    [newTunnel startTunnel:self withError:&error];
    
    if (error) {
        completionHandler(error);
    } else {
        self.pendingStartCompletion = completionHandler;
        self.tunnel = newTunnel;
    }
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
	// Add code here to start the process of stopping the tunnel.
    self.pendingStartCompletion = nil;
    self.pendingStopCompletion = completionHandler;
    
    [self.tunnel closeTunnel];
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(void (^)(NSData *))completionHandler {
	// Add code here to handle the message.
}

- (void)sleepWithCompletionHandler:(void (^)(void))completionHandler {
	// Add code here to get ready to sleep.
	completionHandler();
}

- (void)wake {
	// Add code here to wake up.
}

- (void)tunnelDidOpen:(Tunnel *)tunnel {
    ClientTunnelConnection *newConnection = [[ClientTunnelConnection alloc] initWithTunnel:(ClientTunnel *)tunnel clientPacketFlow:self.packetFlow delegate:self];
    [newConnection open];
    self.tunnelConnection = newConnection;
}

- (void)tunnelDidClose:(Tunnel *)tunnel {
    if (self.pendingStartCompletion) {
        self.pendingStartCompletion(self.tunnel.lastError);
        self.pendingStartCompletion = nil;
    } else if (self.pendingStopCompletion) {
        self.pendingStopCompletion();
        self.pendingStopCompletion = nil;
    } else {
        [self cancelTunnelWithError:self.tunnel.lastError];
    }
    self.tunnel = nil;
}

- (void)tunnelDidSendConfiguration:(Tunnel *)tunnel configuration:(NSDictionary *)configs {
    
}

- (void)tunnelConnectionDidOpen:(ClientTunnelConnection *)connection configuration:(NSDictionary *)configuration {

    NEPacketTunnelNetworkSettings *settings = [self createTunnelSettingsFromConfiguration:configuration];
    if (!settings) {
        self.pendingStartCompletion([NSError errorWithDomain:@"SimpleTunnelError" code:STEInternalError userInfo:nil]);
        self.pendingStartCompletion = nil;
        return;
    }
    
    __weak PacketTunnelProvider *weakSelf = self;
    [self setTunnelNetworkSettings:settings completionHandler:^(NSError * _Nullable error) {
        NSError *startError;
        
        if (error) {
            NSLog(@"Failed to set the tunnel network settings: %@",error);
            
            startError = [NSError errorWithDomain:@"SimpleTunnelError" code:STEInternalError userInfo:nil];
        } else {
            [weakSelf.tunnelConnection startHandlingPacket];
        }
        
        weakSelf.pendingStartCompletion(startError);
        weakSelf.pendingStartCompletion = nil;
    }];
}

- (void)tunnelConnectionDidClose:(ClientTunnelConnection *)connection error:(NSError *)error {
    self.tunnelConnection = nil;
    [self.tunnel closeTunnelWithError:error];
}

- (NEPacketTunnelNetworkSettings *)createTunnelSettingsFromConfiguration:(NSDictionary *)configuration {
    NSString *tunnelAddress = self.tunnel.remoteHost;
    NSString *address = (NSString *)[util getValueFromPlist:configuration keyArray:@[@"IPv4",@"Address"]];
    NSString *netmask = [util getValueFromPlist:configuration keyArray:@[@"IPv4",@"Netmask"]];
    
    if (!tunnelAddress || !address || !netmask) {
        return nil;
    }
    
    NEPacketTunnelNetworkSettings *newSettings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:tunnelAddress];
    BOOL fullTunnel = NO;
    newSettings.IPv4Settings = [[NEIPv4Settings alloc] initWithAddresses:@[address] subnetMasks:@[netmask]];
    
    NSArray *routes = [util getValueFromPlist:configuration keyArray:@[@"IPv4", @"Routes"]];
    if (routes) {
        NSMutableArray *includedRoutes = [NSMutableArray array];
        for (NSDictionary *route in routes) {
            NSString *netAddress = route[@"Address"];
            NSString *netMask = route[@"Netmask"];
            if (netAddress && netMask) {
                [includedRoutes addObject:[[NEIPv4Route alloc] initWithDestinationAddress:netAddress subnetMask:netMask]];
            }
        }
        newSettings.IPv4Settings.includedRoutes = includedRoutes;
        fullTunnel = YES;
    } else {
        newSettings.IPv4Settings.includedRoutes = @[NEIPv4Route.defaultRoute];
    }
    
    NSDictionary *dnsDictionary = configuration[@"DNS"];
    
    if (dnsDictionary) {
        NSArray *dnsServers = dnsDictionary[@"Servers"];
        if (dnsServers) {
            newSettings.DNSSettings = [[NEDNSSettings alloc] initWithServers:dnsServers];
            
            NSArray *dnsSearchDomains = dnsDictionary[@"SearchDomains"];
            if (dnsSearchDomains) {
                newSettings.DNSSettings.searchDomains = dnsSearchDomains;
                
                if (!fullTunnel) {
                    newSettings.DNSSettings.matchDomains = dnsSearchDomains;
                }
            }
        }
    }
    
    newSettings.tunnelOverheadBytes = @(150);
    
    return newSettings;
}






@end
