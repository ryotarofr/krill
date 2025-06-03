import ctypes

lib = ctypes.CDLL('./zig-out/lib/liblogger.so')
lib.run_logger(b'logger.py', len('logger.py'))