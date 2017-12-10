//
//  Connection.h
//  PacketTunnel
//
//  Created by yangshengfu on 07/12/2017.
//  Copyright © 2017 Minivision. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Tunnel;
@class SavedData;

typedef enum : NSUInteger {
    TCCDNone = 1,
    TCCDRead,
    TCCDWrite,
    TCCDAll
} TunnelConnectionCloseDirection;

typedef enum : NSUInteger {
    TCORSuccess,
    TCORInvalidParam,
    TCORNoSuchHost,
    TCORRefused,
    TCORTimeout,
    TCORInternalError
} TunnelConnectionOpenResult;


@interface Connection : NSObject

@property (nonatomic) NSInteger identifier;

@property (nonatomic,strong) Tunnel* tunnel;

@property (nonatomic, strong) SavedData* savedData;

@property (nonatomic) TunnelConnectionCloseDirection currentCloseDirection;

@property (nonatomic) BOOL isExclusiveTunnel;

- (BOOL)isClosedForRead;

- (BOOL)isClosedForWrite;

- (BOOL)isClosedCompletely;

- (instancetype)initWithConnectionIdentifier:(NSInteger)identifer parentTunnel:(Tunnel *)tunnel;

- (instancetype)initWithConnectionIdentifier:(NSInteger)identifer;

- (void)setNewTunnel:(Tunnel *)tunnel;

- (void)closeConnectionWithDirection:(TunnelConnectionCloseDirection)direction;

- (void)abort;

- (void)suspend;

- (void)resume;

- (void)sendData:(NSData *)data;

- (void)sendData:(NSData *)data endPointHost:(NSString *)host port:(NSNumber *)port;

- (void)sendPackets:(NSArray *)packets protocols:(NSArray *)protocols;

- (void)handleOpenCompleted:(TunnelConnectionOpenResult)resultCode properties:(NSDictionary *)properties;


@end
