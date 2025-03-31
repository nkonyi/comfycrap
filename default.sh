#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

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

CHECKPOINT_MODELS=(
    "https://civitai.com/api/download/models/798204?type=Model&format=SafeTensor&size=full&fp=fp16"
)

UNET_MODELS=(
)

LORA_MODELS=(
)

VAE_MODELS=(
)

ESRGAN_MODELS=(
)

CONTROLNET_MODELS=(
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages

    # Default model downloads:
    provisioning_get_files \
        "${COMFYUI_DIR}/models/checkpoints" \
        "${CHECKPOINT_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/unet" \
        "${UNET_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/lora" \
        "${LORA_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/controlnet" \
        "${CONTROLNET_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/vae" \
        "${VAE_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/esrgan" \
        "${ESRGAN_MODELS[@]}"

    ######################################################
    # CUSTOM STEP: Overwrite models & custom_nodes
    ######################################################
    apt update && apt install -y python3-pip tar
    pip install gdown

    cd "${COMFYUI_DIR}"

    # Remove default folders
    rm -rf "${COMFYUI_DIR}/custom_nodes"
    rm -rf "${COMFYUI_DIR}/models"

    #----------------------------------------------------
    # 1) Download & extract custom_nodes.tar (same ID as before)
    #----------------------------------------------------
    CUSTOM_NODES_ID="1KdCBjqr7M79cOIqTVvrcCIxEmn2mJypD"
    gdown "https://drive.google.com/uc?id=${CUSTOM_NODES_ID}" -O custom_nodes.tar
    tar -xf custom_nodes.tar -C "${COMFYUI_DIR}/"
    rm custom_nodes.tar
    echo "✅ Replaced default custom_nodes with yours."

    #----------------------------------------------------
    # 2) Download & assemble models.tar (split in 11 parts)
    #----------------------------------------------------
    # Put each part's GDrive file ID in order
    MODEL_PART_IDS=(
      "10ACCPahelzVzJ4A13T0Kj3RZ0Iv7wu_y"
      "1VAjdm_628lpLPcYXZLmS8vTtIFGAbhrI"
      "1A7d1t1DVxCNojW_EFg2vhtyAr7CmWvrm"
      "1WewztStFTTMwOdce5IuUyU3MajP4lLxU"
      "1ARC7JPOHyUGnAtFhfAFbvwI-CiyEXRCv"
      "1A4tdZ8ENxmSkD4RFZnTZmRM8s1SVdvvf"
      "1wKLRHc_KiIfeeX0ncKo0Iyaf3fiPEA3b"
      "15BBOYKmV2L0WLlprV_Cecg2hy88hLq_w"
      "1tmBvzbbZQdURqOeOKLHduV_DA8W1vNo1"
      "160f1bJzpK_nzT8hnb-ObVjNX7_JQpW25"
      "1clRrxbAx_4pTI0sIU-m6brDhu1ZB6zH0"
    )

    i=1
    for ID in "${MODEL_PART_IDS[@]}"; do
        part_num=$(printf "%03d" $i)  # ensures 001, 002, etc
        echo "Downloading models.tar.${part_num} from Google Drive..."
        gdown "https://drive.google.com/uc?id=${ID}" -O "models.tar.${part_num}"
        ((i++))
    done

    # Combine all parts into one .tar
    cat models.tar.0* > models.tar

    # Extract into ComfyUI
    tar -xf models.tar -C "${COMFYUI_DIR}/"

    # Clean up parts
    rm models.tar.0*
    rm models.tar

    echo "✅ Replaced default models with your (11-part) version from Google Drive."

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
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
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

    # Check if the token is valid
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

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

# Download from $1 URL to $2 file path
function provisioning_download() {
    # If a Hugging Face token is provided, or Civitai token is provided, handle it
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi

    if [[ -n $auth_token ]]; then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

# Allow user to disable provisioning if they started with a script they didn't want
if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi
