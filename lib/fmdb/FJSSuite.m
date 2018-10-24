#import "FJSSuite.h"
#import "FJSDatabaseQueue.h"
#import "FJSDatabaseAdditions.h"
#import "FJS.h"
#import "FJSPrivate.h"


#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SQLCode(text) @ STRINGIZE2(text)

static NSString *COSUTTypeNumber = @"R.number";
static NSString *COSUTTypeTable = @"R.table";
static NSString *COSUTTypeFunction = @"R.function";

@interface FJSSuite ()
@property (strong) NSString *tablePath;
@property (strong) NSString *tableID;
@property (strong) FJSDatabaseQueue *q;
@end

@implementation FJSSuite

- (instancetype)init {
    self = [super init];
    if (self) {
        // _modules = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)tableWithPath:(NSString*)path {
    
    FJSSuite *me = [FJSSuite new];
    [me setTablePath:path];
    
    [me setQ:[self q]];
    
    return me;
}

+ (instancetype)rootWithURL:(NSURL*)fileURL {
    
    FJSSuite *me = [FJSSuite new];
    
    [me setQ:[FJSDatabaseQueue databaseQueueWithPath:[fileURL path]]];
    [me setupDatabase];
    
    return me;
}

+ (instancetype)rootWithPath:(NSString*)filePath {
    return [self rootWithURL:[NSURL fileURLWithPath:filePath]];
}

- (void)setupDatabase {
    
    [_q inDatabase:^(FJSDatabase *db) {
       
        if (![db tableExists:@"R"]) {
            
            NSString *const rDB = SQLCode (
             create table R (uniqueID text,
                             name text not null,
                             data blob,
                             uti text not null,
                             parentID text);
             );
            
            if (![db executeUpdate:rDB]) {
                NSLog(@"error creating R table: %@", [db lastError]);
            }
        }
        
    }];
    
}

- (instancetype)subTableWithName:(NSString*)name {
    
    if (_tablePath) {
        return [self tableWithPath:[_tablePath stringByAppendingFormat:@".%@", name]];
    }
    
    return [self tableWithPath:name];
}

- (instancetype)makeTable:(NSString*)tableName {
    
    FJSSuite *sub = [self subTableWithName:tableName];
    
    #pragma message "FIXME: make sure to return an existing one if it's already around"
    
    [sub setTableID:FJSUUID()];
    
    [self setTableObject:sub withUTI:COSUTTypeTable uuid:[sub tableID] forKey:tableName];
    
    return sub;
}


//- (id)fileSystemObjectWithKey:(NSString*)key {
//
//    NSString *basePath = [[_q path] stringByDeletingLastPathComponent];
//
//
//    // FIXME: is this too fragile?
//    NSString *subFolder = [_tablePath stringByReplacingOccurrencesOfString:@"." withString:@"/"];
//
//    basePath = [basePath stringByAppendingPathComponent:subFolder];
//
//    NSString *filePath   = [basePath stringByAppendingPathComponent:key];
//    NSString *lookupPath = filePath;
//
//    BOOL found = [[NSFileManager defaultManager] fileExistsAtPath:lookupPath];
//
//    if (!found) {
//
//        NSArray *extensions = @[@"js", @"coscript"];
//
//        for (NSString *ext in extensions) {
//
//            lookupPath = [filePath stringByAppendingPathExtension:ext];
//
//            debug(@"lookupPath: '%@'", lookupPath);
//
//            if ([[NSFileManager defaultManager] fileExistsAtPath:lookupPath]) {
//                found = YES;
//                break;
//            }
//        }
//    }
//
//    if (found) {
//
//        NSError *outErr = nil;
//        NSString *script = [NSString stringWithContentsOfFile:lookupPath encoding:NSUTF8StringEncoding error:&outErr];
//        if (!script) {
//            NSLog(@"Error reading path '%@'", lookupPath);
//            NSLog(@"%@", outErr);
//            return nil;
//        }
//
//
//        NSString *rep = [NSString stringWithFormat:@"R.%@.%@", _tablePath, key];
//        script = [script stringByReplacingOccurrencesOfString:@"$R" withString:rep];
//
//        FJSRuntime *rt = [FJSRuntime currentRuntime];
//
//        FJSValue *v = [rt evaluateScript:script withSourceURL:[NSURL fileURLWithPath:lookupPath]];
//
//        return [v toObject];
//    }
//
//
//    return nil;
//
//}

- (BOOL)hasFJSValueForKeyedSubscript:(NSString *)key inRuntime:(FJSRuntime*)runtime {
    
    if ([self respondsToSelector:NSSelectorFromString(key)] || [self respondsToSelector:NSSelectorFromString([key stringByAppendingString:@":"])]) {
        return NO;
    }
    
    __block BOOL found = NO;
    
    [_q inDatabase:^(FJSDatabase *db) {
        NSString *query = @"select uniqueID from R where name = ? and parentID = ?";
        
        if (!_tableID) {
            query = @"select uniqueID from R where name = ? and parentID is null";
        }
        
        FJSResultSet *rs = [db executeQuery:query, key, _tableID];
        
        found = [rs next];
        [rs close];
    }];
    
    return found;
}
- (FJSValue*)FJSValueForKeyedSubscript:(NSString *)key inRuntime:(FJSRuntime*)runtime {
   
    #pragma message "FIXME: This method is hacked together with duct tape and glue. Please clean it up."
    
    if ([self respondsToSelector:NSSelectorFromString(key)] || [self respondsToSelector:NSSelectorFromString([key stringByAppendingString:@":"])]) {
        return nil;
    }
    
    __block id value = nil; // why two types?!
    __block FJSValue *returnValue = nil;
    
    [_q inDatabase:^(FJSDatabase *db) {
        NSString *query = @"select data, uti, uniqueID from R where name = ? and parentID = ?";
        
        if (!_tableID) {
            query = @"select data, uti, uniqueID from R where name = ? and parentID is null";
        }
        
        FJSResultSet *rs = [db executeQuery:query, key, _tableID];
        
        if ([rs next]) {
            
            CFStringRef uti = (__bridge CFStringRef)[rs stringForColumn:@"uti"];
            
            if (UTTypeConformsTo(uti, kUTTypeText)) {
                value = [rs stringForColumn:@"data"];
            }
            else if ([(__bridge id)uti isEqualToString:COSUTTypeNumber]) {
                value = [rs objectForColumn:@"data"];
                assert([value isKindOfClass:[NSNumber class]]);
            }
            else if ([(__bridge id)uti isEqualToString:COSUTTypeTable]) {
                value = [self subTableWithName:key];
                [(FJSSuite*)value setTableID:[rs stringForColumn:@"uniqueID"]];
            }
            else if ([(__bridge id)uti isEqualToString:COSUTTypeFunction]) {
                
                NSString *f = [rs stringForColumn:@"data"];
                returnValue = [FJSValue valueWithSerializedJSFunction:f inRuntime:runtime];
            }
            else {
                value = [rs dataForColumn:@"data"];
            }
            
            [rs close];
        }
    }];
    
//    if (!value) {
//        value = [self fileSystemObjectWithKey:key];
//    }
    
    if (returnValue) {
        return returnValue;
    }
    
    
    if (!value) {
        NSLog(@"Could not find value for key '%@' in table %@ / %@", key, _tablePath, _tableID);
        return nil;
    }
    
    return [FJSValue valueWithInstance:(__bridge CFTypeRef _Nonnull)(value) inRuntime:runtime];
}

/*
- (void)_dynamicContextEvaluation:(id)e patternString:(NSString*)s {
    debug(@"s: '%@'", s);
    debug(@"e: '%@' (%@)", e, NSStringFromClass([e class]));
}
*/

- (BOOL)setFJSValue:(FJSValue*)value forKeyedSubscript:(NSString*)key inRuntime:(FJSRuntime*)runtime {
    
    
    NSString *uuid = nil;
    NSString *uti = (id)kUTTypeData;
    
    id obj = [value toObject];
    
    if ([value isJSFunction]) {
        uti = COSUTTypeFunction;
        
        FMAssert([obj isKindOfClass:[NSString class]]);
        
        #pragma message "FIXME: This is completely wrong. We need ot check for the existance of it, make sure it's at the front, and then trim only that part out."
        //obj = [obj stringByReplacingOccurrencesOfString:@"function () " withString:@""];
        //obj = [NSString stringWithFormat:@"(%@())", obj];
    }
    else if ([obj isKindOfClass:[NSString class]]) {
        uti = (id)kUTTypeUTF8PlainText;
    }
    else if ([obj isKindOfClass:[NSNumber class]]) {
        uti = COSUTTypeNumber;
    }
    else if ([obj isKindOfClass:[FJSSuite class]]) {
        uti = COSUTTypeTable;
        
        uuid = [(FJSSuite*)obj tableID];
        assert([(FJSSuite*)obj tableID]);
        
        obj = [NSNull null];
    }
    
    return [self setTableObject:obj withUTI:uti uuid:nil forKey:key];
}

- (BOOL)setTableObject:(id)theObj withUTI:(NSString*)uti uuid:(nullable NSString*)uuid forKey:(NSString *)key {
    
    __block id obj = theObj;
    
    uuid = uuid ? uuid : FJSUUID();
    
    [_q inDatabase:^(FJSDatabase *db) {
        
        
        
        
        NSString *delete = @"delete from R where name = ? and parentID = ?";
        
        if (!_tableID) {
            delete = @"delete from R where name = ? and parentID is null";
        }
        
        [db executeUpdate:delete, key, _tableID];
        
        if (obj) {
            NSString *sql = @"insert into R (uniqueID, name, data, uti, parentID) values (?, ?, ?, ?, ?)";
            if (![db executeUpdate:sql, uuid, key, obj, uti, _tableID]) {
                NSLog(@"Could not set value '%@' for '%@' in table '%@'", obj, key, _tablePath ? _tablePath : [NSNull null]);
            }
        }
        
        if ([_tablePath length]) {
            assert(_tableID);
        }
        
    }];
    
    return YES;
}

- (NSArray*)subTables {
    
    NSMutableArray *subTables = [NSMutableArray array];
    
    [_q inDatabase:^(FJSDatabase *db) {
        
        NSString *query = @"select name from R where uti = ? and parentID = ?";
        
        if (!_tablePath) {
            query = @"select name, uniqueID from R where uti = ? and parentID is null";
        }
        
        FJSResultSet *rs = [db executeQuery:query, COSUTTypeTable, _tableID];
        while ([rs next]) {
            
            FJSSuite *sub = [self subTableWithName:[rs stringForColumn:@"name"]];
            [sub setTableID:[rs stringForColumn:@"uniqueID"]];
            [subTables addObject:sub];
        }
        
    }];
    
    
    return subTables;
}

- (NSArray*)keys {
    
    NSMutableArray *keyNames = [NSMutableArray array];
    
    [_q inDatabase:^(FJSDatabase *db) {
        
        NSString *query = @"select name from R where parentID = ?";
        
        if (!_tablePath) {
            query = @"select name from R where parentID is null";
        }
        
        FJSResultSet *rs = [db executeQuery:query, _tableID];
        while ([rs next]) {
            [keyNames addObject:[rs stringForColumn:@"name"]];
        }
        
    }];
    
    return keyNames;
}

- (NSString*)description {
    
    return [[super description] stringByAppendingFormat:@" (%@ id:%@)", _tablePath, _tableID];
    
    
}

- (BOOL)xrespondsToSelector:(SEL)aSelector {
    debug(@"-[%@ %@]?", NSStringFromClass([self class]), NSStringFromSelector(aSelector));
    return [super respondsToSelector:aSelector];
}


@end
