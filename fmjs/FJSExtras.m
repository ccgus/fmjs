#import "FJSExtras.h"
#import <ScriptingBridge/ScriptingBridge.h>

// This file is just a collection of little categories on objects, so that it's easier to do some things in JavaScript.

@implementation NSApplication (FJSExtras)

- (id)open:(NSString*)pathToFile {
    
    NSError *err = nil;
    
    NSURL *url = [pathToFile isKindOfClass:[NSURL class]] ? (NSURL*)pathToFile : [NSURL fileURLWithPath:pathToFile];

    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"

    id doc = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES error:&err];

    #pragma clang diagnostic pop
    if (err) {
        NSLog(@"Error: %@", err);
        return nil;
    }
    
    return doc;
}

- (void)activate {

    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"

    ProcessSerialNumber xpsn = { 0, kCurrentProcess };
    SetFrontProcess( &xpsn );

    #pragma clang diagnostic pop
}

- (NSInteger)displayDialog:(NSString*)msg withTitle:(NSString*)title {
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setAlertStyle:NSAlertStyleInformational];
    [alert setMessageText:title];
    [alert setInformativeText:msg];
    
    NSInteger button = [alert runModal];
    
    return button;
}

- (NSInteger)displayDialog:(NSString*)msg {
    
    NSString *title = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey];
    
    if (!title) {
        title = @"Unknown Application";
    }
    
    return [self displayDialog:msg withTitle:title];
}

- (id)sharedDocumentController {
    return [NSDocumentController sharedDocumentController];
}

- (id)standardUserDefaults {
    return [NSUserDefaults standardUserDefaults];
}

@end


@implementation NSDocument (FJSExtras)

- (id)dataOfType:(NSString*)type {
    
    NSError *err = nil;
    
    NSData *data = [self dataOfType:type error:&err];
    
    
    return data;
    
}

@end


@implementation NSData (FJSExtras)

- (BOOL)writeToFile:(NSString*)path {
    
    return [self writeToURL:[NSURL fileURLWithPath:path] atomically:YES];
}

@end

@implementation NSObject (FJSExtras)

- (Class)ojbcClass {
    return [self class];
}

@end


@implementation SBApplication (FJSExtras)

+ (id)application:(NSString*)appName {
    
    NSString *appPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:appName];
    
    if (!appPath) {
        NSLog(@"Could not find application '%@'", appName);
        return nil;
    }
    
    NSBundle *appBundle = [NSBundle bundleWithPath:appPath];
    NSString *bundleId  = [appBundle bundleIdentifier];
    
    return [SBApplication applicationWithBundleIdentifier:bundleId];
}


@end



@implementation NSString (FJSExtras)

- (NSURL*)fileURL {
    return [NSURL fileURLWithPath:self];
}


+ (id)stringWithUUID {
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidString = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);
    
    return [uuidString lowercaseString];
}

@end



@implementation NSGradient (FJSExtras)


+ (id)gradientWithColors:(NSArray*)colors locationArray:(NSArray*)arLocs colorSpace:(NSColorSpace *)colorSpace {
    
    
    CGFloat *locs = malloc(sizeof(CGFloat) * [arLocs count]);
    
    [arLocs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        locs[idx] = [obj doubleValue];
    }];
    
    
    
    if (!colorSpace) {
        colorSpace = [NSColorSpace genericRGBColorSpace];
    }
    
    
    NSGradient *g = [[NSGradient alloc] initWithColors:colors atLocations:locs colorSpace:colorSpace];
    
    return g;
}

@end
