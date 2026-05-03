#!/bin/bash
set -e

# -------------------------------------------------------------
#  Color codes
# -------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# -------------------------------------------------------------
#  Helper functions
# -------------------------------------------------------------
step() {
	echo -e "\n${CYAN}========== $1 ==========${NC}\n"
}

success() {
	echo -e "${GREEN}[OK] $1${NC}"
}

fail() {
	echo -e "${RED}[FAIL] $1${NC}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -------------------------------------------------------------
#  1. Sudo authentication
# -------------------------------------------------------------
clear
echo -e "${YELLOW}Starting installation...${NC}"

step "Sudo authentication [1/8]"
SUDO_PW="123"

if echo "$SUDO_PW" | sudo -S -v; then
	success "Sudo authenticated with default password."
else
	fail "Default sudo password failed."
    while true; do
		read -r -s -p "Enter sudo password: " SUDO_PW
		echo ""
		if echo "$SUDO_PW" | sudo -S -v; then
			success "Sudo authenticated."
			break
		else
			fail "Sudo authentication failed. Try again."
		fi
	done
fi

sudo_cmd() {
	echo "$SUDO_PW" | sudo -S "$@"
}

# -------------------------------------------------------------
#  2. Update System
# -------------------------------------------------------------
step "Updating system [2/8]"
sudo_cmd apt update -y
sudo_cmd apt upgrade -y

# -------------------------------------------------------------
#  3. Install system dependencies
# -------------------------------------------------------------
step "Installing dependencies [3/8]"
sudo_cmd apt install -y wget curl snapd gnupg lsb-release ca-certificates unzip graphviz openjdk-8-jdk

# -------------------------------------------------------------
#  4. Install uv and set up virtual environment
# -------------------------------------------------------------
step "Setting up Python environment [4/8]"

if [ -f "$HOME/.local/bin/env" ]; then
	# Load uv into the current shell if available
	# shellcheck source=/dev/null
	source "$HOME/.local/bin/env"
fi

if ! command -v uv >/dev/null 2>&1; then
    # Downloading uv
    echo -e "${YELLOW}uv not found. Installing uv...${NC}"
	curl -LsSf https://astral.sh/uv/install.sh | sh
fi

if [ -f "$HOME/.local/bin/env" ]; then
	# Load uv into the current shell if available
	# shellcheck source=/dev/null
	source "$HOME/.local/bin/env"
fi

if [ ! -d "$HOME/.venv" ]; then
	uv venv "$HOME/.venv" --python=python3.12
	success "Virtual environment created at ~/.venv."
else
	success "Virtual environment already exists."
fi

# Ensure shell rc files are updated for uv, venv auto-activation, and pip alias
apply_shell_block() {
	local rc_file="$1"
	local start_marker="# >>> lab-setup >>>"
	local end_marker="# <<< lab-setup <<<"

	touch "$rc_file"

	awk -v start="$start_marker" -v end="$end_marker" '
		$0==start {inblock=1; next}
		$0==end {inblock=0; next}
		!inblock {print}
	' "$rc_file" > "${rc_file}.tmp" && mv "${rc_file}.tmp" "$rc_file"

	cat >> "$rc_file" <<'EOF'
# >>> lab-setup >>>
if [ -f "$HOME/.local/bin/env" ]; then
  source "$HOME/.local/bin/env"
fi
if [ -f "$HOME/.venv/bin/activate" ]; then
  . "$HOME/.venv/bin/activate"
fi
alias pip="uv pip"
# <<< lab-setup <<<
EOF
}

apply_shell_block "$HOME/.bashrc"
apply_shell_block "$HOME/.zshrc"

success "Shell configuration updated for uv, venv auto-activation, and pip alias."

# -------------------------------------------------------------
#  5. Install Python packages
# -------------------------------------------------------------
step "Installing Python packages [5/8]"

# shellcheck source=/dev/null
source "$HOME/.venv/bin/activate"

uv pip install \
	ipykernel notebook gymnasium matplotlib numpy pandas scikit-learn seaborn \
	tensorflow pydot graphviz deap

uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

success "Python packages installed."

# -------------------------------------------------------------
#  6. Download and extract datasets
# -------------------------------------------------------------
step "Downloading and extracting datasets [6/8]"

DATASET_URL="https://github.com/tempzeal/lp/releases/download/lab/Datasets.zip"
DESKTOP_PATH="$HOME/Desktop"
TARGET_DIR="$DESKTOP_PATH/Datasets"

mkdir -p "$TARGET_DIR"

wget -O "$DESKTOP_PATH/Datasets.zip" "$DATASET_URL"
unzip -oq "$DESKTOP_PATH/Datasets.zip" -d "$TARGET_DIR"
rm -f "$DESKTOP_PATH/Datasets.zip"

success "Datasets downloaded and extracted to: $TARGET_DIR"

# -------------------------------------------------------------
#  7. Install VS Code
# -------------------------------------------------------------
step "Installing Visual Studio Code [7/8]"

# if ! command -v snap >/dev/null 2>&1; then
# 	sudo_cmd apt install -y snapd
# 	sudo_cmd systemctl enable snapd.socket || true
# 	sudo_cmd systemctl start snapd.socket || true
# fi

# if snap list | grep -q "code"; then
# 	success "Visual Studio Code already installed."
# else
# 	sudo_cmd snap install code --classic
# 	success "Visual Studio Code installed."
# fi

# -------------------------------------------------------------
#  8. Run verification script
# -------------------------------------------------------------
step "Running verification script [8/8]"

chmod +x "$SCRIPT_DIR/test.sh"

if command -v gnome-terminal >/dev/null 2>&1; then
	gnome-terminal -- bash -c "bash '$SCRIPT_DIR/test.sh'; exec bash"
elif command -v x-terminal-emulator >/dev/null 2>&1; then
	x-terminal-emulator -e "bash '$SCRIPT_DIR/test.sh'"
elif command -v konsole >/dev/null 2>&1; then
	konsole -e "bash '$SCRIPT_DIR/test.sh'"
elif [ "$TERM_PROGRAM" = "vscode" ]; then
	echo "Running inside VS Code terminal, executing directly..."
	bash "$SCRIPT_DIR/test.sh"
else
	echo "No GUI terminal detected. Running test script in current shell..."
	bash "$SCRIPT_DIR/test.sh"
fi

unset SUDO_PW
