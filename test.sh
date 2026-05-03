#!/bin/bash
set -e

# -------------------------------------------------------------
#  Color Codes
# -------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

MISSING=()
PKG_MISSING=()
DATASET_MISSING=()

# -------------------------------------------------------------
#  Helper Functions
# -------------------------------------------------------------
step() {
	echo -e "\n${CYAN}========== $1 ==========${NC}\n"
}

add_missing() {
	MISSING+=("$1")
}

# -------------------------------------------------------------
#  1. Verify uv, venv, and shell config
# -------------------------------------------------------------
step "Verifying uv, venv, and shell config [1/7]"

if [ -f "$HOME/.local/bin/env" ]; then
	# Load uv into the current shell if available
	# shellcheck source=/dev/null
	source "$HOME/.local/bin/env"
fi

if command -v uv &>/dev/null; then
	echo -e "${GREEN}  ✔ uv is installed.${NC}"
else
	echo -e "${RED}  ✘ uv not found.${NC}"
	add_missing "uv"
fi

if [ -d "$HOME/.venv" ]; then
	echo -e "${GREEN}  ✔ Virtual environment exists at ~/.venv.${NC}"
	if [ -f "$HOME/.venv/bin/activate" ]; then
		echo -e "${GREEN}  ✔ Virtual environment structure valid.${NC}"
	else
		echo -e "${RED}  ✘ Activation file missing in virtual environment.${NC}"
		add_missing "Virtual Environment (activation file missing)"
	fi
else
	echo -e "${RED}  ✘ Virtual environment not found at ~/.venv.${NC}"
	add_missing "Virtual Environment"
fi

alias_found=false
activation_found=false
uv_env_found=false

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
	if [ -f "$rc" ]; then
		if grep -Fq 'alias pip="uv pip"' "$rc"; then
			alias_found=true
		fi
		if grep -Fq '. "$HOME/.venv/bin/activate"' "$rc"; then
			activation_found=true
		fi
		if grep -Fq 'source "$HOME/.local/bin/env"' "$rc"; then
			uv_env_found=true
		fi
	fi
done

if [ "$alias_found" = true ]; then
	echo -e "${GREEN}  ✔ pip alias to uv pip is configured.${NC}"
else
	echo -e "${RED}  ✘ pip alias to uv pip not found in shell rc.${NC}"
	add_missing "pip alias (uv pip)"
fi

if [ "$activation_found" = true ]; then
	echo -e "${GREEN}  ✔ venv auto-activation configured.${NC}"
else
	echo -e "${RED}  ✘ venv auto-activation not found in shell rc.${NC}"
	add_missing "venv auto-activation"
fi

if [ "$uv_env_found" = true ]; then
	echo -e "${GREEN}  ✔ uv env sourcing configured.${NC}"
else
	echo -e "${RED}  ✘ uv env sourcing not found in shell rc.${NC}"
	add_missing "uv env sourcing"
fi

# -------------------------------------------------------------
#  2. Verify VS Code
# -------------------------------------------------------------
step "Verifying Visual Studio Code [2/7]"

if command -v code &>/dev/null; then
	echo -e "${GREEN}  ✔ Visual Studio Code is installed.${NC}"
else
	echo -e "${RED}  ✘ Visual Studio Code not found.${NC}"
	add_missing "VS Code"
fi

# -------------------------------------------------------------
#  3. Verify OpenJDK 8
# -------------------------------------------------------------
step "Verifying OpenJDK 8 [3/7]"

java_ok=false
javac_ok=false

if command -v java &>/dev/null; then
	JAVA_VER=$(java -version 2>&1 | head -n 1)
	if echo "$JAVA_VER" | grep -Eq '"1\.8\.|"8\.'; then
		echo -e "${GREEN}  ✔ Java is OpenJDK 8: ${JAVA_VER}${NC}"
		java_ok=true
	else
		echo -e "${RED}  ✘ Java is not OpenJDK 8: ${JAVA_VER}${NC}"
		add_missing "OpenJDK 8 (java)"
	fi
else
	echo -e "${RED}  ✘ java not found.${NC}"
	add_missing "OpenJDK 8 (java)"
fi

if command -v javac &>/dev/null; then
	JAVAC_VER=$(javac -version 2>&1)
	if echo "$JAVAC_VER" | grep -Eq ' 1\.8\.| 8\.'; then
		echo -e "${GREEN}  ✔ javac is OpenJDK 8: ${JAVAC_VER}${NC}"
		javac_ok=true
	else
		echo -e "${RED}  ✘ javac is not OpenJDK 8: ${JAVAC_VER}${NC}"
		add_missing "OpenJDK 8 (javac)"
	fi
else
	echo -e "${RED}  ✘ javac not found.${NC}"
	add_missing "OpenJDK 8 (javac)"
fi

# -------------------------------------------------------------
#  4. Verify Python packages
# -------------------------------------------------------------
step "Verifying Python packages [4/7]"

REQUIRED_PKGS=(
	ipykernel notebook gymnasium matplotlib numpy pandas sklearn seaborn
	tensorflow pydot graphviz deap torch torchvision torchaudio
)

PYTHON_BIN="$HOME/.venv/bin/python3"

if [ -x "$PYTHON_BIN" ]; then
	for pkg in "${REQUIRED_PKGS[@]}"; do
		if "$PYTHON_BIN" -c "import $pkg" &>/dev/null; then
			echo -e "${GREEN}  ✔ $pkg ${NC}"
		else
			echo -e "${RED}  ✘ $pkg is missing.${NC}"
			PKG_MISSING+=("$pkg")
		fi
	done
else
	echo -e "${RED}  ✘ Virtual environment Python not found at $PYTHON_BIN.${NC}"
	add_missing "Python Packages (no venv Python)"
fi

if command -v dot &>/dev/null; then
	echo -e "${GREEN}  ✔ Graphviz ${NC}"
else
	echo -e "${RED}  ✘ Graphviz system binary (dot) not found.${NC}"
	add_missing "Graphviz system package"
fi

# -------------------------------------------------------------
#  5. Verify TensorFlow datasets
# -------------------------------------------------------------
step "Verifying TensorFlow datasets [5/7]"

KERAS_DIR="$HOME/.keras/datasets"

if [ -d "$KERAS_DIR" ]; then
	if [ -f "$KERAS_DIR/mnist.npz" ]; then
		echo -e "${GREEN}  ✔ MNIST ${NC}"
	else
		echo -e "${RED}  ✘ MNIST dataset missing (${KERAS_DIR}/mnist.npz).${NC}"
		DATASET_MISSING+=("MNIST (keras)")
	fi

	if [ -f "$KERAS_DIR/imdb.npz" ]; then
		echo -e "${GREEN}  ✔ IMDB ${NC}"
	else
		echo -e "${RED}  ✘ IMDB dataset missing (${KERAS_DIR}/imdb.npz).${NC}"
		DATASET_MISSING+=("IMDB (keras)")
	fi

	if [ -d "$KERAS_DIR/cifar-10-batches-py" ] || [ -f "$KERAS_DIR/cifar-10-python.tar.gz" ]; then
		echo -e "${GREEN}  ✔ CIFAR-10 ${NC}"
	else
		echo -e "${RED}  ✘ CIFAR-10 dataset missing (${KERAS_DIR}/cifar-10-batches-py).${NC}"
		DATASET_MISSING+=("CIFAR-10 (keras)")
	fi
else
	echo -e "${RED}  ✘ Keras datasets directory not found (${KERAS_DIR}).${NC}"
	DATASET_MISSING+=("MNIST (keras)" "IMDB (keras)" "CIFAR-10 (keras)")
fi

# -------------------------------------------------------------
#  6. Verify Desktop Datasets Folder
# -------------------------------------------------------------
step "Verifying Desktop Datasets Folder [6/7]"

DESKTOP_PATH="$HOME/Desktop"
if [ -d "$DESKTOP_PATH/BE - Datasets" ]; then
	echo -e "${GREEN}  ✔ Datasets folder found on Desktop.${NC}"
	if [ "$(ls -A "$DESKTOP_PATH/BE - Datasets")" ]; then
		FILE_COUNT=$(find "$DESKTOP_PATH/BE - Datasets" -type f | wc -l | tr -d ' ')
		echo -e "${GREEN}  ✔ Datasets folder contains files (${FILE_COUNT} files).${NC}"
		echo -e "${CYAN}  File names:${NC}"
		find "$DESKTOP_PATH/BE - Datasets" -type f -print \
			| sed "s|^$DESKTOP_PATH/BE - Datasets/||" \
			| sed 's|^BE - Datasets/||' \
			| sed 's|^|    - |'
	else
		echo -e "${RED}  ✘ Datasets folder is empty.${NC}"
		add_missing "Datasets (empty folder)"
	fi
else
	echo -e "${RED}  ✘ Datasets folder not found on Desktop.${NC}"
	add_missing "Datasets folder (Desktop)"
fi

# -------------------------------------------------------------
#  7. Summary
# -------------------------------------------------------------
step "Summary [7/7]"

if [ ${#MISSING[@]} -eq 0 ] && [ ${#PKG_MISSING[@]} -eq 0 ] && [ ${#DATASET_MISSING[@]} -eq 0 ]; then
	echo -e "${GREEN}All checks passed. You are good to go!${NC}"
else
	echo -e "${RED}Some components are missing:${NC}"

	for item in "${MISSING[@]}"; do
		echo -e " - ${YELLOW}${item}${NC}"
	done

	if [ ${#PKG_MISSING[@]} -gt 0 ]; then
		echo -e " - ${YELLOW}Python Packages:${NC}"
		for pkg in "${PKG_MISSING[@]}"; do
			echo -e "     * ${pkg}"
		done
	fi

	if [ ${#DATASET_MISSING[@]} -gt 0 ]; then
		echo -e " - ${YELLOW}Datasets:${NC}"
		for ds in "${DATASET_MISSING[@]}"; do
			echo -e "     * ${ds}"
		done
	fi

	echo -e "\n${YELLOW}Please install or fix the above components before proceeding.${NC}"
fi

echo -e "\n${CYAN}========== Verification Completed ==========${NC}\n"
