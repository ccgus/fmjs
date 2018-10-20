#import <Foundation/Foundation.h>

@class FJSTDParser;
@class FJSTDCollectionParser;
@class FJSTDTerminal;
@class FJSTDLiteral;
@class FJSTDAlternation;
@class FJSTDTokenizerState;
@class FJSTDWhitespaceState;
@class FJSTDWord;
@class FJSTDToken;
@class FJSTDAny;
@class FJSTDAssembly;
@class FJSTDCaseInsensitiveLiteral;
@class FJSTDChar;
@class FJSTDCharacterAssembly;
@class FJSTDComment;
@class FJSTDCommentState;
@class FJSTDDigit;
@class FJSTDEmpty;
@class FJSTDLetter;
@class FJSTDLowercaseWord;
@class FJSTDMultiLineCommentState;
@class FJSTDNonReservedWord;
@class FJSTDNum;
@class FJSTDNumberState;
@class FJSTDParseKit;
@class FJSTDQuoteState;
@class FJSTDQuotedString;
@class FJSTDReader;
@class FJSTDRepetition;
@class FJSTDReservedWord;
@class FJSTDScientificNumberState;
@class FJSTDSequence;
@class FJSTDSingleLineCommentState;
@class FJSTDSpecificChar;
@class FJSTDSymbol;
@class FJSTDSymbolNode;
@class FJSTDSymbolRootNode;
@class FJSTDSymbolState;
@class FJSTDTokenArraySource;
@class FJSTDTokenAssembly;
@class FJSTDTokenizer;
@class FJSTDTrack;
@class FJSTDTrackException;
@class FJSTDUppercaseWord;
@class FJSTDWordState;
@class FJSTDWordOrReservedState;
//
//  TDParser.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



@class FJSTDAssembly;

/*!
    @class      TDParser 
    @brief      An Abstract class. A <tt>TDParser</tt> is an object that recognizes the elements of a language.
    @details    <p>Each <tt>TDParser</tt> object is either a <tt>TDTerminal</tt> or a composition of other parsers. The <tt>TDTerminal</tt> class is a subclass of Parser, and is itself a hierarchy of parsers that recognize specific patterns of text. For example, a <tt>TDWord</tt> recognizes any word, and a <tt>TDLiteral</tt> matches a specific string.</p>
                <p>In addition to <tt>TDTerminal</tt>, other subclasses of <tt>TDParser</tt> provide composite parsers, describing sequences, alternations, and repetitions of other parsers. For example, the following <tt>TDParser</tt> objects culminate in a good parser that recognizes a description of good coffee.</p>
@code
    TDAlternation *adjective = [TDAlternation alternation];
    [adjective add:[TDLiteral literalWithString:@"steaming"]];
    [adjective add:[TDLiteral literalWithString:@"hot"]];
    TDSequence *good = [TDSequence sequence];
    [good add:[TDRepetition repetitionWithSubparser:adjective]];
    [good add:[TDLiteral literalWithString:@"coffee"]];
    NSString *s = @"hot hot steaming hot coffee";
    TDAssembly *a = [TDTokenAssembly assemblyWithString:s];
    NSLog([good bestMatchFor:a]);
@endcode
                <p>This prints out:</p>
@code
    [hot, hot, steaming, hot, coffee]
    hot/hot/steaming/hot/coffee^
@endcode
                <p>The parser does not match directly against a string, it matches against a <tt>TDAssembly</tt>. The resulting assembly shows its stack, with four words on it, along with its sequence of tokens, and the index at the end of these. In practice, parsers will do some work on an assembly, based on the text they recognize.</p>
*/
@interface FJSTDParser : NSObject {
    id assembler;
    SEL selector;
    NSString *name;
}

/*!
    @brief      Convenience factory method for initializing an autoreleased parser.
    @result     an initialized autoreleased parser.
*/
+ (id)parser;

/*!
    @brief      Sets the object and method that will work on an assembly whenever this parser successfully matches against the assembly.
    @details    The method represented by <tt>sel</tt> must accept a single <tt>TDAssembly</tt> argument. The signature of <tt>sel</tt> should be similar to: <tt>- (void)workOnAssembly:(TDAssembly *)a</tt>.
    @param      a the assembler this parser will use to work on an assembly
    @param      sel a selector that assembler <tt>a</tt> responds to which will work on an assembly
*/
- (void)setAssembler:(id)a selector:(SEL)sel;

/*!
    @brief      Returns the most-matched assembly in a collection.
    @param      inAssembly the assembly for which to find the best match
    @result     an assembly with the greatest possible number of elements consumed by this parser
*/
- (FJSTDAssembly *)bestMatchFor:(FJSTDAssembly *)inAssembly;

/*!
    @brief      Returns either <tt>nil</tt>, or a completely matched version of the supplied assembly.
    @param      inAssembly the assembly for which to find the complete match
    @result     either <tt>nil</tt>, or a completely matched version of the supplied assembly
*/
- (FJSTDAssembly *)completeMatchFor:(FJSTDAssembly *)inAssembly;

/*!
    @brief      Given a set of assemblies, this method matches this parser against all of them, and returns a new set of the assemblies that result from the matches.
    @details    <p>Given a set of assemblies, this method matches this parser against all of them, and returns a new set of the assemblies that result from the matches.</p>
                <p>For example, consider matching the regular expression <tt>a*</tt> against the string <tt>aaab</tt>. The initial set of states is <tt>{^aaab}</tt>, where the <tt>^</tt> indicates how far along the assembly is. When <tt>a*</tt> matches against this initial state, it creates a new set <tt>{^aaab, a^aab, aa^ab, aaa^b}</tt>.</p>
    @param      inAssemblies set of assemblies to match against
    @result     a set of assemblies that result from matching against a beginning set of assemblies
*/
- (NSSet *)allMatchesFor:(NSSet *)inAssemblies;

/*!
    @property   assembler
    @brief      The assembler this parser will use to work on a matched assembly.
    @details    <tt>assembler</tt> should respond to the selector held by this parser's <tt>selector</tt> property.
*/
@property (nonatomic, assign) id assembler;

/*!
    @property   selector
    @brief      The method of <tt>assembler</tt> this parser will call to work on a matched assembly.
    @details    The method represented by <tt>selector</tt> must accept a single <tt>TDAssembly</tt> argument. The signature of <tt>selector</tt> should be similar to: <tt>- (void)workOnAssembly:(TDAssembly *)a</tt>.
*/
@property (nonatomic, assign) SEL selector;

/*!
    @property   name
    @brief      The name of this parser.
    @discussion Use this property to help in identifying a parser or for debugging purposes.
*/
@property (nonatomic, copy) NSString *name;
@end
//
//  TDCollectionParser.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDCollectionParser 
    @brief      An Abstract class. This class abstracts the behavior common to parsers that consist of a series of other parsers.
*/
@interface FJSTDCollectionParser : FJSTDParser {
    NSMutableArray *subparsers;
}

/*!
    @brief      Adds a parser to the collection.
    @param      p parser to add
*/
- (void)add:(FJSTDParser *)p;

/*!
    @property   subparsers
    @brief      This parser's subparsers.
*/
@property (nonatomic, readonly, retain) NSMutableArray *subparsers;
@end
//
//  TDTerminal.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@class FJSTDToken;

/*!
    @class      TDTerminal
    @brief      An Abstract Class. A <tt>TDTerminal</tt> is a parser that is not a composition of other parsers.
*/
@interface FJSTDTerminal : FJSTDParser {
    NSString *string;
    BOOL discardFlag;
}

/*!
    @brief      Designated Initializer for all concrete <tt>TDTerminal</tt> subclasses.
    @details    Note this is an abtract class and this method must be called on a concrete subclass.
    @param      s the string matched by this parser
    @result     an initialized <tt>TDTerminal</tt> subclass object
*/
- (id)initWithString:(NSString *)s;

/*!
    @brief      By default, terminals push themselves upon a assembly's stack, after a successful match. This method will turn off that behavior.
    @details    This method returns this parser as a convenience for chainging-style usage.
    @result     this parser, returned for chaining/convenience
*/
- (FJSTDTerminal *)discard;

/*!
    @property   string
    @brief      the string matched by this parser.
*/
@property (nonatomic, readonly, copy) NSString *string;
@end
//
//  TDLiteral.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@class FJSTDToken;

/*!
    @class      TDLiteral 
    @brief      A Literal matches a specific word from an assembly.
*/
@interface FJSTDLiteral : FJSTDTerminal {
    FJSTDToken *literal;
}

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDLiteral</tt> object with a given string.
    @param      s the word represented by this literal
    @result     an initialized autoreleased <tt>TDLiteral</tt> object representing <tt>s</tt>
*/
+ (id)literalWithString:(NSString *)s;
@end
//
//  TDAlternation.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDAlternation
    @brief      A <tt>TDAlternation</tt> object is a collection of parsers, any one of which can successfully match against an assembly.
*/
@interface FJSTDAlternation : FJSTDCollectionParser {

}

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDAlternation</tt> parser.
    @result     an initialized autoreleased <tt>TDAlternation</tt> parser.
*/
+ (id)alternation;
@end
//
//  TDParseKitState.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



#define TD_USE_MUTABLE_STRING_BUF 1

@class FJSTDToken;
@class FJSTDTokenizer;
@class FJSTDReader;

/*!
    @class      TDTokenizerState 
    @brief      A <tt>TDTokenizerState</tt> returns a token, given a reader, an initial character read from the reader, and a tokenizer that is conducting an overall tokenization of the reader.
    @details    The tokenizer will typically have a character state table that decides which state to use, depending on an initial character. If a single character is insufficient, a state such as <tt>TDSlashState</tt> will read a second character, and may delegate to another state, such as <tt>TDSlashStarState</tt>. This prospect of delegation is the reason that the <tt>-nextToken</tt> method has a tokenizer argument.
*/
@interface FJSTDTokenizerState : NSObject {
#if TD_USE_MUTABLE_STRING_BUF
    NSMutableString *stringbuf;
#else
    unichar *__strong charbuf;
    NSUInteger length;
    NSUInteger index;
#endif
}

/*!
    @brief      Return a token that represents a logical piece of a reader.
    @param      r the reader from which to read additional characters
    @param      cin the character that a tokenizer used to determine to use this state
    @param      t the tokenizer currently powering the tokenization
    @result     a token that represents a logical piece of the reader
*/
- (FJSTDToken *)nextTokenFromReader:(FJSTDReader *)r startingWith:(NSInteger)cin tokenizer:(FJSTDTokenizer *)t;
@end
//
//  TDWhitespaceState.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDWhitespaceState
    @brief      A whitespace state ignores whitespace (such as blanks and tabs), and returns the tokenizer's next token.
    @details    By default, all characters from 0 to 32 are whitespace.
*/
@interface FJSTDWhitespaceState : FJSTDTokenizerState {
    NSMutableArray *whitespaceChars;
    BOOL reportsWhitespaceTokens;
}

/*!
    @brief      Informs whether the given character is recognized as whitespace (and therefore ignored) by this state.
    @param      cin the character to check
    @result     true if the given chracter is recognized as whitespace
*/
- (BOOL)isWhitespaceChar:(NSInteger)cin;

/*!
    @brief      Establish the given character range as whitespace to ignore.
    @param      yn true if the given character range is whitespace
    @param      start the "start" character. e.g. <tt>'a'</tt> or <tt>65</tt>.
    @param      end the "end" character. <tt>'z'</tt> or <tt>90</tt>.
*/
- (void)setWhitespaceChars:(BOOL)yn from:(NSInteger)start to:(NSInteger)end;

/*!
    @property   reportsWhitespaceTokens
    @brief      determines whether a <tt>TDTokenizer</tt> associated with this state reports or silently consumes whitespace tokens. default is <tt>NO</tt> which causes silent consumption of whitespace chars
*/
@property (nonatomic) BOOL reportsWhitespaceTokens;
@end
//
//  TDWord.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDWord 
    @brief      A <tt>TDWord</tt> matches a word from a token assembly.
*/
@interface FJSTDWord : FJSTDTerminal {

}

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDWord</tt> object.
    @result     an initialized autoreleased <tt>TDWord</tt> object
*/
+ (id)word;
@end
//
//  TDToken.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



/*!
    @typedef    enum TDTokenType
    @brief      Indicates the type of a <tt>TDToken</tt>
    @var        TDTokenTypeEOF A constant indicating that the endo fo the stream has been read.
    @var        TDTokenTypeNumber A constant indicating that a token is a number, like <tt>3.14</tt>.
    @var        TDTokenTypeQuotedString A constant indicating that a token is a quoted string, like <tt>"Launch Mi"</tt>.
    @var        TDTokenTypeSymbol A constant indicating that a token is a symbol, like <tt>"&lt;="</tt>.
    @var        TDTokenTypeWord A constant indicating that a token is a word, like <tt>cat</tt>.
*/
typedef enum {
    FJSTDTokenTypeEOF,
    FJSTDTokenTypeNumber,
    FJSTDTokenTypeQuotedString,
    FJSTDTokenTypeSymbol,
    FJSTDTokenTypeWord,
    FJSTDTokenTypeWhitespace,
    FJSTDTokenTypeComment
} FJSTDTokenType;

/*!
    @class      TDToken
    @brief      A token represents a logical chunk of a string.
    @details    For example, a typical tokenizer would break the string <tt>"1.23 &lt;= 12.3"</tt> into three tokens: the number <tt>1.23</tt>, a less-than-or-equal symbol, and the number <tt>12.3</tt>. A token is a receptacle, and relies on a tokenizer to decide precisely how to divide a string into tokens.
*/
@interface FJSTDToken : NSObject {
    CGFloat floatValue;
    NSString *stringValue;
    FJSTDTokenType tokenType;
    
    BOOL number;
    BOOL quotedString;
    BOOL symbol;
    BOOL word;
    BOOL whitespace;
    BOOL comment;
    
    id value;
}

/*!
    @brief      Factory method for creating a singleton <tt>TDToken</tt> used to indicate that there are no more tokens.
    @result     A singleton used to indicate that there are no more tokens.
*/
+ (FJSTDToken *)EOFToken;

/*!
    @brief      Factory convenience method for creating an autoreleased token.
    @param      t the type of this token.
    @param      s the string value of this token.
    @param      n the number falue of this token.
    @result     an autoreleased initialized token.
*/
+ (id)tokenWithTokenType:(FJSTDTokenType)t stringValue:(NSString *)s floatValue:(CGFloat)n;

/*!
    @brief      Designated initializer. Constructs a token of the indicated type and associated string or numeric values.
    @param      t the type of this token.
    @param      s the string value of this token.
    @param      n the number falue of this token.
    @result     an autoreleased initialized token.
*/
- (id)initWithTokenType:(FJSTDTokenType)t stringValue:(NSString *)s floatValue:(CGFloat)n;

/*!
    @brief      Returns true if the supplied object is an equivalent <tt>TDToken</tt>, ignoring differences in case.
    @param      obj the object to compare this token to.
    @result     true if <tt>obj</tt> is an equivalent <tt>TDToken</tt>, ignoring differences in case.
*/
- (BOOL)isEqualIgnoringCase:(id)obj;

/*!
    @brief      Returns more descriptive textual representation than <tt>-description</tt> which may be useful for debugging puposes only.
    @details    Usually of format similar to: <tt>&lt;QuotedString "Launch Mi"></tt>, <tt>&lt;Word cat></tt>, or <tt>&lt;Num 3.14></tt>
    @result     A textual representation including more descriptive information than <tt>-description</tt>.
*/
- (NSString *)debugDescription;

/*!
    @property   number
    @brief      True if this token is a number. getter=isNumber
*/
@property (nonatomic, readonly, getter=isNumber) BOOL number;

/*!
    @property   quotedString
    @brief      True if this token is a quoted string. getter=isQuotedString
*/
@property (nonatomic, readonly, getter=isQuotedString) BOOL quotedString;

/*!
    @property   symbol
    @brief      True if this token is a symbol. getter=isSymbol
*/
@property (nonatomic, readonly, getter=isSymbol) BOOL symbol;

/*!
    @property   word
    @brief      True if this token is a word. getter=isWord
*/
@property (nonatomic, readonly, getter=isWord) BOOL word;

/*!
    @property   whitespace
    @brief      True if this token is whitespace. getter=isWhitespace
*/
@property (nonatomic, readonly, getter=isWhitespace) BOOL whitespace;

/*!
    @property   comment
    @brief      True if this token is a comment. getter=isComment
*/
@property (nonatomic, readonly, getter=isComment) BOOL comment;

/*!
    @property   tokenType
    @brief      The type of this token.
*/
@property (nonatomic, readonly) FJSTDTokenType tokenType;

/*!
    @property   floatValue
    @brief      The numeric value of this token.
*/
@property (nonatomic, readonly) CGFloat floatValue;

/*!
    @property   stringValue
    @brief      The string value of this token.
*/
@property (nonatomic, readonly, copy) NSString *stringValue;

/*!
    @property   value
    @brief      Returns an object that represents the value of this token.
*/
@property (nonatomic, readonly, copy) id value;
@end
//
//  TDAny.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 12/14/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDAny 
    @brief      A <tt>TDAny</tt> matches any token from a token assembly.
*/
@interface FJSTDAny : FJSTDTerminal {

}

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDAny</tt> object.
    @result     an initialized autoreleased <tt>TDAny</tt> object
*/
+ (id)any;
@end
//
//  TDAssembly.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



/*!
    @class      TDAssembly 
    @brief      An Abstract class. A <tt>TDAssembly</tt> maintains a stream of language elements along with stack and target objects.
    @details    <p>Parsers use assemblers to record progress at recognizing language elements from assembly's string.</p>
                <p>Note that <tt>TDAssembly</tt> is an abstract class and may not be instantiated directly. Subclasses include <tt>TDTokenAssembly</tt> and <tt>TDCharAssembly</tt>.</p>
*/
@interface FJSTDAssembly : NSObject <NSCopying> {
    NSMutableArray *stack;
    id target;
    NSUInteger index;
    NSString *string;
    NSString *defaultDelimiter;
}

/*!
    @brief      Convenience factory method for initializing an autoreleased assembly.
    @param      s string to be worked on
    @result     an initialized autoreleased assembly
*/
+ (id)assemblyWithString:(NSString *)s;

/*!
    @brief      Designated Initializer. Initializes an assembly with a given string.
    @details    Designated Initializer.
    @param      s string to be worked on
    @result     an initialized assembly
*/
- (id)initWithString:(NSString *)s;

/*!
    @brief      Shows the next object in the assembly, without removing it
    @details    Note this is not the next object in this assembly's stack, but rather the next object from this assembly's stream of elements (tokens or chars depending on the type of concrete <tt>TDAssembly</tt> subclass of this object).
    @result     the next object in the assembly.
*/
- (id)peek;

/*!
    @brief      Returns the next object in the assembly.
    @details    Note this is not the next object in this assembly's stack, but rather the next object from this assembly's stream of elements (tokens or chars depending on the type of concrete <tt>TDAssembly</tt> subclass of this object).
    @result     the next object in the assembly.
*/
- (id)next;

/*!
    @brief      Returns true if this assembly has unconsumed elements.
    @result     true, if this assembly has unconsumed elements
*/
- (BOOL)hasMore;

/*!
    @brief      Returns the elements of this assembly that have been consumed, separated by the specified delimiter.
    @param      delimiter string with which to separate elements of this assembly
    @result     string representing the elements of this assembly that have been consumed, separated by the specified delimiter
*/
- (NSString *)consumedObjectsJoinedByString:(NSString *)delimiter;

/*!
    @brief      Returns the elements of this assembly that remain to be consumed, separated by the specified delimiter.
    @param      delimiter string with which to separate elements of this assembly
    @result     string representing the elements of this assembly that remain to be consumed, separated by the specified delimiter
*/
- (NSString *)remainingObjectsJoinedByString:(NSString *)delimiter;

/*!
    @brief      Removes the object at the top of this assembly's stack and returns it.
    @details    Note this returns an object from this assembly's stack, not from its stream of elements (tokens or chars depending on the type of concrete <tt>TDAssembly</tt> subclass of this object).
    @result     the object at the top of this assembly's stack
*/
- (id)pop;

/*!
    @brief      Pushes an object onto the top of this assembly's stack.
    @param      object object to push
*/
- (void)push:(id)object;

/*!
    @brief      Returns true if this assembly's stack is empty.
    @result     true, if this assembly's stack is empty
*/
- (BOOL)isStackEmpty;

/*!
    @brief      Returns a vector of the elements on this assembly's stack that appear before a specified fence.
    @details    <p>Returns a vector of the elements on this assembly's stack that appear before a specified fence.</p>
                <p>Sometimes a parser will recognize a list from within a pair of parentheses or brackets. The parser can mark the beginning of the list with a fence, and then retrieve all the items that come after the fence with this method.</p>
    @param      fence object that indicates the limit of elements returned from this assembly's stack
    @result     Array of the elements above the specified fence
*/
- (NSArray *)objectsAbove:(id)fence;

/*!
    @property   length
    @brief      The number of elements in this assembly.
*/
@property (nonatomic, readonly) NSUInteger length;

/*!
    @property   objectsConsumed
    @brief      The number of elements that have been consumed.
*/
@property (nonatomic, readonly) NSUInteger objectsConsumed;

/*!
    @property   objectsRemaining
    @brief      The number of elements that have not been consumed
*/
@property (nonatomic, readonly) NSUInteger objectsRemaining;

/*!
    @property   defaultDelimiter
    @brief      The default string to show between elements
*/
@property (nonatomic, readonly, retain) NSString *defaultDelimiter;

/*!
    @property   stack
    @brief      This assembly's stack.
*/
@property (nonatomic, readonly, retain) NSMutableArray *stack;

/*!
    @property   target
    @brief      This assembly's target.
    @details    The object identified as this assembly's "target". Clients can set and retrieve a target, which can be a convenient supplement as a place to work, in addition to the assembly's stack. For example, a parser for an HTML file might use a web page object as its "target". As the parser recognizes markup commands like &lt;head>, it could apply its findings to the target.
*/
@property (nonatomic, retain) id target;
@end
//
//  TDCaseInsensitiveLiteral.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDCaseInsensitiveLiteral 
    @brief      A <tt>TDCaselessLiteral</tt> matches a specified <tt>NSString</tt> from an assembly, disregarding case.
*/
@interface FJSTDCaseInsensitiveLiteral : FJSTDLiteral {

}

@end
//
//  TDChar.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/14/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



/*!
    @class      TDChar 
    @brief      A <tt>TDChar</tt> matches a character from a character assembly.
    @details    <tt>-[TDChar qualifies:]</tt> returns true every time, since this class assumes it is working against a <tt>TDCharacterAssembly</tt>.
*/
@interface FJSTDChar : FJSTDTerminal {

}

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDChar</tt> parser.
    @result     an initialized autoreleased <tt>TDChar</tt> parser.
*/
+ (id)char;
@end
//
//  TDCharacterAssembly.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



/*!
    @class      TDCharacterAssembly 
    @brief      A <tt>TDCharacterAssembly</tt> is a <tt>TDAssembly</tt> whose elements are characters.
*/
@interface FJSTDCharacterAssembly : FJSTDAssembly {

}

@end
//
//  TDComment.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 12/31/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDComment
    @brief      A Comment matches a comment from a token assembly.
*/
@interface FJSTDComment : FJSTDTerminal {

}

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDComment</tt> object.
    @result     an initialized autoreleased <tt>TDComment</tt> object
*/
+ (id)comment;
@end
//
//  TDCommentState.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 12/28/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@class FJSTDSymbolRootNode;
@class FJSTDSingleLineCommentState;
@class FJSTDMultiLineCommentState;

/*!
    @class      TDCommentState
    @brief      This state will either delegate to a comment-handling state, or return a <tt>TDSymbol</tt> token with just the first char in it.
    @details    By default, C and C++ style comments. (<tt>//</tt> to end of line and <tt> &0x002A;/</tt>)
*/
@interface FJSTDCommentState : FJSTDTokenizerState {
    FJSTDSymbolRootNode *rootNode;
    FJSTDSingleLineCommentState *singleLineState;
    FJSTDMultiLineCommentState *multiLineState;
    BOOL reportsCommentTokens;
    BOOL balancesEOFTerminatedComments;
}

/*!
    @brief      Adds the given string as a single-line comment start marker. may be multi-char.
    @details    single line comments begin with <tt>start</tt> and continue until the next new line character. e.g. C-style comments (<tt>// comment text</tt>)
    @param      start a single- or multi-character symbol that should be recognized as the start of a single-line comment
*/
- (void)addSingleLineStartSymbol:(NSString *)start;

/*!
    @brief      Removes the given string as a single-line comment start marker. may be multi-char.
    @details    If <tt>start</tt> was never added as a single-line comment start symbol, this has no effect.
    @param      start a single- or multi-character symbol that should no longer be recognized as the start of a single-line comment
*/
- (void)removeSingleLineStartSymbol:(NSString *)start;

/*!
    @brief      Adds the given strings as a multi-line comment start and end markers. both may be multi-char
    @details    <tt>start</tt> and <tt>end</tt> may be different strings. e.g. <tt></tt> and <tt>&0x002A;/</tt>. Also, the actual comment may or may not be multi-line.
    @param      start a single- or multi-character symbol that should be recognized as the start of a multi-line comment
    @param      end a single- or multi-character symbol that should be recognized as the end of a multi-line comment that began with <tt>start</tt>
*/
- (void)addMultiLineStartSymbol:(NSString *)start endSymbol:(NSString *)end;

/*!
    @brief      Removes <tt>start</tt> and its orignall <tt>end</tt> counterpart as a multi-line comment start and end markers.
    @details    If <tt>start</tt> was never added as a multi-line comment start symbol, this has no effect.
    @param      start a single- or multi-character symbol that should no longer be recognized as the start of a multi-line comment
*/
- (void)removeMultiLineStartSymbol:(NSString *)start;

/*!
    @property   reportsCommentTokens
    @brief      if true, the tokenizer associated with this state will report comment tokens, otherwise it silently consumes comments
    @details    if true, this state will return <tt>TDToken</tt>s of type <tt>TDTokenTypeComment</tt>.
                Otherwise, it will silently consume comment text and return the next token from another of the tokenizer's states
*/
@property (nonatomic) BOOL reportsCommentTokens;

/*!
    @property   balancesEOFTerminatedComments
    @brief      if true, this state will append a matching comment string (<tt>&0x002A;/</tt> [C++] or <tt>:)</tt> [XQuery]) to quotes terminated by EOF. Default is NO.
*/
@property (nonatomic) BOOL balancesEOFTerminatedComments;
@end
//
//  TDDigit.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/14/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



/*!
    @class      TDDigit 
    @brief      A <tt>TDDigit</tt> matches a digit from a character assembly.
    @details    <tt>-[TDDitgit qualifies:]</tt> returns true if an assembly's next element is a digit.
*/
@interface FJSTDDigit : FJSTDTerminal {

}

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDDigit</tt> parser.
    @result     an initialized autoreleased <tt>TDDigit</tt> parser.
*/
+ (id)digit;
@end
//
//  TDEmpty.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDEmpty 
    @brief      A <tt>TDEmpty</tt> parser matches any assembly once, and applies its assembler that one time.
    @details    <p>Language elements often contain empty parts. For example, a language may at some point allow a list of parameters in parentheses, and may allow an empty list. An empty parser makes it easy to match, within the parenthesis, either a list of parameters or "empty".</p>
*/
@interface FJSTDEmpty : FJSTDParser {

}

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDEmpty</tt> parser.
    @result     an initialized autoreleased <tt>TDEmpty</tt> parser.
*/
+ (id)empty;
@end
//
//  TDLetter.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/14/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



/*!
    @class      TDLetter 
    @brief      A <tt>TDLetter</tt> matches any letter from a character assembly.
    @details    <tt>-[TDLetter qualifies:]</tt> returns true if an assembly's next element is a letter.
*/
@interface FJSTDLetter : FJSTDTerminal {

}

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDLetter</tt> parser.
    @result     an initialized autoreleased <tt>TDLetter</tt> parser.
*/
+ (id)letter;
@end
//
//  TDLowercaseWord.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@interface FJSTDLowercaseWord : FJSTDWord {

}

@end
//
//  TDMultiLineCommentState.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 12/28/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@interface FJSTDMultiLineCommentState : FJSTDTokenizerState {
    NSMutableArray *startSymbols;
    NSMutableArray *endSymbols;
    NSString *currentStartSymbol;
}

@end
//
//  TDNonReservedWord.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@interface FJSTDNonReservedWord : FJSTDWord {

}

@end
//
//  TDNum.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDNum 
    @brief      A Num matches a number from a token assembly.
*/
@interface FJSTDNum : FJSTDTerminal {

}

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDNum</tt> object.
    @result     an initialized autoreleased <tt>TDNum</tt> object
*/
+ (id)num;
@end
//
//  TDNumberState.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDNumberState 
    @brief      A number state returns a number from a reader.
    @details    This state's idea of a number allows an optional, initial minus sign, followed by one or more digits. A decimal point and another string of digits may follow these digits.
*/
@interface FJSTDNumberState : FJSTDTokenizerState {
    BOOL allowsTrailingDot;
    BOOL gotADigit;
    BOOL negative;
    NSInteger c;
    CGFloat floatValue;
}

/*!
    @property   allowsTrailingDot
    @brief      If true, numbers are allowed to end with a trialing dot, e.g. <tt>42.</tt>
    @details    false by default.
*/
@property (nonatomic) BOOL allowsTrailingDot;
@end
//
//  TDParseKit.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/21/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//

/*!
    @mainpage   TDParseKit
                TDParseKit is a Mac OS X Framework written by Todd Ditchendorf in Objective-C 2.0 and released under the MIT Open Source License.
				The framework is an Objective-C implementation of the tools described in <a href="http://www.amazon.com/Building-Parsers-Java-Steven-Metsker/dp/0201719622" title="Amazon.com: Building Parsers With Java(TM): Steven John Metsker: Books">"Building Parsers with Java" by Steven John Metsker</a>. 
				TDParseKit includes some significant additions beyond the designs from the book (many of them hinted at in the book itself) in order to enhance the framework's feature set, usefulness and ease-of-use. Other changes have been made to the designs in the book to match common Cocoa/Objective-C design patterns and conventions. 
				However, these changes are relatively superficial, and Metsker's book is the best documentation available for this framework.
                
                Classes in the TDParseKit Framework offer 2 basic services of general use to Cocoa developers:
    @li Tokenization via a tokenizer class
    @li Parsing via a high-level parser-building toolkit
                Learn more on the <a target="_top" href="http://code.google.com/p/todparsekit/">project site</a>
*/
 


// io


// parse











//chars






// tokens
























// ext






//  TDQuoteState.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDQuoteState 
    @brief      A quote state returns a quoted string token from a reader
    @details    This state will collect characters until it sees a match to the character that the tokenizer used to switch to this state. For example, if a tokenizer uses a double- quote character to enter this state, then <tt>-nextToken</tt> will search for another double-quote until it finds one or finds the end of the reader.
*/
@interface FJSTDQuoteState : FJSTDTokenizerState {
    BOOL balancesEOFTerminatedQuotes;
}

/*!
    @property   balancesEOFTerminatedQuotes
    @brief      if true, this state will append a matching quote char (<tt>'</tt> or <tt>"</tt>) to quotes terminated by EOF. Default is NO.
*/
@property (nonatomic) BOOL balancesEOFTerminatedQuotes;
@end
//
//  TDQuotedString.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDQuotedString 
    @brief      A <tt>TDQuotedString</tt> matches a quoted string, like "this one" from a token assembly.
*/
@interface FJSTDQuotedString : FJSTDTerminal {

}

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDQuotedString</tt> object.
    @result     an initialized autoreleased <tt>TDQuotedString</tt> object
*/
+ (id)quotedString;
@end
//
//  TDReader.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/21/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



/*!
    @class      TDReader 
    @brief      A character-stream reader that allows characters to be pushed back into the stream.
*/
@interface FJSTDReader : NSObject {
    NSString *string;
    NSUInteger cursor;
    NSUInteger length;
}

/*!
    @brief      Designated Initializer. Initializes a reader with a given string.
    @details    Designated Initializer.
    @param      s string from which to read
    @result     an initialized reader
*/
- (id)initWithString:(NSString *)s;

/*!
    @brief      Read a single character
    @result     The character read, or -1 if the end of the stream has been reached
*/
- (NSInteger)read;

/*!
    @brief      Push back a single character
    @details    moves the cursor back one position
*/
- (void)unread;

/*!
    @property   string
    @brief      This reader's string.
*/
@property (nonatomic, retain) NSString *string;
@end
//
//  TDRepetition.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDRepetition 
    @brief      A <tt>TDRepetition</tt> matches its underlying parser repeatedly against a assembly.
*/
@interface FJSTDRepetition : FJSTDParser {
    FJSTDParser *subparser;
    id preassembler;
    SEL preassemblerSelector;
}

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDRepetition</tt> parser to repeatedly match against subparser <tt>p</tt>.
    @param      p the subparser against wich to repeatedly match
    @result     an initialized autoreleased <tt>TDRepetition</tt> parser.
*/
+ (id)repetitionWithSubparser:(FJSTDParser *)p;

/*!
    @brief      Designated Initializer. Initialize a <tt>TDRepetition</tt> parser to repeatedly match against subparser <tt>p</tt>.
    @details    Designated Initializer. Initialize a <tt>TDRepetition</tt> parser to repeatedly match against subparser <tt>p</tt>.
    @param      p the subparser against wich to repeatedly match
    @result     an initialized <tt>TDRepetition</tt> parser.
*/
- (id)initWithSubparser:(FJSTDParser *)p;

/*!
    @brief      Sets the object that will work on every assembly before matching against it.
    @details    Setting a preassembler is entirely optional, but sometimes useful for repetition parsers to do work on an assembly before matching against it.
    @param      a the assembler this parser will use to work on an assembly before matching against it.
    @param      sel a selector that assembler <tt>a</tt> responds to which will work on an assembly
*/
- (void)setPreassembler:(id)a selector:(SEL)sel;

/*!
    @property   subparser
    @brief      this parser's subparser against which it repeatedly matches
*/
@property (nonatomic, readonly, retain) FJSTDParser *subparser;

/*!
    @property   preassembler
    @brief      The assembler this parser will use to work on an assembly before matching against it.
    @discussion <tt>preassembler</tt> should respond to the selector held by this parser's <tt>preassemblerSelector</tt> property.
*/
@property (nonatomic, retain) id preassembler;

/*!
    @property   preAssemlerSelector
    @brief      The method of <tt>preassembler</tt> this parser will call to work on an assembly.
    @details    The method represented by <tt>preassemblerSelector</tt> must accept a single <tt>TDAssembly</tt> argument. The signature of <tt>preassemblerSelector</tt> should be similar to: <tt>- (void)workOnAssembly:(TDAssembly *)a</tt>.
*/
@property (nonatomic, assign) SEL preassemblerSelector;
@end
//
//  TDReservedWord.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@interface FJSTDReservedWord : FJSTDWord {

}

+ (void)setReservedWords:(NSArray *)inWords;
@end
//
//  TDScientificNumberState.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/25/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



/*!
    @class      TDScientificNumberState 
    @brief      A <tt>TDScientificNumberState</tt> object returns a number from a reader.
    @details    <p>This state's idea of a number expands on its superclass, allowing an 'e' followed by an integer to represent 10 to the indicated power. For example, this state will recognize <tt>1e2</tt> as equaling <tt>100</tt>.</p>
                <p>This class exists primarily to show how to introduce a new tokenizing state.</p>
*/
@interface FJSTDScientificNumberState : FJSTDNumberState {
    CGFloat exp;
    BOOL negativeExp;
}

@end
//
//  TDSequence.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDSequence 
    @brief      A <tt>TDSequence</tt> object is a collection of parsers, all of which must in turn match against an assembly for this parser to successfully match.
*/
@interface FJSTDSequence : FJSTDCollectionParser {

}

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDSequence</tt> parser.
    @result     an initialized autoreleased <tt>TDSequence</tt> parser.
*/
+ (id)sequence;
@end
//
//  TDSingleLineCommentState.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 12/28/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@interface FJSTDSingleLineCommentState : FJSTDTokenizerState {
    NSMutableArray *startSymbols;
    NSString *currentStartSymbol;
}

@end
//
//  TDSpecificChar.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/14/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



/*!
    @class      TDSpecificChar 
    @brief      A <tt>TDSpecificChar</tt> matches a specified character from a character assembly.
    @details    <tt>-[TDSpecificChar qualifies:]</tt> returns true if an assembly's next element is equal to the character this object was constructed with.
*/
@interface FJSTDSpecificChar : FJSTDTerminal {
}

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDSpecificChar</tt> parser.
    @param      c the character this object should match
    @result     an initialized autoreleased <tt>TDSpecificChar</tt> parser.
*/
+ (id)specificCharWithChar:(NSInteger)c;

/*!
    @brief      Designated Initializer. Initializes a <tt>TDSpecificChar</tt> parser.
    @param      c the character this object should match
    @result     an initialized <tt>TDSpecificChar</tt> parser.
*/
- (id)initWithSpecificChar:(NSInteger)c;
@end
//
//  TDSymbol.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@class FJSTDToken;

/*!
    @class      TDSymbol 
    @brief      A <tt>TDSymbol</tt> matches a specific sequence, such as <tt>&lt;</tt>, or <tt>&lt;=</tt> that a tokenizer returns as a symbol.
*/
@interface FJSTDSymbol : FJSTDTerminal {
    FJSTDToken *symbol;
}

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDSymbol</tt> object with a <tt>nil</tt> string value.
    @result     an initialized autoreleased <tt>TDSymbol</tt> object with a <tt>nil</tt> string value
*/
+ (id)symbol;

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDSymbol</tt> object with <tt>s</tt> as a string value.
    @param      s the string represented by this symbol
    @result     an initialized autoreleased <tt>TDSymbol</tt> object with <tt>s</tt> as a string value
*/
+ (id)symbolWithString:(NSString *)s;
@end
//
//  TDSymbolNode.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



/*!
    @class      TDSymbolNode 
    @brief      A <tt>TDSymbolNode</tt> object is a member of a tree that contains all possible prefixes of allowable symbols.
    @details    A <tt>TDSymbolNode</tt> object is a member of a tree that contains all possible prefixes of allowable symbols. Multi-character symbols appear in a <tt>TDSymbolNode</tt> tree with one node for each character. For example, the symbol <tt>=:~</tt> will appear in a tree as three nodes. The first node contains an equals sign, and has a child; that child contains a colon and has a child; this third child contains a tilde, and has no children of its own. If the colon node had another child for a dollar sign character, then the tree would contain the symbol <tt>=:$</tt>. A tree of <tt>TDSymbolNode</tt> objects collaborate to read a (potentially multi-character) symbol from an input stream. A root node with no character of its own finds an initial node that represents the first character in the input. This node looks to see if the next character in the stream matches one of its children. If so, the node delegates its reading task to its child. This approach walks down the tree, pulling symbols from the input that match the path down the tree. When a node does not have a child that matches the next character, we will have read the longest possible symbol prefix. This prefix may or may not be a valid symbol. Consider a tree that has had <tt>=:~</tt> added and has not had <tt>=:</tt> added. In this tree, of the three nodes that contain =:~, only the first and third contain complete symbols. If, say, the input contains <tt>=:a</tt>, the colon node will not have a child that matches the <tt>'a'</tt> and so it will stop reading. The colon node has to "unread": it must push back its character, and ask its parent to unread. Unreading continues until it reaches an ancestor that represents a valid symbol.
*/
@interface FJSTDSymbolNode : NSObject {
    NSString *ancestry;
    FJSTDSymbolNode *parent;
    NSMutableDictionary *children;
    NSInteger character;
    NSString *string;
}

/*!
    @brief      Initializes a <tt>TDSymbolNode</tt> with the given parent, representing the given character.
    @param      p the parent of this node
    @param      c the character for this node
    @result     An initialized <tt>TDSymbolNode</tt>
*/
- (id)initWithParent:(FJSTDSymbolNode *)p character:(NSInteger)c;

/*!
    @property   ancestry
    @brief      The string of the mulit-character symbol this node represents.
*/
@property (nonatomic, readonly, retain) NSString *ancestry;
@end
//
//  TDSymbolRootNode.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@class FJSTDReader;

/*!
    @class      TDSymbolRootNode 
    @brief      This class is a special case of a <tt>TDSymbolNode</tt>.
    @details    This class is a special case of a <tt>TDSymbolNode</tt>. A <tt>TDSymbolRootNode</tt> object has no symbol of its own, but has children that represent all possible symbols.
*/
@interface FJSTDSymbolRootNode : FJSTDSymbolNode {
}

/*!
    @brief      Adds the given string as a multi-character symbol.
    @param      s a multi-character symbol that should be recognized as a single symbol token by this state
*/
- (void)add:(NSString *)s;

/*!
    @brief      Removes the given string as a multi-character symbol.
    @param      s a multi-character symbol that should no longer be recognized as a single symbol token by this state
    @details    if <tt>s</tt> was never added as a multi-character symbol, this has no effect
*/
- (void)remove:(NSString *)s;

/*!
    @brief      Return a symbol string from a reader.
    @param      r the reader from which to read
    @param      cin the character from witch to start
    @result     a symbol string from a reader
*/
- (NSString *)nextSymbol:(FJSTDReader *)r startingWith:(NSInteger)cin;
@end
//
//  TDSymbolState.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@class FJSTDSymbolRootNode;

/*!
    @class      TDSymbolState 
    @brief      The idea of a symbol is a character that stands on its own, such as an ampersand or a parenthesis.
    @details    <p>The idea of a symbol is a character that stands on its own, such as an ampersand or a parenthesis. For example, when tokenizing the expression (isReady)& (isWilling) , a typical tokenizer would return 7 tokens, including one for each parenthesis and one for the ampersand. Thus a series of symbols such as )&( becomes three tokens, while a series of letters such as isReady becomes a single word token.</p>
                <p>Multi-character symbols are an exception to the rule that a symbol is a standalone character. For example, a tokenizer may want less-than-or-equals to tokenize as a single token. This class provides a method for establishing which multi-character symbols an object of this class should treat as single symbols. This allows, for example, "cat <= dog" to tokenize as three tokens, rather than splitting the less-than and equals symbols into separate tokens.</p>
                <p>By default, this state recognizes the following multi- character symbols: <tt>!=</tt>, <tt>:-</tt>, <tt><=</tt>, <tt>>=</tt></p>
*/
@interface FJSTDSymbolState : FJSTDTokenizerState {
    FJSTDSymbolRootNode *rootNode;
    NSMutableArray *addedSymbols;
}

/*!
    @brief      Adds the given string as a multi-character symbol.
    @param      s a multi-character symbol that should be recognized as a single symbol token by this state
*/
- (void)add:(NSString *)s;

/*!
    @brief      Removes the given string as a multi-character symbol.
    @details    If <tt>s</tt> was never added as a multi-character symbol, this has no effect.
    @param      s a multi-character symbol that should no longer be recognized as a single symbol token by this state
*/
- (void)remove:(NSString *)s;
@end
//
//  TDTokenArraySource.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 12/11/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



@class FJSTDTokenizer;
@class FJSTDToken;

/*!
    @class      TDTokenArraySource
    @brief      A <tt>TokenArraySource</tt> is a handy utility that enumerates over a specified reader, returning <tt>NSArray</tt>s of <tt>TDToken</tt>s delimited by a specified delimiter.
    @details    For example,
 
@code
    NSString *s = @"I came; I saw; I left in peace;";

    TDTokenizer *t = [TDTokenizer tokenizerWithString:s];
    TDTokenArraySource *src = [[[TDTokenArraySource alloc] initWithTokenizer:t delimiter:@";"] autorelease];
 
    while ([src hasMore]) {
        NSLog(@"%@", [src nextTokenArray]);
    }
@endcode
 
 prints out:

@code
    I came
    I saw
    I left in peace
@endcode
*/
@interface FJSTDTokenArraySource : NSObject {
    FJSTDTokenizer *tokenizer;
    NSString *delimiter;
    FJSTDToken *nextToken;
}

/*
*/
- (id)initWithTokenizer:(FJSTDTokenizer *)t delimiter:(NSString *)s;

/*!
    @brief      true if the source has more arrays of tokens.
    @result     true, if the source has more arrays of tokens that have not yet been popped with <tt>-nextTokenArray</tt>
*/
- (BOOL)hasMore;

/*!
    @brief      Returns the next array of tokens from the source.
    @result     the next array of tokens from the source
*/
- (NSArray *)nextTokenArray;
@end
//
//  TDTokenAssembly.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 7/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



@class FJSTDTokenizer;

/*!
    @class      TDTokenAssembly 
    @brief      A <tt>TDTokenAssembly</tt> is a <tt>TDAssembly</tt> whose elements are <tt>TDToken</tt>s.
    @details    <tt>TDToken</tt>s are, roughly, the chunks of text that a <tt>TDTokenizer</tt> returns.
*/
@interface FJSTDTokenAssembly : FJSTDAssembly <NSCopying> {
    FJSTDTokenizer *tokenizer;
    NSArray *tokens;
    BOOL preservesWhitespaceTokens;
}

/*!
    @brief      Convenience factory method for initializing an autoreleased assembly with the tokenizer <tt>t</tt> and its string
    @param      t tokenizer whose string will be worked on
    @result     an initialized autoreleased assembly
*/
+ (id)assemblyWithTokenizer:(FJSTDTokenizer *)t;

/*!
    @brief      Initializes an assembly with the tokenizer <tt>t</tt> and its string
    @param      t tokenizer whose string will be worked on
    @result     an initialized assembly
*/
- (id)initWithTokenzier:(FJSTDTokenizer *)t;

/*!
    @brief      Convenience factory method for initializing an autoreleased assembly with the token array <tt>a</tt> and its string
    @param      a token array whose string will be worked on
    @result     an initialized autoreleased assembly
*/
+ (id)assemblyWithTokenArray:(NSArray *)a;

/*!
    @brief      Initializes an assembly with the token array <tt>a</tt> and its string
    @param      a token array whose string will be worked on
    @result     an initialized assembly
*/
- (id)initWithTokenArray:(NSArray *)a;

/*!
    @property   preservesWhitespaceTokens
    @brief      If true, whitespace tokens retreived from this assembly's tokenizier will be silently placed on this assembly's stack without being reported by -next or -peek. Default is false.
*/
@property (nonatomic) BOOL preservesWhitespaceTokens;
@end
//
//  TDParseKit.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



@class FJSTDToken;
@class FJSTDTokenizerState;
@class FJSTDNumberState;
@class FJSTDQuoteState;
@class FJSTDSlashState;
@class FJSTDCommentState;
@class FJSTDSymbolState;
@class FJSTDWhitespaceState;
@class FJSTDWordState;
@class FJSTDReader;

/*!
    @class      TDTokenizer
    @brief      A tokenizer divides a string into tokens.
    @details    <p>This class is highly customizable with regard to exactly how this division occurs, but it also has defaults that are suitable for many languages. This class assumes that the character values read from the string lie in the range <tt>0-MAXINT</tt>. For example, the Unicode value of a capital A is 65, so <tt>NSLog(@"%C", (unichar)65);</tt> prints out a capital A.</p>
                <p>The behavior of a tokenizer depends on its character state table. This table is an array of 256 <tt>TDTokenizerState</tt> states. The state table decides which state to enter upon reading a character from the input string.</p>
                <p>For example, by default, upon reading an 'A', a tokenizer will enter a "word" state. This means the tokenizer will ask a <tt>TDWordState</tt> object to consume the 'A', along with the characters after the 'A' that form a word. The state's responsibility is to consume characters and return a complete token.</p>
                <p>The default table sets a <tt>TDSymbolState</tt> for every character from 0 to 255, and then overrides this with:</p>
@code
     From     To    State
        0    ' '    whitespaceState
      'a'    'z'    wordState
      'A'    'Z'    wordState
      160    255    wordState
      '0'    '9'    numberState
      '-'    '-'    numberState
      '.'    '.'    numberState
      '"'    '"'    quoteState
     '\''   '\''    quoteState
      '/'    '/'    commentState
@endcode
                <p>In addition to allowing modification of the state table, this class makes each of the states above available. Some of these states are customizable. For example, wordState allows customization of what characters can be part of a word, after the first character.</p>
*/
@interface FJSTDTokenizer : NSObject {
    NSString *string;
    FJSTDReader *reader;
    
    NSMutableArray *tokenizerStates;
    
    FJSTDNumberState *numberState;
    FJSTDQuoteState *quoteState;
    FJSTDCommentState *commentState;
    FJSTDSymbolState *symbolState;
    FJSTDWhitespaceState *whitespaceState;
    FJSTDWordState *wordState;
}

/*!
    @brief      Convenience factory method. Sets string to read from to <tt>nil</tt>.
    @result     An initialized tokenizer.
*/
+ (id)tokenizer;

/*!
    @brief      Convenience factory method.
    @param      s string to read from.
    @result     An autoreleased initialized tokenizer.
*/
+ (id)tokenizerWithString:(NSString *)s;

/*!
    @brief      Designated Initializer. Constructs a tokenizer to read from the supplied string.
    @param      s string to read from.
    @result     An initialized tokenizer.
*/
- (id)initWithString:(NSString *)s;

/*!
    @brief      Returns the next token.
    @result     the next token.
*/
- (FJSTDToken *)nextToken;

/*!
    @brief      Change the state the tokenizer will enter upon reading any character between "start" and "end".
    @param      state the state for this character range
    @param      start the "start" character. e.g. <tt>'a'</tt> or <tt>65</tt>.
    @param      end the "end" character. <tt>'z'</tt> or <tt>90</tt>.
*/
- (void)setTokenizerState:(FJSTDTokenizerState *)state from:(NSInteger)start to:(NSInteger)end;

/*!
    @property   string
    @brief      The string to read from.
*/
@property (nonatomic, retain) NSString *string;

/*!
    @property    numberState
    @brief       The state this tokenizer uses to build numbers.
*/
@property (nonatomic, retain) FJSTDNumberState *numberState;

/*!
    @property   quoteState
    @brief      The state this tokenizer uses to build quoted strings.
*/
@property (nonatomic, retain) FJSTDQuoteState *quoteState;

/*!
    @property   commentState
    @brief      The state this tokenizer uses to recognize (and possibly ignore) comments.
*/
@property (nonatomic, retain) FJSTDCommentState *commentState;

/*!
    @property   symbolState
    @brief      The state this tokenizer uses to recognize symbols.
*/
@property (nonatomic, retain) FJSTDSymbolState *symbolState;

/*!
    @property   whitespaceState
    @brief      The state this tokenizer uses to recognize (and possibly ignore) whitespace.
*/
@property (nonatomic, retain) FJSTDWhitespaceState *whitespaceState;

/*!
    @property   wordState
    @brief      The state this tokenizer uses to build words.
*/
@property (nonatomic, retain) FJSTDWordState *wordState;
@end
//
//  TDTrack.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDTrack
    @brief      A <tt>TDTrack</tt> is a sequence that throws a <tt>TDTrackException</tt> if the sequence begins but does not complete.
    @details    If <tt>-[TDTrack allMatchesFor:]</tt> begins but does not complete, it throws a <tt>TDTrackException</tt>.
*/
@interface FJSTDTrack : FJSTDSequence {

}

/*!
    @brief      Convenience factory method for initializing an autoreleased <tt>TDTrack</tt> parser.
    @result     an initialized autoreleased <tt>TDTrack</tt> parser.
*/
+ (id)track;
@end
//
//  TDTrackException.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 10/14/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//



extern NSString * const FJSTDTrackExceptionName;

/*!
 @class     TDTrackException
 @brief     Signals that a parser could not match text after a specific point.
 @details   The <tt>userInfo</tt> for this exception contains the following keys:<pre>
            <tt>after</tt> (<tt>NSString *</tt>) - some indication of what text was interpretable before this exception occurred
            <tt>expected</tt> (<tt>NSString *</tt>) - some indication of what kind of thing was expected, such as a ')' token
            <tt>found</tt> (<tt>NSString *</tt>) - the text element the thrower actually found when it expected something else</pre>
*/
@interface FJSTDTrackException : NSException {

}

@end
//
//  TDUppercaseWord.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/13/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




@interface FJSTDUppercaseWord : FJSTDWord {

}

@end
//
//  TDWordState.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 1/20/06.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDWordState 
    @brief      A word state returns a word from a reader.
    @details    <p>Like other states, a tokenizer transfers the job of reading to this state, depending on an initial character. Thus, the tokenizer decides which characters may begin a word, and this state determines which characters may appear as a second or later character in a word. These are typically different sets of characters; in particular, it is typical for digits to appear as parts of a word, but not as the initial character of a word.</p>
                <p>By default, the following characters may appear in a word. The method setWordChars() allows customizing this.</p>
@code
     From     To
      'a'    'z'
      'A'    'Z'
      '0'    '9'
@endcode
                <p>as well as: minus sign <tt>-</tt>, underscore <tt>_</tt>, and apostrophe <tt>'</tt>.</p>
*/
@interface FJSTDWordState : FJSTDTokenizerState {
    NSMutableArray *wordChars;
}

/*!
    @brief      Establish characters in the given range as valid characters for part of a word after the first character. Note that the tokenizer must determine which characters are valid as the beginning character of a word.
    @param      yn true if characters in the given range are word characters
    @param      start the "start" character. e.g. <tt>'a'</tt> or <tt>65</tt>.
    @param      end the "end" character. <tt>'z'</tt> or <tt>90</tt>.
*/
- (void)setWordChars:(BOOL)yn from:(NSInteger)start to:(NSInteger)end;


- (BOOL)isWordChar:(NSInteger)c;
@end
//
//  TDWordOrReservedState.h
//  TDParseKit
//
//  Created by Todd Ditchendorf on 8/14/08.
//  Copyright 2008 Todd Ditchendorf. All rights reserved.
//




/*!
    @class      TDWordOrReservedState 
    @brief      Override <tt>TDWordState</tt> to return known reserved words as tokens of type <tt>TDTT_RESERVED</tt>.
*/
@interface FJSTDWordOrReservedState : FJSTDWordState {
    NSMutableSet *reservedWords;
}

/*!
    @brief      Adds the specified string as a known reserved word.
    @param      s reserved word to add
*/
- (void)addReservedWord:(NSString *)s;
@end
