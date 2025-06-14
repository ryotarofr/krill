import os
import logging
import tempfile
import shutil

from krill.code import setup_logger

def test_krill_logger():
    root_id = "API_ROOT_ID"
    json_path = "./core/dist/logger_output.json"

    logger = setup_logger(root_id, str(json_path))

    logger.info("info message", identifier=True)
    logger.debug("debug message", identifier=True)
    logger.warning("warning message", identifier=True)
    logger.error("error message", identifier=True)
    logger.critical("critical message", identifier=True)

    expected = ["001", "002", "003", "004", "005"]
    assert logger.getSubKeyList() == expected
    assert logger.getLastSubkey() == "005"