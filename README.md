# fmjs
A JavaScript to C/Cocoa bridge

A playground for some Cocoa JS things I want to try. I borrow liberally from the Mocha project: [https://github.com/logancollins/Mocha](https://github.com/logancollins/Mocha)


# Conversions (not all implemented yet)

### Bridging from C to JavaScript:
* To JS String: NSString + subclasses, selectors, char pointers (_C_CHARPTR)  
* To JS Boolean: BOOL, bool  
* To JS Number: char, short, int, long, long long, float, double  
* To JS Object: NSObject, Class, 

Not handled (yet?): Blocks, structs, pointers

### JavaScript to C:

If runtime information is available, we'll try and do the right conversions. If no runtime info is available, this is what will happen:

* From JS String: NSString
* From JS Boolean: BOOL
* From JS Number: long (NSInteger)
* From JS Objects NSDictionary?
* From JS Null: nil
* From JS Function: Not handled
* From JS Undefined: Not handled