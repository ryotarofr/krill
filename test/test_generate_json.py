from pathlib import Path
from c_krill.generate_json import generate_json

def test_generate_json_creates_file():

    pyfile = "core/test/logger.py"
    root_id = "API_ROOT_ID"
    output_path = "test/logger_output.json"
    prefix = "logger"
    env_identifier = True

    generate_json(str(pyfile), root_id, str(output_path), prefix, env_identifier)

    output_path = Path(output_path)
    assert output_path.exists(), "Output file was not created"

    content = output_path.read_text()
    assert len(content) > 0, "Output file is empty"