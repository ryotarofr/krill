import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))
from c_krill.generate_json import generate_json

pyfile = "logger.py"
root_id = "API_ROOT_ID"
output_path = "logger_output.json"
prefix = "logger"
env_identifier = True
generate_json(str(pyfile), root_id, str(output_path), prefix, env_identifier)

output_path = "logger_output2.json"
env_identifier = False
generate_json(str(pyfile), root_id, str(output_path), prefix, env_identifier)