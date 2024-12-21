#!/bin/bash

# Ollm Bridge v0.6 - macOS Version
# Ollm Bridge aims to create a structure of directories and symlinks to make Ollama models more easily accessible to LMStudio users.
#
# This is free and unencumbered software released into the public domain.
# See LICENSE file for full terms or visit https://unlicense.org

# Define the directory variables
manifest_dir="$HOME/.ollama/models/manifests/registry.ollama.ai"
blob_dir="$HOME/.ollama/models/blobs"
publicModels_dir="$HOME/publicmodels"

# Print the base directories to confirm the variables
echo ""
echo "Confirming Directories:"
echo ""
echo "Manifest Directory: $manifest_dir"
echo "Blob Directory: $blob_dir"
echo "Public Models Directory: $publicModels_dir"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install it using 'brew install jq'"
    exit 1
fi

# Check if the publicmodels/lmstudio directory already exists, and delete it if so
if [ -d "$publicModels_dir/lmstudio" ]; then
    echo ""
    rm -rf "$publicModels_dir/lmstudio"
    echo "Ollm Bridge Directory Reset."
fi

if [ -d "$publicModels_dir" ]; then
    echo ""
    echo "Public Models Directory Confirmed."
else
    mkdir -p "$publicModels_dir"
    echo ""
    echo "Public Models Directory Created."
fi

# Explore the manifest directory and record the manifest file locations
echo ""
echo "Exploring Manifest Directory:"
echo ""

# Find all files in manifest directory
find "$manifest_dir" -type f -print0 | while IFS= read -r -d '' manifest; do
    echo "Processing: $manifest"
    
    # Extract config digest and create modelConfig path
    config_digest=$(jq -r '.config.digest' "$manifest" | sed 's/sha256:/sha256-/')
    modelConfig="$blob_dir/$config_digest"

    # Extract layer information
    while read -r layer; do
        mediaType=$(echo "$layer" | jq -r '.mediaType')
        digest=$(echo "$layer" | jq -r '.digest' | sed 's/sha256:/sha256-/')
        
        case "$mediaType" in
            *"model")
                modelFile="$blob_dir/$digest"
                ;;
            *"template")
                modelTemplate="$blob_dir/$digest"
                ;;
            *"params")
                modelParams="$blob_dir/$digest"
                ;;
        esac
    done < <(jq -c '.layers[]' "$manifest")

    # Extract variables from modelConfig
    if [ -f "$modelConfig" ]; then
        modelQuant=$(jq -r '.file_type' "$modelConfig")
        modelExt=$(jq -r '.model_format' "$modelConfig")
        modelTrainedOn=$(jq -r '.model_type' "$modelConfig")
    fi

    # Get model name from parent directory
    modelName=$(basename "$(dirname "$manifest")")

    echo ""
    echo "Model Name is $modelName"
    echo "Quant is $modelQuant"
    echo "Extension is $modelExt"
    echo "Number of Parameters Trained on is $modelTrainedOn"
    echo ""

    # Create necessary directories
    mkdir -p "$publicModels_dir/lmstudio/$modelName/$modelQuant"

    # Create symbolic link
    echo ""
    echo "Creating symbolic link for $modelFile..."
    ln -sf "$modelFile" "$publicModels_dir/lmstudio/$modelName/$modelQuant/$modelName-$modelTrainedOn-$modelQuant.$modelExt"
done

echo ""
echo ""
echo "*********************"
echo "Ollm Bridge complete."
echo "Set the Models Directory in LMStudio to $publicModels_dir/lmstudio"