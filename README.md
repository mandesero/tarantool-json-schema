# Tarantool JSON Schema Generator

This repository provides tool for generating JSON schemas for various Tarantool versions.

## Installation

### Prerequisites

1. Install `jq` for formatting JSON files:
   ```bash
   sudo apt-get install jq
   ```

2. Set up the Python environment using `pipenv`:
   ```bash
   pipenv shell
   pipenv install
   ```

## Running

### Step 1: Build Tarantool Versions

1. **Specify Versions**:
   In `schema_gen.bash`, list the Tarantool versions you want to build:

   ```bash
   versions=(
       "3.0.0"
       "3.0.1"
       "3.0.2"
       "3.1.0"
       "3.1.1"
       "3.1.2"
       "3.2.0"
   )
   ```

2. **Run the Bash Script**:
   Execute the `schema_gen.bash` script to build the specified versions of Tarantool:
   ```bash
   ./schema_gen.bash
   ```

   After running the script, you will have a set of directories named:
   - `tc-3.0.0`
   - `tc-3.0.1`
   - `tc-3.0.2`
   - and so on for each version.

### Step 2: Generate JSON Schemas

1. **Specify Versions**:
   In `schema_gen.py`, list the same versions of Tarantool that you built earlier:

   ```python
   versions = (
       "3.0.0",
       "3.0.1",
       "3.0.2",
       "3.1.0",
       "3.1.1",
       "3.1.2",
       "3.2.0",
   )
   ```

2. **Run the Python Script**:
   Execute the Python script to generate the JSON schemas:
   ```bash
   python3 schema_gen.py
   ```

   After running the script, you will have a set of JSON schema files stored in the `schemas` directory.
