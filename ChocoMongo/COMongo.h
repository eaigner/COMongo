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
@property (nonatomic, copy, readonly) NSString *database;
@property (nonatomic, copy, readonly) NSString *user;
@property (nonatomic, copy, readonly) NSString *password;

/*!
 @property healthy
 @abstract Checks if the connection is healthy
 */
@property (nonatomic, readonly, getter = isHealthy) BOOL healthy;

/*!
 @property lastErrorString
 @abstract Returns the last encountered error message
 */
@property (nonatomic, readonly) NSString *lastErrorString;

/*!
 @property lastErrorCode
 @abstract Returns the last encountered error code
 */
@property (nonatomic, readonly) NSInteger lastErrorCode;

- (id)initWithHost:(NSString *)host port:(int)port database:(NSString *)db;
- (id)initWithHost:(NSString *)host port:(int)port database:(NSString *)db user:(NSString *)user password:(NSString *)password operationTimeout:(int)millis;

- (BOOL)connect:(NSError **)error;
- (void)destroy;
- (const char *)namespaceForCollection:(NSString *)collection;

/*!
 @method insert:intoCollection:
 @abstract Encodes the keys and values of |doc| in BSON and inserts it into the collection.
 */
- (BOOL)insert:(NSDictionary *)doc intoCollection:(NSString *)collection;

/*!
 @method find:inCollection:limit:skip:
 @abstract Finds matching documents in the provided collection.
 */
- (NSArray *)find:(NSDictionary *)query inCollection:(NSString *)collection limit:(NSInteger)limit skip:(NSInteger)skip;

@end

@interface COMongo (BSON)

- (void)encodeObject:(id)obj toBSON:(bson *)bson insertNewRootID:(BOOL)flag;
- (id)decodeBSONToObject:(bson *)bson;

@end
