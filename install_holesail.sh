#!/bin/bash

# Function to install Holesail on Linux or macOS
install_unix() {
    echo "Installing Holesail on Linux/macOS..."
    
    # Install NVM
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    
    # Add NVM to environment variables
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Install Node.js 20
    nvm install 20
    nvm use 20
    
    # Install Holesail
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        npm i holesail -g
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        npm i holesail -g
    fi
}

# Function to install Holesail on Windows
install_windows() {
    echo "Installing Holesail on Windows..."
    echo "Please download and install Node.js from https://nodejs.org/"
    echo "After installing Node.js, run the following command in Command Prompt:"
    echo "npm i holesail -g"
    echo ""
    echo "If installation fails, try running Command Prompt as Administrator and execute:"
    echo "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned"
}

# Main script
if [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "darwin"* ]]; then
    install_unix
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    install_windows
else
    echo "Unsupported operating system"
    exit 1
fi

# Verify installation
if command -v holesail &> /dev/null; then
    echo "Holesail installed successfully!"
    holesail --help
else
    echo "Holesail installation failed or not found in PATH"
    exit 1
fi
