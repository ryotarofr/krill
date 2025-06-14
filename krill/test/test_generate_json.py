import os

def test_generate_json_creates_file():
    from generate_json import generate_json

    pyfile = "core/test/logger.py"
    root_id = "API_ROOT_ID"
    output_path = "./core/dist/logger_output.json"
    env_identifier = True

    generate_json(str(pyfile), root_id, str(output_path), env_identifier)

    assert output_path.exists(), "Output file was not created"

    content = output_path.read_text()
    assert len(content) > 0, "Output file is empty"