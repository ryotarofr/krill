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
