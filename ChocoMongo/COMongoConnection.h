//
//  COMongoConnection.h
//  ChocoMongo
//
//  Created by Erik Aigner on 04.01.12.
//  Copyright (c) 2012 chocomoko.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface COMongoConnection : NSObject
@property (nonatomic, copy, readonly) NSString *host;
@property (nonatomic, assign, readonly) int port;
@property (nonatomic, assign, readonly) int operationTimeout;

- (id)initWithHost:(NSString *)host port:(int)port;
- (id)initWithHost:(NSString *)host port:(int)port operationTimeout:(int)millis;

- (BOOL)connect;

@end
