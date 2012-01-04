#### COMongo

COMongo is an Objective-C wrapper around the MongoDB C driver.
Be aware that this project is under development and is not suitable for production yet,
contributions are always welcome!

#### License

COMongo uses the simplified (2 clause) BSD license (see [LICENSE](https://github.com/eaigner/COMongo/blob/master/LICENSE) file)

#### Example

    NSError *error = nil;
    COMongo *mongo = [[COMongo alloc] initWithHost:MONGO_HOST port:MONGO_PORT database:MONGO_DB];
    
    // Try to connect to the mongo db
    if ([mongo connect:&error]) {

      // Create a new document
      NSDictionary *doc = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"foo", @"stringKey",
                           [@"foo" dataUsingEncoding:NSUTF8StringEncoding], @"binaryKey",
                           [NSNumber numberWithInt:3], @"intKey",
                           [NSNumber numberWithLong:5], @"longKey",
                           [NSNumber numberWithDouble:4.78], @"doubleKey",
                           [NSNumber numberWithBool:YES], @"boolKey",
                           [NSArray arrayWithObjects:@"a0", @"a1", @"a2", @"a3", nil], @"arrayKey",
                           [NSDictionary dictionaryWithObject:@"subDictObj" forKey:@"subDictKey"], @"dictKey", nil];

      // Insert the document into |mycollection|
      if ([mongo insert:doc intoCollection:@"mycollection"]) {
        NSLog(@"done: inserted doc!");
      }
    }
    else {
      NSLog(@"error: could not connect to mongo (%@)", error.localizedDescription);
    }

#### TODO

- Support more BSON types
- Finish mongo command implementations