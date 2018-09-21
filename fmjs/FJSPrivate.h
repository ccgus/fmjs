#import "FJSValue.h"
#import "FJSSymbolManager.h"
#import "FJSFFI.h"

@interface FJSValue (Private)

@property (assign) BOOL isJSNative;
@property (strong) FJSSymbol *symbol;
@property (assign) FJSObjCValue cValue;
@property (assign) JSType jsValueType;


+ (instancetype)valueForJSObject:(nullable JSObjectRef)jso inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithSymbol:(FJSSymbol*)sym inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithInstance:(CFTypeRef)instance inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithWeakInstance:(id)instance inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithConstantPointer:(void*)p ofType:(char)type inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithClass:(Class)c inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithCValue:(FJSObjCValue)cvalue inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithNullInRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithUndefinedInRuntime:(FJSRuntime*)runtime;


- (BOOL)isClass;
- (BOOL)isInstance;

- (BOOL)isSymbol;
- (BOOL)isFunction;
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
