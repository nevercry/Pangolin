//
//  util.m
//  PacketTunnel
//
//  Created by yangshengfu on 07/12/2017.
//  Copyright © 2017 Minivision. All rights reserved.
//

#import "util.h"

@implementation SavedData

- (instancetype)init {
    if (self = [super init]) {
        self.chain = [NSMutableArray array];
    }
    
    return self;
}

- (BOOL)isEmpty {
    return [self.chain count] == 0;
}

- (void)append:(NSData *)data offset:(NSInteger)offset {
    NSDictionary *tmpDict = @{@"data": data, @"offset": @(offset)};
    [self.chain addObject:tmpDict];
}

- (BOOL)writeToStream:(NSOutputStream *)stream {
    BOOL result = true;
    NSInteger stopIndex = -1;
    
    for (NSInteger i = 0; i < self.chain.count; i++) {
        NSDictionary *tmpDict = [self.chain objectAtIndex:i];
        
        NSInteger written = [self writeData:[tmpDict objectForKey:@"data"] toStream:stream startingOffset:[[tmpDict objectForKey:@"offset"] integerValue]];
        
        if (written < 0) {
            result = false;
            break;
        }
        
        if (written < ([[tmpDict objectForKey:@"data"] length] - [[tmpDict objectForKey:@"offset"] integerValue])) {
            NSData *newData = [tmpDict objectForKey:@"data"];
            NSInteger newOffset = [[tmpDict objectForKey:@"offset"] integerValue] + written;
            
            self.chain[i] = @{@"data": newData,@"offset": @(newOffset)};
            
            stopIndex = i;
            break;
        }
    }
    
    if (stopIndex > 0) {
        
        [self.chain removeObjectsInRange:NSMakeRange(0, stopIndex)];
        
    } else {
        [self.chain removeAllObjects];
    }
    
    return result;
}

- (void)clear {
    [self.chain removeAllObjects];
}

- (NSInteger)writeData:(NSData *)data toStream:(NSOutputStream *)stream startingOffset:(NSInteger)offset {
    NSInteger written = 0;
    NSInteger currentOffset = offset;
    while ([stream hasSpaceAvailable] && currentOffset < [data length]) {
        uint8_t *writeBytes = (uint8_t *)[data bytes];
        writeBytes += currentOffset;
        
        NSInteger writeResult = [stream write:writeBytes maxLength:[data length] - currentOffset];
        
        if (writeResult >= 0) {
            written += writeResult;
            currentOffset += writeResult;
        } else {
            return writeResult;
        }
    }
    
    return written;
}

- (NSDictionary *)createMessagePropertiesForConnection:(NSInteger)identifier commandType:(TunnelCommand)cmd extraProperties:(NSDictionary *)extraProperties {
    
    NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithDictionary:extraProperties];
    
    [properties setObject:@(identifier) forKey: [util stringWithTunnelMessageKey:TMKIdentifier]];
    [properties setObject:@(cmd) forKey:[util stringWithTunnelMessageKey:TMKCommand]];
    
    return properties;
}


@end




@implementation util

+ (NSString *)stringWithTunnelMessageKey:(TunnelMessageKey)input {
    NSArray *arr = @[
                     @"identifier",
                     @"command",
                     @"data",
                     @"close-type",
                     @"dns-packet",
                     @"dns-packet-source",
                     @"result-code",
                     @"tunnel-type",
                     @"host",
                     @"port",
                     @"configuration",
                     @"packets",
                     @"protocols",
                     ];
    return (NSString *)[arr objectAtIndex:input];
}

+ (NSDictionary *)createMessagePropertiesForConnection:(NSInteger)identifier cmd:(TunnelCommand)cmd extraProperties:(NSDictionary *)extraProperties {
    NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithDictionary:extraProperties];
    
    [properties setObject:@(identifier) forKey: [util stringWithTunnelMessageKey:TMKIdentifier]];
    [properties setObject:@(cmd) forKey:[util stringWithTunnelMessageKey:TMKCommand]];
    
    return properties;
}

+ (id)getValueFromPlist:(NSDictionary *)plist keyArray:(NSArray *)keyArray {
    NSDictionary *subPlist = plist;
    for (NSInteger i=0;i<keyArray.count;i++) {
        NSString *key = keyArray[i];
        
        if (i == keyArray.count - 1) {
            return subPlist[key];
        } else if (subPlist[key]) {
            NSDictionary *subSubPlist = subPlist[key];
            subPlist = subSubPlist;
        } else {
            break;
        }
    }
    
    return nil;
}

@end
