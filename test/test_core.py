import logging

from c_krill.core import KrillCore, KrillLogger

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

def test_krill_logger():
    root_id = "API_ROOT_ID"
    json_path = "test/logger_output.json"

    logger = setup_logger(root_id, str(json_path))

    logger.info("info message", identifier=True)
    logger.debug("debug message", identifier=True)
    logger.warning("warning message", identifier=True)
    logger.error("error message", identifier=True)
    logger.critical("critical message", identifier=True)

    expected = ["001", "002", "003", "004", "005"]
    assert set(logger.getSubKeyList()) == set(expected)
    assert logger.getLastSubkey() == "005"