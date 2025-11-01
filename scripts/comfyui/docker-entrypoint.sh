#!/usr/bin/env bash

set -eu -o pipefail

export COMFYUI_PATH="/opt/ComfyUI"

if [ -d "/root/.cache" ]; then
    chown -R root:root /root/.cache
fi

python3 -m venv .venv
source .venv/bin/activate
echo "*" >.venv/.gitignore
python3 -m pip install --upgrade pip
echo ""
if ! [ -f /lockfile ]; then
    if [ ! -d "$COMFYUI_PATH" ]; then
        (cd /opt/ &&
            mkdir -p "$COMFYUI_PATH" &&
            git clone --recursive https://github.com/comfyanonymous/ComfyUI.git ComfyUI || echo "ComfyUI clone failed")
    else
        (cd $COMFYUI_PATH &&
            git config --global --add safe.directory /opt/ComfyUI &&
            git pull https://github.com/comfyanonymous/ComfyUI.git || echo "ComfyUI pull failed")
    fi
    # echo ""
    # pip3 install --upgrade opencv-python onnxruntime
    echo ""
    pip3 install --upgrade --pre torch torchaudio torchvision --index-url https://download.pytorch.org/whl/nightly/cu128 || echo "ComfyUI requirements install/upgrade failed"
    echo ""
    pip3 install --upgrade --trusted-host pypi.org --trusted-host files.pythonhosted.org -r $COMFYUI_PATH/requirements.txt || echo "ComfyUI requirements install/upgrade failed"
    echo ""
    echo "== Installing Huggingface Hub"
    pip3 install --upgrade --trusted-host pypi.org --trusted-host files.pythonhosted.org -U "huggingface_hub[cli]" || echo "HuggingFace Hub CLI install/upgrade failed"
    echo ""
    if [ ! -d $COMFYUI_PATH/custom_nodes/comfyui-prompt-control ]; then
        (pip3 install --upgrade lark && cd $COMFYUI_PATH/custom_nodes && git clone --recursive https://github.com/asagi4/comfyui-prompt-control.git || echo "comfyui-prompt-control clone failed")
    else
        (cd $COMFYUI_PATH/custom_nodes/comfyui-prompt-control && git pull https://github.com/asagi4/comfyui-prompt-control.git || echo "comfyui-prompt-control pull failed")
    fi
    echo ""
    if [ ! -d $COMFYUI_PATH/custom_nodes/ComfyUI-Manager ]; then
        echo "== Cloning ComfyUI-Manager"
        (cd $COMFYUI_PATH/custom_nodes && git clone --recursive https://github.com/ltdrdata/ComfyUI-Manager.git || echo "ComfyUI-Manager clone failed")
    fi
    if [ ! -d $COMFYUI_PATH/custom_nodes/ComfyUI-Manager ]; then echo "ComfyUI-Manager not found"; fi
    echo "== Installing/Updating ComfyUI-Manager's requirements (from $COMFYUI_PATH/custom_nodes/ComfyUI-Manager/requirements.txt)"
    pip3 install --upgrade --trusted-host pypi.org --trusted-host files.pythonhosted.org -r $COMFYUI_PATH/custom_nodes/ComfyUI-Manager/requirements.txt || echo "ComfyUI-Manager CLI requirements install/upgrade failed"
    echo ""
    echo "== Running ComfyUI-Manager CLI to fix installed custom nodes"
    if [ -f $COMFYUI_PATH/custom_nodes/ComfyUI-Manager/cm-cli.py ]; then
        python3 $COMFYUI_PATH/custom_nodes/ComfyUI-Manager/cm-cli.py fix all && echo "ComfyUI-Manager CLI: nodes fixed" || echo "ComfyUI-Manager CLI failed -- in case of issue with custom nodes: use 'Manager -> Custom Nodes Manager -> Filter: Import Failed -> Try Fix' from the WebUI"
    fi
    echo ""
    TAESD_PATH="/opt/taesd"
    if ! [ -d $TAESD_PATH ]; then
        (cd /opt &&
            git clone --recursive https://github.com/madebyollin/taesd.git || echo "TAESD clone failed")
    else
        (cd $TAESD_PATH &&
            git pull https://github.com/madebyollin/taesd.git || echo "TAESD pull failed")
    fi
    mkdir -p $COMFYUI_PATH/models/vae_approx
    if [ -f $TAESD_PATH/taesd_decoder.pth ]; then
        cp -v $TAESD_PATH/taesd_decoder.pth $COMFYUI_PATH/models/vae_approx/
    fi
    if [ -f $TAESD_PATH/taesdxl_decoder.pth ]; then
        cp -v $TAESD_PATH/taesdxl_decoder.pth $COMFYUI_PATH/models/vae_approx/
    fi
    if [ -f $TAESD_PATH/taesd3_decoder.pth ]; then
        cp -v $TAESD_PATH/taesd3_decoder.pth $COMFYUI_PATH/models/vae_approx/
    fi
    if [ -f $TAESD_PATH/taef1_decoder.pth ]; then
        cp -v $TAESD_PATH/taef1_decoder.pth $COMFYUI_PATH/models/vae_approx/
    fi
    touch /lockfile
fi
echo ""
# cm_conf_user=${COMFYUI_PATH}/user/default/ComfyUI-Manager/config.ini
cm_conf=${COMFYUI_PATH}/custom_nodes/ComfyUI-Manager/config.ini
if [ -f $cm_conf ]; then
    perl -p -i -e 's%security_level = \w+%security_level = '"${SECURITY_LEVEL}"'%g' $cm_conf
    echo -n "  -- ComfyUI-Manager (should show: ${SECURITY_LEVEL}): "
    grep security_level $cm_conf
fi
echo ""
if [[ $USE_HTTPS == "yes" ]]; then
    (cd $COMFYUI_PATH && python3 ./main.py --cache-none --tls-keyfile /etc/certs/key.pem --tls-certfile /etc/certs/cert.pem --listen 0.0.0.0 --port 8188 --disable-auto-launch --preview-method taesd &)
else
    (cd $COMFYUI_PATH && python3 ./main.py --cache-none --listen 0.0.0.0 --port 8188 --disable-auto-launch --preview-method taesd &)
fi
tail -f /dev/null
