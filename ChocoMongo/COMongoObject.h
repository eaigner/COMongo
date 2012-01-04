//
//  COMongoObject.h
//  ChocoMongo
//
//  Created by Erik Aigner on 04.01.12.
//  Copyright (c) 2012 chocomoko.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface COMongoObject : NSObject
@property (nonatomic, copy) NSString *_id;

- (id)initWithDictionary:(NSDictionary *)dict;

- (NSDictionary *)serializedProperties;
- (NSData *)serializedPropertiesJSON;

@end
