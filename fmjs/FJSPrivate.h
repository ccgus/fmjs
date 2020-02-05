#import "FJSValue.h"
#import "FJSSymbolManager.h"
#import "FJSSymbol.h"
#import "FJSFFI.h"
#import "FJSUtil.h"
#import "FJSPointer.h"

#define FJSRuntimeLookupKey @"fmjs"

NS_ASSUME_NONNULL_BEGIN

@interface FJSRuntime (Private)
@property (assign) JSGlobalContextRef jsContext;
@property (assign) JSClassRef globalClass;


- (void)reportNSException:(NSException*)e;
- (void)reportPossibleJSException:(nullable JSValueRef)exception;
+ (instancetype)runtimeInContext:(JSContextRef)context;

- (void)pushAsCurrentFJS;
- (void)popAsCurrentFJS;

- (void)setObject:(id)object forKeyedSubscript:(NSString *)name inJSObject:(JSObjectRef)jsObject;
- (FJSValue*)objectForKeyedSubscript:(id)name inJSObject:(JSObjectRef)jsObject;

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
@property (assign) BOOL debugFinalizeCalled;


+ (instancetype)valueWithSymbol:(FJSSymbol*)sym inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithBlock:(CFTypeRef)block inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithInstance:(CFTypeRef)instance inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithWeakInstance:(id)instance inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithConstantPointer:(void*)p withSymbol:(FJSSymbol*)sym inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithClass:(Class)c inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithCValue:(FJSObjCValue)cvalue inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithNewObjectInRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithNullInRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithUndefinedInRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithSerializedJSFunction:(NSString*)function inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithPointer:(void*)p ofType:(char)type inRuntime:(FJSRuntime*)runtime;

- (BOOL)isClass;
- (BOOL)isInstance;
- (BOOL)isCFType;
- (BOOL)isBlock;
- (BOOL)isStruct;
- (BOOL)isSymbol;
- (BOOL)isCFunction;
- (BOOL)isJSFunction;
- (BOOL)isInstanceMethod;
- (BOOL)isClassMethod;

- (BOOL)hasClassMethodNamed:(NSString*)m;

- (nullable JSValueRef)JSValueRef;
- (nullable JSValueRef)toJSString;

- (nullable id)instance;
- (Class)rtClass;
- (void)setClass:(Class)c;
- (void)retainReturnValue;

- (FJSValue*)unwrapValue;

- (nullable void*)pointerPointer;

- (NSString*)structToString;

@end

NS_ASSUME_NONNULL_END
