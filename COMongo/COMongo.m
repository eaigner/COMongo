//
//  COMongo.m
//  COMongo
//
//  Created by Erik Aigner on 04.01.12.
//  Copyright (c) 2012 chocomoko.com. All rights reserved.
//

#import "COMongo.h"

#import <objc/runtime.h>

#define kCOMongoErrorDomain @"com.chocomoko.ChocoMongo"
#define kCOMongoIDKey @"_id"

@interface COMongo ()
@property (nonatomic, copy, readwrite) NSString *host;
@property (nonatomic, assign, readwrite) int port;
@property (nonatomic, assign, readwrite) int operationTimeout;
@property (nonatomic, copy, readwrite) NSString *database;
@end

@implementation COMongo {
@private
  mongo *mongo_;
}
@synthesize host = host_;
@synthesize port = port_;
@synthesize operationTimeout = operationTimeout_;
@synthesize database = database_;

- (id)initWithHost:(NSString *)host port:(int)port database:(NSString *)db {
  return [self initWithHost:host port:port database:db operationTimeout:1000];
}

- (id)initWithHost:(NSString *)host port:(int)port database:(NSString *)db operationTimeout:(int)millis {
  assert(host.length > 0);
  assert(port > 0);
  assert(db.length > 0);
  self = [super init];
  if (self) {
    mongo_ = malloc(sizeof(mongo));
    self.host = host;
    self.port = port;
    self.database = db;
    self.operationTimeout = millis;
    
    mongo_init(mongo_);
    mongo_set_op_timeout(mongo_, millis);
  }
  return self;
}

- (void)dealloc {
  [self destroy];
}

- (BOOL)connect:(NSError **)error {
  int status = mongo_connect(mongo_, self.host.UTF8String, self.port);
  
  if(status != MONGO_OK) {
    NSString *errorCause = nil;
    switch (mongo_->err) {
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

- (BOOL)authenticateWithUser:(NSString *)user password:(NSString *)password {
  assert(user.length > 0);
  assert(password.length > 0);
  int status = mongo_cmd_authenticate(mongo_, self.database.UTF8String, user.UTF8String, password.UTF8String);
  if (status != MONGO_OK) {
    NSLog(@"mongo error: could not authenticate '%@' with '%@'", user, self.database);
  }
  return (status == MONGO_OK);
}

- (void)destroy {
  if (mongo_ != NULL) {
    mongo_destroy(mongo_);
    free(mongo_);
    mongo_ = NULL;
  }
}

- (BOOL)isHealthy {
  return (mongo_check_connection(mongo_) == MONGO_OK);
}

- (NSString *)lastErrorString {
  char *str = mongo_->lasterrstr;
  if (str != NULL) {
    return [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
  }
  return nil;
}

- (NSInteger)lastErrorCode {
  return (NSInteger)mongo_->lasterrcode;
}

static void encodeBson(bson *b, id obj, const char *key) {
  if ([obj isKindOfClass:[NSDictionary class]]) {
    // If this is not a root object and thus a recursive call, start a new object with the key
    if (key != NULL) {
      if (bson_append_start_object(b, key) != BSON_OK) {
        NSLog(@"bson error: could not start object for key '%s'", key);
      }
    }
    
    // Append _id key first, as recommended by mongo docs
    NSString *oidStr = [obj objectForKey:kCOMongoIDKey];
    if (oidStr.length > 0) {
      bson_oid_t oid;
      bson_oid_from_string(&oid, oidStr.UTF8String);
      bson_append_oid(b, kCOMongoIDKey.UTF8String, &oid);
    }
    
    // Append other keys and values
    for (NSString *key in obj) {
      if ([key isEqualToString:kCOMongoIDKey]) {
        continue;
      }
      encodeBson(b, [obj objectForKey:key], key.UTF8String);
    }
    
    if (key != NULL) {
      if (bson_append_finish_object(b) != BSON_OK) {
        NSLog(@"bson error: could not finish object for key '%s'", key);
      }
    }
  }
  else if ([obj isKindOfClass:[NSArray class]]) {
    if (key != NULL) {
      if (bson_append_start_array(b, key) != BSON_OK) {
        NSLog(@"bson error: could not start array for key '%s'", key);
      }
    }
    for (int c=0; c<[obj count]; c++) {
      encodeBson(b, [obj objectAtIndex:c], [[NSString stringWithFormat:@"%d", c] UTF8String]);
    }
    if (key != NULL) {
      if (bson_append_finish_array(b) != BSON_OK) {
        NSLog(@"bson error: could not finish array for key '%s'", key);
      }
    }
  }
  else if ([obj isKindOfClass:[NSString class]]) {
    if ([obj isOID]) {
      bson_oid_t oid[1];
      [obj getOID:oid];
      if (bson_append_oid(b, key, oid) != BSON_OK) {
        NSLog(@"bson error: could not append oid for key '%s'", key);
      }
    }
    else {
      if (bson_append_string(b, key, [obj UTF8String]) != BSON_OK) {
        NSLog(@"bson error: could not append string for key '%s'", key);
      }
    }
  }
  else if ([obj isKindOfClass:[NSNumber class]]) {
    NSNumber *number = (NSNumber *)obj;
    const char *objCType = number.objCType;
    
    // DEVNOTE: Obj-C type encoding table
    // http://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
    
    int status = BSON_OK;
    switch (*objCType) {
      case 'd': // double
      case 'f': // float
        status = bson_append_double(b, key, [number doubleValue]);
        break;
      case 'l': // long
      case 'L': // unsigned long
        status = bson_append_long(b, key, [number longValue]);
        break;
      case 'q': // long long
      case 'Q': // unsigned long long
        status = bson_append_long(b, key, [number longLongValue]);
        break;
      case 'B': // bool
      case 'c': // char (BOOL is encoded as 'c')
        status = bson_append_bool(b, key, [number boolValue]);
        break;
      case 'C': // unsigned char
      case 's': // short
      case 'S': // unsigned short
      case 'i': // int
      case 'I': // unsigned int
      default:
        status = bson_append_int(b, key, [number intValue]);
        break;
    }
    if (status != BSON_OK) {
      NSLog(@"bson error: could not append number for key '%s'", key);
    }
  }
  else if ([obj isKindOfClass:[NSData class]]) {
    NSData *data = (NSData *)obj;
    int bufLen = (int)data.length;
    const char buf[bufLen];
    [data getBytes:(void *)buf length:bufLen];
    
    if (bson_append_binary(b, key, BSON_BIN_BINARY, buf, bufLen) != BSON_OK) {
      NSLog(@"bson error: could not append binary for key '%s'", key);
    }
  }
  else if ([obj isKindOfClass:[NSNull class]]) {
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
    id obj = nil;
    
    bson_type type = bson_iterator_next(iter);
    const char *key = bson_iterator_key(iter);
    
    switch (type) {
      case BSON_EOO:
        break;
      case BSON_DOUBLE:
        obj = [NSNumber numberWithDouble:bson_iterator_double(iter)];
        break;
      case BSON_STRING:
        obj = [NSString stringWithCString:bson_iterator_string(iter) encoding:NSUTF8StringEncoding];
        break;
      case BSON_OBJECT: {
        bson sub[1];
        bson_iterator_subobject(iter, sub);
        obj = decodeBson(sub, [NSMutableDictionary new]);
      }
        break;
      case BSON_ARRAY: {
        bson sub[1];
        bson_iterator_subobject(iter, sub);
        obj = decodeBson(sub, [NSMutableArray new]);
      }
        break;
      case BSON_BINDATA: {
        const char *buf = bson_iterator_bin_data(iter);
        int bufLen = bson_iterator_bin_len(iter);
        obj = [NSData dataWithBytes:buf length:bufLen];
      }
        break;
      case BSON_UNDEFINED:
        break;
      case BSON_OID:
        obj = [NSString OIDStringWithOID:bson_iterator_oid(iter)];
        break;
      case BSON_BOOL:
        obj = [NSNumber numberWithBool:bson_iterator_bool(iter)];
        break;
      case BSON_DATE:
        break;
      case BSON_NULL:
        obj = [NSNull null];
        break;
      case BSON_REGEX:
        break;
      case BSON_DBREF: // deprecated
        break;
      case BSON_CODE:
        break;
      case BSON_SYMBOL:
        break;
      case BSON_CODEWSCOPE:
        break;
      case BSON_INT:
        obj = [NSNumber numberWithInt:bson_iterator_int(iter)];
        break;
      case BSON_TIMESTAMP:
        break;
      case BSON_LONG:
        obj = [NSNumber numberWithLong:bson_iterator_long(iter)];
        break;
    }
    
    if (obj != nil) {
      decodeBsonAddToCollection(key, obj, collection);
    }
  }
  
  return collection;
}

static const char *namespace(NSString *database, NSString *collection) {
  return [[NSString stringWithFormat:@"%@.%@", database, collection] UTF8String];
}

- (BOOL)insert:(NSDictionary *)doc intoCollection:(NSString *)collection {
  assert(self.database.length > 0);
  assert(collection.length > 0);
  assert(mongo_->connected);
  
  bson b[1];
  bson_init(b);
  
  [self encodeObject:doc toBSON:b];
  
  bson_finish(b);
  
  const char *ns = namespace(self.database, collection);
  int status = mongo_insert(mongo_, ns, b);
  
  if (status != MONGO_OK) {
    NSLog(@"mongo error: could not insert document into '%s'", ns);
  }
  
  bson_destroy(b);
  
  return (status == MONGO_OK);
}

- (NSArray *)find:(NSDictionary *)query inCollection:(NSString *)collection limit:(NSInteger)limit skip:(NSInteger)skip {
  assert(self.database.length > 0);
  assert(collection.length > 0);
  assert(mongo_->connected);
  
  // Encode query
  bson b[1];
  bson_init(b);
  if (query != nil) {
    encodeBson(b, query, NULL);
  }
  else {
    bson_empty(b);
  }  
  bson_finish(b);
  
  NSMutableArray *results = [NSMutableArray new];
  
  const char *ns = namespace(self.database, collection);
  mongo_cursor *cursor = mongo_find(mongo_, ns, b, NULL, limit, skip, 0);
  
  while (cursor != NULL && mongo_cursor_next(cursor) == MONGO_OK) {
    id obj = [self decodeBSONToObject:&cursor->current];
    [results addObject:obj];
  }
  
  mongo_cursor_destroy(cursor);
  bson_destroy(b);
  
  return results;
}

@end

@implementation COMongo (BSON)

- (void)encodeObject:(id)obj toBSON:(bson *)bson {
  encodeBson(bson, obj, NULL);
}

- (id)decodeBSONToObject:(bson *)bson {
  return decodeBson(bson, [NSMutableDictionary new]);
}

@end

@implementation NSString (MongoOID)

static char kNSStringIsOIDKey;

+ (NSString *)newOID {
  bson_oid_t oid[1];
  bson_oid_gen(oid);
  return [self OIDStringWithOID:oid];
}

+ (NSString *)OIDStringWithOID:(bson_oid_t *)oid {
  char buf[24];
  bson_oid_to_string(oid, buf);
  NSString *str = [[NSString alloc] initWithBytes:buf length:24 encoding:NSUTF8StringEncoding];
  return [self OIDStringWithString:str];
}

+ (NSString *)OIDStringWithString:(NSString *)string {
  NSString *oidStr = [string copy];
  objc_setAssociatedObject(oidStr, &kNSStringIsOIDKey, [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  return oidStr;
}

- (BOOL)isOID {
  return [(NSNumber *)objc_getAssociatedObject(self, &kNSStringIsOIDKey) boolValue];
}

- (void)getOID:(bson_oid_t *)oid {
  if ([self isOID]) {
    bson_oid_from_string(oid, self.UTF8String);
  }
}

@end
