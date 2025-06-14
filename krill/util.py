import importlib.resources
import sys

def get_liblogger_path():
    # Determine the correct file extension based on the platform
    if sys.platform.startswith("linux"):
        ext = ".so"
    elif sys.platform == "darwin":
        ext = ".dylib"
    elif sys.platform in ("win32", "cygwin"):
        ext = ".dll"
    else:
        raise RuntimeError(f"Unsupported platform: {sys.platform}")
    # Use importlib.resources to find the library file in the krill/lib package
    with importlib.resources.path("krill/lib", f"liblogger{ext}") as p:
        return str(p)
