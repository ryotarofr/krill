# krill

## API Reference

This module provides a ctypes-based interface to a Zig-made shared library for JSON‑based key→subkey lookups, and a custom `logging.Logger` subclass that records identifiers retrieved from that library.

---

## Classes

### `KrillCore`

```python
KrillCore(json_path: str, key: str, subkey: str)
```

**Description**
Calls into the Zig-based shared library via `ctypes` to perform lookups from a JSON file. Maintains internal state for `key` and `subkey`.

**Parameters**

- `json_path` (`str`): Path to the JSON file containing nested key→subkey mappings.
- `key` (`str`): Primary lookup key.
- `subkey` (`str`): Secondary lookup key.

**Attributes**

- `json_path` (`str`)
- `key` (`str`)
- `subkey` (`str`)
- `buf_size` (`int`): Size of the output buffer (default: `256`).

#### Methods

- `setSubkey(subkey: str) -> None`

  - Set the secondary lookup key for subsequent calls.

- `_bytes_from_string(s: str) -> bytes`

  - Encode a Python string to UTF‑8 bytes.

- `find() -> Optional[str]`
  - Perform the lookup in the shared library and return the matching string (or `None` if not found).

---

### `KrillLogger`

```python
class KrillLogger(logging.Logger)
```

**Description**
A `logging.Logger` subclass that integrates with `KrillCore` to optionally record subkey identifiers on each log call.

**Attributes**

- `_krill` (`Optional[KrillCore]`): Attached `KrillCore` instance (set by `setup_logger`).
- `alloc_id_list` (`list[Optional[str]]`): History of identifiers retrieved from `KrillCore`.

#### Methods

- `getSubKeyList() -> list[Optional[str]]`

  - Return the full list of recorded subkey identifiers.

- `getLastSubkey() -> Optional[str]`

  - Return the most recently recorded subkey identifier (or `None`).

- `debug(msg, identifier: bool=False, *args, **kwargs)`
- `info(msg, identifier: bool=False, *args, **kwargs)`
- `warning(msg, identifier: bool=False, *args, **kwargs)`
- `error(msg, identifier: bool=False, *args, **kwargs)`
- `critical(msg, identifier: bool=False, *args, **kwargs)`

  Each logging method accepts an extra `identifier` flag. If `True` and a `KrillCore` instance is attached, it will:

  1. Call `KrillCore.setSubkey(msg)` with the log message.
  2. Call `KrillCore.find()` and append the result to `alloc_id_list`.

---

## Functions

### `setup_logger`

```python
def setup_logger(
    name: str,
    json_path: str,
    level: int = logging.INFO
) -> KrillLogger:
```

**Description**
Configure the root logging system to use `KrillLogger`, attach a `KrillCore` instance, and return the configured logger.

**Parameters**

- `name` (`str`): Logger name (also used as the primary key for lookups).
- `json_path` (`str`): Path to the JSON file for `KrillCore`.
- `level` (`int`, optional): Logging level (default: `logging.INFO`).

**Returns**

- `KrillLogger`: Configured logger with a `StreamHandler` and attached `KrillCore`.

---

## Sample Usage

```python
import logging
from krill import KrillCore, KrillLogger, setup_logger

API_NAME  = 'API_ROOT_ID'
JSON_PATH = 'logger_output.json'

# Initialize the logger
logger = setup_logger(
    name=API_NAME,
    json_path=JSON_PATH,
    level=logging.DEBUG
)

# Log messages with subkey tracking enabled
logger.info("hello", identifier=True)
logger.debug("debug message", identifier=True)
logger.warning("warning message", identifier=True)
logger.error("error message", identifier=True)
logger.critical("critical message", identifier=True)

# Inspect recorded identifiers
print("SubKey List:", logger.getSubKeyList())
print("Last SubKey:", logger.getLastSubkey())
```

- **Step-by-step**
  1. Call `setup_logger()` to create a `KrillLogger` with attached `KrillCore`.
  2. Pass `identifier=True` to any log call to record the JSON lookup result for the message.
  3. Use `getSubKeyList()` or `getLastSubkey()` to retrieve identifiers collected so far.

---
