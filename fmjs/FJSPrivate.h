#import "FJSValue.h"
#import "FJSSymbolManager.h"
#import "FJSSymbol.h"
#import "FJSFFI.h"
#import "FJSUtil.h"

NS_ASSUME_NONNULL_BEGIN

@interface FJSRuntime (Private)
- (void)reportNSException:(NSException*)e;
- (void)reportPossibleJSException:(nullable JSValueRef)exception;

@end

@interface FJSSymbolManager (Private)
- (NSArray*)symbolNames;
- (void)addSymbol:(FJSSymbol*)symbol;
- (void)parseBridgeString:(NSString*)str;
@end

@interface FJSValue (Private)

@property (assign) BOOL isJSNative;
@property (strong) FJSSymbol *symbol;
@property (assign) FJSObjCValue cValue;
@property (assign) JSType jsValueType;
@property (weak) FJSRuntime *runtime;


+ (instancetype)valueForJSValue:(nullable JSValueRef)jso inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithSymbol:(FJSSymbol*)sym inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithBlock:(CFTypeRef)block inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithInstance:(CFTypeRef)instance inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithWeakInstance:(id)instance inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithConstantPointer:(void*)p withSymbol:(FJSSymbol*)sym inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithClass:(Class)c inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithCValue:(FJSObjCValue)cvalue inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithNullInRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithUndefinedInRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithSerializedJSFunction:(NSString*)function inRuntime:(FJSRuntime*)runtime;


- (BOOL)isClass;
- (BOOL)isInstance;
- (BOOL)isBlock;
- (BOOL)isStruct;
- (BOOL)isSymbol;
- (BOOL)isCFunction;
- (BOOL)isJSFunction;
- (BOOL)isInstanceMethod;
- (BOOL)isClassMethod;

- (BOOL)hasClassMethodNamed:(NSString*)m;

- (nullable JSValueRef)JSValue;
- (nullable JSValueRef)toJSString;

- (id)instance;
- (Class)rtClass;
- (void)setClass:(Class)c;
- (void)retainReturnValue;

@end

NS_ASSUME_NONNULL_END
