import ctypes

lib = ctypes.CDLL('./zig-out/lib/liblogger.so')

lib.toJson.argtypes = [
    ctypes.c_char_p, ctypes.c_size_t,  # pyfile_ptr, pyfile_len
    ctypes.c_char_p, ctypes.c_size_t,  # root_id_ptr, root_id_len
    ctypes.c_char_p, ctypes.c_size_t   # output_path_ptr, output_path_len
]
lib.toJson.restype = None

pyfile = b'logger.py'
root_id = b'API_ROOT'
output_path = b'logger_output.json'
is_lambda = True


lib.toJson(
    pyfile, len(pyfile),
    root_id, len(root_id),
    output_path, len(output_path),
    is_lambda, is_lambda,
)
