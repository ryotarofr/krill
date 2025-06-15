title: zig 備忘録

## 構造体型定義

`fn Hoge() type {return struct {}}` と `const Hoge = struct {}` は同じような振る舞いをするが、どのように使い分ければよいか。

`fn Hoge() type {return struct {}}` : ジェネリクスや型ごとに異なる構造体を返したい場合に使用
`const Hoge = struct {}` : 関数内で型が 1 つになる場合に使用

```zig
/// fn Hoge() type {return struct {}} の例
fn Wrapper(comptime T: type) type {
    return struct { value: T };
}
const IntWrapper = Wrapper(i32);
const StrWrapper = Wrapper([]const u8);
```

## 構造的型チェック

**割となんでも渡せるというイメージ。**

> 「型が必要なフィールドやメソッドを持っていれば、その型として使える」

という考え方。

C++ や Rust のように名前が完全に一致する必要はなく、型名が同じである必要はない。

なので以下 Rust の「明示的な型制約」をつけることはできない。

```rust
// T は Display と Debug 両方を満たす
fn foo<T: Display>(x: T) where T: Debug { ... }
```

---

# 記事

タイトル: python 用のカスタムログライブラリを作りました。

今回は、zig の学習ついでに作ったものを紹介させていただきます。

## 作ったもの

[krill](https://github.com/ryotarofr/krill)

python の 標準機能の `logging` をカスタムしたものになります。
ログを出すのに `logging.info("message")` のように使われることも多いかと思います。
ここで出したログに内部で ID を割り振り、ログ情報そのものを DB などでデータ管理をしたかったので作成しました。

工夫した点としては、内部で ID を管理したことです。わざわざすべてのログに ID を振る手間を避けたかったためです。

## 機能と用途

README の内容と重複しますが、改めて記載させていただきます。

機能は「ログの生成」「ログを検索」の 2 つです。

1. ログの生成

```py
from c_krill import generate_json

pyfile = "logger.py"
root_id = "API_ROOT_ID"
output_path = "logger_output.json"
env_identifier = True
generate_json(str(pyfile), root_id, str(output_path), env_identifier)

output_path = "logger_output2.json"
env_identifier = False
generate_json(str(pyfile), root_id, str(output_path), env_identifier)
```

### `env_identifier`

- `True` で出力した Json → 実行環境でログメッセージから識別子を取得するために使うもの

```json
// json
{
  "API_ROOT_ID": {
    "hello": "001"
  }
}
```

```py
# py
logger.info("hello", identifier=True)
```

このような Json と python コードがあった場合に logger の "hello" という文字列から "001" を取得します。

- `False`で出力した Json → 実行環境以外で使うもの

```json
// json
{
  "API_ROOT_ID": {
    "001": {
      "level": "info",
      "message": "hello"
    },
    "002": {
      "level": "debug",
      "message": "debug message"
    },
    "003": {
      "level": "warning",
      "message": "warning message"
    },
    "004": {
      "level": "error",
      "message": "error message"
    },
    "005": {
      "level": "critical",
      "message": "critical message"
    }
  }
}
```

例えば、上記で "001" という識別子をテーブルに登録しておけば、"001" から該当するメッセージの取得ができます。

2. ログを検索

```py
# py
import logging

from c_krill import KrillCore, KrillLogger

def setup_logger(name: str, json_path: str, level: int = logging.INFO) -> logging.Logger:
    logging.setLoggerClass(KrillLogger)

    logger = logging.getLogger(name)
    logger.setLevel(level)

    ch = logging.StreamHandler()
    ch.setLevel(level)
    formatter = logging.Formatter('%(asctime)s [%(name)s][%(levelname)s] %(message)s')
    ch.setFormatter(formatter)
    logger.addHandler(ch)

    logger._krill = KrillCore(
        json_path=json_path,
        key=name,
        subkey=""
    )

    return logger


if __name__ == "__main__":
    API_NAME  = 'API_ROOT_ID'
    JSON_PATH = 'logger_output.json'

    logger = setup_logger(API_NAME, JSON_PATH)

    logger.info("hello", identifier=True)
    logger.debug("debug message", identifier=True)
    logger.warning("warning message", identifier=True)
    logger.error("error message", identifier=True)
    logger.critical("critical message", identifier=True)

    print("list :", logger.getSubKeyList())
    print("last :", logger.getLastSubkey())

```

追跡をするログに関しては `logger.info("hello", identifier=True)` のように 第二引数を `identifier=True` にする必要があります。そのため、 `logger.info("hello")` のようにした場合、ログを出力しますが、追跡は行いません。

追跡したログは `logger.getSubKeyList()` や `logger.getLastSubkey()` のようにして取り出すことができます。

## 終わり

最後までお読みいただき、ありがとうございました。

今回は、zig(v0.14) で作成しました。zig は構造的型チェックがシステム言語の中では緩めなので初学者の身としては扱いやすくサクサクかけました。

本記事で紹介した `c-krill/krill` は、Python の標準 logging にほんの少しだけ“魔法”をかけ、ログ出力と検索をシームレスにつなげることを目指しています。
今後は以下のようなアップデートを検討しています：

DB・ストレージ連携の強化
現在は JSON ファイルを前提としていますが、PostgreSQL や Elasticsearch など、より大規模／高速な検索基盤との連携をサポート予定です。

非同期ログ対応
asyncio／マルチスレッド環境下での ID 管理をより堅牢に行う仕組みを検討中です。

プラグイン拡張
ログフォーマットや出力先を柔軟にカスタマイズできるプラグイン・インターフェースを整備し、コミュニティで拡張機能を作り込めるようにします。

ご意見・バグ報告・プルリクエストは大歓迎です！
