# Zig API リファレンス

## このドキュメントでは、`json.zig` に定義された Zig ロガーユーティリティの公開 API を説明します。

## 型

### LogLevel

```
enum LogLevel {
    Debug,
    Info,
    Warning,
    Error,
    Critical,
}
```

ログレベルを表します。

### LogEntry

```
const LogEntry = struct {

message: []const u8, // ログメッセージ
    level: LogLevel,    // ログレベル
};
```

単一のログエントリを表します。

### EntryType

```
pub const EntryType = struct {
    pyfile_ptr: [*]const u8,   // Python ファイルパスへのポインター（ヌル終端なし）

pyfile_len: usize,         // Python ファイルのパス長
    root_id: []const u8,       // JSON 出力用のルート ID
    output_path: []const u8,   // 出力ファイルのパス
    allocator: Allocator,      // メモリ管理用のアロケーター
    // メソッド:
    pub fn pyfile(self: @This()) []const u8

pub fn openFile(self: @This()) !std.fs.File
    pub fn readToEndAlloc(self: @This(), max_size: usize) ![]const u8
    pub fn run(self: @This()) !std.ArrayList(LogEntry)
};
```

Python ファイルからログエントリを抽出するためのコンテキストを表します。

### Json

```
pub fn Json() type // Json構造体の型を返します
// struct Json {
//     allocator: Allocator,
//     logs: []const LogEntry,
//     pub fn init(allocator: Allocator, logs: []const LogEntry) Self
//     pub fn writeBody(list: *std.ArrayList(u8), id_buf: *const [3]u8, level_str: []const u8, message: []const u8) !void
//     pub fn toJson(self: Self, root_id: []const u8) ![]u8
// }
```

ログエントリの JSON 変換を処理します。

### LoggerZig

```
pub fn LoggerZig() type // LoggerZig構造体の型を返します
// struct LoggerZig {
//     pyfile_ptr: [*]const u8,
//     pyfile_len: usize,
//     root_id: []const u8,
//     output_path: []const u8,
//     pub fn run(self: Self) void
// }
```

## C/Python からログラーを実行するためのメインエントリポイント。

## 関数

### loggerZig

```
pub export fn loggerZig(
    pyfile_ptr: [*]const u8, pyfile_len: usize,

root_id_ptr: [*]const u8, root_id_len: usize,
    output_path_ptr: [*]const u8, output_path_len: usize
)
 void
```

ログ記録を実行します。すべての引数は、C/Python FFI 互換性のため、ポインターと長さのペアとして渡されます。

- `pyfile_ptr`, `pyfile_len`: Python ファイルパス（ヌル終端なし）
- `root_id_ptr`, `root_id_len`: JSON 出力用のルート ID
- `output_path_ptr`, `output_path_len`: 出力ファイルパス

---

## 使用例 (Python)

```python
import ctypes
lib = ctypes.CDLL(『./zig-out/lib/liblogger.so』)
lib.loggerZig.argtypes = [
    ctypes.c_char_p, ctypes.c_size_t,
    ctypes.c_char_p, ctypes.c_size_t,
    ctypes.c_char_p, ctypes.c_size_t,
]
lib.loggerZig.restype = None
lib.loggerZig(b『logger.py』, len(『logger.py』), b『SKIC05008E004』, len(『SKIC05008E004』), b『logger_output.json』, len(『logger_output.json』))
```

---

## 注意事項

- すべてのメモリ割り当ては Zig の標準割り当て関数を使用します。
- ログ出力は、Python ファイルに`logger.<level>(「message」)`のような行が含まれていることを想定しています。
- 出力は、ルート ID とログエントリの辞書マッピングを含む JSON ファイルです。
- ログエントリが見つからない場合、出力は`{ 「<root_id>」: {} }`となります。
