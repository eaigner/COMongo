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
  mongo_destroy(&conn_);
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

@end
