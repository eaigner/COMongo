//
//  COMongoTests.m
//  ChocoMongo
//
//  Created by Erik Aigner on 04.01.12.
//  Copyright (c) 2012 chocomoko.com. All rights reserved.
//

#import "COMongoTests.h"

#import "COMongo.h"

@implementation COMongoTests

- (void)testBSONEncode {
  bson b[1];
  bson_init(b);
  
  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                        @"obj1", @"obj1Key",
                        @"obj2", @"obj2Key",
                        [NSArray arrayWithObjects:@"a0", @"a1", @"a2", @"a3", nil], @"arrayKey",
                        [NSDictionary dictionaryWithObject:@"dictObj1" forKey:@"dictKey1"], @"dictKey0",
                        nil];
  
  [[COMongo new] encodeObject:dict toBSON:b];
  
  bson_finish(b);
  bson_print(b);
}

@end
