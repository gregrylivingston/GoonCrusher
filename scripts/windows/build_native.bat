REM Must be called from project root folder
REM Builds the GDExtension in native/ (debug and release) into bin/windows/. Needs SCons and MSVC.
git submodule update --init native/godot-cpp || exit /b 1
pushd native
scons target=template_debug || (popd & exit /b 1)
scons target=template_release || (popd & exit /b 1)
popd
