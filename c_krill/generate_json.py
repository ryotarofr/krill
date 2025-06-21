import ctypes
from . import util

def generate_json(pyfile: str, root_id: str, output_path: str, prefix: str, env_identifier: bool):
    lib_path = util.get_liblogger_path()
    _lib = ctypes.CDLL(lib_path)
    _lib.toJson.argtypes = [
        ctypes.c_char_p, ctypes.c_size_t,  # pyfile_ptr, pyfile_len
        ctypes.c_char_p, ctypes.c_size_t,  # root_id_ptr, root_id_len
        ctypes.c_char_p, ctypes.c_size_t,   # output_path_ptr, output_path_len
        ctypes.c_char_p, ctypes.c_size_t   # prefix_ptr, prefix_len
    ]
    _lib.toJson.restype = None

    pyfile = _bytes_from_string(pyfile)
    root_id = _bytes_from_string(root_id)
    output_path = _bytes_from_string(output_path)
    prefix = _bytes_from_string(prefix)

    _lib.toJson(
        pyfile, len(pyfile),
        root_id, len(root_id),
        output_path, len(output_path),
        prefix, len(prefix),
        env_identifier, env_identifier,
    )

def _bytes_from_string(s: str) -> bytes:
    return s.encode('utf-8')