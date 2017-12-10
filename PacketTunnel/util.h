//
//  util.h
//  PacketTunnel
//
//  Created by yangshengfu on 07/12/2017.
//  Copyright © 2017 Minivision. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    STEBadConfiguration,
    STEBadConnection,
    STEInternalError,
} SimpleTunnelError;

typedef enum : NSUInteger {
    TCData = 1,
    TCSuspend,
    TCResume,
    TCClose,
    TCDNS,
    TCOpen,
    TCOpenResult,
    TCPackets,
    TCFetchConfiguration
} TunnelCommand;

typedef enum : NSUInteger {
    TMKIdentifier,
    TMKCommand,
    TMKData,
    TMKCloseDirection,
    TMKDNSPacket,
    TMKDNSPacketSource,
    TMKResultCode,
    TMKTunnelType,
    TMKHost,
    TMKPort,
    TMKConfiguration,
    TMKPackets,
    TMKProtocols
} TunnelMessageKey;




@interface SavedData : NSObject

@property (nonatomic, strong) NSMutableArray *chain;

- (BOOL)isEmpty;

- (void)append:(NSData *)data offset:(NSInteger)offset;

- (BOOL)writeToStream:(NSOutputStream *)stream;

- (void)clear;

- (NSInteger)writeData:(NSData *)data toStream:(NSOutputStream *)stream startingOffset:(NSInteger)offset;

- (NSDictionary *)createMessagePropertiesForConnection:(NSInteger)identifier commandType:(TunnelCommand)cmd extraProperties:(NSDictionary *)extraProperties;


@end


@interface util : NSObject

+ (NSString *)stringWithTunnelMessageKey:(TunnelMessageKey)input;
+ (NSDictionary *)createMessagePropertiesForConnection:(NSInteger)identifier cmd:(TunnelCommand)cmd extraProperties:(NSDictionary *)extraProperties;
+ (id)getValueFromPlist:(NSDictionary *)plist keyArray:(NSArray *)keyArray;

@end
