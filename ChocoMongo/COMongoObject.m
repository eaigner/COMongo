//
//  COMongoObject.m
//  ChocoMongo
//
//  Created by Erik Aigner on 04.01.12.
//  Copyright (c) 2012 chocomoko.com. All rights reserved.
//

#import "COMongoObject.h"

#import <objc/runtime.h>

@implementation COMongoObject
@synthesize _id = _id_;

- (id)initWithDictionary:(NSDictionary *)dict {
  self = [super init];
  if (self) {
    for (NSString *key in dict) {
      id value = [dict objectForKey:key];
      if (value != nil && value != [NSNull null]) {
        [self setValue:value forKey:key];
      }
    }
  }
  return self;
}

- (NSDictionary *)serializedProperties {
  NSMutableDictionary *props = [NSMutableDictionary new];
  
  // Get current class
  id clazz = self.class;
  
  // Extract properties while class not reached COMongoObject's superclass
  while (clazz != [COMongoObject superclass]) {
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList(clazz, &outCount);
    for(i = 0; i < outCount; i++) {
      objc_property_t property = properties[i];
      const char *propName = property_getName(property);
      if(propName) {
        NSString *propertyName = [NSString stringWithCString:propName encoding:NSUTF8StringEncoding];
        id value = [self valueForKey:propertyName];
        if (value != nil) {
          [props setObject:value forKey:propertyName];
        }
      }
    }
    free(properties);
    
    // Continue extracting from superclass
    clazz = class_getSuperclass(clazz);
  }
  
  return [NSDictionary dictionaryWithDictionary:props];;
}

- (NSData *)serializedPropertiesJSON {
  NSError *jsonError = nil;
  id obj = [NSJSONSerialization dataWithJSONObject:[self serializedProperties]
                                           options:0
                                             error:&jsonError];
  if (jsonError != nil) {
    NSLog(@"error: could not serialize properties to JSON (%@)", jsonError.localizedDescription);
    return nil;
  }
  return obj;
}

@end
