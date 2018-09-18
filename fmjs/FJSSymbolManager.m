//
//  FJSBridgeParser.m
//  yd
//
//  Created by August Mueller on 8/21/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import "FJSSymbolManager.h"
#import "FJS.h"

@import ObjectiveC;

@interface FJSSymbolManager ()

@property (strong) FJSSymbol *currentFunction;
@property (strong) FJSSymbol *currentClass;
@property (strong) FJSSymbol *currentMethod;

@end

@implementation FJSSymbolManager

+ (instancetype)sharedManager {
    
    static FJSSymbolManager *bp = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bp = [[self alloc] init];
    });
    
    
    return bp;
    
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _symbols = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (FJSSymbol*)symbolForName:(NSString*)name {
    
    return [self symbolForName:name inObject:nil];
}

+ (FJSSymbol*)symbolForName:(NSString*)name inObject:(nullable id)object {
    FJSSymbol *sym = nil;
    
    if (object) {
        
        if (object == [object class]) {
            NSString *className = NSStringFromClass(object);
            FJSSymbol *classSymbol = [[[self sharedManager] symbols] objectForKey:className];
            FMAssert(classSymbol);
            sym = [classSymbol classMethodNamed:name];
        }
        else {
            
#pragma message "FIXME: This isn't going to fly for getting bridge specific info out of a subclass / superclass relationship."
#pragma message "FIXME: make a more generalized solution, that'll also work with Class objects"
            Class currentClass = [object class];
            NSString *className = NSStringFromClass(currentClass);
            FJSSymbol *instanceSymbol = [[[self sharedManager] symbols] objectForKey:className];
            while (!instanceSymbol && [currentClass superclass]) {
                currentClass = [currentClass superclass];
                className = NSStringFromClass(currentClass);
                instanceSymbol = [[[self sharedManager] symbols] objectForKey:className];
            }
            
            
            FMAssert(instanceSymbol);
            sym = [instanceSymbol instanceMethodNamed:name];
        }
        
        return sym;
    }
    
    
    sym = [[[self sharedManager] symbols] objectForKey:name];
    
    if (!sym) {
        
        Class objCClass = NSClassFromString(name);
        
        if (objCClass) {
            sym = [[FJSSymbol alloc] init];
            [sym setSymbolType:@"class"];
            [sym setName:name];
            
            [[[self sharedManager] symbols] setObject:sym forKey:name];
        }
        
    }
    
    return sym;
}

- (void)parseBridgeFileAtPath:(NSString*)bridgePath {
    
    NSXMLParser *p = [[NSXMLParser alloc] initWithContentsOfURL:[NSURL fileURLWithPath:bridgePath]];
    
    [p setDelegate:self];
    
    [p parse];
    
    
}


- (void)parserDidStartDocument:(NSXMLParser *)parser {
    
}

- (void)parserDidEndDocument:(NSXMLParser *)parser {
    
}


//// DTD handling methods for various declarations.
//- (void)parser:(NSXMLParser *)parser foundNotationDeclarationWithName:(NSString *)name publicID:(nullable NSString *)publicID systemID:(nullable NSString *)systemID;
//
//- (void)parser:(NSXMLParser *)parser foundUnparsedEntityDeclarationWithName:(NSString *)name publicID:(nullable NSString *)publicID systemID:(nullable NSString *)systemID notationName:(nullable NSString *)notationName;
//
//- (void)parser:(NSXMLParser *)parser foundAttributeDeclarationWithName:(NSString *)attributeName forElement:(NSString *)elementName type:(nullable NSString *)type defaultValue:(nullable NSString *)defaultValue;
//
//- (void)parser:(NSXMLParser *)parser foundElementDeclarationWithName:(NSString *)elementName model:(NSString *)model;
//
//- (void)parser:(NSXMLParser *)parser foundInternalEntityDeclarationWithName:(NSString *)name value:(nullable NSString *)value;
//
//- (void)parser:(NSXMLParser *)parser foundExternalEntityDeclarationWithName:(NSString *)name publicID:(nullable NSString *)publicID systemID:(nullable NSString *)systemID;


// sent when the parser finds an element start tag.
// In the case of the cvslog tag, the following is what the delegate receives:
//   elementName == cvslog, namespaceURI == http://xml.apple.com/cvslog, qualifiedName == cvslog
// In the case of the radar tag, the following is what's passed in:
//    elementName == radar, namespaceURI == http://xml.apple.com/radar, qualifiedName == radar:radar
// If namespace processing >isn't< on, the xmlns:radar="http://xml.apple.com/radar" is returned as an attribute pair, the elementName is 'radar:radar' and there is no qualifiedName.
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName attributes:(NSDictionary<NSString *, NSString *> *)attributeDict {
    
    
    FJSSymbol *sym = [[FJSSymbol alloc] init];
    [sym setSymbolType:elementName];
    [sym setName:[attributeDict objectForKey:@"name"]];
    
    
    
    NSString *type = [attributeDict objectForKey:@"type64"];
    if (!type) {
        type = [attributeDict objectForKey:@"type"];
    }
    
    if (type) {
        type = [type stringByRemovingPercentEncoding];
        
        [sym setRuntimeType:type];
    }
    
    
    if ([elementName isEqualToString:@"enum"]) {
        [sym setRuntimeValue:[attributeDict objectForKey:@"value"]];
    }
    else if ([elementName isEqualToString:@"function"]) {
        _currentFunction = sym;
    }
    else if ([elementName isEqualToString:@"class"]) {
        
        _currentClass = [_symbols objectForKey:[sym name]];
        if (!_currentClass) {
            _currentClass = sym;
        }
        else {
            sym = nil;
        }
        
        
    }
    else if ([elementName isEqualToString:@"method"]) {
        _currentMethod = sym;
        NSString *s = [attributeDict objectForKey:@"selector"];
        assert(s);
        if (s) {
            [sym setSelector:NSSelectorFromString(s)];
        }
    }
    
    
    
    if (_currentFunction && [elementName isEqualToString:@"arg"]) {
        [_currentFunction addArgument:sym];
    }
    else if (_currentFunction && [elementName isEqualToString:@"retval"]) {
        [_currentFunction setReturnValue:sym];
    }
    else if (_currentClass && [elementName isEqualToString:@"method"]) {
        
        assert(_currentMethod);
        
        if ([[attributeDict objectForKey:@"class_method"] boolValue]) {
            [_currentClass addClassMethod:sym];
        }
        else {
            [_currentClass addInstanceMethod:sym];
        }
    }
    
    #pragma message "FIXME: What about constants?"
    if ([sym name] && ([elementName isEqualToString:@"class"] || [elementName isEqualToString:@"function"] || [elementName isEqualToString:@"enum"])) {
        [_symbols setObject:sym forKey:[sym name]];
    }
    
}

// sent when an end tag is encountered. The various parameters are supplied as above.
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName {
    if ([elementName isEqualToString:@"function"]) {
//        debug(@"Clearing function %@", [_currentFunction name]);
//        debug(@"args: %@", [_currentFunction arguments]);
//        debug(@"retr: %@", [_currentFunction returnValue]);
//
//
        _currentFunction = nil;
    }
    else if ([elementName isEqualToString:@"class"]) {
        
        _currentClass = nil;
        
    }
    else if ([elementName isEqualToString:@"method"]) {
        _currentMethod = nil;
    }
}


//- (void)parser:(NSXMLParser *)parser didStartMappingPrefix:(NSString *)prefix toURI:(NSString *)namespaceURI;
//// sent when the parser first sees a namespace attribute.
//// In the case of the cvslog tag, before the didStartElement:, you'd get one of these with prefix == @"" and namespaceURI == @"http://xml.apple.com/cvslog" (i.e. the default namespace)
//// In the case of the radar:radar tag, before the didStartElement: you'd get one of these with prefix == @"radar" and namespaceURI == @"http://xml.apple.com/radar"
//
//- (void)parser:(NSXMLParser *)parser didEndMappingPrefix:(NSString *)prefix;
//// sent when the namespace prefix in question goes out of scope.


// This returns the string of the characters encountered thus far. You may not necessarily get the longest character run. The parser reserves the right to hand these to the delegate as potentially many calls in a row to -parser:foundCharacters:
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    
}

// The parser reports ignorable whitespace in the same way as characters it's found.
- (void)parser:(NSXMLParser *)parser foundIgnorableWhitespace:(NSString *)whitespaceString {
    
}


//- (void)parser:(NSXMLParser *)parser foundProcessingInstructionWithTarget:(NSString *)target data:(nullable NSString *)data;
// The parser reports a processing instruction to you using this method. In the case above, target == @"xml-stylesheet" and data == @"type='text/css' href='cvslog.css'"

//- (void)parser:(NSXMLParser *)parser foundComment:(NSString *)comment;
// A comment (Text in a <!-- --> block) is reported to the delegate as a single string

// this reports a CDATA block to the delegate as an NSData.
- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock {
    
}


//- (nullable NSData *)parser:(NSXMLParser *)parser resolveExternalEntityName:(NSString *)name systemID:(nullable NSString *)systemID;
// this gives the delegate an opportunity to resolve an external entity itself and reply with the resulting data.

// ...and this reports a fatal error to the delegate. The parser will stop parsing.
- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    debug(@"parseError: '%@'", parseError);
    assert(NO);
}


//- (void)parser:(NSXMLParser *)parser validationErrorOccurred:(NSError *)validationError;



@end




@implementation FJSSymbol

- (void)addArgument:(FJSSymbol*)sym {
    if (!_arguments) {
        _arguments = [NSMutableArray array];
    }
    
    [_arguments addObject:sym];
}

- (void)addClassMethod:(FJSSymbol*)sym {
    if (!_classMethods) {
        _classMethods = [NSMutableArray array];
    }
    
    [_classMethods addObject:sym];
}

- (void)addInstanceMethod:(FJSSymbol*)sym {
    if (!_instanceMethods) {
        _instanceMethods = [NSMutableArray array];
    }
    
    [_instanceMethods addObject:sym];
}

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@: %p %@ %@>", NSStringFromClass([self class]), self, _name, _runtimeType];
}

- (FJSSymbol*)methodNamed:(NSString*)name isClass:(BOOL)isClassMethod {
    
    name = [name stringByReplacingOccurrencesOfString:@"_" withString:@":"];
    
    assert([[self symbolType] isEqualToString:@"class"]);
    
    for (FJSSymbol *sym in isClassMethod ? _classMethods : _instanceMethods) {
        if ([[sym name] isEqualToString:name]) {
            return sym;
        }
    }
    
    // OK, it wasn't part of the bridge xml file. Let's look it up in the runtime.
    
    
    Class c = NSClassFromString([self name]);
    assert(c); // We have to exist, right?
    
    SEL selector = NSSelectorFromString(name);
    
    Method method = isClassMethod ? class_getClassMethod(c, selector) : class_getInstanceMethod(c, selector);
    
    
    if (method) {
        
        FJSSymbol *methodSymbol = [FJSSymbol new];
        [methodSymbol setName:name];
        [methodSymbol setSymbolType:@"method"];
        
        NSMethodSignature *methodSignature = isClassMethod ? [c methodSignatureForSelector:selector] : [c instanceMethodSignatureForSelector:selector];
        assert(methodSignature);
        
        if ([methodSignature methodReturnType]) {
            FJSSymbol *returnValue = [FJSSymbol new];
            [returnValue setRuntimeType:[NSString stringWithFormat:@"%s", [methodSignature methodReturnType]]];
            [methodSymbol setReturnValue:returnValue];
        }
        
        
        for (NSUInteger idx = 2; idx < [methodSignature numberOfArguments]; idx++) {
            
            FJSSymbol *argument = [FJSSymbol new];
            [argument setRuntimeType:[NSString stringWithFormat:@"%s", [methodSignature methodReturnType]]];
            [[methodSymbol arguments] addObject:argument];
        }
        
        
        [(isClassMethod ? [self classMethods] : [self instanceMethods]) addObject:methodSymbol];
        
        assert([NSThread isMainThread]); // need to put things in a queue if we're doing this in a background thread.
        
        return methodSymbol;
    }
    
    
    
    
    return nil;
    
}

- (FJSSymbol*)classMethodNamed:(NSString*)name {
    return [self methodNamed:name isClass:YES];
}

- (FJSSymbol*)instanceMethodNamed:(NSString*)name {
    return [self methodNamed:name isClass:NO];
}

- (BOOL)returnsRetained {
#pragma message "FIXME: Look up the actual +1 rules. Isn't it create anywhere in the name?"

    if ([_symbolType isEqualToString:@"method"]) {
        return ([_name isEqualToString:@"new"] || [_name isEqualToString:@"init"] || [_name isEqualToString:@"copy"] || [_name isEqualToString:@"mutableCopy"] || [_name hasPrefix:@"create"]);
    }
    
    NSLog(@"Programming error: asking if returnsRetained on a symbol of type: %@", _symbolType);
    FMAssert(NO);
    
    return NO;
    
}

@end



