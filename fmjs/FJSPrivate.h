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
+ (nullable instancetype)runtimeInContext:(JSContextRef)context;

- (void)pushAsCurrentFJS;
- (void)popAsCurrentFJS;

- (void)setObject:(nullable id)object forKeyedSubscript:(NSString *)name inJSObject:(JSObjectRef)jsObject;
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


+ (nullable instancetype)valueWithSymbol:(FJSSymbol*)sym inRuntime:(FJSRuntime*)runtime;
+ (nullable instancetype)valueWithBlock:(CFTypeRef)block inRuntime:(FJSRuntime*)runtime;
+ (nullable instancetype)valueWithInstance:(CFTypeRef)instance inRuntime:(FJSRuntime*)runtime;
+ (nullable instancetype)valueWithWeakInstance:(id)instance inRuntime:(FJSRuntime*)runtime;
+ (nullable instancetype)valueWithConstantPointer:(void*)p withSymbol:(FJSSymbol*)sym inRuntime:(FJSRuntime*)runtime;
+ (nullable instancetype)valueWithClass:(Class)c inRuntime:(FJSRuntime*)runtime;
+ (nullable instancetype)valueWithCValue:(FJSObjCValue)cvalue inRuntime:(FJSRuntime*)runtime;
+ (nullable instancetype)valueWithNewObjectInRuntime:(FJSRuntime*)runtime;
+ (nullable instancetype)valueWithSerializedJSFunction:(NSString*)function inRuntime:(FJSRuntime*)runtime;
+ (nullable instancetype)valueWithPointer:(void*)p ofType:(char)type inRuntime:(FJSRuntime*)runtime;

+ (void)setCaptureJSValueInstancesForDebugging:(BOOL)b;

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

- (void)setInstance:(nullable CFTypeRef)o;
- (nullable id)instance;
- (Class)rtClass;
- (void)setClass:(Class)c;
- (void)retainReturnValue;

- (FJSValue*)unwrapValue;

- (nullable void*)pointerPointer;

- (NSString*)structToString;

@end

NS_ASSUME_NONNULL_END
