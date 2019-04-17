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
* To JS Fucntions: Blocks

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

    FJSRuntime *runtime = [FJSRuntime new];

    runtime[@"funkItUp"] = ^(NSString *what) {
        // Do whatever here
    };

    [runtime evaluateScript:@"funkItUp('funky');"];
    







### Notes

Q: Why is the framework called FMJS, but the class prefixes FJS?  
A: I hate four letter prefixes, and having it "FJS" always makes me think it stands for "F'n JavaScript".


### Random Todos:

 * Stop using NSString for the encodings in the symbols. Try c strings, will ya?
 * Can we bridge to swift some day using Mirror (and once the ABI is finalized?) https://swift.org/blog/how-mirror-works/
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


