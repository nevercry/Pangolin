//
//  Tunnel.m
//  PacketTunnel
//
//  Created by yangshengfu on 07/12/2017.
//  Copyright © 2017 Minivision. All rights reserved.
//

#import "Tunnel.h"

@implementation Tunnel

@dynamic allTunnels;

static NSMutableArray * _allTunnels = nil;

+ (NSMutableArray *)allTunnels {
    if (!_allTunnels) {
        _allTunnels = [NSMutableArray array];
    }
    
    return _allTunnels;
}

+ (void)setAllTunnels:(NSMutableArray *)allTunnels {
    _allTunnels = allTunnels;
}

+ (NSInteger)maximumMessageSize {
    return 128* 1024;
}

+ (NSInteger)packetSize {
    return 8192;
}

+ (NSInteger)maximumPacketsPerMessage {
    return 32;
}

- (instancetype)init {
    
    if (self = [super init]) {
        self.connections = [NSMutableDictionary dictionary];
        self.savedData = [[SavedData alloc] init];
        
        [Tunnel.allTunnels addObject:self];
    }
    
    return self;
}

- (void)closeTunnel {
    for (Connection *connection in [self.connections allValues]) {
        connection.tunnel = nil;
        [connection abort];
    }
    
    [self.connections removeAllObjects];
    
    [self.savedData clear];
    
    
    NSInteger removeIndex = -1;
    
    for (NSInteger i=0; i< Tunnel.allTunnels.count; i++) {
        Tunnel *tunnel = [Tunnel.allTunnels objectAtIndex:i];
        
        if (tunnel == self) {
            removeIndex = i;
        }
    }
    
    if (removeIndex != -1) {
        [Tunnel.allTunnels removeObjectAtIndex:removeIndex];
    }
}

- (void)addConnection:(Connection *)connection {
    [self.connections setObject:connection forKey:@(connection.identifier)];
}

- (void)dropConnection:(Connection *)connection {
    [self.connections removeObjectForKey:@(connection.identifier)];
}

- (void)closeAll {
    for (Tunnel *tunnel in Tunnel.allTunnels) {
        [tunnel closeTunnel];
    }
    
    [[Tunnel allTunnels] removeAllObjects];
}

- (NSInteger)writeDataToTunnel:(NSData *)data startingAtOffset:(NSInteger)offset {
    return -1;
}

- (NSData *)serializeMessage:(NSDictionary *)messageProperties {
    NSMutableData *messageData=[NSMutableData data];
    
    NSError *error;
    NSData *payload = [NSPropertyListSerialization dataWithPropertyList:messageProperties format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
    if (error) {
        NSLog(@"Failed to create a data object from a message proerty list: %@",messageProperties);
    }
    UInt32 payload_len = (UInt32)payload.length + sizeof(UInt32);
    
    [messageData appendBytes:(char*)&payload_len length:sizeof(UInt32)];
    [messageData appendBytes:[payload bytes] length:payload.length];
    
    return messageData;
}

- (BOOL)sendMessage:(NSDictionary *)messageProperties {
    NSInteger written = 0;
    
    NSData *messageData = [self serializeMessage:messageProperties];
    
    if (!messageData) {
        NSLog(@"Fauked to create message data");
        return false;
    }
    
    if ([self.savedData isEmpty]) {
        written = [self writeDataToTunnel:messageData startingAtOffset:0];
        if (written < 0) {
            [self closeTunnel];
        }
    }
    
    if (written < messageData.length) {
        [self.savedData append:messageData offset:written];
        
        for (Connection *connection in self.connections.allValues) {
            [connection suspend];
        }
    }
    
    return true;
}

- (void)sendData:(NSData *)data forConnection:(NSInteger)connectionIdentifier {
    NSDictionary *properties = [util createMessagePropertiesForConnection:connectionIdentifier cmd:TCData extraProperties:@{[util stringWithTunnelMessageKey:TMKData] : data}];
    
    if (![self sendMessage:properties]) {
        NSLog(@"Failed to send a data message for connection %ld",(long)connectionIdentifier);
    }
}

- (void)sendDataWithEndPoint:(NSData *)data forConnection:(NSInteger)connectionIdentifier host:(NSString *)host port:(NSInteger)port {
    NSString *tmkDataKey = [util stringWithTunnelMessageKey:TMKData];
    NSString *tmkHostKey = [util stringWithTunnelMessageKey:TMKHost];
    NSString *tmkPorkKey = [util stringWithTunnelMessageKey:TMKPort];
    
    
    NSDictionary *properties = [util createMessagePropertiesForConnection:connectionIdentifier cmd:TCData extraProperties:@{tmkDataKey : data, tmkHostKey : host, tmkPorkKey : @(port)}];
    
    if (![self sendMessage:properties]) {
        NSLog(@"Failed to send a data message for connection %ld",(long)connectionIdentifier);
    }
}

- (void)sendSuspendForConnection:(NSInteger)connectionIdentifier {
    NSDictionary *properties = [util createMessagePropertiesForConnection:connectionIdentifier cmd:TCSuspend extraProperties:@{}];
    if (![self sendMessage:properties]) {
        NSLog(@"Failed to send a suspend message for connection %ld",(long)connectionIdentifier);
    }
}

- (void)sendResumeForConnection:(NSInteger)connectionIdentifier {
    NSDictionary *properties = [util createMessagePropertiesForConnection:connectionIdentifier cmd:TCResume extraProperties:@{}];
    if (![self sendMessage:properties]) {
        NSLog(@"Failed to send a resume message for connection %ld",(long)connectionIdentifier);
    }
}

- (void)sendCloseType:(TunnelConnectionCloseDirection)type forConnection:(NSInteger)identifier {
    NSDictionary *properties = [util createMessagePropertiesForConnection:identifier cmd:TCClose extraProperties:@{}];
    if (![self sendMessage:properties]) {
        NSLog(@"Failed to send a close message for connection %ld",(long)identifier);
    }
}

- (void)sendPackets:(NSArray *)packets protocols:(NSArray *)protocols forConnection:(NSInteger)identifier {
    NSString *tmkPacketsKey = [util stringWithTunnelMessageKey:TMKPackets];
    NSString *tmkProtocolsKey = [util stringWithTunnelMessageKey:TMKProtocols];
    
    NSDictionary *properties = [util createMessagePropertiesForConnection:identifier cmd:TCPackets extraProperties:@{tmkPacketsKey: packets, tmkProtocolsKey: protocols}];

    if (![self sendMessage:properties]) {
        NSLog(@"Failed to send a packet message");
    }
}

- (BOOL)handlePacket:(NSData *)packet {
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    NSError *error;
    
    properties = [NSPropertyListSerialization propertyListWithData:packet options:NSPropertyListMutableContainers format:nil error:&error];
    
    if (error) {
        NSLog(@"Failed to create the message properties from the packet");
        return false;
    }
    
    NSNumber *commandNum = properties[[util stringWithTunnelMessageKey:TMKCommand]];
    
    if (!commandNum) {
        NSLog(@"Message command type is missing");
        return false;
    }
    
    
    
    if ([commandNum integerValue] < TCData || [commandNum integerValue] > TCFetchConfiguration) {
        NSLog(@"Message command type %@ is invalid", commandNum);
        return false;
    }
    
    TunnelCommand commandType = [commandNum integerValue];
    
    Connection *connection;
    
    NSString *tmkIdentifierKey = [util stringWithTunnelMessageKey:TMKIdentifier];
    
    if ([properties[tmkIdentifierKey] isKindOfClass:[NSNumber class]] && commandType != TCOpen && commandType != TCDNS) {
        
        NSNumber *keyIdentifier = properties[tmkIdentifierKey];
        
        connection = [self.connections objectForKey:keyIdentifier];
    }
    
    if (!connection) {
        return [self handleMessage:commandType properties:properties connection:connection];
    }
    
    switch (commandType) {
        case TCData: {
            NSString *tmkDataKey = [util stringWithTunnelMessageKey:TMKData];
            NSData *data = properties[tmkDataKey];
            if (!data) {
                break;
            }
            
            NSString *tmkHostKey = [util stringWithTunnelMessageKey:TMKHost];
            NSString *tmkPortKey = [util stringWithTunnelMessageKey:TMKPort];
            
            NSString *host = properties[tmkHostKey];
            NSNumber *port = properties[tmkPortKey];
            if (host && port) {
                NSLog(@"Received data for connection %ld from %@ : %@",connection.identifier,host,port);
                [connection sendData:data endPointHost:host port:port];
            } else {
                [connection sendData:data];
            }
        }
            break;
        case TCSuspend: {
            [connection suspend];
        }
            break;
        case TCResume: {
            [connection resume];
        }
            break;
        case TCClose: {
            NSString *tmkCloseDirectionKey = [util stringWithTunnelMessageKey:TMKCloseDirection];
            
            NSNumber *closeDirectionNum = properties[tmkCloseDirectionKey];
            if (closeDirectionNum && ([closeDirectionNum integerValue] >= TCCDNone && [closeDirectionNum integerValue] <= TCCDAll)) {
                TunnelConnectionCloseDirection closeDirection = [closeDirectionNum integerValue];
                NSLog(@"connection %ld : closeing %ld",connection.identifier,closeDirection);
                [connection closeConnectionWithDirection:closeDirection];
            } else {
                [connection closeConnectionWithDirection:TCCDAll];
            }
        }
            break;
        case TCPackets: {
            NSString *tmkPacketsKey = [util stringWithTunnelMessageKey:TMKPackets];
            NSString *tmkProtocolsKey = [util stringWithTunnelMessageKey:TMKProtocols];
            
            NSArray *packets = properties[tmkPacketsKey];
            NSArray *protocols = properties[tmkProtocolsKey];
            
            if (packets && protocols && packets.count == protocols.count) {
                [connection sendPackets:packets protocols:protocols];
            }
        }
            break;
        default:
            return [self handleMessage:commandType properties:properties connection:connection];
            break;
    }
    
    return true;
}



- (BOOL)handleMessage:(TunnelCommand)cmd properties:(NSDictionary *)properties connection:(Connection *)connection {
    NSLog(@"handleMessage called on abstract base class");
    return false;
}


@end
