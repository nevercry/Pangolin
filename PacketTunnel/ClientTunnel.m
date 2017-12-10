//
//  ClientTunnel.m
//  PacketTunnel
//
//  Created by yangshengfu on 07/12/2017.
//  Copyright © 2017 Minivision. All rights reserved.
//

#import "ClientTunnel.h"

@implementation ClientTunnel

- (void)startTunnel:(NETunnelProvider *)provider withError:(NSError **)error {
    
    NSString *serverAddress = provider.protocolConfiguration.serverAddress;
    
    if (!serverAddress) {
        *error = [NSError errorWithDomain:@"SimpleTunnelError" code:STEBadConfiguration userInfo:nil];
        return;
    }
    
    NWEndpoint *endPoint;
    
    NSRange searchRange = NSMakeRange(0, serverAddress.length);
    
    NSRange colonRange = [serverAddress rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@":"] options:NSCaseInsensitiveSearch range:searchRange];
    
    if (colonRange.location != NSNotFound) {
        NSString *hostName = [serverAddress substringWithRange:NSMakeRange(0, colonRange.location)];
        NSString *portString = [serverAddress substringWithRange:NSMakeRange(colonRange.location + colonRange.length, serverAddress.length)];
        
        if (hostName.length == 0 && portString.length == 0) {
            *error = [NSError errorWithDomain:@"SimpleTunnelError" code:STEBadConfiguration userInfo:nil];
            return;
        }
        
        endPoint = [NWHostEndpoint endpointWithHostname:hostName port:portString];
    } else {
        *error = [NSError errorWithDomain:@"SimpleTunnelError" code:STEBadConfiguration userInfo:nil];
        return;
    }
    
    self.connection = [provider createTCPConnectionToEndpoint:endPoint enableTLS:false TLSParameters:nil delegate:nil];
    
    [self.connection addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionInitial context: &_connection];
    
    return;
}

- (void)closeTunnelWithError:(NSError *)error {
    self.lastError = error;
    [self closeTunnel];
}

- (void)readNextPacket {
    if (!self.connection) {
        [self closeTunnelWithError:[NSError errorWithDomain:@"SimpleTunnelError" code:STEBadConnection userInfo:nil]];
        return;
    }
    
    [self.connection readMinimumLength:sizeof(UInt32) maximumLength:sizeof(UInt32) completionHandler:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Got an Error on the tunnel connection: %@",error);
            return ;
        }
        
        NSData* lengthData = data;
        
        if (lengthData.length != sizeof(UInt32)) {
            NSLog(@"Length data length %lu != sizeof(UInt32) %lu",(unsigned long)lengthData.length, sizeof(UInt32));
            [self closeTunnelWithError:[NSError errorWithDomain:@"SimpleTunnelError" code:STEInternalError userInfo:nil]];
            return;
        }
        
        UInt32 totalLength = 0;
        [lengthData getBytes:&totalLength length:sizeof(UInt32)];
        
        if (totalLength > (UInt32)[Tunnel maximumMessageSize]) {
            NSLog(@"Got a length that is too big : %u",(unsigned int)totalLength);
            [self closeTunnelWithError:[NSError errorWithDomain:@"SimpleTunnelError" code:STEInternalError userInfo:nil]];
            return;
        }
        
        totalLength -= (UInt32)sizeof(UInt32);
        
        [self.connection readMinimumLength:totalLength maximumLength:totalLength completionHandler:^(NSData * _Nullable data, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Got an Error on the tunnel connection: %@",error);
                [self closeTunnelWithError:error];
                return;
            }
            
            NSData *payloadData = data;
            
            if (payloadData.length != (NSInteger)totalLength) {
                NSLog(@"Payload data length %ld != payload length %u ", payloadData.length, (unsigned int)totalLength);
                [self closeTunnelWithError:[NSError errorWithDomain:@"SimpleTunnelError" code:STEInternalError userInfo:nil]];
                return;
            }
            
            [self handlePacket:payloadData];
            
            [self readNextPacket];
        }];
    }];
}

- (void)sendMessage:(NSDictionary *)messageProperties completionHandler:(void (^)(NSError *))completionBlock {
    NSData *messageData = [self serializeMessage:messageProperties];
    
    if (!messageData) {
        completionBlock([NSError errorWithDomain:@"SimpleTunnelError" code:STEInternalError userInfo:nil]);
        return;
    }
    
    [self.connection write:messageData completionHandler:completionBlock];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    
    if ([keyPath isEqualToString:@"state"] && context == &_connection) {
        NSLog(@"Tunnel connection state change to %ld",(long)self.connection.state);
        
        switch (self.connection.state) {
            case NWTCPConnectionStateConnected: {
                NWHostEndpoint *remoteAddress = (NWHostEndpoint *)self.connection.remoteAddress;
                
                if (remoteAddress) {
                    self.remoteHost = remoteAddress.hostname;
                }
                
                [self readNextPacket];
                
                if (self.delegate != nil) {
                    [self.delegate tunnelDidOpen:self];
                }
            }
                break;
            case NWTCPConnectionStateDisconnected: {
                [self closeTunnelWithError:self.connection.error];
            }
            case NWTCPConnectionStateCancelled: {
                [self.connection removeObserver:self forKeyPath:@"state" context:&_connection];
                self.connection = nil;
                
                if (self.delegate != nil) {
                    [self.delegate tunnelDidClose:self];
                }
            }
            default:
                break;
        }
    }
}

- (void)closeTunnel {
    [super closeTunnel];
    
    if (self.connection) {
        [self.connection cancel];
    }
}

- (NSInteger)writeDataToTunnel:(NSData *)data startingAtOffset:(NSInteger)offset {
    [self.connection write:data completionHandler:^(NSError * _Nullable error) {
        if (error) {
            [self closeTunnelWithError:error];
        }
    }];
    return data.length;
}

- (BOOL)handleMessage:(TunnelCommand)cmd properties:(NSDictionary *)properties connection:(Connection *)connection {
    BOOL success = true;
    
    switch (cmd) {
        case TCOpenResult: {
            NSNumber *resultCodeNumber = properties[[util stringWithTunnelMessageKey:TMKResultCode]];
            NSInteger resultCode = [resultCodeNumber integerValue];
            
            if (resultCode < TCORSuccess || resultCode > TCORInternalError) {
                success = false;
                break;
            } else {
                
                if (connection) {
                    [connection handleOpenCompleted:resultCode properties:properties];
                }
            }
        }
            break;
        case TCFetchConfiguration: {
            NSDictionary *configuration = properties[[util stringWithTunnelMessageKey:TMKConfiguration]];
            if (configuration) {
                if (self.delegate != nil) {
                    [self.delegate tunnelDidSendConfiguration:self configuration:configuration];
                }
            }
        }
            break;
        default: {
            NSLog(@"Tunnel received an invalid command");
            success = false;
        }
            break;
    }
    return success;
}

- (void)sendFetchConfiguration {
    NSDictionary *properties = [util createMessagePropertiesForConnection:0 cmd:TCFetchConfiguration extraProperties:@{}];
    if (![self sendMessage:properties]) {
        NSLog(@"Fail to send a fetch configuratiom message");
    }
}


@end
