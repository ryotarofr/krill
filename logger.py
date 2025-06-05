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
logger.debug("debug message")
logger.info("info message")
logger.warning("warning message")
logger.error("error message")
logger.critical("critical message")