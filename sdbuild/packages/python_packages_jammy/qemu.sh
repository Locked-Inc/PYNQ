export HOME=/root

set -x
set -e


# Captured using pip3 freeze on image after packages installed with no versions
cd /root

export PYNQ_VENV=/usr/local/share/pynq-venv

python3 -m venv --system-site-packages $PYNQ_VENV
echo "source $PYNQ_VENV/bin/activate" > /etc/profile.d/pynq_venv.sh
source /etc/profile.d/pynq_venv.sh

# Configure pip cache if available (speeds up builds significantly)
if [ -n "$PIP_CACHE_DIR" ] && [ -d "$PIP_CACHE_DIR" ]; then
    echo "Using pip cache: $PIP_CACHE_DIR"
    export PIP_CACHE_DIR
    # Use cache directory for faster installs
    python3 -m pip install --cache-dir "$PIP_CACHE_DIR" pip==22.0.2
    python3 -m pip install --cache-dir "$PIP_CACHE_DIR" -r requirements.txt
else
    echo "No pip cache configured - downloading packages"
    python3 -m pip install pip==22.0.2
    python3 -m pip install -r requirements.txt
fi
rm requirements.txt
