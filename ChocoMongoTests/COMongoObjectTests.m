//
//  COMongoObjectTests.m
//  ChocoMongo
//
//  Created by Erik Aigner on 04.01.12.
//  Copyright (c) 2012 chocomoko.com. All rights reserved.
//

#import "COMongoObjectTests.h"

#import "COMongoObject.h"

@interface COSampleMongoObject : COMongoObject
@property (nonatomic, copy) NSString *stringField;
@property (nonatomic, copy) NSData *dataField;

@end

@implementation COSampleMongoObject
@synthesize stringField = stringField_;
@synthesize dataField = dataField_;
@end

@implementation COMongoObjectTests

- (void)testPropertyExtract {
  COSampleMongoObject *mo = [COSampleMongoObject new];
  mo._id = @"id";
  mo.stringField = @"stringField";
  mo.dataField = [@"dataField" dataUsingEncoding:NSUTF8StringEncoding];
  
  NSDictionary *props = [mo serializedProperties];
  
  COSampleMongoObject *mo2 = [[COSampleMongoObject alloc] initWithDictionary:props];
  
  STAssertNotNil(mo2._id, nil);
  STAssertNotNil(mo2.stringField, nil);
  STAssertNotNil(mo2.dataField, nil);
  STAssertEqualObjects(mo._id, mo2._id, nil);
  STAssertEqualObjects(mo.stringField, mo2.stringField, nil);
  STAssertEqualObjects(mo.dataField, mo2.dataField, nil);
}

@end
