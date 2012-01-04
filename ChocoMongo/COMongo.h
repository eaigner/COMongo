//
//  COMongo.h
//  ChocoMongo
//
//  Created by Erik Aigner on 04.01.12.
//  Copyright (c) 2012 chocomoko.com. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "mongo.h"

@interface COMongo : NSObject
@property (nonatomic, copy, readonly) NSString *host;
@property (nonatomic, assign, readonly) int port;
@property (nonatomic, assign, readonly) int operationTimeout;

- (id)initWithHost:(NSString *)host port:(int)port;
- (id)initWithHost:(NSString *)host port:(int)port operationTimeout:(int)millis;

- (BOOL)connect:(NSError **)error;
- (void)destroy;

/*!
 @method performWithDatabase:collection:block:
 @abstract Performs a command with the given database and collection.
 */
- (void)performWithDatabase:(NSString *)db collection:(NSString *)collection block:(dispatch_block_t)block;

/*!
 @method insert:
 @abstract Encodes the keys and values of |doc| in BSON and inserts it into the collection.
 @discussion Has to be called inside -performWithDatabase:collection:block:
 */
- (void)insert:(NSDictionary *)doc;

@end

@interface COMongo (BSON)

- (void)encodeObject:(id)obj toBSON:(bson *)bson;

@end
