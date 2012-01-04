//
//  COMongoConnection.m
//  ChocoMongo
//
//  Created by Erik Aigner on 04.01.12.
//  Copyright (c) 2012 chocomoko.com. All rights reserved.
//

#import "COMongoConnection.h"

#import "mongo.h"

@interface COMongoConnection ()
@property (nonatomic, copy, readwrite) NSString *host;
@property (nonatomic, assign, readwrite) int port;
@property (nonatomic, assign, readwrite) int operationTimeout;
@end

@implementation COMongoConnection {
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

- (BOOL)connect {
  int status = mongo_connect(&conn_, self.host.UTF8String, self.port);
  return (status == MONGO_OK);
}

@end
