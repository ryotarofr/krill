import logging

def setup_logger(name: str, level: int = logging.INFO) -> logging.Logger:
    logger = logging.getLogger(name)
    logger.setLevel(level)
    
    # Create console handler
    ch = logging.StreamHandler()
    ch.setLevel(level)
    
    # Create formatter and add it to the handler
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    
    # Add the handler to the logger
    logger.addHandler(ch)
    
    return logger

logger = setup_logger('my_logger')

id1 = logger.info("ログテスト")
print(f"Logger ID: {id1}")
logger.debug("デバッグメッセージ")
logger.warning("警告メッセージ")
logger.error("エラーメッセージ")
logger.critical("クリティカルメッセージ")