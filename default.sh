#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# Set your token (using the one you provided)
CIVITAI_TOKEN="f2433afed972b76cdd473760a6a9ac8e"

# Packages are installed after nodes so we can fix them...
APT_PACKAGES=(
    #"package-1"
    #"package-2"
)

PIP_PACKAGES=(
    #"package-1"
    #"package-2"
)

NODES=(
    #"https://github.com/ltdrdata/ComfyUI-Manager"
    #"https://github.com/cubiq/ComfyUI_essentials"
)

WORKFLOWS=(

)

# CHECKPOINT_MODELS (go to models/checkpoints)
# For private Civtai files, add a pipe with the output filename.
CHECKPOINT_MODELS=(
    "https://civitai.com/api/download/models/798204?type=Model&format=SafeTensor&size=full&fp=fp16"  # original (if public)
    "https://civitai.com/api/download/models/1569593?type=Model&format=SafeTensor&size=pruned&fp=fp16|lustifyolt.safetensors"
    "https://civitai.com/api/download/models/1099200?type=Model&format=SafeTensor&size=pruned&fp=fp16|lustifydmd2.safetensors"
)

# UNET_MODELS (go to models/unet) – from Hugging Face, assumed public
UNET_MODELS=(
    "https://huggingface.co/city96/Wan2.1-I2V-14B-480P-gguf/resolve/main/wan2.1-i2v-14b-480p-Q8_0.gguf?download=true"
)

# LORA_MODELS (go to models/lora) – using private orchestration endpoints; filenames provided after pipe.
LORA_MODELS=(
    "https://civitai.com/api/download/models/1475095?type=Model&format=SafeTensor|wan-nsfw.safetensors"
    "https://civitai.com/api/download/models/1623136?type=Model&format=SafeTensor|wan-missionary.safetensors"
    "https://civitai.com/api/download/models/1513684?type=Model&format=SafeTensor|wan-bj.safetensors"
    "https://civitai.com/api/download/models/1514116?type=Model&format=SafeTensor|wan-tittydrop.safetensors"
    "https://civitai.com/api/download/models/1602715?type=Model&format=SafeTensor|wan-cum.safetensors"
    "https://civitai.com/api/download/models/1517164?type=Model&format=SafeTensor|wan-bouncy.safetensors"
    "https://civitai.com/api/download/models/1537915?type=Model&format=SafeTensor|wan-bouncewalk.safetensors"
    "https://civitai.com/api/download/models/1565668?type=Model&format=SafeTensor|wan-details.safetensors"
)

# VAE_MODELS (go to models/vae)
VAE_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
)

# TEXT_ENCODERS_MODELS (go to models/text_encoders)
TEXT_ENCODERS_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
)

# CLIP_VISION_MODELS (go to models/clip_vision)
CLIP_VISION_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"
)

ESRGAN_MODELS=(
    # (none for now)
)

CONTROLNET_MODELS=(
    # (none for now)
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages

    # Download models into respective directories:
    provisioning_get_files "${COMFYUI_DIR}/models/checkpoints" "${CHECKPOINT_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/unet" "${UNET_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/lora" "${LORA_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/controlnet" "${CONTROLNET_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/vae" "${VAE_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/esrgan" "${ESRGAN_MODELS[@]}"

    # Download models for additional directories:
    provisioning_get_files "${COMFYUI_DIR}/models/text_encoders" "${TEXT_ENCODERS_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/clip_vision" "${CLIP_VISION_MODELS[@]}"

    # Replace default custom_nodes with your custom version from Google Drive
    apt update && apt install -y python3-pip tar
    pip install gdown
    cd "${COMFYUI_DIR}"
    rm -rf "${COMFYUI_DIR}/custom_nodes"
    gdown https://drive.google.com/uc?id=1KdCBjqr7M79cOIqTVvrcCIxEmn2mJypD -O custom_nodes.tar
    tar -xf custom_nodes.tar -C "${COMFYUI_DIR}/"
    rm custom_nodes.tar
    echo "✅ Replaced default custom_nodes with your custom version from Google Drive."

    provisioning_print_end
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
        sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
        pip install --no-cache-dir ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="${COMFYUI_DIR}custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                   pip install --no-cache-dir -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip install --no-cache-dir -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_files() {
    if [[ -z $2 ]]; then return 1; fi
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for entry in "${arr[@]}"; do
        printf "Downloading: %s\n" "$entry"
        provisioning_download "$entry" "$dir"
        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete: Application will start now\n\n"
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"
    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?hidden=1&limit=1"
    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Content-Type: application/json")
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

# Modified download function to support custom filenames and use curl for Civtai URLs.
function provisioning_download() {
    local full_entry="$1"
    local out_dir="$2"
    local url filename

    # If the entry contains a pipe, split it.
    if [[ "$full_entry" == *"|"* ]]; then
        url=$(echo "$full_entry" | cut -d'|' -f1)
        filename=$(echo "$full_entry" | cut -d'|' -f2)
    else
        url="$full_entry"
        filename=""
    fi

    # If the URL is from civitai.com or orchestration.civitai.com, use curl.
    if [[ "$url" =~ ^https://([a-zA-Z0-9_-]+\.)?(civitai\.com|orchestration\.civitai\.com)(/|$|\?) ]]; then
        if [[ -n "$filename" ]]; then
            curl -H "Authorization: Bearer $CIVITAI_TOKEN" -L -o "${out_dir}/${filename}" "$url"
        else
            curl -H "Authorization: Bearer $CIVITAI_TOKEN" -L -O "$url" -P "$out_dir"
        fi
    elif [[ -n $HF_TOKEN && "$url" =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        if [[ -n "$filename" ]]; then
            wget --header="Authorization: Bearer $HF_TOKEN" -qnc --content-disposition --show-progress -O "${out_dir}/${filename}" "$url"
        else
            wget --header="Authorization: Bearer $HF_TOKEN" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$out_dir" "$url"
        fi
    else
        if [[ -n "$filename" ]]; then
            wget -qnc --content-disposition --show-progress -O "${out_dir}/${filename}" "$url"
        else
            wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$out_dir" "$url"
        fi
    fi
}

if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi
