#!/bin/bash

versions=(
    "3.0.0"
    "3.0.1"
    "3.0.2"
    "3.1.0"
    "3.1.1"
    "3.1.2"
    "3.2.0"
)

rm -rf tarantool
git clone https://github.com/tarantool/tarantool.git

for version in "${versions[@]}"; do
    echo "Processing version: $version"

    rm -rf "tc-$version"
    cp -r tarantool "tc-$version"

    (
        cd "tc-$version" && \
        git checkout "$version" && \
        cmake . && \
        make -j
    )

    if [ $? -eq 0 ]; then
        echo "Version $version built successfully."
    else
        echo "Error building version $version."
        break
    fi
done
