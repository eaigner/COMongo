//
//  COMongo.m
//  ChocoMongo
//
//  Created by Erik Aigner on 04.01.12.
//  Copyright (c) 2012 chocomoko.com. All rights reserved.
//

#import "COMongo.h"


#define kCOMongoErrorDomain @"com.chocomoko.ChocoMongo"
#define kCOMongoIDKey @"_id"

@interface COMongo ()
@property (nonatomic, copy, readwrite) NSString *host;
@property (nonatomic, assign, readwrite) int port;
@property (nonatomic, assign, readwrite) int operationTimeout;
@property (nonatomic, copy, readwrite) NSString *database;
@property (nonatomic, copy, readwrite) NSString *user;
@property (nonatomic, copy, readwrite) NSString *password;
@end

@implementation COMongo {
@private
  mongo mongo_;
}
@synthesize host = host_;
@synthesize port = port_;
@synthesize operationTimeout = operationTimeout_;
@synthesize database = database_;
@synthesize user = user_;
@synthesize password = password_;

- (id)initWithHost:(NSString *)host port:(int)port database:(NSString *)db {
  return [self initWithHost:host port:port database:db user:nil password:nil operationTimeout:1000];
}

- (id)initWithHost:(NSString *)host port:(int)port database:(NSString *)db user:(NSString *)user password:(NSString *)password operationTimeout:(int)millis {
  assert(host.length > 0);
  assert(port > 0);
  assert(db.length > 0);
  self = [super init];
  if (self) {
    self.host = host;
    self.port = port;
    self.database = db;
    self.user = user;
    self.password = password;
    self.operationTimeout = millis;
    
    mongo_init(&mongo_);
    mongo_set_op_timeout(&mongo_, millis);
  }
  return self;
}

- (void)dealloc {
  [self destroy];
}

- (BOOL)connect:(NSError **)error {
  int status = mongo_connect(&mongo_, self.host.UTF8String, self.port);
  
  if(status != MONGO_OK) {
    NSString *errorCause = nil;
    switch (mongo_.err) {
      case MONGO_CONN_NO_SOCKET: errorCause = @"could not create socket"; break;
      case MONGO_CONN_FAIL: errorCause = @"connection failed"; break;
      case MONGO_CONN_ADDR_FAIL: errorCause = @"could not get address info"; break;
      case MONGO_CONN_NOT_MASTER: errorCause = @"no master node"; break;
      case MONGO_CONN_BAD_SET_NAME: errorCause = @"rs name does not match replica set"; break;
      case MONGO_CONN_NO_PRIMARY: errorCause = @"cannot find primary replica set"; break;
      default: errorCause = nil; break;
    }
    
    if (errorCause != nil) {
      if (error != nil) {
        *error = [NSError errorWithDomain:kCOMongoErrorDomain
                                     code:status
                                 userInfo:[NSDictionary dictionaryWithObject:errorCause forKey:NSLocalizedDescriptionKey]];
      }
      return NO;
    }
  }
  else if (self.database.length > 0 && self.user.length > 0 && self.password.length > 0) {
    if (mongo_cmd_authenticate(&mongo_, self.database.UTF8String, self.user.UTF8String, self.password.UTF8String) != MONGO_OK) {
      NSLog(@"mongo error: could not authenticate '%@' with '%@'", self.user, self.database);
    }
  }
  
  return (status == MONGO_OK);
}

- (void)destroy {
  mongo_destroy(&mongo_);
}

static void encodeBson(bson *b, id obj, const char *key, BOOL insertRootId) {
  /* dicts */ if ([obj isKindOfClass:[NSDictionary class]]) {
    // If this is not a root object and thus a recursive call, start a new object with the key
    if (key != NULL) {
      if (bson_append_start_object(b, key) != BSON_OK) {
        NSLog(@"bson error: could not start object for key '%s'", key);
      }
    }
    
    // Append _id key first, as recommended by mongo docs
    NSString *oidStr = [obj objectForKey:kCOMongoIDKey];
    if (oidStr == nil && key == NULL && insertRootId) {
      bson_append_new_oid(b, kCOMongoIDKey.UTF8String);
    }
    else if (oidStr.length > 0) {
      bson_oid_t oid;
      bson_oid_from_string(&oid, oidStr.UTF8String);
      bson_append_oid(b, kCOMongoIDKey.UTF8String, &oid);
    }
    
    // Append other keys and values
    for (NSString *key in obj) {
      if ([key isEqualToString:kCOMongoIDKey]) {
        continue;
      }
      encodeBson(b, [obj objectForKey:key], key.UTF8String, insertRootId);
    }
    
    if (key != NULL) {
      if (bson_append_finish_object(b) != BSON_OK) {
        NSLog(@"bson error: could not finish object for key '%s'", key);
      }
    }
  }
  /* arrays */ else if ([obj isKindOfClass:[NSArray class]]) {
    if (key != NULL) {
      if (bson_append_start_array(b, key) != BSON_OK) {
        NSLog(@"bson error: could not start array for key '%s'", key);
      }
    }
    for (int c=0; c<[obj count]; c++) {
      encodeBson(b, [obj objectAtIndex:c], [[NSString stringWithFormat:@"%d", c] UTF8String], insertRootId);
    }
    if (key != NULL) {
      if (bson_append_finish_array(b) != BSON_OK) {
        NSLog(@"bson error: could not finish array for key '%s'", key);
      }
    }
  }
  /* strings */ else if ([obj isKindOfClass:[NSString class]]) {
    if (bson_append_string(b, key, [obj UTF8String]) != BSON_OK) {
      NSLog(@"bson error: could not append string for key '%s'", key);
    }
  }
  /* numbers */ else if ([obj isKindOfClass:[NSNumber class]]) {
    NSNumber *number = (NSNumber *)obj;
    const char *numType = number.objCType;
    
#define eqType(x) (strncmp(numType, x, strlen(x)) == 0)
    
    if (eqType(@encode(int))) {
      if (bson_append_int(b, key, number.intValue) != BSON_OK) {
        NSLog(@"bson error: could not append int for key '%s'", key);
      }
    }
    else if (eqType(@encode(long))) {
      if (bson_append_long(b, key, number.longValue) != BSON_OK) {
        NSLog(@"bson error: could not append long for key '%s'", key);
      }
    }
    else if (eqType(@encode(double))) {
      if (bson_append_double(b, key, number.doubleValue) != BSON_OK) {
        NSLog(@"bson error: could not append double for key '%s'", key);
      }
    }
    else if (eqType(@encode(BOOL))) {
      if (bson_append_bool(b, key, (bson_bool_t)number.boolValue) != BSON_OK) {
        NSLog(@"bson error: could not append bool for key '%s'", key);
      }
    }
  }
  /* data */ else if ([obj isKindOfClass:[NSData class]]) {
    NSData *data = (NSData *)obj;
    int bufLen = (int)data.length;
    const char buf[bufLen];
    [data getBytes:(void *)buf length:bufLen];
    
    if (bson_append_binary(b, key, BSON_BIN_BINARY, buf, bufLen) != BSON_OK) {
      NSLog(@"bson error: could not append binary for key '%s'", key);
    }
  }
  /* null */ else if ([obj isKindOfClass:[NSNull class]]) {
    if (bson_append_null(b, key) != BSON_OK) {
      NSLog(@"bson error: could not append null for key '%s'", key);
    }
  }
}

static void decodeBsonAddToCollection(const char *key, id value, id collection) {
  if ([collection isKindOfClass:[NSMutableDictionary class]]) {
    NSString *keyStr = [NSString stringWithCString:key encoding:NSUTF8StringEncoding];
    [collection setObject:value forKey:keyStr];
  }
  else if ([collection isKindOfClass:[NSMutableArray class]]) {
    [collection addObject:value];
  }
  else {
    assert(NO && "collection is not an object or array");
  }
}

static id decodeBson(bson *b, id collection) {
  bson_iterator iter[1];
  bson_iterator_init(iter, b);
  
  // Iterate
  while (bson_iterator_more(iter)) {
    bson_type type = bson_iterator_next(iter);
    const char *key = bson_iterator_key(iter);
    
    id obj = nil;
    
    if (type == BSON_OBJECT) {
      bson sub[1];
      bson_iterator_subobject(iter, sub);
      obj = decodeBson(sub, [NSMutableDictionary new]);
    }
    else if (type == BSON_ARRAY) {
      bson sub[1];
      bson_iterator_subobject(iter, sub);
      obj = decodeBson(sub, [NSMutableArray new]);
    }
    else {
      if (type == BSON_STRING) {
        obj = [NSString stringWithCString:bson_iterator_string(iter) encoding:NSUTF8StringEncoding];
      }
      else if (type == BSON_INT) {
        obj = [NSNumber numberWithInt:bson_iterator_int(iter)];
      }
      else if (type == BSON_LONG) {
        obj = [NSNumber numberWithLong:bson_iterator_long(iter)];
      }
      else if (type == BSON_DOUBLE) {
        obj = [NSNumber numberWithDouble:bson_iterator_double(iter)];
      }
      else if (type == BSON_BOOL) {
        obj = [NSNumber numberWithBool:bson_iterator_bool(iter)];
      }
      else if (type == BSON_BINDATA) {
        const char *buf = bson_iterator_bin_data(iter);
        int bufLen = bson_iterator_bin_len(iter);
        obj = [NSData dataWithBytes:buf length:bufLen];
      }
      else if (type == BSON_NULL) {
        obj = [NSNull null];
      }
    }
    
    if (obj != nil) {
      decodeBsonAddToCollection(key, obj, collection);
    }
  }
  
  return collection;
}

- (BOOL)insert:(NSDictionary *)doc intoCollection:(NSString *)collection {
  assert(self.database.length > 0);
  assert(collection.length > 0);
  assert(mongo_.connected);
  NSString *dbcol = [NSString stringWithFormat:@"%@.%@", self.database, collection];
  
  bson b[1];
  bson_init(b);
  
  [self encodeObject:doc toBSON:b insertNewRootID:YES];
  
  bson_finish(b);
  
  int status = mongo_insert(&mongo_, dbcol.UTF8String, b);
  if (status != MONGO_OK) {
    NSLog(@"mongo error: could not insert document into %@", dbcol);
  }
  
  return (status == MONGO_OK);
}

- (NSArray *)find:(NSDictionary *)query inCollection:(NSString *)collection limit:(NSInteger)limit skip:(NSInteger)skip {
  assert(self.database.length > 0);
  assert(collection.length > 0);
  
  // Encode query
  bson bsonQuery[1];
  bson_init(bsonQuery);
  if (query != nil) {
    encodeBson(bsonQuery, query, NULL, NO);
  }
  else {
    bson_empty(bsonQuery);
  }  
  bson_finish(bsonQuery);

  NSString *namespace = [NSString stringWithFormat:@"%@.%@", self.database, collection];
  
  mongo_cursor *cursor = mongo_find(&mongo_,
                                    namespace.UTF8String,
                                    bsonQuery,
                                    NULL,
                                    limit,
                                    skip,
                                    0); // cursor flags */
  
  while (cursor != NULL && mongo_cursor_next(cursor) == MONGO_OK) {
    id obj = [self decodeBSONToObject:&cursor->current];
    NSLog(@"obj: %@", obj);
  }
  
  mongo_cursor_destroy(cursor);
  
  return nil;
}

@end

@implementation COMongo (BSON)

- (void)encodeObject:(id)obj toBSON:(bson *)bson insertNewRootID:(BOOL)flag {
  encodeBson(bson, obj, NULL, flag);
}

- (id)decodeBSONToObject:(bson *)bson {
  return decodeBson(bson, [NSMutableDictionary new]);
}

@end
