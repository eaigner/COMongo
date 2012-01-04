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
@property (nonatomic, copy) NSString *db;
@property (nonatomic, copy) NSString *collection;
@end

@implementation COMongo {
@private
  mongo mongo_;
}
@synthesize host = host_;
@synthesize port = port_;
@synthesize operationTimeout = operationTimeout_;
@synthesize db = db_;
@synthesize collection = collection_;

- (id)initWithHost:(NSString *)host port:(int)port {
  return [self initWithHost:host port:port operationTimeout:1000];
}

- (id)initWithHost:(NSString *)host port:(int)port operationTimeout:(int)millis {
  assert(host.length > 0);
  assert(port > 0);
  self = [super init];
  if (self) {
    self.host = host;
    self.port = port;
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

- (void)performWithDatabase:(NSString *)db collection:(NSString *)collection block:(dispatch_block_t)block {
  @synchronized (self) {
    self.db = db;
    self.collection = collection;
    block();
    self.db = nil;
    self.collection = nil;
  }
}

- (BOOL)insert:(NSDictionary *)doc {
  assert(self.db != nil);
  assert(self.collection != nil);
  assert(mongo_.connected);
  NSString *dbcol = [NSString stringWithFormat:@"%@.%@", self.db, self.collection];
  
  bson b[1];
  bson_init(b);
  
  [self encodeObject:doc toBSON:b insertNewRootID:YES];
  
  bson_finish(b);
  
  if (mongo_insert(&mongo_, dbcol.UTF8String, b) != MONGO_OK) {
    NSLog(@"mongo error: could not insert document into %@", dbcol);
    return NO;
  }
  return YES;
}

@end

@implementation COMongo (BSON)

- (void)encodeObject:(id)obj toBSON:(bson *)bson insertNewRootID:(BOOL)flag {
  encodeBson(bson, obj, NULL, flag);
}

@end
