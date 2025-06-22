import ctypes
from . import util

def generate_json(pyfile: str, output_path: str, prefix: str, target_loglevel: list[str], env_identifier: bool):
    lib_path = util.get_liblogger_path()
    _lib = ctypes.CDLL(lib_path)
    _lib.toJson.argtypes = [
        ctypes.c_char_p, ctypes.c_size_t,
        ctypes.c_char_p, ctypes.c_size_t,
        ctypes.c_char_p, ctypes.c_size_t,
        ctypes.POINTER(ctypes.c_char_p), ctypes.c_size_t,
        ctypes.c_bool
    ]
    _lib.toJson.restype = None

    pyfile = _bytes_from_string(pyfile)
    output_path = _bytes_from_string(output_path)
    prefix = _bytes_from_string(prefix)
    target_loglevel = [_bytes_from_string(s) for s in target_loglevel]
    target_loglevel_c = (ctypes.c_char_p * len(target_loglevel))(*target_loglevel)
    

    _lib.toJson(
        pyfile, len(pyfile),
        output_path, len(output_path),
        prefix, len(prefix),
        target_loglevel_c, len(target_loglevel),
        env_identifier, env_identifier,
    )

def _bytes_from_string(s: str) -> bytes:
    return s.encode('utf-8')