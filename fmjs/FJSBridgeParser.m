//
//  FJSBridgeParser.m
//  yd
//
//  Created by August Mueller on 8/21/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import "FJSBridgeParser.h"

#define debug NSLog

@interface FJSBridgeParser ()

@property (strong) FJSSymbol *currentFunction;
@property (strong) FJSSymbol *currentClass;
@property (strong) FJSSymbol *currentMethod;

@end

@implementation FJSBridgeParser

+ (instancetype)sharedParser {
    
    static FJSBridgeParser *bp = nil;
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
    return [[[self sharedParser] symbols] objectForKey:name];
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

- (FJSSymbol*)classMethodNamed:(NSString*)name {
    
    assert([[self symbolType] isEqualToString:@"class"]);
    
    for (FJSSymbol *sym in _classMethods) {
        if ([[sym name] isEqualToString:name]) {
            return sym;
        }
    }
    
    // HRM.
    
    Class c = NSClassFromString([self name]);
    assert(c); // We have to exist, right?
    
    SEL selector = NSSelectorFromString(name);
    
    if ([c respondsToSelector:selector]) {
        debug(@"Found class method '%@' in the runtime", name);
        
        NSMethodSignature *methodSignature = [c methodSignatureForSelector:selector];
        assert(methodSignature);
        debug(@"methodSignature: '%@'", methodSignature);
        
        FJSSymbol *classMethodSymol = [FJSSymbol new];
        [classMethodSymol setName:name];
        [classMethodSymol setSymbolType:@"method"];
        [classMethodSymol setIsClassMethod:YES];
        
        if ([methodSignature methodReturnType]) {
            FJSSymbol *returnValue = [FJSSymbol new];
            [returnValue setRuntimeType:[NSString stringWithFormat:@"%s", [methodSignature methodReturnType]]];
            [classMethodSymol setReturnValue:returnValue];
        }
        
        
        for (NSUInteger idx = 2; idx < [methodSignature numberOfArguments]; idx++) {
            
            FJSSymbol *argument = [FJSSymbol new];
            [argument setRuntimeType:[NSString stringWithFormat:@"%s", [methodSignature methodReturnType]]];
            [[classMethodSymol arguments] addObject:argument];
            debug(@"argument: '%@'", argument);
        }
        
        [[self classMethods] addObject:classMethodSymol];
        
        assert([NSThread isMainThread]); // need to put things in a queue if we're doing this in a background thread.
        
        return classMethodSymol;
    }
    
    
    
    
    
    return nil;
}

- (FJSSymbol*)instanceMethodNamed:(NSString*)name {
    for (FJSSymbol *sym in _instanceMethods) {
        if ([[sym name] isEqualToString:name]) {
            return sym;
        }
    }
    
    return nil;
}

@end



