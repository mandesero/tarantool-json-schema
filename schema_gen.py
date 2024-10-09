import subprocess
import os
import json
from loguru import logger

versions = (
    "3.0.0",
    "3.0.1",
    "3.0.2",
    "3.1.0",
    "3.1.1",
    "3.1.2",
    "3.2.0",
)


def run_command(command):
    """Runs a shell command and returns its output or None if the command fails."""
    try:
        result = subprocess.run(
            command, shell=True, check=True, capture_output=True, text=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        logger.error(f"Error executing command: {command}")
        logger.error(f"Output: {e.output.strip()}")
        return None


def check_schema_file(file_name):
    """Checks if the JSON schema file is valid and formats it with jq."""
    if not os.path.exists(file_name):
        logger.error(f"File {file_name} not found.")
        return False

    logger.info(f"File {file_name} found. Checking metaschema compliance.")

    # Validate the schema using check-jsonschema
    check_command = f"check-jsonschema --check-metaschema {file_name}"
    if run_command(check_command) is None:
        logger.error(f"File {file_name} failed metaschema validation.")
        return False

    # Format the schema using jq
    jq_command = f"jq --sort-keys -M . {file_name} > {file_name}.tmp && mv {file_name}.tmp {file_name}"
    if run_command(jq_command) is not None:
        logger.info(f"File {file_name} was successfully formatted using jq.")
        return True
    else:
        logger.error(f"Error formatting file {file_name} with jq.")
        return False


def generate_schema(version):
    """Generates schema for a given version and checks its compliance."""
    logger.info(f"Processing version {version}")

    lua_script = "schema_gen.lua"
    tarantool_command = f"./tc-{version}/src/tarantool {lua_script} {version}"
    output = run_command(tarantool_command)

    if output is None:
        logger.error("Lua script execution failed or some field lacks a description.")
        return

    # The output should be the file name
    file_name = output
    logger.info(f"Lua script executed successfully. File name: {file_name}")

    # Load and validate the JSON schema
    if check_schema_file(file_name):
        logger.info(f"File {file_name} passed all checks.")
    else:
        logger.error(f"Schema validation failed for {file_name}.")


if __name__ == "__main__":
    for version in versions:
        generate_schema(version)
