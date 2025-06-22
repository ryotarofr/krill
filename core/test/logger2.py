# This file is test code for setting up a logger in Python.
import logging

import c_crill

def setup_logger(name: str, level: int = logging.INFO) -> logging.Logger:
    logger = logging.getLogger(name)
    logger.setLevel(level)
    
    ch = logging.StreamHandler()
    ch.setLevel(level)
    
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    
    logger.addHandler(ch)
    
    return logger
  
CKRILL_API_KEY = "API_ROOT_ID_2"

logger = setup_logger('my_logger2')
logger.debug("debug message2")
logger.info("info message2")
logger.warning("warning message2")
logger.error("error message2")
logger.critical("critical message2")