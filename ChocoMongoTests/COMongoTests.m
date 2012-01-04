//
//  COMongoTests.m
//  ChocoMongo
//
//  Created by Erik Aigner on 04.01.12.
//  Copyright (c) 2012 chocomoko.com. All rights reserved.
//

#import "COMongoTests.h"

#import "COMongo.h"
#import "COMongoCredentials.h"

@implementation COMongoTests

- (void)testBSONEncode {
  bson b[1];
  bson_init(b);
  
  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                        @"obj1", @"obj1Key",
                        @"obj2", @"obj2Key",
                        [NSNumber numberWithInt:3], @"intKey",
                        [NSNumber numberWithLong:5], @"longKey",
                        [NSNumber numberWithDouble:4.876], @"doubleKey",
                        [NSNumber numberWithBool:YES], @"boolKey",
                        [@"dataObj" dataUsingEncoding:NSUTF8StringEncoding], @"dataKey",
                        [NSArray arrayWithObjects:@"a0", @"a1", @"a2", @"a3", nil], @"arrayKey",
                        [NSDictionary dictionaryWithObject:@"dictObj1" forKey:@"dictKey1"], @"dictKey0",
                        nil];
  
  [[COMongo new] encodeObject:dict toBSON:b insertNewRootID:NO];
  
  bson_finish(b);
  bson_print(b);
}

- (void)testInsert {
  NSDictionary *doc = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"str", @"strKey",
                       [NSNumber numberWithInt:3], @"intKey",
                       [NSNumber numberWithLong:5], @"longKey",
                       [NSNumber numberWithDouble:4.876], @"doubleKey",
                       [NSNumber numberWithBool:YES], @"boolKey",
                       [@"dataObj" dataUsingEncoding:NSUTF8StringEncoding], @"dataKey",
                       [NSArray arrayWithObjects:@"a0", @"a1", @"a2", @"a3", nil], @"arrayKey",
                       [NSDictionary dictionaryWithObject:@"subDictObj" forKey:@"subDictKey"], @"dictKey", nil];
  
  COMongo *mongo = [[COMongo alloc] initWithHost:MONGO_HOST
                                            port:MONGO_PORT
                                        database:MONGO_DB
                                            user:MONGO_USER
                                        password:MONGO_PW
                                operationTimeout:1000];
  
  NSError *error = nil;
  BOOL connected = [mongo connect:&error];
  STAssertTrue(connected, nil);
  STAssertNil(error, @"error: %@", error);
  
  if (connected) {    
    BOOL inserted = [mongo insert:doc intoCollection:@"chocomongo"];
    STAssertTrue(inserted, nil);
    
    [mongo destroy];
  }
}

@end
