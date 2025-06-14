import logging
from typing import Optional
import ctypes

import util

class KrillCore:
    """
    Calls Zig-made shared libraries via ctypes and
    provides core functionality to search for key→subkey from JSON.
    """
    def __init__(self, json_path: str, key: str, subkey: str):
        lib_path = util.get_liblogger_path()
        lib = ctypes.CDLL(lib_path)
        self._lib = lib
        self._lib.find.argtypes = [
            ctypes.POINTER(ctypes.c_ubyte), ctypes.c_size_t,  # json_ptr, json_len
            ctypes.POINTER(ctypes.c_ubyte), ctypes.c_size_t,  # key_ptr, key_len
            ctypes.POINTER(ctypes.c_ubyte), ctypes.c_size_t,  # subkey_ptr, subkey_len
            ctypes.POINTER(ctypes.c_ubyte), ctypes.c_size_t   # out_buf, out_buf_len
        ]
        self._lib.find.restype = ctypes.c_bool

        self.json_path = json_path
        self.key = key
        self.subkey = subkey
        self.buf_size = 256

    def setSubkey(self, subkey: str):
        self.subkey = subkey

    def _bytes_from_string(self, s: str) -> bytes:
        return s.encode('utf-8')

    def find(self) -> Optional[str]:
        key_b = self._bytes_from_string(self.key)
        subkey_b = self._bytes_from_string(self.subkey)

        with open(self.json_path, 'rb') as f:
            json_bytes = f.read()

        json_arr   = (ctypes.c_ubyte * len(json_bytes)).from_buffer_copy(json_bytes)
        key_arr    = (ctypes.c_ubyte * len(key_b)).from_buffer_copy(key_b)
        subkey_arr = (ctypes.c_ubyte * len(subkey_b)).from_buffer_copy(subkey_b)
        out_buf    = (ctypes.c_ubyte * self.buf_size)()

        found = self._lib.find(
            json_arr,      len(json_bytes),
            key_arr,       len(key_b),
            subkey_arr,    len(subkey_b),
            out_buf,       self.buf_size
        )

        if not found:
            return None

        raw = bytes(out_buf)
        return raw.split(b'\0', 1)[0].decode('utf-8', errors='replace')


class KrillLogger(logging.Logger):
    """
    A custom logger that integrates with KrillCore to log messages
    with optional subkey tracking.
    """
    def __init__(self, name: str, level: int = logging.NOTSET):
        super().__init__(name, level)
        self._krill: Optional[KrillCore] = None
        self.alloc_id_list: list[Optional[str]] = []

    def getSubKeyList(self) -> list[Optional[str]]:
        return self.alloc_id_list

    def getLastSubkey(self) -> Optional[str]:
        return self.alloc_id_list[-1] if self.alloc_id_list else None

    def _log_and_record(self, level_fn, msg, identifier: bool, *args, **kwargs):
        level_fn(msg, *args, **kwargs)
        if identifier and self._krill is not None:
            self._krill.setSubkey(msg)
            self.alloc_id_list.append(self._krill.find())

    def debug(self, msg, identifier: bool = False, *args, **kwargs):
        self._log_and_record(super().debug, msg, identifier, *args, **kwargs)

    def info(self, msg, identifier: bool = False, *args, **kwargs):
        self._log_and_record(super().info, msg, identifier, *args, **kwargs)

    def warning(self, msg, identifier: bool = False, *args, **kwargs):
        self._log_and_record(super().warning, msg, identifier, *args, **kwargs)

    def error(self, msg, identifier: bool = False, *args, **kwargs):
        self._log_and_record(super().error, msg, identifier, *args, **kwargs)

    def critical(self, msg, identifier: bool = False, *args, **kwargs):
        self._log_and_record(super().critical, msg, identifier, *args, **kwargs)


# def setup_logger(name: str, json_path: str, level: int = logging.INFO) -> logging.Logger:
#     logging.setLoggerClass(KrillLogger)

#     logger = logging.getLogger(name)
#     logger.setLevel(level)

#     ch = logging.StreamHandler()
#     ch.setLevel(level)
#     formatter = logging.Formatter('%(asctime)s [%(name)s][%(levelname)s] %(message)s')
#     ch.setFormatter(formatter)
#     logger.addHandler(ch)

#     logger._krill = KrillCore(
#         json_path=json_path,
#         key=name,
#         subkey=""
#     )

#     return logger


# if __name__ == "__main__":
#     API_NAME  = 'SKIC05008E004'
#     JSON_PATH = 'logger_output.json'

#     logger = setup_logger(API_NAME, JSON_PATH)

#     logger.info("hello", identifier=True)
#     logger.debug("debug message", identifier=True)
#     logger.warning("warning message", identifier=True)
#     logger.error("error message", identifier=True)
#     logger.critical("critical message", identifier=True)

#     print("SubKey 一覧:", logger.getSubKeyList())
#     print("最後の SubKey:", logger.getLastSubkey())
