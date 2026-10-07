extends GameTest

#The GDExtension in native/ must be built and loaded (docs/NATIVE.md). If this fails, run
#`scons` in native/. The version must match NATIVE_VERSION in native/src/goon_native.cpp.

const NATIVE_VERSION = "1"

func test_native_library_loads():
	assert_true(ClassDB.class_exists("GoonNative"), "bin/windows has no gooncrusher DLL; run scons in native/")
	if not ClassDB.class_exists("GoonNative"): return
	assert_eq(ClassDB.class_call_static("GoonNative", "version"), NATIVE_VERSION, "stale DLL; rebuild native/")
