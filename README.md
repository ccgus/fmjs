# FMJS
An incomplete and experimental JavaScript to C/Cocoa bridge

Code borrowed liberally from the Mocha project: [https://github.com/logancollins/Mocha](https://github.com/logancollins/Mocha)


# Planned Conversions (not all implemented yet)

### Bridging from C to JavaScript:
* To JS String: NSString + subclasses, selectors, char pointers (_C_CHARPTR)  
* To JS Boolean: BOOL, bool  
* To JS Number: char, short, int, long, long long, float, double  
* To JS Object: NSObject, Class, 

Not handled (yet?): Blocks, structs, out pointers

### JavaScript to C:

If runtime information is available, we'll try and do the right conversions. If no runtime info is available, this is what will happen:

* From JS String: NSString
* From JS Boolean: BOOL
* From JS Number: long (NSInteger)
* From JS Objects NSDictionary?
* From JS Null: nil
* From JS Function: Not handled
* From JS Undefined: Not handled


### Notes

Q: Why is the framework called FMJS, but the class prefixes FJS?  
A: I hate four letter prefixes, and having it "FJS" always makes me think it stands for "F'n JavaScript".


### Random Todos:

 * Stop using NSString for the encodings in the symbols. Try c strings, will ya?


### Other Random Notes:

If /usr/bin/gen_bridge_metadata isn't working because it can't find @rpath/libclang.dylib, you can symlink it to /usr/local/lib/:
`sudo mkdir /usr/local/lib`
`cd /usr/local/lib/`
`sudo ln -s /Library/Developer/CommandLineTools/usr/lib/libclang.dylib`

`gen_bridge_metadata -c '-lffi' ~/Projects/fmjs/fmjsTests/FJSSimpleTests.h`
