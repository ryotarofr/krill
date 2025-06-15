# krill

`krill` はプランクトンの一種です。PYPI にすでに `krill` というパッケージが存在していたため、`c_krill` という名前にしました。

このパッケージには 2 つの機能があります。

1. ログの生成
2. ログを検索

## インストール

```bash
pip3 install c_krill
```

## 使い方

以下にサンプルコードを記載します。

```py
# 1. ログの生成
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

```py
# 2. ログを検索
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

## API リファレンス

パッケージの中身は、Zig で作成された JSON ベースのキー → サブキー検索用の共有ライブラリに対して ctypes ベースのインターフェースを提供し、そのライブラリから取得した識別子を記録するカスタム`logging.Logger`サブクラスを含みます。

### `KrillCore`

```python
KrillCore(json_path: str, key: str, subkey: str)
```

`ctypes`経由で呼び出しを行い、JSON ファイルから検索を実行します。`key`と`subkey`の内部状態を保持します。

**パラメータ**

- `json_path` (`str`): ネストされたキー → サブキーのマッピングを含む JSON ファイルへのパス.
- `key` (`str`): プライマリ key.
- `subkey` (`str`): セカンダリ lookup key.

**属性**

- `json_path` (`str`)
- `key` (`str`)
- `subkey` (`str`)
- `buf_size` (`int`): default: `256`.

### `KrillLogger`

```python
class KrillLogger(logging.Logger)
```

`logging.Logger` のサブクラスで、`KrillCore` と統合され、各ログ呼び出し時にサブキー識別子をオプションで記録。

**属性**

- `_krill` (`Optional[KrillCore]`): `KrillCore` インスタンス内で（`setup_logger` を設定 → アプリケーション側で任意設定）。
- `alloc_id_list` (`list[Optional[str]]`): `KrillCore`から取得した識別子のアロケータ。
