#import "TDConglomerate.h"

//
//  TDAlternation.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@interface FJSTDParser ()
- (NSSet *)matchAndAssemble:(NSSet *)inAssemblies;
@end

@implementation FJSTDAlternation

+ (id)alternation {
    return [[[self alloc] init] autorelease];
}


- (NSSet *)allMatchesFor:(NSSet *)inAssemblies {
    NSParameterAssert(inAssemblies);
    NSMutableSet *outAssemblies = [NSMutableSet set];
    
    for (FJSTDParser *p in subparsers) {
        [outAssemblies unionSet:[p matchAndAssemble:inAssemblies]];
    }
    
    return outAssemblies;
}

@end
//
//  TDAny.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 12/14/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@implementation FJSTDAny

+ (id)any {
    return [[[self alloc] initWithString:@""] autorelease];
}


- (BOOL)qualifies:(id)obj {
    return [obj isKindOfClass:[FJSTDToken class]];
}

@end
//
//  TDAssembly.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



static NSString * const TDAssemblyDefaultDelimiter = @"/";

@interface FJSTDAssembly ()
@property (nonatomic, readwrite, retain) NSMutableArray *stack;
@property (nonatomic) NSUInteger index;
@property (nonatomic, retain) NSString *string;
@property (nonatomic, readwrite, retain) NSString *defaultDelimiter;
@end

@implementation FJSTDAssembly

+ (id)assemblyWithString:(NSString *)s {
    return [[[self alloc] initWithString:s] autorelease];
}


- (id)init {
    return [self initWithString:nil];
}


- (id)initWithString:(NSString *)s {
    self = [super init];
    if (self) {
        self.stack = [NSMutableArray array];
        self.string = s;
    }
    return self;
}


// this private intializer exists simply to improve the performance of the -copyWithZone: method.
// note flow *does not* go thru the designated initializer above. however, that ugliness is worth it cuz
// the perf of -copyWithZone: in this class is *vital* to the framework's performance
- (id)_init {
    return [super init];
}


// this method diverges from coding standards cuz it is vital to the entire framework's performance
- (void)dealloc {
    [stack release]; 
    [string release];
    if (target) [target release];
    if (defaultDelimiter) [defaultDelimiter release];
    [super dealloc];
}


// this method diverges from coding standards cuz it is vital to the entire framework's performance
- (id)copyWithZone:(NSZone *)zone {
    FJSTDAssembly *a = [[[self class] allocWithZone:zone] _init];
    a->stack = [stack mutableCopyWithZone:zone];
    a->string = [string retain];
    if (defaultDelimiter) a->defaultDelimiter = [defaultDelimiter retain];
    if (target) a->target = [target mutableCopyWithZone:zone];
    a->index = index;
    return a;
}


- (id)next {
    NSAssert1(0, @"-[TDAssembly %@] must be overriden", NSStringFromSelector(_cmd));
    return nil;
}


- (BOOL)hasMore {
    NSAssert1(0, @"-[TDAssembly %@] must be overriden", NSStringFromSelector(_cmd));
    return NO;
}


- (NSString *)consumedObjectsJoinedByString:(NSString *)delimiter {
    NSAssert1(0, @"-[TDAssembly %@] must be overriden", NSStringFromSelector(_cmd));
    return nil;
}


- (NSString *)remainingObjectsJoinedByString:(NSString *)delimiter {
    NSAssert1(0, @"-[TDAssembly %@] must be overriden", NSStringFromSelector(_cmd));
    return nil;
}


- (NSUInteger)length {
    NSAssert1(0, @"-[TDAssembly %@] must be overriden", NSStringFromSelector(_cmd));
    return 0;
}


- (NSUInteger)objectsConsumed {
    NSAssert1(0, @"-[TDAssembly %@] must be overriden", NSStringFromSelector(_cmd));
    return 0;
}


- (NSUInteger)objectsRemaining {
    NSAssert1(0, @"-[TDAssembly %@] must be overriden", NSStringFromSelector(_cmd));
    return 0;
}


- (id)peek {
    NSAssert1(0, @"-[TDAssembly %@] must be overriden", NSStringFromSelector(_cmd));
    return nil;
}


- (id)pop {
    id result = nil;
    if (stack.count) {
        result = [[[stack lastObject] retain] autorelease];
        [stack removeLastObject];
    }
    return result;
}


- (void)push:(id)object {
    if (object) {
        [stack addObject:object];
    }
}


- (BOOL)isStackEmpty {
    return 0 == stack.count;
}


- (NSArray *)objectsAbove:(id)fence {
    NSMutableArray *result = [NSMutableArray array];
    
    while (stack.count) {        
        id obj = [self pop];
        
        if ([obj isEqual:fence]) {
            [self push:obj];
            break;
        } else {
            [result addObject:obj];
        }
    }
    
    return result;
}


- (NSString *)description {
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"["];
    
    NSUInteger i = 0;
    NSUInteger len = stack.count;
    
    for (id obj in stack) {
        [s appendString:[obj description]];
        if (len - 1 != i++) {
            [s appendString:@", "];
        }
    }
    
    [s appendString:@"]"];
    
    NSString *d = defaultDelimiter ? defaultDelimiter : TDAssemblyDefaultDelimiter;
    [s appendString:[self consumedObjectsJoinedByString:d]];
    [s appendString:@"^"];
    [s appendString:[self remainingObjectsJoinedByString:d]];
    
    return [[s copy] autorelease];
}

@synthesize stack;
@synthesize target;
@synthesize index;
@synthesize string;
@synthesize defaultDelimiter;
@end
//
//  TDCaseInsensitiveLiteral.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@implementation FJSTDCaseInsensitiveLiteral

- (BOOL)qualifies:(id)obj {
    return NSOrderedSame == [literal.stringValue caseInsensitiveCompare:[obj stringValue]];
//    return [literal isEqualIgnoringCase:obj];
}

@end
//
//  TDChar.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/14/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



@implementation FJSTDChar

+ (id)char {
    return [[[self alloc] initWithString:@""] autorelease];
}


- (BOOL)qualifies:(id)obj {
    return YES;
}

@end
//
//  TDCharacterAssembly.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@implementation FJSTDCharacterAssembly

- (id)init {
    return [self initWithString:nil];
}


- (id)initWithString:(NSString *)s {
    self = [super initWithString:s];
    if (self) {
        self.defaultDelimiter = @"";
    }
    return self;
}


- (void)dealloc {
    [super dealloc];
}


- (id)copyWithZone:(NSZone *)zone {
    FJSTDCharacterAssembly *a = (FJSTDCharacterAssembly *)[super copyWithZone:zone];
    return a;
}


- (id)peek {
    if (index >= string.length) {
        return nil;
    }
    NSInteger c = [string characterAtIndex:index];
    return [NSNumber numberWithInteger:c];
}


- (id)next {
    id obj = [self peek];
    if (obj) {
        index++;
    }
    return obj;
}


- (BOOL)hasMore {
    return (index < string.length);
}


- (NSUInteger)length {
    return string.length;
} 


- (NSUInteger)objectsConsumed {
    return index;
}


- (NSUInteger)objectsRemaining {
    return (string.length - index);
}


- (NSString *)consumedObjectsJoinedByString:(NSString *)delimiter {
    NSParameterAssert(delimiter);
    return [string substringToIndex:self.objectsConsumed];
}


- (NSString *)remainingObjectsJoinedByString:(NSString *)delimiter {
    NSParameterAssert(delimiter);
    return [string substringFromIndex:self.objectsConsumed];
}


// overriding simply to print NSNumber objects as their unichar values
- (NSString *)description {
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"["];
    
    NSInteger i = 0;
    NSInteger len = stack.count;
    
    for (id obj in self.stack) {
        if ([obj isKindOfClass:[NSNumber class]]) { // ***this is needed for Char Assemblies
            [s appendFormat:@"%C", [obj unsignedShortValue]];
        } else {
            [s appendString:[obj description]];
        }
        if (len - 1 != i++) {
            [s appendString:@", "];
        }
    }
    
    [s appendString:@"]"];
    
    [s appendString:[self consumedObjectsJoinedByString:self.defaultDelimiter]];
    [s appendString:@"^"];
    [s appendString:[self remainingObjectsJoinedByString:self.defaultDelimiter]];
    
    return [[s copy] autorelease];
}

@end
//
//  TDCollectionParser.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



@interface FJSTDCollectionParser ()
@property (nonatomic, readwrite, retain) NSMutableArray *subparsers;
@end

@implementation FJSTDCollectionParser

- (id)init {
    self = [super init];
    if (self) {
        self.subparsers = [NSMutableArray array];
    }
    return self;
}


- (void)dealloc {
    self.subparsers = nil;
    [super dealloc];
}


- (void)add:(FJSTDParser *)p {
    NSParameterAssert(p);
    [subparsers addObject:p];
}

@synthesize subparsers;
@end
//
//  TDComment.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 12/31/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@implementation FJSTDComment

+ (id)comment {
    return [[[self alloc] initWithString:@""] autorelease];
}


- (BOOL)qualifies:(id)obj {
    FJSTDToken *tok = (FJSTDToken *)obj;
    return tok.isComment;
}

@end//
//  TDCommentState.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 12/28/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//








@interface FJSTDCommentState ()
@property (nonatomic, retain) FJSTDSymbolRootNode *rootNode;
@property (nonatomic, retain) FJSTDSingleLineCommentState *singleLineState;
@property (nonatomic, retain) FJSTDMultiLineCommentState *multiLineState;
@end

@interface FJSTDSingleLineCommentState ()
- (void)addStartSymbol:(NSString *)start;
- (void)removeStartSymbol:(NSString *)start;
@property (nonatomic, retain) NSMutableArray *startSymbols;
@property (nonatomic, retain) NSString *currentStartSymbol;
@end

@interface FJSTDMultiLineCommentState ()
- (void)addStartSymbol:(NSString *)start endSymbol:(NSString *)end;
- (void)removeStartSymbol:(NSString *)start;
@property (nonatomic, retain) NSMutableArray *startSymbols;
@property (nonatomic, retain) NSMutableArray *endSymbols;
@property (nonatomic, copy) NSString *currentStartSymbol;
@end

@implementation FJSTDCommentState

- (id)init {
    self = [super init];
    if (self) {
        self.rootNode = [[[FJSTDSymbolRootNode alloc] init] autorelease];
        self.singleLineState = [[[FJSTDSingleLineCommentState alloc] init] autorelease];
        self.multiLineState = [[[FJSTDMultiLineCommentState alloc] init] autorelease];
    }
    return self;
}


- (void)dealloc {
    self.rootNode = nil;
    self.singleLineState = nil;
    self.multiLineState = nil;
    [super dealloc];
}


- (void)addSingleLineStartSymbol:(NSString *)start {
    NSParameterAssert(start.length);
    [rootNode add:start];
    [singleLineState addStartSymbol:start];
}


- (void)removeSingleLineStartSymbol:(NSString *)start {
    NSParameterAssert(start.length);
    [rootNode remove:start];
    [singleLineState removeStartSymbol:start];
}


- (void)addMultiLineStartSymbol:(NSString *)start endSymbol:(NSString *)end {
    NSParameterAssert(start.length);
    NSParameterAssert(end.length);
    [rootNode add:start];
    [rootNode add:end];
    [multiLineState addStartSymbol:start endSymbol:end];
}


- (void)removeMultiLineStartSymbol:(NSString *)start {
    NSParameterAssert(start.length);
    [rootNode remove:start];
    [multiLineState removeStartSymbol:start];
}


- (FJSTDToken *)nextTokenFromReader:(FJSTDReader *)r startingWith:(NSInteger)cin tokenizer:(FJSTDTokenizer *)t {
    NSParameterAssert(r);
    NSParameterAssert(t);

    NSString *symbol = [rootNode nextSymbol:r startingWith:cin];

    if ([multiLineState.startSymbols containsObject:symbol]) {
        multiLineState.currentStartSymbol = symbol;
        return [multiLineState nextTokenFromReader:r startingWith:cin tokenizer:t];
    } else if ([singleLineState.startSymbols containsObject:symbol]) {
        singleLineState.currentStartSymbol = symbol;
        return [singleLineState nextTokenFromReader:r startingWith:cin tokenizer:t];
    } else {
        NSInteger i = 0;
        for ( ; i < symbol.length - 1; i++) {
            [r unread];
        }
        return [FJSTDToken tokenWithTokenType:TDTokenTypeSymbol stringValue:[NSString stringWithFormat:@"%C", (unsigned short)cin] floatValue:0.0];
    }
}

@synthesize rootNode;
@synthesize singleLineState;
@synthesize multiLineState;
@synthesize reportsCommentTokens;
@synthesize balancesEOFTerminatedComments;
@end
//
//  TDDigit.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/14/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



@implementation FJSTDDigit

+ (id)digit {
    return [[[self alloc] initWithString:@""] autorelease];
}


- (BOOL)qualifies:(id)obj {
    NSInteger c = [obj integerValue];
    return isdigit((int)c);
}

@end
//
//  TDEmpty.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



@implementation FJSTDEmpty

+ (id)empty {
    return [[[self alloc] init] autorelease];
}


- (NSSet *)allMatchesFor:(NSSet *)inAssemblies {
    NSParameterAssert(inAssemblies);
    //return [[[NSSet alloc] initWithSet:inAssemblies copyItems:YES] autorelease];
    return inAssemblies;
}

@end
//
//  TDLetter.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/14/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



@implementation FJSTDLetter

+ (id)letter {
    return [[[self alloc] initWithString:@""] autorelease];
}


- (BOOL)qualifies:(id)obj {
    NSInteger c = [obj integerValue];
    return isalpha((int)c);
}

@end
//
//  TDLiteral.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@interface FJSTDLiteral ()
@property (nonatomic, retain) FJSTDToken *literal;
@end

@implementation FJSTDLiteral

+ (id)literalWithString:(NSString *)s {
    return [[[self alloc] initWithString:s] autorelease];
}


- (id)initWithString:(NSString *)s {
    //NSParameterAssert(s);
    self = [super initWithString:s];
    if (self) {
        self.literal = [FJSTDToken tokenWithTokenType:TDTokenTypeWord stringValue:s floatValue:0.0];
    }
    return self;
}


- (void)dealloc {
    self.literal = nil;
    [super dealloc];
}


- (BOOL)qualifies:(id)obj {
    return [literal.stringValue isEqualToString:[obj stringValue]];
    //return [literal isEqual:obj];
}


- (NSString *)description {
    NSString *className = [[self className] substringFromIndex:2];
    if (name.length) {
        return [NSString stringWithFormat:@"%@ (%@) %@", className, name, literal.stringValue];
    } else {
        return [NSString stringWithFormat:@"%@ %@", className, literal.stringValue];
    }
}

@synthesize literal;
@end
//
//  TDLowercaseWord.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@implementation FJSTDLowercaseWord

- (BOOL)qualifies:(id)obj {
    FJSTDToken *tok = (FJSTDToken *)obj;
    if (!tok.isWord) {
        return NO;
    }
    
    NSString *s = tok.stringValue;
    return s.length && islower([s characterAtIndex:0]);
}

@end
//
//  TDMultiLineCommentState.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 12/28/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//








@interface FJSTDTokenizerState ()
- (void)reset;
- (void)append:(NSInteger)c;
- (void)appendString:(NSString *)s;
- (NSString *)bufferedString;
@end



@interface FJSTDMultiLineCommentState ()
- (void)addStartSymbol:(NSString *)start endSymbol:(NSString *)end;
- (void)removeStartSymbol:(NSString *)start;

@end

@implementation FJSTDMultiLineCommentState

- (id)init {
    self = [super init];
    if (self) {
        self.startSymbols = [NSMutableArray array];
        self.endSymbols = [NSMutableArray array];
    }
    return self;
}


- (void)dealloc {
    self.startSymbols = nil;
    self.endSymbols = nil;
    self.currentStartSymbol = nil;
    [super dealloc];
}


- (void)addStartSymbol:(NSString *)start endSymbol:(NSString *)end {
    NSParameterAssert(start.length);
    NSParameterAssert(end.length);
    [startSymbols addObject:start];
    [endSymbols addObject:end];
}


- (void)removeStartSymbol:(NSString *)start {
    NSParameterAssert(start.length);
    NSInteger i = [startSymbols indexOfObject:start];
    if (NSNotFound != i) {
        [startSymbols removeObject:start];
        [endSymbols removeObjectAtIndex:i]; // this should always be in range.
    }
}


- (void)unreadSymbol:(NSString *)s fromReader:(FJSTDReader *)r {
    NSInteger len = s.length;
    NSInteger i = 0;
    for ( ; i < len - 1; i++) {
        [r unread];
    }
}


- (FJSTDToken *)nextTokenFromReader:(FJSTDReader *)r startingWith:(NSInteger)cin tokenizer:(FJSTDTokenizer *)t {
    NSParameterAssert(r);
    NSParameterAssert(t);
    
    BOOL balanceEOF = t.commentState.balancesEOFTerminatedComments;
    BOOL reportTokens = t.commentState.reportsCommentTokens;
    if (reportTokens) {
        [self reset];
        [self appendString:currentStartSymbol];
    }
    
    NSInteger i = [startSymbols indexOfObject:currentStartSymbol];
    NSString *currentEndSymbol = [endSymbols objectAtIndex:i];
    NSInteger e = [currentEndSymbol characterAtIndex:0];
    
    // get the definitions of all multi-char comment start and end symbols from the commentState
    FJSTDSymbolRootNode *rootNode = t.commentState.rootNode;
        
    NSInteger c;
    while (1) {
        c = [r read];
        if (-1 == c) {
            if (balanceEOF) {
                [self appendString:currentEndSymbol];
            }
            break;
        }
        
        if (e == c) {
            NSString *peek = [rootNode nextSymbol:r startingWith:e];
            if ([currentEndSymbol isEqualToString:peek]) {
                if (reportTokens) {
                    [self appendString:currentEndSymbol];
                }
                c = [r read];
                break;
            } else {
                [self unreadSymbol:peek fromReader:r];
                if (e != [peek characterAtIndex:0]) {
                    if (reportTokens) {
                        [self append:c];
                    }
                    c = [r read];
                }
            }
        }
        if (reportTokens) {
            [self append:c];
        }
    }
    
    if (-1 != c) {
        [r unread];
    }
    
    self.currentStartSymbol = nil;

    if (reportTokens) {
        return [FJSTDToken tokenWithTokenType:TDTokenTypeComment stringValue:[self bufferedString] floatValue:0.0];
    } else {
        return [t nextToken];
    }
}

@synthesize startSymbols;
@synthesize endSymbols;
@synthesize currentStartSymbol;
@end
//
//  TDNonReservedWord.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//





@interface FJSTDReservedWord ()
+ (NSArray *)reservedWords;
@end

@implementation FJSTDNonReservedWord

- (BOOL)qualifies:(id)obj {
    FJSTDToken *tok = (FJSTDToken *)obj;
    if (!tok.isWord) {
        return NO;
    }
    
    NSString *s = tok.stringValue;
    return s.length && ![[FJSTDReservedWord reservedWords] containsObject:s];
}

@end
//
//  TDNum.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@implementation FJSTDNum

+ (id)num {
    return [[[self alloc] initWithString:@""] autorelease];
}


- (BOOL)qualifies:(id)obj {
    FJSTDToken *tok = (FJSTDToken *)obj;
    return tok.isNumber;
}

@end//
//  TDNumberState.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//







@interface FJSTDTokenizerState ()
- (void)reset;
- (void)append:(NSInteger)c;
- (NSString *)bufferedString;
@end

@interface FJSTDNumberState ()
- (CGFloat)absorbDigitsFromReader:(FJSTDReader *)r isFraction:(BOOL)fraction;
- (CGFloat)value;
- (void)parseLeftSideFromReader:(FJSTDReader *)r;
- (void)parseRightSideFromReader:(FJSTDReader *)r;
- (void)reset:(NSInteger)cin;
@end

@implementation FJSTDNumberState

- (void)dealloc {
    [super dealloc];
}


- (FJSTDToken *)nextTokenFromReader:(FJSTDReader *)r startingWith:(NSInteger)cin tokenizer:(FJSTDTokenizer *)t {
    NSParameterAssert(r);
    NSParameterAssert(t);

    [self reset];
    negative = NO;
    NSInteger originalCin = cin;
    
    if ('-' == cin) {
        negative = YES;
        cin = [r read];
        [self append:'-'];
    } else if ('+' == cin) {
        cin = [r read];
        [self append:'+'];
    }
    
    [self reset:cin];
    if ('.' == c) {
        [self parseRightSideFromReader:r];
    } else {
        [self parseLeftSideFromReader:r];
        [self parseRightSideFromReader:r];
    }
    
    // erroneous ., +, or -
    if (!gotADigit) {
        if (negative && -1 != c) { // ??
            [r unread];
        }
        return [t.symbolState nextTokenFromReader:r startingWith:originalCin tokenizer:t];
    }
    
    if (-1 != c) {
        [r unread];
    }

    if (negative) {
        floatValue = -floatValue;
    }
    
    return [FJSTDToken tokenWithTokenType:TDTokenTypeNumber stringValue:[self bufferedString] floatValue:[self value]];
}


- (CGFloat)value {
    return floatValue;
}


- (CGFloat)absorbDigitsFromReader:(FJSTDReader *)r isFraction:(BOOL)isFraction {
    CGFloat divideBy = 1.0;
    CGFloat v = 0.0;
    
    while (1) {
        if (isdigit((int)c)) {
            [self append:c];
            gotADigit = YES;
            v = v * 10.0 + (c - '0');
            c = [r read];
            if (isFraction) {
                divideBy *= 10.0;
            }
        } else {
            break;
        }
    }
    
    if (isFraction) {
        v = v / divideBy;
    }

    return (CGFloat)v;
}


- (void)parseLeftSideFromReader:(FJSTDReader *)r {
    floatValue = [self absorbDigitsFromReader:r isFraction:NO];
}


- (void)parseRightSideFromReader:(FJSTDReader *)r {
    if ('.' == c) {
        NSInteger n = [r read];
        BOOL nextIsDigit = isdigit((int)n);
        if (-1 != n) {
            [r unread];
        }

        if (nextIsDigit || allowsTrailingDot) {
            [self append:'.'];
            if (nextIsDigit) {
                c = [r read];
                floatValue += [self absorbDigitsFromReader:r isFraction:YES];
            }
        }
    }
}


- (void)reset:(NSInteger)cin {
    gotADigit = NO;
    floatValue = 0.0;
    c = cin;
}

@synthesize allowsTrailingDot;
@end
//
//  TDParser.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@interface FJSTDParser ()
- (NSSet *)matchAndAssemble:(NSSet *)inAssemblies;
- (FJSTDAssembly *)best:(NSSet *)inAssemblies;
@end

@implementation FJSTDParser

+ (id)parser {
    return [[[self alloc] init] autorelease];
}


- (id)init {
    self = [super init];
    if (self) {
    }
    return self;
}


- (void)dealloc {
    assembler = nil;
    self.selector = nil;
    self.name = nil;
    [super dealloc];
}


- (void)setAssembler:(id)a selector:(SEL)sel {
    self.assembler = a;
    self.selector = sel;
}


- (NSSet *)allMatchesFor:(NSSet *)inAssemblies {
    NSAssert1(0, @"-[TDParser %@] must be overriden", NSStringFromSelector(_cmd));
    return nil;
}


- (FJSTDAssembly *)bestMatchFor:(FJSTDAssembly *)a {
    NSParameterAssert(a);
    NSSet *initialState = [NSSet setWithObject:a];
    NSSet *finalState = [self matchAndAssemble:initialState];
    return [self best:finalState];
}


- (FJSTDAssembly *)completeMatchFor:(FJSTDAssembly *)a {
    NSParameterAssert(a);
    FJSTDAssembly *best = [self bestMatchFor:a];
    if (best && ![best hasMore]) {
        return best;
    }
    return nil;
}


- (NSSet *)matchAndAssemble:(NSSet *)inAssemblies {
    NSParameterAssert(inAssemblies);
    NSSet *outAssemblies = [self allMatchesFor:inAssemblies];
    if (assembler) {
        NSAssert2([assembler respondsToSelector:selector], @"provided assembler %@ should respond to %@", assembler, NSStringFromSelector(selector));
        for (FJSTDAssembly *a in outAssemblies) {
            [assembler performSelector:selector withObject:a];
        }
    }
    return outAssemblies;
}


- (FJSTDAssembly *)best:(NSSet *)inAssemblies {
    NSParameterAssert(inAssemblies);
    FJSTDAssembly *best = nil;
    
    for (FJSTDAssembly *a in inAssemblies) {
        if (![a hasMore]) {
            best = a;
            break;
        }
        if (!best || a.objectsConsumed > best.objectsConsumed) {
            best = a;
        }
    }
    
    return best;
}


- (NSString *)description {
    NSString *className = [[self className] substringFromIndex:2];
    if (name.length) {
        return [NSString stringWithFormat:@"%@ (%@)", className, name];
    } else {
        return [NSString stringWithFormat:@"%@", className];
    }
}

@synthesize assembler;
@synthesize selector;
@synthesize name;
@end
//
//  TDQuoteState.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//





@interface FJSTDTokenizerState ()
- (void)reset;
- (void)append:(NSInteger)c;
- (NSString *)bufferedString;
@end

@implementation FJSTDQuoteState

- (void)dealloc {
    [super dealloc];
}


- (FJSTDToken *)nextTokenFromReader:(FJSTDReader *)r startingWith:(NSInteger)cin tokenizer:(FJSTDTokenizer *)t {
    NSParameterAssert(r);
    [self reset];
    
    [self append:cin];
    NSInteger c;
    do {
        c = [r read];
        if (-1 == c) {
            c = cin;
            if (balancesEOFTerminatedQuotes) {
                [self append:c];
            }
        } else {
            [self append:c];
        }
        
    } while (c != cin);
    
    return [FJSTDToken tokenWithTokenType:TDTokenTypeQuotedString stringValue:[self bufferedString] floatValue:0.0];
}

@synthesize balancesEOFTerminatedQuotes;
@end
//
//  TDQuotedString.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@implementation FJSTDQuotedString

+ (id)quotedString {
    return [[[self alloc] initWithString:@""] autorelease];
}


- (BOOL)qualifies:(id)obj {
    FJSTDToken *tok = (FJSTDToken *)obj;
    return tok.isQuotedString;
}

@end
//
//  TDReader.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/21/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



@implementation FJSTDReader

- (id)init {
    return [self initWithString:nil];
}


- (id)initWithString:(NSString *)s {
    self = [super init];
    if (self) {
        self.string = s;
    }
    return self;
}


- (void)dealloc {
    self.string = nil;
    [super dealloc];
}


- (NSString *)string {
    return string;
}


- (void)setString:(NSString *)s {
    if (string != s) {
        [string release];
        string = [s retain];
        length = string.length;
    }
    // reset cursor
    cursor = 0;
}


- (NSInteger)read {
    if (0 == length || cursor > length - 1) {
        return -1;
    }
    return [string characterAtIndex:cursor++];
}


- (void)unread {
    cursor = (0 == cursor) ? 0 : cursor - 1;
}

@end
//
//  TDRepetition.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//





@interface FJSTDRepetition ()
@property (nonatomic, readwrite, retain) FJSTDParser *subparser;
@end

@implementation FJSTDRepetition

+ (id)repetitionWithSubparser:(FJSTDParser *)p {
    return [[[self alloc] initWithSubparser:p] autorelease];
}


- (id)init {
    return [self initWithSubparser:nil];
}


- (id)initWithSubparser:(FJSTDParser *)p {
    //NSParameterAssert(p);
    self = [super init];
    if (self) {
        self.subparser = p;
    }
    return self;
}


- (void)dealloc {
    self.subparser = nil;
    self.preassembler = nil;
    self.preassemblerSelector = nil;
    [super dealloc];
}


- (void)setPreassembler:(id)a selector:(SEL)sel {
    self.preassembler = a;
    self.preassemblerSelector = sel;
}


- (NSSet *)allMatchesFor:(NSSet *)inAssemblies {
    NSParameterAssert(inAssemblies);
    if (preassembler) {
        NSAssert2([preassembler respondsToSelector:preassemblerSelector], @"provided preassembler %@ should respond to %@", preassembler, NSStringFromSelector(preassemblerSelector));
        for (FJSTDAssembly *a in inAssemblies) {
            [preassembler performSelector:preassemblerSelector withObject:a];
        }
    }
    
    //NSMutableSet *outAssemblies = [[[NSSet alloc] initWithSet:inAssemblies copyItems:YES] autorelease];
    NSMutableSet *outAssemblies = [[inAssemblies mutableCopy] autorelease];
    
    NSSet *s = inAssemblies;
    while (s.count) {
        s = [subparser matchAndAssemble:s];
        [outAssemblies unionSet:s];
    }
    
    return outAssemblies;
}

@synthesize subparser;
@synthesize preassembler;
@synthesize preassemblerSelector;
@end
//
//  TDReservedWord.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




static NSArray *sTDReservedWords = nil;

@interface FJSTDReservedWord ()
+ (NSArray *)reservedWords;
@end

@implementation FJSTDReservedWord

+ (NSArray *)reservedWords {
    return [[sTDReservedWords retain] autorelease];
}


+ (void)setReservedWords:(NSArray *)inWords {
    if (inWords != sTDReservedWords) {
        [sTDReservedWords autorelease];
        sTDReservedWords = [inWords copy];
    }
}


- (BOOL)qualifies:(id)obj {
    FJSTDToken *tok = (FJSTDToken *)obj;
    if (!tok.isWord) {
        return NO;
    }
    
    NSString *s = tok.stringValue;
    return s.length && [[FJSTDReservedWord reservedWords] containsObject:s];
}

@end
//
//  TDScientificNumberState.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/25/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@interface FJSTDTokenizerState ()
- (void)append:(NSInteger)c;
@end


@implementation FJSTDScientificNumberState

- (void)parseRightSideFromReader:(FJSTDReader *)r {
    NSParameterAssert(r);
    [super parseRightSideFromReader:r];
    if ('e' == c || 'E' == c) {
        NSInteger e = c;
        c = [r read];
        
        BOOL hasExp = isdigit((int)c);
        negativeExp = ('-' == c);
        BOOL positiveExp = ('+' == c);

        if (!hasExp && (negativeExp || positiveExp)) {
            c = [r read];
            hasExp = isdigit((int)c);
        }
        if (-1 != c) {
            [r unread];
        }
        if (hasExp) {
            [self append:e];
            if (negativeExp) {
                [self append:'-'];
            } else if (positiveExp) {
                [self append:'+'];
            }
            c = [r read];
            exp = [super absorbDigitsFromReader:r isFraction:NO];
        }
    }
}


- (void)reset:(NSInteger)cin {
    [super reset:cin];
    exp = (CGFloat)0.0;
    negativeExp = NO;
}


- (CGFloat)value {
    CGFloat result = (CGFloat)floatValue;
    
    NSUInteger i = 0;
    for ( ; i < exp; i++) {
        if (negativeExp) {
            result /= (CGFloat)10.0;
        } else {
            result *= (CGFloat)10.0;
        }
    }
    
    return (CGFloat)result;
}

@end
//
//  TDSequence.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//





@implementation FJSTDSequence

+ (id)sequence {
    return [[[self alloc] init] autorelease];
}


- (NSSet *)allMatchesFor:(NSSet *)inAssemblies {
    NSParameterAssert(inAssemblies);
    NSSet *outAssemblies = inAssemblies;
    
    for (FJSTDParser *p in subparsers) {
        outAssemblies = [p matchAndAssemble:outAssemblies];
        if (!outAssemblies.count) {
            break;
        }
    }
    
    return outAssemblies;
}

@end
//
//  TDSignificantWhitespaceState.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/14/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//






@interface FJSTDTokenizerState ()
- (void)reset;
- (void)append:(NSInteger)c;
- (NSString *)bufferedString;
@end



//
//  TDSingleLineCommentState.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 12/28/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//







@interface FJSTDTokenizerState ()
- (void)reset;
- (void)append:(NSInteger)c;
- (void)appendString:(NSString *)s;
- (NSString *)bufferedString;
@end

@interface FJSTDSingleLineCommentState ()
- (void)addStartSymbol:(NSString *)start;
- (void)removeStartSymbol:(NSString *)start;

@end

@implementation FJSTDSingleLineCommentState

- (id)init {
    self = [super init];
    if (self) {
        self.startSymbols = [NSMutableArray array];
    }
    return self;
}


- (void)dealloc {
    self.startSymbols = nil;
    self.currentStartSymbol = nil;
    [super dealloc];
}


- (void)addStartSymbol:(NSString *)start {
    NSParameterAssert(start.length);
    [startSymbols addObject:start];
}


- (void)removeStartSymbol:(NSString *)start {
    NSParameterAssert(start.length);
    [startSymbols removeObject:start];
}


- (FJSTDToken *)nextTokenFromReader:(FJSTDReader *)r startingWith:(NSInteger)cin tokenizer:(FJSTDTokenizer *)t {
    NSParameterAssert(r);
    NSParameterAssert(t);
    
    BOOL reportTokens = t.commentState.reportsCommentTokens;
    if (reportTokens) {
        [self reset];
        if (currentStartSymbol.length > 1) {
            [self appendString:currentStartSymbol];
        }
    }
    
    NSInteger c;
    while (1) {
        c = [r read];
        if ('\n' == c || '\r' == c || -1 == c) {
            break;
        }
        if (reportTokens) {
            [self append:c];
        }
    }
    
    if (-1 != c) {
        [r unread];
    }
    
    self.currentStartSymbol = nil;
    
    if (reportTokens) {
        return [FJSTDToken tokenWithTokenType:TDTokenTypeComment stringValue:[self bufferedString] floatValue:0.0];
    } else {
        return [t nextToken];
    }
}

@synthesize startSymbols;
@synthesize currentStartSymbol;
@end
//
//  TDSpecificChar.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/14/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



@implementation FJSTDSpecificChar

+ (id)specificCharWithChar:(NSInteger)c {
    return [[[self alloc] initWithSpecificChar:c] autorelease];
}


- (id)initWithSpecificChar:(NSInteger)c {
    self = [super initWithString:[NSString stringWithFormat:@"%C", (unsigned short)c]];
    if (self) {
    }
    return self;
}


- (BOOL)qualifies:(id)obj {
    NSInteger c = [obj integerValue];
    return c == [string characterAtIndex:0];
}

@end
//
//  TDSymbol.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@interface FJSTDSymbol ()
@property (nonatomic, retain) FJSTDToken *symbol;
@end

@implementation FJSTDSymbol

+ (id)symbol {
    return [[[self alloc] initWithString:@""] autorelease];
}


+ (id)symbolWithString:(NSString *)s {
    return [[[self alloc] initWithString:s] autorelease];
}


- (id)initWithString:(NSString *)s {
    self = [super initWithString:s];
    if (self) {
        if (s.length) {
            self.symbol = [FJSTDToken tokenWithTokenType:TDTokenTypeSymbol stringValue:s floatValue:0.0];
        }
    }
    return self;
}


- (void)dealloc {
    self.symbol = nil;
    [super dealloc];
}


- (BOOL)qualifies:(id)obj {
    if (symbol) {
        return [symbol isEqual:obj];
    } else {
        FJSTDToken *tok = (FJSTDToken *)obj;
        return tok.isSymbol;
    }
}


- (NSString *)description {
    NSString *className = [[self className] substringFromIndex:2];
    if (name.length) {
        if (symbol) {
            return [NSString stringWithFormat:@"%@ (%@) %@", className, name, symbol.stringValue];
        } else {
            return [NSString stringWithFormat:@"%@ (%@)", className, name];
        }
    } else {
        if (symbol) {
            return [NSString stringWithFormat:@"%@ %@", className, symbol.stringValue];
        } else {
            return [NSString stringWithFormat:@"%@", className];
        }
    }
}

@synthesize symbol;
@end
//
//  TDSymbolNode.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@interface FJSTDSymbolNode ()
@property (nonatomic, readwrite, retain) NSString *ancestry;
@property (nonatomic, assign) FJSTDSymbolNode *parent;  // this must be 'assign' to avoid retain loop leak
@property (nonatomic, retain) NSMutableDictionary *children;
@property (nonatomic) NSInteger character;
@property (nonatomic, retain) NSString *string;

- (void)determineAncestry;
@end

@implementation FJSTDSymbolNode

- (id)initWithParent:(FJSTDSymbolNode *)p character:(NSInteger)c {
    self = [super init];
    if (self) {
        self.parent = p;
        self.character = c;
        self.children = [NSMutableDictionary dictionary];

        // this private property is an optimization. 
        // cache the NSString for the char to prevent it being constantly recreated in -determinAncestry
        self.string = [NSString stringWithFormat:@"%C", (unsigned short)character];

        [self determineAncestry];
    }
    return self;
}


- (void)dealloc {
    parent = nil; // makes clang static analyzer happy
    self.ancestry = nil;
    self.string = nil;
    self.children = nil;
    [super dealloc];
}


- (void)determineAncestry {
    if (-1 == parent.character) { // optimization for sinlge-char symbol (parent is symbol root node)
        self.ancestry = string;
    } else {
        NSMutableString *result = [NSMutableString string];
        
        FJSTDSymbolNode *n = self;
        while (-1 != n.character) {
            [result insertString:n.string atIndex:0];
            n = n.parent;
        }
        
        self.ancestry = [[result copy] autorelease]; // assign an immutable copy
    }
}


- (NSString *)description {
    return [NSString stringWithFormat:@"<TDSymbolNode %@>", self.ancestry];
}

@synthesize ancestry;
@synthesize parent;
@synthesize character;
@synthesize string;
@synthesize children;
@end
//
//  TDSymbolRootNode.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



@interface FJSTDSymbolRootNode ()
- (void)addWithFirst:(NSInteger)c rest:(NSString *)s parent:(FJSTDSymbolNode *)p;
- (void)removeWithFirst:(NSInteger)c rest:(NSString *)s parent:(FJSTDSymbolNode *)p;
- (NSString *)nextWithFirst:(NSInteger)c rest:(FJSTDReader *)r parent:(FJSTDSymbolNode *)p;
@end

@implementation FJSTDSymbolRootNode

- (id)init {
    self = [super initWithParent:nil character:-1];
    if (self) {
        
    }
    return self;
}


- (void)add:(NSString *)s {
    NSParameterAssert(s);
    if (s.length < 2) return;
    
    [self addWithFirst:[s characterAtIndex:0] rest:[s substringFromIndex:1] parent:self];
}


- (void)remove:(NSString *)s {
    NSParameterAssert(s);
    if (s.length < 2) return;
    
    [self removeWithFirst:[s characterAtIndex:0] rest:[s substringFromIndex:1] parent:self];
}


- (void)addWithFirst:(NSInteger)c rest:(NSString *)s parent:(FJSTDSymbolNode *)p {
    NSParameterAssert(p);
    NSNumber *key = [NSNumber numberWithInteger:c];
    FJSTDSymbolNode *child = [p.children objectForKey:key];
    if (!child) {
        child = [[FJSTDSymbolNode alloc] initWithParent:p character:c];
        [p.children setObject:child forKey:key];
        [child release];
    }

    NSString *rest = nil;
    
    if (0 == s.length) {
        return;
    } else if (s.length > 1) {
        rest = [s substringFromIndex:1];
    }
    
    [self addWithFirst:[s characterAtIndex:0] rest:rest parent:child];
}


- (void)removeWithFirst:(NSInteger)c rest:(NSString *)s parent:(FJSTDSymbolNode *)p {
    NSParameterAssert(p);
    NSNumber *key = [NSNumber numberWithInteger:c];
    FJSTDSymbolNode *child = [p.children objectForKey:key];
    if (child) {
        NSString *rest = nil;
        
        if (0 == s.length) {
            return;
        } else if (s.length > 1) {
            rest = [s substringFromIndex:1];
            [self removeWithFirst:[s characterAtIndex:0] rest:rest parent:child];
        }
        
        [p.children removeObjectForKey:key];
    }
}


- (NSString *)nextSymbol:(FJSTDReader *)r startingWith:(NSInteger)cin {
    NSParameterAssert(r);
    return [self nextWithFirst:cin rest:r parent:self];
}


- (NSString *)nextWithFirst:(NSInteger)c rest:(FJSTDReader *)r parent:(FJSTDSymbolNode *)p {
    NSParameterAssert(p);
    NSString *result = [NSString stringWithFormat:@"%C", (unsigned short)c];

    // this also works.
//    NSString *result = [[[NSString alloc] initWithCharacters:(const unichar *)&c length:1] autorelease];
    
    // none of these work.
    //NSString *result = [[[NSString alloc] initWithBytes:&c length:1 encoding:NSUTF8StringEncoding] autorelease];

//    NSLog(@"c: %d", c);
//    NSLog(@"string for c: %@", result);
//    NSString *chars = [[[NSString alloc] initWithCharacters:(const unichar *)&c length:1] autorelease];
//    NSString *utfs  = [[[NSString alloc] initWithUTF8String:(const char *)&c] autorelease];
//    NSString *utf8  = [[[NSString alloc] initWithBytes:&c length:1 encoding:NSUTF8StringEncoding] autorelease];
//    NSString *utf16 = [[[NSString alloc] initWithBytes:&c length:1 encoding:NSUTF16StringEncoding] autorelease];
//    NSString *ascii = [[[NSString alloc] initWithBytes:&c length:1 encoding:NSASCIIStringEncoding] autorelease];
//    NSString *iso   = [[[NSString alloc] initWithBytes:&c length:1 encoding:NSISOLatin1StringEncoding] autorelease];
//
//    NSLog(@"chars: '%@'", chars);
//    NSLog(@"utfs: '%@'", utfs);
//    NSLog(@"utf8: '%@'", utf8);
//    NSLog(@"utf16: '%@'", utf16);
//    NSLog(@"ascii: '%@'", ascii);
//    NSLog(@"iso: '%@'", iso);
    
    NSNumber *key = [NSNumber numberWithInteger:c];
    FJSTDSymbolNode *child = [p.children objectForKey:key];
    
    if (!child) {
        if (p == self) {
            return result;
        } else {
            [r unread];
            return @"";
        }
    } 
    
    c = [r read];
    if (-1 == c) {
        return result;
    }
    
    return [result stringByAppendingString:[self nextWithFirst:c rest:r parent:child]];
}


- (NSString *)description {
    return @"<TDSymbolRootNode>";
}

@end
//
//  TDSymbolState.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//







@interface FJSTDSymbolState ()
@property (nonatomic, retain) FJSTDSymbolRootNode *rootNode;
@property (nonatomic, retain) NSMutableArray *addedSymbols;
@end

@implementation FJSTDSymbolState

- (id)init {
    self = [super init];
    if (self) {
        self.rootNode = [[[FJSTDSymbolRootNode alloc] init] autorelease];
        self.addedSymbols = [NSMutableArray array];
    }
    return self;
}


- (void)dealloc {
    self.rootNode = nil;
    self.addedSymbols = nil;
    [super dealloc];
}


- (FJSTDToken *)nextTokenFromReader:(FJSTDReader *)r startingWith:(NSInteger)cin tokenizer:(FJSTDTokenizer *)t {
    NSParameterAssert(r);
    NSString *symbol = [rootNode nextSymbol:r startingWith:cin];
    NSInteger len = symbol.length;

    if (0 == len || (len > 1 && [addedSymbols containsObject:symbol])) {
        return [FJSTDToken tokenWithTokenType:TDTokenTypeSymbol stringValue:symbol floatValue:0.0];
    } else {
        NSInteger i = 0;
        for ( ; i < len - 1; i++) {
            [r unread];
        }
        return [FJSTDToken tokenWithTokenType:TDTokenTypeSymbol stringValue:[NSString stringWithFormat:@"%C", (unsigned short)cin] floatValue:0.0];
    }
}


- (void)add:(NSString *)s {
    NSParameterAssert(s);
    [rootNode add:s];
    [addedSymbols addObject:s];
}


- (void)remove:(NSString *)s {
    NSParameterAssert(s);
    [rootNode remove:s];
    [addedSymbols removeObject:s];
}

@synthesize rootNode;
@synthesize addedSymbols;
@end
//
//  TDTerminal.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//





@interface FJSTDTerminal ()
- (FJSTDAssembly *)matchOneAssembly:(FJSTDAssembly *)inAssembly;
- (BOOL)qualifies:(id)obj;

@property (nonatomic, readwrite, copy) NSString *string;
@end

@implementation FJSTDTerminal

- (id)init {
    return [self initWithString:nil];
}


- (id)initWithString:(NSString *)s {
    self = [super init];
    if (self) {
        self.string = s;
    }
    return self;
}


- (void)dealloc {
    self.string = nil;
    [super dealloc];
}


- (NSSet *)allMatchesFor:(NSSet *)inAssemblies {
    NSParameterAssert(inAssemblies);
    NSMutableSet *outAssemblies = [NSMutableSet set];
    
    for (FJSTDAssembly *a in inAssemblies) {
        FJSTDAssembly *b = [self matchOneAssembly:a];
        if (b) {
            [outAssemblies addObject:b];
        }
    }
    
    return outAssemblies;
}


- (FJSTDAssembly *)matchOneAssembly:(FJSTDAssembly *)inAssembly {
    NSParameterAssert(inAssembly);
    if (![inAssembly hasMore]) {
        return nil;
    }
    
    FJSTDAssembly *outAssembly = nil;
    
    if ([self qualifies:[inAssembly peek]]) {
        outAssembly = [[inAssembly copy] autorelease];
        id obj = [outAssembly next];
        if (!discardFlag) {
            [outAssembly push:obj];
        }
    }
    
    return outAssembly;
}


- (BOOL)qualifies:(id)obj {
    NSAssert1(0, @"-[TDTerminal %@] must be overriden", NSStringFromSelector(_cmd));
    return NO;
}


- (FJSTDTerminal *)discard {
    discardFlag = YES;
    return self;
}

@synthesize string;
@end
//
//  TDToken.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



@interface TDTokenEOF : FJSTDToken {}
+ (TDTokenEOF *)instance;
@end

@implementation TDTokenEOF

static TDTokenEOF *EOFToken = nil;

#ifndef __clang_analyzer__ // SD: disabled analyzer for this somewhat crazy code; not sure quite what would be wrong with just doing a dispatch_once here...
+ (TDTokenEOF *)instance {
    @synchronized(self) {
        if (!EOFToken) {
            [[self alloc] init]; // assignment not done here
        }
    }
    return EOFToken;
}
#endif

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (!EOFToken) {
            EOFToken = [super allocWithZone:zone];
            return EOFToken;  // assignment and return on first allocation
        }
    }
    return nil; //on subsequent allocation attempts return nil
}


- (id)copyWithZone:(NSZone *)zone {
    return self;
}


- (id)retain {
    return self;
}


- (oneway void)release {
    // do nothing
}


- (id)autorelease {
    return self;
}


- (NSUInteger)retainCount {
    return UINT_MAX; // denotes an object that cannot be released
}


- (NSString *)description {
    return [NSString stringWithFormat:@"<TDTokenEOF %p>", self];
}


- (NSString *)debugDescription {
    return [self description];
}

@end

@interface FJSTDToken ()
- (BOOL)isEqual:(id)rhv ignoringCase:(BOOL)ignoringCase;

@property (nonatomic, readwrite, getter=isNumber) BOOL number;
@property (nonatomic, readwrite, getter=isQuotedString) BOOL quotedString;
@property (nonatomic, readwrite, getter=isSymbol) BOOL symbol;
@property (nonatomic, readwrite, getter=isWord) BOOL word;
@property (nonatomic, readwrite, getter=isWhitespace) BOOL whitespace;
@property (nonatomic, readwrite, getter=isComment) BOOL comment;

@property (nonatomic, readwrite) CGFloat floatValue;
@property (nonatomic, readwrite, copy) NSString *stringValue;
@property (nonatomic, readwrite) TDTokenType tokenType;
@property (nonatomic, readwrite, copy) id value;
@end

@implementation FJSTDToken

+ (FJSTDToken *)EOFToken {
    return [TDTokenEOF instance];
}


+ (id)tokenWithTokenType:(TDTokenType)t stringValue:(NSString *)s floatValue:(CGFloat)n {
    return [[[self alloc] initWithTokenType:t stringValue:s floatValue:n] autorelease];
}


// designated initializer
- (id)initWithTokenType:(TDTokenType)t stringValue:(NSString *)s floatValue:(CGFloat)n {
    //NSParameterAssert(s);
    self = [super init];
    if (self) {
        self.tokenType = t;
        self.stringValue = s;
        self.floatValue = n;
        
        self.number = (TDTokenTypeNumber == t);
        self.quotedString = (TDTokenTypeQuotedString == t);
        self.symbol = (TDTokenTypeSymbol == t);
        self.word = (TDTokenTypeWord == t);
        self.whitespace = (TDTokenTypeWhitespace == t);
        self.comment = (TDTokenTypeComment == t);
    }
    return self;
}


- (void)dealloc {
    self.stringValue = nil;
    self.value = nil;
    [super dealloc];
}


- (NSUInteger)hash {
    return [stringValue hash];
}


- (BOOL)isEqual:(id)rhv {
    return [self isEqual:rhv ignoringCase:NO];
}


- (BOOL)isEqualIgnoringCase:(id)rhv {
    return [self isEqual:rhv ignoringCase:YES];
}


- (BOOL)isEqual:(id)rhv ignoringCase:(BOOL)ignoringCase {
    if (![rhv isMemberOfClass:[FJSTDToken class]]) {
        return NO;
    }
    
    FJSTDToken *tok = (FJSTDToken *)rhv;
    if (tokenType != tok.tokenType) {
        return NO;
    }
    
    if (self.isNumber) {
        return floatValue == tok.floatValue;
    } else {
        if (ignoringCase) {
            return (NSOrderedSame == [stringValue caseInsensitiveCompare:tok.stringValue]);
        } else {
            return [stringValue isEqualToString:tok.stringValue];
        }
    }
}


- (id)value {
    if (!value) {
        id v = nil;
        if (self.isNumber) {
            v = [NSNumber numberWithFloat:floatValue];
        } else if (self.isQuotedString) {
            v = stringValue;
        } else if (self.isSymbol) {
            v = stringValue;
        } else if (self.isWord) {
            v = stringValue;
        } else if (self.isWhitespace) {
            v = stringValue;
        } else { // support for token type extensions
            v = stringValue;
        }
        self.value = v;
    }
    return value;
}


- (NSString *)debugDescription {
    NSString *typeString = nil;
    if (self.isNumber) {
        typeString = @"Number";
    } else if (self.isQuotedString) {
        typeString = @"Quoted String";
    } else if (self.isSymbol) {
        typeString = @"Symbol";
    } else if (self.isWord) {
        typeString = @"Word";
    } else if (self.isWhitespace) {
        typeString = @"Whitespace";
    } else if (self.isComment) {
        typeString = @"Comment";
    }
    return [NSString stringWithFormat:@"<%@ %C%@%C>", typeString, (unsigned short)0x00AB, self.value, (unsigned short)0x00BB];
}


- (NSString *)description {
    return stringValue;
}

@synthesize number;
@synthesize quotedString;
@synthesize symbol;
@synthesize word;
@synthesize whitespace;
@synthesize comment;
@synthesize floatValue;
@synthesize stringValue;
@synthesize tokenType;
@synthesize value;
@end
//
//  TDTokenArraySource.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 12/11/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//





@interface FJSTDTokenArraySource ()
@property (nonatomic, retain) FJSTDTokenizer *tokenizer;
@property (nonatomic, retain) NSString *delimiter;
@property (nonatomic, retain) FJSTDToken *nextToken;
@end

@implementation FJSTDTokenArraySource

- (id)init {
    return [self initWithTokenizer:nil delimiter:nil];
}


- (id)initWithTokenizer:(FJSTDTokenizer *)t delimiter:(NSString *)s {
    NSParameterAssert(t);
    NSParameterAssert(s);
    self = [super init];
    if (self) {
        self.tokenizer = t;
        self.delimiter = s;
    }
    return self;
}


- (void)dealloc {
    self.tokenizer = nil;
    self.delimiter = nil;
    self.nextToken = nil;
    [super dealloc];
}


- (BOOL)hasMore {
    if (!nextToken) {
        self.nextToken = [tokenizer nextToken];
    }

    return ([FJSTDToken EOFToken] != nextToken);
}


- (NSArray *)nextTokenArray {
    if (![self hasMore]) {
        return nil;
    }
    
    NSMutableArray *res = [NSMutableArray arrayWithObject:nextToken];
    self.nextToken = nil;
    
    FJSTDToken *eof = [FJSTDToken EOFToken];
    FJSTDToken *tok = nil;

    while ((tok = [tokenizer nextToken]) != eof) {
        if ([tok.stringValue isEqualToString:delimiter]) {
            break; // discard delimiter tok
        }
        [res addObject:tok];
    }
    
    //return [[res copy] autorelease];
    return res; // optimization
}

@synthesize tokenizer;
@synthesize delimiter;
@synthesize nextToken;
@end
//
//  TDTokenAssembly.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//





@interface FJSTDTokenAssembly ()
- (id)initWithString:(NSString *)s tokenzier:(FJSTDTokenizer *)t tokenArray:(NSArray *)a;
- (void)tokenize;
- (NSString *)objectsFrom:(NSInteger)start to:(NSInteger)end separatedBy:(NSString *)delimiter;

@property (nonatomic, retain) FJSTDTokenizer *tokenizer;
@property (nonatomic, copy) NSArray *tokens;
@end

@implementation FJSTDTokenAssembly

+ (id)assemblyWithTokenizer:(FJSTDTokenizer *)t {
    return [[[self alloc] initWithTokenzier:t] autorelease];
}


- (id)initWithTokenzier:(FJSTDTokenizer *)t {
    return [self initWithString:t.string tokenzier:t tokenArray:nil];
}


+ (id)assemblyWithTokenArray:(NSArray *)a {
    return [[[self alloc] initWithTokenArray:a] autorelease];
}


- (id)initWithTokenArray:(NSArray *)a {
    return [self initWithString:[a componentsJoinedByString:@""] tokenzier:nil tokenArray:a];
}


- (id)initWithString:(NSString *)s {
    return [self initWithTokenzier:[[[FJSTDTokenizer alloc] initWithString:s] autorelease]];
}


// designated initializer. this method is private and should not be called from other classes
- (id)initWithString:(NSString *)s tokenzier:(FJSTDTokenizer *)t tokenArray:(NSArray *)a {
    self = [super initWithString:s];
    if (self) {
        if (t) {
            self.tokenizer = t;
        } else {
            self.tokens = a;
        }
    }
    return self;
}


- (void)dealloc {
    [tokenizer release];
    [tokens release];
    //self.tokenizer = nil;
    //self.tokens = nil;
    [super dealloc];
}


- (id)copyWithZone:(NSZone *)zone {
    FJSTDTokenAssembly *a = (FJSTDTokenAssembly *)[super copyWithZone:zone];
    a->tokens = [self.tokens copyWithZone:zone];
    a->preservesWhitespaceTokens = preservesWhitespaceTokens;
    return a;
}


- (NSArray *)tokens {
    if (!tokens) {
        [self tokenize];
    }
    return tokens;
}


- (id)peek {
    FJSTDToken *tok = nil;
    
    while (1) {
        if (index >= self.tokens.count) {
            tok = nil;
            break;
        }
        
        tok = [self.tokens objectAtIndex:index];
        if (!preservesWhitespaceTokens) {
            break;
        }
        if (TDTokenTypeWhitespace == tok.tokenType) {
            [self push:tok];
            index++;
        } else {
            break;
        }
    }
    
    return tok;
}


- (id)next {
    id tok = [self peek];
    if (tok) {
        index++;
    }
    return tok;
}


- (BOOL)hasMore {
    return (index < self.tokens.count);
}


- (NSUInteger)length {
    return self.tokens.count;
} 


- (NSUInteger)objectsConsumed {
    return index;
}


- (NSUInteger)objectsRemaining {
    return (self.tokens.count - index);
}


- (NSString *)consumedObjectsJoinedByString:(NSString *)delimiter {
    NSParameterAssert(delimiter);
    return [self objectsFrom:0 to:self.objectsConsumed separatedBy:delimiter];
}


- (NSString *)remainingObjectsJoinedByString:(NSString *)delimiter {
    NSParameterAssert(delimiter);
    return [self objectsFrom:self.objectsConsumed to:self.length separatedBy:delimiter];
}


#pragma mark -
#pragma mark Private

- (void)tokenize {
    if (!tokenizer) {
        return;
    }
    
    NSMutableArray *a = [NSMutableArray array];
    
    FJSTDToken *eof = [FJSTDToken EOFToken];
    FJSTDToken *tok = nil;
    while ((tok = [tokenizer nextToken]) != eof) {
        [a addObject:tok];
    }

    self.tokens = a;
}


- (NSString *)objectsFrom:(NSInteger)start to:(NSInteger)end separatedBy:(NSString *)delimiter {
    NSMutableString *s = [NSMutableString string];

    NSInteger i = start;
    for ( ; i < end; i++) {
        FJSTDToken *tok = [self.tokens objectAtIndex:i];
        [s appendString:tok.stringValue];
        if (end - 1 != i) {
            [s appendString:delimiter];
        }
    }
    
    return [[s copy] autorelease];
}

@synthesize tokenizer;
@synthesize tokens;
@synthesize preservesWhitespaceTokens;
@end
//
//  TDParseKit.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@interface FJSTDTokenizer ()
- (void)addTokenizerState:(FJSTDTokenizerState *)state from:(NSInteger)start to:(NSInteger)end;
- (FJSTDTokenizerState *)tokenizerStateFor:(NSInteger)c;
@property (nonatomic, retain) FJSTDReader *reader;
@property (nonatomic, retain) NSMutableArray *tokenizerStates;
@end

@implementation FJSTDTokenizer

+ (id)tokenizer {
    return [self tokenizerWithString:nil];
}


+ (id)tokenizerWithString:(NSString *)s {
    return [[[self alloc] initWithString:s] autorelease];
}


- (id)init {
    return [self initWithString:nil];
}


- (id)initWithString:(NSString *)s {
    self = [super init];
    if (self) {
        self.string = s;
        self.reader = [[[FJSTDReader alloc] init] autorelease];
        
        numberState = [[FJSTDNumberState alloc] init];
        quoteState = [[FJSTDQuoteState alloc] init];
        commentState = [[FJSTDCommentState alloc] init];
        symbolState = [[FJSTDSymbolState alloc] init];
        whitespaceState = [[FJSTDWhitespaceState alloc] init];
        wordState = [[FJSTDWordState alloc] init];
        
        [symbolState add:@"<="];
        [symbolState add:@">="];
        [symbolState add:@"!="];
        [symbolState add:@"=="];
        
        [commentState addSingleLineStartSymbol:@"//"];
        [commentState addMultiLineStartSymbol:@"/*" endSymbol:@"*/"];
        
        tokenizerStates = [[NSMutableArray alloc] initWithCapacity:256];
        
        [self addTokenizerState:whitespaceState from:   0 to: ' ']; // From:  0 to: 32    From:0x00 to:0x20
        [self addTokenizerState:symbolState     from:  33 to:  33];
        [self addTokenizerState:quoteState      from: '"' to: '"']; // From: 34 to: 34    From:0x22 to:0x22
        [self addTokenizerState:symbolState     from:  35 to:  38];
        [self addTokenizerState:quoteState      from:'\'' to:'\'']; // From: 39 to: 39    From:0x27 to:0x27
        [self addTokenizerState:symbolState     from:  40 to:  42];
        [self addTokenizerState:symbolState     from: '+' to: '+']; // From: 43 to: 43    From:0x2B to:0x2B
        [self addTokenizerState:symbolState     from:  44 to:  44];
        [self addTokenizerState:numberState     from: '-' to: '-']; // From: 45 to: 45    From:0x2D to:0x2D
        [self addTokenizerState:numberState     from: '.' to: '.']; // From: 46 to: 46    From:0x2E to:0x2E
        [self addTokenizerState:commentState    from: '/' to: '/']; // From: 47 to: 47    From:0x2F to:0x2F
        [self addTokenizerState:numberState     from: '0' to: '9']; // From: 48 to: 57    From:0x30 to:0x39
        [self addTokenizerState:symbolState     from:  58 to:  64];
        [self addTokenizerState:wordState       from: 'A' to: 'Z']; // From: 65 to: 90    From:0x41 to:0x5A
        [self addTokenizerState:symbolState     from:  91 to:  96];
        [self addTokenizerState:wordState       from: 'a' to: 'z']; // From: 97 to:122    From:0x61 to:0x7A
        [self addTokenizerState:symbolState     from: 123 to: 191];
        [self addTokenizerState:wordState       from:0xC0 to:0xFF]; // From:192 to:255    From:0xC0 to:0xFF
    }
    return self;
}


- (void)dealloc {
    self.string = nil;
    self.reader = nil;
    self.tokenizerStates = nil;
    self.numberState = nil;
    self.quoteState = nil;
    self.commentState = nil;
    self.symbolState = nil;
    self.whitespaceState = nil;
    self.wordState = nil;
    [super dealloc];
}


- (FJSTDToken *)nextToken {
    NSInteger c = [reader read];
    
    FJSTDToken *result = nil;
    
    if (-1 == c) {
        result = [FJSTDToken EOFToken];
    } else {
        FJSTDTokenizerState *state = [self tokenizerStateFor:c];
        if (state) {
            result = [state nextTokenFromReader:reader startingWith:c tokenizer:self];
        } else {
            result = [FJSTDToken EOFToken];
        }
    }
    
    return result;
}


- (void)addTokenizerState:(FJSTDTokenizerState *)state from:(NSInteger)start to:(NSInteger)end {
    NSParameterAssert(state);
    
    //void (*addObject)(id, SEL, id);
    //addObject = (void (*)(id, SEL, id))[tokenizerStates methodForSelector:@selector(addObject:)];
    
    NSInteger i = start;
    for ( ; i <= end; i++) {
        [tokenizerStates addObject:state];
        //addObject(tokenizerStates, @selector(addObject:), state);
    }
}


- (void)setTokenizerState:(FJSTDTokenizerState *)state from:(NSInteger)start to:(NSInteger)end {
    NSParameterAssert(state);

    //void (*relaceObject)(id, SEL, NSUInteger, id);
    //relaceObject = (void (*)(id, SEL, NSUInteger, id))[tokenizerStates methodForSelector:@selector(replaceObjectAtIndex:withObject:)];

    NSInteger i = start;
    for ( ; i <= end; i++) {
        [tokenizerStates replaceObjectAtIndex:i withObject:state];
        //relaceObject(tokenizerStates, @selector(replaceObjectAtIndex:withObject:), i, state);
    }
}


- (FJSTDReader *)reader {
    return reader;
}


- (void)setReader:(FJSTDReader *)r {
    if (reader != r) {
        [reader release];
        reader = [r retain];
        reader.string = string;
    }
}


- (NSString *)string {
    return string;
}


- (void)setString:(NSString *)s {
    if (string != s) {
        [string release];
        string = [s retain];
    }
    reader.string = string;
}


#pragma mark -

- (FJSTDTokenizerState *)tokenizerStateFor:(NSInteger)c {
    if (c < 0 || c > 255) {
        if (c >= 0x19E0 && c <= 0x19FF) { // khmer symbols
            return symbolState;
        } else if (c >= 0x2000 && c <= 0x2BFF) { // various symbols
            return symbolState;
        } else if (c >= 0x2E00 && c <= 0x2E7F) { // supplemental punctuation
            return symbolState;
        } else if (c >= 0x3000 && c <= 0x303F) { // cjk symbols & punctuation
            return symbolState;
        } else if (c >= 0x3200 && c <= 0x33FF) { // enclosed cjk letters and months, cjk compatibility
            return symbolState;
        } else if (c >= 0x4DC0 && c <= 0x4DFF) { // yijing hexagram symbols
            return symbolState;
        } else if (c >= 0xFE30 && c <= 0xFE6F) { // cjk compatibility forms, small form variants
            return symbolState;
        } else if (c >= 0xFF00 && c <= 0xFFFF) { // hiragana & katakana halfwitdh & fullwidth forms, Specials
            return symbolState;
        } else {
            return wordState;
        }
    }
    return [tokenizerStates objectAtIndex:c];
}

@synthesize numberState;
@synthesize quoteState;
@synthesize commentState;
@synthesize symbolState;
@synthesize whitespaceState;
@synthesize wordState;
@synthesize string;
@synthesize tokenizerStates;
@end
//
//  TDParseKitState.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



@interface FJSTDTokenizerState ()
- (void)reset;
- (void)append:(NSInteger)c;
- (void)appendString:(NSString *)s;
- (NSString *)bufferedString;

#if TD_USE_MUTABLE_STRING_BUF
@property (nonatomic, retain) NSMutableString *stringbuf;
#else
- (void)checkBufLength;
- (unichar *)mallocCharbuf:(NSUInteger)size;
#endif
@end

@implementation FJSTDTokenizerState

- (void)dealloc {
#if TD_USE_MUTABLE_STRING_BUF
    self.stringbuf = nil;
#else
    if (charbuf && ![[NSGarbageCollector defaultCollector] isEnabled]) {
        free(charbuf);
        charbuf = NULL;
    }
#endif
    [super dealloc];
}


- (FJSTDToken *)nextTokenFromReader:(FJSTDReader *)r startingWith:(NSInteger)cin tokenizer:(FJSTDTokenizer *)t {
    NSAssert(0, @"TDTokenizerState is an Abstract Classs. nextTokenFromStream:at:tokenizer: must be overriden");
    return nil;
}


- (void)reset {
#if TD_USE_MUTABLE_STRING_BUF
    self.stringbuf = [NSMutableString string];
#else
    if (charbuf && ![[NSGarbageCollector defaultCollector] isEnabled]) {
        free(charbuf);
        charbuf = NULL;
    }
    index = 0;
    length = 16;
    charbuf = [self mallocCharbuf:length];
#endif
}


- (void)append:(NSInteger)c {
#if TD_USE_MUTABLE_STRING_BUF
    [stringbuf appendFormat:@"%C", (unsigned short)c];
#else 
    [self checkBufLength];
    charbuf[index++] = c;
#endif
}


- (void)appendString:(NSString *)s {
#if TD_USE_MUTABLE_STRING_BUF
    [stringbuf appendString:s];
#else 
    // TODO
    NSAssert1(0, @"-[TDTokenizerState %s] not impl for charbuf", _cmd);
#endif
}


- (NSString *)bufferedString {
#if TD_USE_MUTABLE_STRING_BUF
    return [[stringbuf copy] autorelease];
#else
    return [[[NSString alloc] initWithCharacters:(const unichar *)charbuf length:index] autorelease];
//    return [[[NSString alloc] initWithBytes:charbuf length:index encoding:NSUTF8StringEncoding] autorelease];
#endif
}


#if TD_USE_MUTABLE_STRING_BUF
#else
- (void)checkBufLength {
    if (index >= length) {
        unichar *nb = [self mallocCharbuf:length * 2];
        
        NSInteger j = 0;
        for ( ; j < length; j++) {
            nb[j] = charbuf[j];
        }
        if (![[NSGarbageCollector defaultCollector] isEnabled]) {
            free(charbuf);
            charbuf = NULL;
        }
        charbuf = nb;
        
        length = length * 2;
    }
}


- (unichar *)mallocCharbuf:(NSUInteger)size {
    unichar *result = NULL;
    if ((result = (unichar *)NSAllocateCollectable(size, 0)) == NULL) {
        [NSException raise:@"Out of memory" format:nil];
    }
    return result;
}
#endif

#if TD_USE_MUTABLE_STRING_BUF
@synthesize stringbuf;
#endif
@end
//
//  TDTrack.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//





@interface FJSTDTrack ()
- (void)throwTrackExceptionWithPreviousState:(NSSet *)inAssemblies parser:(FJSTDParser *)p;
@end

@implementation FJSTDTrack

+ (id)track {
    return [[[self alloc] init] autorelease];
}


- (NSSet *)allMatchesFor:(NSSet *)inAssemblies {
    NSParameterAssert(inAssemblies);
    BOOL inTrack = NO;
    NSSet *lastAssemblies = inAssemblies;
    NSSet *outAssemblies = inAssemblies;
    
    for (FJSTDParser *p in subparsers) {
        outAssemblies = [p matchAndAssemble:outAssemblies];
        if (!outAssemblies.count) {
            if (inTrack) {
                [self throwTrackExceptionWithPreviousState:lastAssemblies parser:p];
            }
            break;
        }
        inTrack = YES;
        lastAssemblies = outAssemblies;
    }
    
    return outAssemblies;
}

- (void)throwTrackExceptionWithPreviousState:(NSSet *)inAssemblies parser:(FJSTDParser *)p {
    FJSTDAssembly *best = [self best:inAssemblies];
    
    NSString *after = [best consumedObjectsJoinedByString:@" "];
    if (!after.length) {
        after = @"-nothing-";
    }
    
    NSString *expected = [p description];
    
    id next = [best peek];
    NSString *found = next ? [next description] : @"-nothing-";
    
    NSString *reason = [NSString stringWithFormat:@"\n\nAfter : %@\nExpected : %@\nFound : %@\n\n", after, expected, found];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              after, @"after",
                              expected, @"expected",
                              found, @"found",
                              nil];
    [[FJSTDTrackException exceptionWithName:TDTrackExceptionName reason:reason userInfo:userInfo] raise];
}

@end
//
//  TDTrackException.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 10/14/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



NSString * const TDTrackExceptionName = @"Track Exception";

@implementation FJSTDTrackException

@end
//
//  TDUppercaseWord.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@implementation FJSTDUppercaseWord

- (BOOL)qualifies:(id)obj {
    FJSTDToken *tok = (FJSTDToken *)obj;
    if (!tok.isWord) {
        return NO;
    }
    
    NSString *s = tok.stringValue;
    return s.length && isupper([s characterAtIndex:0]);
}

@end
//
//  TDWhitespaceState.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//






#define TDTRUE (id)kCFBooleanTrue
#define TDFALSE (id)kCFBooleanFalse


@interface FJSTDWhitespaceState ()
@property (nonatomic, retain) NSMutableArray *whitespaceChars;
@end

@implementation FJSTDWhitespaceState

- (id)init {
    self = [super init];
    if (self) {
        const NSUInteger len = 255;
        self.whitespaceChars = [NSMutableArray arrayWithCapacity:len];
        NSUInteger i = 0;
        for ( ; i <= len; i++) {
            [whitespaceChars addObject:TDFALSE];
        }
        
        [self setWhitespaceChars:YES from:0 to:' '];
    }
    return self;
}


- (void)dealloc {
    self.whitespaceChars = nil;
    [super dealloc];
}


- (void)setWhitespaceChars:(BOOL)yn from:(NSInteger)start to:(NSInteger)end {
    NSUInteger len = whitespaceChars.count;
    if (start > len || end > len || start < 0 || end < 0) {
        [NSException raise:@"TDWhitespaceStateNotSupportedException" format:@"TDWhitespaceState only supports setting word chars for chars in the latin1 set (under 256)"];
    }

    id obj = yn ? TDTRUE : TDFALSE;
    NSUInteger i = start;
    for ( ; i <= end; i++) {
        [whitespaceChars replaceObjectAtIndex:i withObject:obj];
    }
}


- (BOOL)isWhitespaceChar:(NSInteger)cin {
    if (cin < 0 || cin > whitespaceChars.count - 1) {
        return NO;
    }
    return TDTRUE == [whitespaceChars objectAtIndex:cin];
}


- (FJSTDToken *)nextTokenFromReader:(FJSTDReader *)r startingWith:(NSInteger)cin tokenizer:(FJSTDTokenizer *)t {
    NSParameterAssert(r);
    if (reportsWhitespaceTokens) {
        [self reset];
    }
    
    NSInteger c = cin;
    while ([self isWhitespaceChar:c]) {
        if (reportsWhitespaceTokens) {
            [self append:c];
        }
        c = [r read];
    }
    if (-1 != c) {
        [r unread];
    }
    
    if (reportsWhitespaceTokens) {
        return [FJSTDToken tokenWithTokenType:TDTokenTypeWhitespace stringValue:[self bufferedString] floatValue:0.0];
    } else {
        return [t nextToken];
    }
}

@synthesize whitespaceChars;
@synthesize reportsWhitespaceTokens;
@end

//
//  TDWord.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@implementation FJSTDWord

+ (id)word {
    return [[[self alloc] initWithString:@""] autorelease];
}


- (BOOL)qualifies:(id)obj {
    FJSTDToken *tok = (FJSTDToken *)obj;
    return tok.isWord;
}

@end
//
//  TDWordOrReservedState.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/14/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



@interface FJSTDWordOrReservedState ()
@property (nonatomic, retain) NSMutableSet *reservedWords;
@end

@implementation FJSTDWordOrReservedState

- (id)init {
    self = [super init];
    if (self) {
        self.reservedWords = [NSMutableSet set];
    }
    return self;
}


- (void)dealloc {
    self.reservedWords = nil;
    [super dealloc];
}


- (void)addReservedWord:(NSString *)s {
    [reservedWords addObject:s];
}


- (FJSTDToken *)nextTokenFromReader:(FJSTDReader *)r startingWith:(NSInteger)cin tokenizer:(FJSTDTokenizer *)t {
    NSParameterAssert(r);
    return nil;
}

@synthesize reservedWords;
@end
//
//  TDWordState.m
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//






#define TDTRUE (id)kCFBooleanTrue
#define TDFALSE (id)kCFBooleanFalse


@interface FJSTDWordState () 
- (BOOL)isWordChar:(NSInteger)c;

@property (nonatomic, retain) NSMutableArray *wordChars;
@end

@implementation FJSTDWordState

- (id)init {
    self = [super init];
    if (self) {
        const NSUInteger len = 255;
        self.wordChars = [NSMutableArray arrayWithCapacity:len];
        NSInteger i = 0;
        for ( ; i <= len; i++) {
            [wordChars addObject:TDFALSE];
        }
        
        [self setWordChars:YES from: 'a' to: 'z'];
        [self setWordChars:YES from: 'A' to: 'Z'];
        [self setWordChars:YES from: '0' to: '9'];
        [self setWordChars:YES from: '-' to: '-'];
        [self setWordChars:YES from: '_' to: '_'];
        [self setWordChars:YES from:'\'' to:'\''];
        [self setWordChars:YES from:0xC0 to:0xFF];
    }
    return self;
}


- (void)dealloc {
    self.wordChars = nil;
    [super dealloc];
}


- (void)setWordChars:(BOOL)yn from:(NSInteger)start to:(NSInteger)end {
    NSInteger len = wordChars.count;
    if (start > len || end > len || start < 0 || end < 0) {
        [NSException raise:@"TDWordStateNotSupportedException" format:@"TDWordState only supports setting word chars for chars in the latin1 set (under 256)"];
    }
    
    id obj = yn ? TDTRUE : TDFALSE;
    NSInteger i = start;
    for ( ; i <= end; i++) {
        [wordChars replaceObjectAtIndex:i withObject:obj];
    }
}


- (BOOL)isWordChar:(NSInteger)c {    
    if (c > -1 && c < wordChars.count - 1) {
        return (TDTRUE == [wordChars objectAtIndex:c]);
    }

    if (c >= 0x2000 && c <= 0x2BFF) { // various symbols
        return NO;
    } else if (c >= 0xFE30 && c <= 0xFE6F) { // general punctuation
        return NO;
    } else if (c >= 0xFE30 && c <= 0xFE6F) { // western musical symbols
        return NO;
    } else if (c >= 0xFF00 && c <= 0xFF65) { // symbols within Hiragana & Katakana
        return NO;            
    } else if (c >= 0xFFF0 && c <= 0xFFFF) { // specials
        return NO;            
    } else if (c < 0) {
        return NO;
    } else {
        return YES;
    }
}


- (FJSTDToken *)nextTokenFromReader:(FJSTDReader *)r startingWith:(NSInteger)cin tokenizer:(FJSTDTokenizer *)t {
    NSParameterAssert(r);
    [self reset];
    
    NSInteger c = cin;
    do {
        [self append:c];
        c = [r read];
    } while ([self isWordChar:c]);
    
    if (-1 != c) {
        [r unread];
    }
    
    return [FJSTDToken tokenWithTokenType:TDTokenTypeWord stringValue:[self bufferedString] floatValue:0.0];
}


@synthesize wordChars;
@end
