from c_krill import generate_json

pyfile = "logger.py"
root_id = "API_ROOT_ID"
output_path = "logger_output.json"
env_identifier = True
generate_json(str(pyfile), root_id, str(output_path), env_identifier)

output_path = "logger_output2.json"
env_identifier = False
generate_json(str(pyfile), root_id, str(output_path), env_identifier)