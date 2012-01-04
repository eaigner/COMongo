//
//  COMongo.m
//  ChocoMongo
//
//  Created by Erik Aigner on 04.01.12.
//  Copyright (c) 2012 chocomoko.com. All rights reserved.
//

#import "COMongo.h"

#import "mongo.h"

#define kCOMongoErrorDomain @"com.chocomoko.ChocoMongo"
#define kCOMongoIDKey @"_id"

@interface COMongo ()
@property (nonatomic, copy, readwrite) NSString *host;
@property (nonatomic, assign, readwrite) int port;
@property (nonatomic, assign, readwrite) int operationTimeout;
@end

@implementation COMongo {
@private
  mongo conn_;
}
@synthesize host = host_;
@synthesize port = port_;
@synthesize operationTimeout = operationTimeout_;

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
    
    mongo_init(&conn_);
    mongo_set_op_timeout(&conn_, millis);
  }
  return self;
}

- (void)dealloc {
  [self destroy];
}

- (BOOL)connect:(NSError **)error {
  int status = mongo_connect(&conn_, self.host.UTF8String, self.port);
  
  if(status != MONGO_OK) {
    NSString *errorCause = nil;
    switch (conn_.err) {
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
  mongo_destroy(&conn_);
}

static void bsonForDictionary(bson *bson, NSDictionary *dict) {
  bson_init(bson);
  
  // Append _id key first
  NSString *oid = [dict objectForKey:kCOMongoIDKey];
  if (oid == nil) {
    bson_append_new_oid(bson, kCOMongoIDKey.UTF8String);
  }
  else {
    bson_oid_t boid;
    bson_oid_from_string(&boid, oid.UTF8String);
    bson_append_oid(bson, kCOMongoIDKey.UTF8String, &boid);
  }
  
  // Append other keys and values
  for (NSString *key in dict) {
    if ([key isEqualToString:kCOMongoIDKey]) {
      continue;
    }
    const char *ckey = key.UTF8String;
    id obj = [dict objectForKey:key];
    
    // Strings
    if ([obj isKindOfClass:[NSString class]]) {
      const char *cvalue = [obj UTF8String];
      if (bson_append_string(bson, ckey, cvalue) != BSON_OK) {
        NSLog(@"bson error: could not append string for key '%s'", ckey);
      }
    }
    
    // Numbers
    else if ([obj isKindOfClass:[NSNumber class]]) {
      NSNumber *number = (NSNumber *)obj;
      const char *numType = number.objCType;
      
#define eqType(x) (strncmp(numType, x, strlen(x)) == 0)
      
      if (eqType(@encode(int))) {
        if (bson_append_int(bson, ckey, number.intValue) != BSON_OK) {
          NSLog(@"bson error: could not append int for key '%s'", ckey);
        }
      }
      else if (eqType(@encode(long))) {
        if (bson_append_long(bson, ckey, number.longValue) != BSON_OK) {
          NSLog(@"bson error: could not append long for key '%s'", ckey);
        }
      }
      else if (eqType(@encode(double))) {
        if (bson_append_double(bson, ckey, number.doubleValue) != BSON_OK) {
          NSLog(@"bson error: could not append double for key '%s'", ckey);
        }
      }
    }
    
    // Data
    else if ([obj isKindOfClass:[NSData class]]) {
      NSData *data = (NSData *)obj;
      int bufLen = (int)data.length;
      const char buf[bufLen];
      [data getBytes:(void *)buf length:bufLen];
      
      if (bson_append_binary(bson, ckey, BSON_BIN_BINARY, buf, bufLen) != BSON_OK) {
        NSLog(@"bson error: could not append binary for key '%s'", ckey);
      }
    }
  }
  
  bson_finish(bson);
}

- (void)performWithDatabase:(NSString *)db collection:(NSString *)collection block:(dispatch_block_t)block {
  // TODO: impl
}

- (void)insert:(NSDictionary *)doc {
  // TODO: impl
}

@end
