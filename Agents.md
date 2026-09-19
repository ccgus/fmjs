# Agents.md

This file provides guidance to coding agents (Claude Code, etc.) when working in this repository.

## What this project is

FMJS is an experimental JavaScript ↔ C/Cocoa bridge for macOS. It wraps JavaScriptCore so Objective-C objects, C functions, structs, blocks, and CoreFoundation types can be called from JS (and vice versa). Type information for the bridge comes from `.bridgesupport` XML files parsed at runtime; calls into C use libffi.

The framework target is named **FMJS**, but all source classes use the prefix **FJS** (the README explains why). Don't rename things to "fix" the inconsistency.

Code and ideas were borrowed from Mocha, PyObjC, JSCocoa, and JavaScriptCore — files that are near-duplicates carry attribution headers; preserve them.

## Layout

- `fmjs/` — the FMJS framework sources (one target produces `FMJS.framework`).
- `fmjs/FJS.bridgesupport` — type metadata bundled into the framework and parsed on first runtime init.
- `tests/` — `FMJSTests.xctest` plus `FJSTests.bridgesupport` and `*.js` fixtures used by the module tests.
- `tool/` — `fmjs` CLI (REPL / script runner) target.
- `FJSTestApp/` — a small AppKit harness with a console window for hand-running scripts.
- `lib/fmdb/` — vendored fmdb (SQLite wrapper) renamed with the FJS prefix so scripts can use it.
- `bin/fmjs_build_tool.sh` — release builder for the CLI; **expects Xcode 11.7 at a hardcoded path** and clones a fresh tree into `/tmp/fmjs`. Don't run it casually.
- `privacy/`, `db/`, `junk/`, `DerivedData/`, `build/` — not source; ignore.

## Build / run / test

Everything lives in `fmjs.xcodeproj`. Targets and schemes:

| Target | Scheme | Product |
|---|---|---|
| `FMJS` | `FMJS` (user scheme) | `FMJS.framework` |
| `FMJSTests` | bundled in `FMJS` scheme | `FMJSTests.xctest` |
| `fmjstool` | `fmjstool` (shared) | CLI binary `fmjs` |
| `FJSTestApp` | (user) | `FJSTestApp.app` |

Common commands (run from the repo root):

```sh
# Build the framework
xcodebuild -project fmjs.xcodeproj -scheme FMJS -configuration Debug build

# Build + run the full test bundle
xcodebuild -project fmjs.xcodeproj -scheme FMJS test

# Run a single test class or method
xcodebuild -project fmjs.xcodeproj -scheme FMJS test \
    -only-testing:FMJSTests/FJSSimpleTests
xcodebuild -project fmjs.xcodeproj -scheme FMJS test \
    -only-testing:FMJSTests/FJSSimpleTests/testSomething

# Build the CLI
xcodebuild -project fmjs.xcodeproj -scheme fmjstool build
```

Deployment target is macOS 10.14 (the framework) / 10.12 (the release script).

The CLI accepts a script file as its first argument, reads stdin when piped, and otherwise drops into an interactive REPL (`FJSInterpreter`). It synthesizes a Node-ish `process` global with `argv` and `exit`.

## Architecture — the parts you need to read together

The bridge is small but every piece touches the others. Skim these in order:

1. **`FJSRuntime`** (`FJSRuntime.{h,m}`) — the public facade. Owns one `JSGlobalContextRef`, an internal `evaluateQueue`, the module cache, and exception/print handlers. `evaluateScript:`, subscript access (`runtime[@"foo"] = ...`), `require:`, and `callFunctionNamed:withArguments:` all funnel through here. On first init it loads several system frameworks via `loadFrameworkAtPath:` so their bridgesupport is available.
2. **`FJSValue`** (`FJSValue.{h,m}`) — the universal wrapper. Every value crossing the bridge is an `FJSValue`, either backed by a native `JSValueRef` (`isJSNative == YES`) or by an `FJSObjCValue` union holding a primitive / instance / class / block / struct / pointer. All JS↔ObjC coercions live here, plus `protect`/`unprotect` for GC roots and `FFITypeWithHint:` to feed libffi.
3. **`FJSSymbol` / `FJSSymbolManager`** (`FJSSymbol.{h,m}`, `FJSSymbolManager.{h,m}`) — parse `.bridgesupport` XML and answer "what is the type encoding / selector / return type of name X?" Without these the bridge cannot know argument types for C functions or methods whose signatures aren't otherwise discoverable.
4. **`FJSFFI`** (`FJSFFI.{h,m}`) — wraps libffi: builds `ffi_type` trees (including for structs by name), prepares cifs, and actually invokes C functions and Obj-C methods given an `FJSSymbol` and a list of `FJSValue` arguments.
5. **`FJSRuntimeCallbacks`** (`FJSRuntimeCallbacks.{h,m}`) — the JSC `JSClassDefinition` callbacks (getProperty, setProperty, callAsFunction, finalize, hasInstance, …). This is where JS access to Obj-C objects gets translated into `FJSValue` lookups and FFI calls.
6. **`FJSCocoaScriptPreprocessor`** + **`TDConglomerate`** — a tokenizer-based preprocessor run over scripts before evaluation (handles `"""…"""` multiline strings and similar conveniences). All scripts pass through this.
7. **`FJSRunLoopThread`** — the background thread/queue used for safe execution. Public users call `-[FJSRuntime dispatchOnQueue:]`; don't touch JSC directly off-queue.
8. **`FJSModule`** — Node-style `require()`. **Currently gated behind the `WORKING_ON_MODULES` macro**; runtime-level `require:` in `FJSRuntime` is what's actually wired up. The `tests/FJSTestModule*.js` files exercise it.

`FJSPrivate.h` re-exports the private categories (`FJSRuntime (Private)`, `FJSValue (Private)`, etc.) — `#import "FJSPrivate.h"` from inside the framework or tests when you need them.

## Conventions worth knowing before you change things

- **Custom JS-side dispatch.** Any Obj-C object can override how JS sees it by implementing the optional methods declared in the `NSObject (FJSRuntimePropertyAccess)` category at the bottom of `FJSRuntime.h`: `doFJSFunction:inRuntime:withValues:returning:` to take over a call entirely; `FJSValueForKeyedSubscript:inRuntime:` / `setFJSValue:…` for dynamic property access; and a `<selector>InFJSRuntime:` shadow selector to receive `FJSValue` arguments instead of unwrapped C values. `FJSSimpleTests.m` exercises all of these.
- **Threading.** The JS context is only safe on the runtime's `evaluateQueue`. Anything that calls `JSValueRef`/`JSObjectRef` APIs from outside must be wrapped in `-[FJSRuntime dispatchOnQueue:]`.
- **GC.** `FJSValue` values that need to outlive a callback must be `protect`/`unprotect`-balanced (wrapping `JSValueProtect`). There are two `#define`s in `FJSRuntime.h` (`FJSMapValuesForEquality`, `FJSAssociateValuesForEquality`) gating experimental identity-preservation strategies — both are off and noted as buggy; don't flip them without reading the comments.
- **Tracing.** Set `FJSTraceFunctionCalls = YES` (or define the `FJSTrace(...)` macro to `NSLog`) to see every FFI call. `setUseSynchronousGarbageCollectForDebugging:` forces synchronous GC for leak chasing.
- **Bridgesupport regeneration.** README has the `gen_bridge_metadata` invocation; if it can't find `libclang.dylib`, the symlink workaround there is the fix.

## Things not to do

- Don't add a four-letter class prefix; the project is intentionally `FJS`.
- Don't "fix" the framework-vs-class name mismatch (FMJS vs FJS).
- Don't enable `FJSMapValuesForEquality` / `FJSAssociateValuesForEquality` without addressing the over-release bug noted in the header.
- Don't bypass the preprocessor or the evaluate queue.
