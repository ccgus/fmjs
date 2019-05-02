# FMJS
An incomplete and experimental JavaScript to C/Cocoa bridge

Code borrowed liberally from the Mocha project: [https://github.com/logancollins/Mocha](https://github.com/logancollins/Mocha)


# Planned Conversions (not all implemented yet)

### Bridging from C to JavaScript:
* To JS String: NSString + subclasses, selectors, char pointers (_C_CHARPTR)  
* To JS Boolean: BOOL, bool  
* To JS Number: char, short, int, long, long long, float, double  
* To JS Object: NSObject, Class, 
* To JS Undefined: returning void from functions.
* To JS Functions: Blocks

Not handled (yet?): out pointers

### JavaScript to C:

If runtime information is available, we'll try and do the right conversions. If no runtime info is available, this is what will happen:

* From JS String: NSString
* From JS Boolean: BOOL
* From JS Number: long (NSInteger)
* From JS Objects NSDictionary?
* From JS Null: nil
* From JS Function: Not handled
* From JS Undefined: Not handled



### Pass blocks to the JavaScript runtime and call them as JavaScript functions:

``` Objective-C

FJSRuntime *runtime = [FJSRuntime new];

runtime[@"funkItUp"] = ^(NSString *what) {
    // Do whatever here
};

[runtime evaluateScript:@"funkItUp('funky');"];

```


### Custom Conversions
If you have a method on an object where you'd like to have a little bit more control with the values being handed to you, you have two options:

You can implement the following function:

`- (BOOL)doFJSFunction:(FJSValue*)function inRuntime:(FJSRuntime*)runtime withValues:(NSArray<FJSValue*>*)values returning:(FJSValue*_Nullable __autoreleasing*_Nullable)returnValue`

And if you return true from this, the original method being called on your object will be skipped in favor of this (obviously, you'd handle the method call in here). Check out `FJSSimpleTests.m` for an example.

Also, let's say you've got a method named `- (int)fooWithBar:(float)f` on an object, but you'd like to get your hands on the FJSValue or JSValueRefs which are being used for the arguments. You can implement the following method in your object and it will be called instead: `-(FJSValue*)fooWithBar:(FJSValue*)f inFJSRuntime:(FJSRuntime*)runtime`. FMJS will look for a method selector with an additional `inFJSRuntime:` tacked on the end to it (or  `fooWithBarInFJSRuntime:` if there were no aguments previously) and call this instead of the original function.



### Thread Safety

FJSRuntime uses an internal queue when evaluating scripts, and when calling functions. The JavaScriptCore API is thread safe but there are parts of FMJS that aren't without evaluating things on the queue. Because of this, FJSRuntime exposes a method which allows you to interact with it on the same queue it uses internally: `- (void)dispatchOnQueue:(DISPATCH_NOESCAPE dispatch_block_t)block;`

If using FMJS in a multithreaded environment, use this method to help coordinate safe execution across threads.

### Notes

Q: Why is the framework called FMJS, but the class prefixes FJS?  
A: I hate four letter prefixes, and having it "FJS" always makes me think it stands for "F'n JavaScript".


### Random Todos:

 * Stop using NSString for the encodings in the symbols. Try c strings, will ya?
 * Bridge to Swift some day using Mirror, especially now that it has a stable ABI ( https://swift.org/blog/how-mirror-works/ )
 * What should we do about converting js native strings to ints via -[FJSValue toInt]?
  * Should we auto-manage CFTypes? CGImageRef, etc? Probably!



### Other Random Notes:

If /usr/bin/gen_bridge_metadata isn't working because it can't find @rpath/libclang.dylib, you can symlink it to /usr/local/lib/:
`sudo mkdir /usr/local/lib`
`cd /usr/local/lib/`
`sudo ln -s /Library/Developer/CommandLineTools/usr/lib/libclang.dylib`

`gen_bridge_metadata -c '-lffi' ~/Projects/fmjs/fmjsTests/FJSSimpleTests.h`


### Code Usage

FMJS utilizes code and ideas from the following projects:

- Mocha (https://github.com/logancollins/Mocha, Apache License)
- PyObjC (http://pyobjc.sourceforge.net/, MIT license)
- JSCocoa (http://inexdo.com/JSCocoa, MIT license)
- JavaScriptCore (http://www.webkit.org/projects/javascript/index.html, WebKit license).
- libffi-iphone (https://github.com/parmanoir/libffi-iphone, MIT license)
- JavaScriptCore-iOS (http://www.phoboslab.org/log/2011/06/javascriptcore-project-files-for-ios, WebKit license).

Files are marked appropriately when code it utilized in complete or near-complete duplicate from these awesome projects.


