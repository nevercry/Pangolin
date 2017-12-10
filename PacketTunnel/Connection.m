//
//  Connection.m
//  PacketTunnel
//
//  Created by yangshengfu on 07/12/2017.
//  Copyright © 2017 Minivision. All rights reserved.
//

#import "Connection.h"
#import "Tunnel.h"
#import "util.h"

@implementation Connection

- (instancetype)initWithConnectionIdentifier:(NSInteger)identifer parentTunnel:(Tunnel *)tunnel {
    
    self = [self initWithConnectionIdentifier:identifer];
    self.isExclusiveTunnel = false;
    self.tunnel = tunnel;
    
    if (tunnel) {
        
        [tunnel addConnection:self];
    }
    
    return self;
}

- (instancetype)initWithConnectionIdentifier:(NSInteger)identifer {
    _isExclusiveTunnel = true;
    _identifier = identifer;
    
    if (self = [super init]) {
        
        self.savedData = [[SavedData alloc] init];
        
    }
    
    return self;
}

- (void)setNewTunnel:(Tunnel *)tunnel {
    self.tunnel = tunnel;
    
    if (tunnel) {
        [tunnel addConnection:self];
    }
}

- (void)closeConnectionWithDirection:(TunnelConnectionCloseDirection)direction {
    if (direction != TCCDNone && direction != self.currentCloseDirection) {
        self.currentCloseDirection = TCCDAll;
    } else {
        self.currentCloseDirection = direction;
    }
    
    if (self.tunnel && self.currentCloseDirection == TCCDAll) {
        
        if (self.isExclusiveTunnel) {
            [self.tunnel closeTunnel];
        } else {
            [self.tunnel dropConnection:self];
            self.tunnel = nil;
        }
    }
}

- (void)abort {
    [self.savedData clear];
}

- (void)sendData:(NSData *)data {
    
}

- (void)sendData:(NSData *)data endPointHost:(NSString *)host port:(NSNumber *)port {
    
}

- (void)sendPackets:(NSArray *)packets protocols:(NSArray *)protocols {
    
}

- (void)suspend {
    
}

- (void)resume {
    
}

- (void)handleOpenCompleted:(TunnelConnectionOpenResult)resultCode properties:(NSDictionary *)properties {
    
}

- (BOOL)isClosedCompletely {
    return self.currentCloseDirection == TCCDAll;
}

- (BOOL)isClosedForRead {
    return self.currentCloseDirection != TCCDNone && self.currentCloseDirection != TCCDWrite;
}

- (BOOL)isClosedForWrite {
    return self.currentCloseDirection != TCCDNone && self.currentCloseDirection != TCCDRead;
}














@end
