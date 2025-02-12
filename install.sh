#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Trap Ctrl+C
trap ctrl_c INT

# Function to handle Ctrl+C
ctrl_c() {
    echo -e "\n\n${YELLOW}[!] Installation cancelled by user${NC}"
    cleanup_incomplete_installation
    exit 1
}

# Function to cleanup incomplete installation
cleanup_incomplete_installation() {
    echo -e "\n${BLUE}[*] Cleaning up incomplete installation...${NC}"
    
    # Remove virtual environment if it exists
    if [ -d ".venv" ]; then
        rm -rf .venv
        echo -e "${GREEN}[✓] Removed virtual environment${NC}"
    fi
    
    # Remove tool installations
    if [ -d "/opt/netspecter" ]; then
        sudo rm -rf /opt/netspecter
        echo -e "${GREEN}[✓] Removed tool directory${NC}"
    fi
    
    # Remove configuration files
    if [ -d "~/.netspecter" ]; then
        rm -rf ~/.netspecter
        echo -e "${GREEN}[✓] Removed configuration files${NC}"
    fi
    
    # Remove symlinks
    if [ -L "/usr/local/bin/rustscan" ]; then
        sudo rm /usr/local/bin/rustscan
        echo -e "${GREEN}[✓] Removed RustScan symlink${NC}"
    fi
    
    echo -e "${YELLOW}[!] Cleanup completed${NC}"
    echo -e "${BLUE}[*] You can run the installer again to start a fresh installation${NC}"
}

# Function to confirm installation
confirm_installation() {
    echo -e "\n${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}                   Installation Configuration                   ${YELLOW}║${NC}"
    echo -e "${YELLOW}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} The following components will be installed:                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} • System dependencies (requires sudo privileges)               ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} • Python virtual environment and packages                      ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} • RustScan (will be installed in /opt/netspecter/tools)        ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} • Configuration files (in ~/.netspecter)                       ${YELLOW}║${NC}"
    echo -e "${YELLOW}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} Installation may take several minutes depending on your system ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${BLUE}[?] Do you want to proceed with the installation? (y/n)${NC}"
    read -r response
    
    case "$response" in
        [yY][eE][sS]|[yY])
            echo -e "${GREEN}[✓] Proceeding with installation...${NC}"
            return 0
            ;;
        *)
            echo -e "${YELLOW}[!] Installation cancelled by user${NC}"
            exit 0
            ;;
    esac
}

# Function to get terminal width
get_terminal_width() {
    if command -v tput >/dev/null 2>&1; then
        tput cols
    else
        echo "80"  # Default fallback width
    fi
}

# Improved spinner function with fixed width output
show_spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local term_width=$(get_terminal_width)
    
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        # Create a fixed width message
        local output=$(printf "%-${term_width}s" "${CYAN}[%c]${NC} ${message}")
        # Clear line and print
        printf "\r\033[K%s" "$output"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    # Clear line and print completion
    printf "\r\033[K${GREEN}[✓]${NC} %s\n" "$message"
}

# Function to handle installation progress
handle_installation() {
    local cmd=$1
    local msg=$2
    local temp_file=$(mktemp)
    
    echo -e "${BLUE}[*] $msg...${NC}"
    
    # Run command in background and redirect output
    eval $cmd > "$temp_file" 2>&1 &
    local pid=$!
    
    # Show spinner with interrupt handling
    show_spinner $pid "$msg" || {
        kill $pid 2>/dev/null
        rm -f "$temp_file"
        return 1
    }
    
    # Wait for process to complete
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}[✗] $msg - Failed${NC}"
        echo -e "${RED}Error output:${NC}"
        cat "$temp_file"
        rm -f "$temp_file"
        return 1
    fi
    
    rm -f "$temp_file"
    echo -e "${GREEN}[✓] $msg - Completed${NC}"
    return 0
}

# Add this function to create necessary directories
setup_config_directories() {
    echo -e "${BLUE}[*] Creating configuration directories...${NC}"
    
    # Create main config directory
    mkdir -p ~/.netspecter/config
    
    # Create paths.conf file
    cat > ~/.netspecter/config/paths.conf << EOF
# Tool paths configuration
RUSTSCAN_PATH=/opt/netspecter/tools/rustscan
NMAP_PATH=$(which nmap)
MASSCAN_PATH=$(which masscan)
EOF

    # Set proper permissions
    chmod 755 ~/.netspecter/config
    chmod 644 ~/.netspecter/config/paths.conf
    
    echo -e "${GREEN}[✓] Configuration directories created${NC}"
}

# Add the show_progress function
show_progress() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    # Clear line before starting
    printf "\r%-80s" ""
    
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf "\r${CYAN}[%c]${NC} %s" "$spinstr" "$message"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    
    wait $pid
    local exit_code=$?
    
    # Clear line before showing final status
    printf "\r%-80s" ""
    
    if [ $exit_code -eq 0 ]; then
        printf "\r${GREEN}[✓]${NC} %s\n" "$message"
    else
        printf "\r${RED}[✗]${NC} %s\n" "$message"
        return 1
    fi
}

# Update the installation process
install_dependencies() {
    echo -e "\n${BLUE}[*] Installing system dependencies...${NC}"
    
    case $1 in
        "wsl"|"linux")
            apt-get update > /dev/null 2>&1 &
            show_progress $! "Updating package lists"
            
            apt-get install -y python3 python3-pip python3-venv python3-dev \
                libpcap-dev nmap git make gcc clang libssl-dev > /dev/null 2>&1 &
            show_progress $! "Installing system packages"
            ;;
            
        "macos")
            brew update > /dev/null 2>&1 &
            show_progress $! "Updating Homebrew"
            
            brew install python3 nmap masscan libpcap > /dev/null 2>&1 &
            show_progress $! "Installing system packages"
            ;;
            
        *)
            echo -e "${RED}[!] Unsupported operating system${NC}"
            exit 1
            ;;
    esac
}

# Update RustScan installation
install_rustscan() {
    echo -e "\n${BLUE}[*] Installing RustScan...${NC}"
    
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Create tools directory if it doesn't exist
    if [ ! -d "$INSTALL_DIR/tools" ]; then
        mkdir -p "$INSTALL_DIR/tools"
        chmod 755 "$INSTALL_DIR/tools"
        chown $SUDO_USER:$SUDO_USER "$INSTALL_DIR/tools"
    fi
    
    # Clone RustScan
    git clone https://github.com/RustScan/RustScan.git /tmp/rustscan > /dev/null 2>&1 &
    show_progress $! "Cloning RustScan repository"
    
    # Build RustScan
    cd /tmp/rustscan
    cargo build --release > /dev/null 2>&1 &
    show_progress $! "Building RustScan"
    
    # Install RustScan
    if [ -f "/tmp/rustscan/target/release/rustscan" ]; then
        cp "/tmp/rustscan/target/release/rustscan" "$INSTALL_DIR/tools/" &
        show_progress $! "Installing RustScan binary"
        chmod +x "$INSTALL_DIR/tools/rustscan"
        chown $SUDO_USER:$SUDO_USER "$INSTALL_DIR/tools/rustscan"
    else
        echo -e "${RED}[✗] RustScan binary not found${NC}"
        return 1
    fi
    
    # Cleanup
    cd - > /dev/null
    rm -rf /tmp/rustscan
    
    # Verify installation
    if [ -x "$INSTALL_DIR/tools/rustscan" ]; then
        echo -e "${GREEN}[✓] RustScan installed successfully${NC}"
        return 0
    else
        echo -e "${RED}[✗] RustScan installation failed${NC}"
        return 1
    fi
}

# Update Python environment setup
setup_python_env() {
    echo -e "\n${BLUE}[*] Setting up Python environment...${NC}"
    
    # Create virtual environment
    python3 -m venv "$INSTALL_DIR/.venv" > /dev/null 2>&1 &
    show_progress $! "Creating virtual environment"
    
    # Activate virtual environment
    source "$INSTALL_DIR/.venv/bin/activate"
    
    # Install requirements
    pip install --upgrade pip > /dev/null 2>&1 &
    show_progress $! "Upgrading pip"
    
    pip install -r requirements.txt > /dev/null 2>&1 &
    show_progress $! "Installing Python dependencies"
    
    # Install the package
    pip install -e . > /dev/null 2>&1 &
    show_progress $! "Installing NetSpecter package"
    
    deactivate
}

# Add function to handle Ctrl+X
handle_ctrl_x() {
    echo -e "\n\n${YELLOW}[!] Installation abort requested (Ctrl+X)${NC}"
    
    # Kill all background processes
    local bg_jobs=$(jobs -p)
    if [ -n "$bg_jobs" ]; then
        echo -e "${YELLOW}[*] Stopping background processes...${NC}"
        kill $bg_jobs 2>/dev/null
    fi
    
    echo -e "\n${BLUE}[*] Cleaning up...${NC}"
    
    # Get installation directory
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Clean up virtual environment
    if [ -d "$INSTALL_DIR/.venv" ]; then
        echo -e "${YELLOW}[*] Removing virtual environment...${NC}"
        rm -rf "$INSTALL_DIR/.venv"
    fi
    
    # Clean up package files
    if [ -d "$INSTALL_DIR/netspecter.egg-info" ]; then
        echo -e "${YELLOW}[*] Removing package files...${NC}"
        rm -rf "$INSTALL_DIR/netspecter.egg-info"
    fi
    
    # Remove temporary files
    echo -e "${YELLOW}[*] Removing temporary files...${NC}"
    find /tmp -name "netspecter_*" -type f -delete 2>/dev/null
    rm -rf /tmp/rustscan 2>/dev/null
    
    # Remove partial installations
    for dir in tools scripts reports logs config; do
        if [ -d "$INSTALL_DIR/$dir" ]; then
            echo -e "${YELLOW}[*] Removing $dir directory...${NC}"
            rm -rf "$INSTALL_DIR/$dir"
        fi
    done
    
    echo -e "\n${GREEN}[✓] Cleanup completed${NC}"
    echo -e "${BLUE}[*] Installation aborted. You can run the installer again to start fresh.${NC}"
    exit 1
}

# Update trap handling at the beginning of the script
setup_signal_handlers() {
    # Handle Ctrl+X (ASCII code 24)
    trap 'handle_ctrl_x' 24
    
    # Handle Ctrl+C
    trap 'handle_interrupt' SIGINT SIGTERM
    
    # Ensure we can receive Ctrl+X signal
    stty susp ^X
}

# Update main installation function
main_installation() {
    # Setup signal handlers
    setup_signal_handlers
    
    local term_width=$(get_terminal_width)
    
    printf "\n%${term_width}s\n" | tr ' ' '='
    echo -e "${BLUE}Starting Installation Process${NC}"
    printf "%${term_width}s\n\n" | tr ' ' '='
    
    echo -e "${YELLOW}[!] Press Ctrl+X at any time to abort installation${NC}"
    sleep 2
    
    # Setup tool structure first
    setup_tool_structure || {
        echo -e "${RED}[✗] Failed to setup tool structure${NC}"
        exit 1
    }
    
    # Install RustScan
    install_rustscan || {
        echo -e "${RED}[✗] Failed to install RustScan${NC}"
        exit 1
    }
    
    # Install Masscan
    install_masscan || {
        echo -e "${RED}[✗] Failed to install Masscan${NC}"
        exit 1
    }
    
    # Rest of your installation code...
    
    # Install dependencies
    install_dependencies "$ENV" || {
        echo -e "${RED}[✗] Failed to install dependencies${NC}"
        exit 1
    }
    
    # Setup Python package structure
    setup_python_package || {
        echo -e "${RED}[✗] Failed to setup Python package${NC}"
        exit 1
    }
    
    # Create setup.py
    create_setup_py || {
        echo -e "${RED}[✗] Failed to create setup.py${NC}"
        exit 1
    }
    
    # Setup Python environment
    setup_python_env || {
        echo -e "${RED}[✗] Failed to setup Python environment${NC}"
        exit 1
    }
    
    # Update wrapper script
    update_wrapper_script || {
        echo -e "${RED}[✗] Failed to update wrapper script${NC}"
        exit 1
    }
    
    echo -e "\n${GREEN}[✓] Installation completed!${NC}"
    echo -e "\n${YELLOW}You can now run NetSpecter using:${NC}"
    echo -e "  ${CYAN}1. ./netspecter.py${NC}"
    echo -e "  ${CYAN}2. source .venv/bin/activate && netspecter${NC}"
}

# Banner
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "███╗   ██╗███████╗████████╗███████╗██████╗ ███████╗ ██████╗████████╗███████╗██████╗"
    echo "████╗  ██║██╔════╝╚══██╔══╝██╔════╝██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔════╝██╔══██╗"
    echo "██╔██╗ ██║█████╗     ██║   ███████╗██████╔╝█████╗  ██║        ██║   █████╗  ██████╔╝"
    echo "██║╚██╗██║██╔══╝     ██║   ╚════██║██╔═══╝ ██╔══╝  ██║        ██║   ██╔══╝  ██╔══██╗"
    echo "██║ ╚████║███████╗   ██║   ███████║██║     ███████╗╚██████╗   ██║   ███████╗██║  ██║"
    echo "╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚══════╝ ╚═════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}                        NetSpecter Installation Script                         ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}                         Advanced Network Scanner                              ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}                       Developer: Indrajit Karmakar                            ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}                 GitHub: https://github.com/indrajitkar                        ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to detect OS and environment
detect_environment() {
    if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null ; then
        echo "wsl"
        return
    fi

    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        CYGWIN*)    echo "windows";;
        MINGW*)     echo "windows";;
        *)          echo "unknown";;
    esac
}

# Function to check and install system dependencies
install_system_dependencies() {
    echo -e "\n${BLUE}[*] Installing system dependencies...${NC}"
    
    case $1 in
        "linux")
            echo -e "${YELLOW}[*] Installing dependencies for Linux...${NC}"
            apt-get update
            apt-get install -y \
                python3 \
                python3-pip \
                python3-venv \
                python3-dev \
                libpcap-dev \
                nmap \
                git \
                make \
                gcc \
                clang \
                libssl-dev
            
            # Install masscan separately with error handling
            install_masscan || {
                echo -e "${RED}[✗] Masscan installation failed${NC}"
                return 1
            }
            ;;

        "wsl")
            echo -e "${YELLOW}[*] Installing dependencies for WSL...${NC}"
            sudo apt-get update
            sudo apt-get install -y \
                python3 python3-pip python3-venv \
                python3-dev \
                libpcap-dev \
                nmap \
                git \
                make \
                gcc \
                libssl-dev \
                libffi-dev \
                zlib1g-dev \
                libxml2-dev \
                libxslt1-dev \
                tcpdump
            
            # WSL specific configurations
            echo -e "${YELLOW}[*] Configuring WSL-specific settings...${NC}"
            sudo setcap cap_net_raw+ep $(which python3)
            sudo setcap cap_net_raw+ep $(which nmap)
            sudo setcap cap_net_raw+ep $(which masscan)
            ;;

        "macos")
            echo -e "${YELLOW}[*] Installing dependencies for macOS...${NC}"
            brew update
            brew install \
                python3 \
                nmap \
                masscan \
                libpcap
            ;;

        *)
            echo -e "${RED}[!] Unsupported operating system${NC}"
            exit 1
            ;;
    esac
}

# Function to set up Python virtual environment
setup_python_env() {
    echo -e "\n${BLUE}[*] Setting up Python environment...${NC}"
    python3 -m venv .venv
    
    case $1 in
        "wsl"|"linux"|"macos")
            source .venv/bin/activate
            ;;
        *)
            echo -e "${RED}[!] Unsupported environment for Python virtual environment${NC}"
            exit 1
            ;;
    esac

    echo -e "${YELLOW}[*] Upgrading pip...${NC}"
    python3 -m pip install --upgrade pip

    echo -e "${YELLOW}[*] Installing Python dependencies...${NC}"
    if [ -f "requirements.txt" ]; then
        python3 -m pip install -r requirements.txt
    else
        echo -e "${RED}[!] requirements.txt not found${NC}"
        exit 1
    fi
}

# Function to set up project structure
setup_project_structure() {
    echo -e "\n${BLUE}[*] Setting up project structure...${NC}"
    
    # Create necessary directories
    mkdir -p ~/.netspecter/{scripts,fingerprints,plugins,reports,logs,data}
    mkdir -p ~/.netspecter/scripts/{vulnerability,enumeration,custom}
    mkdir -p ~/.netspecter/data/{services,os,exploits,vuln_db}

    # Copy default scripts and configurations
    if [ -d "./scripts" ]; then
        cp -r ./scripts/* ~/.netspecter/scripts/
    fi

    # Set permissions
    chmod -R 755 ~/.netspecter/scripts
    chmod +x netspecter.py

    # Create default configuration
    echo -e "${YELLOW}[*] Creating default configuration...${NC}"
    cat > ~/.netspecter/config.json << EOF
{
    "threads": 10,
    "timeout": 5,
    "default_ports": "1-1000",
    "scan_speed": "normal",
    "logging": {
        "level": "INFO",
        "file": "~/.netspecter/logs/netspecter.log"
    },
    "updates": {
        "auto_check": true,
        "check_interval": 86400
    }
}
EOF
}

# Function to perform final checks
perform_checks() {
    echo -e "\n${BLUE}[*] Performing final checks...${NC}"
    
    # Check Python installation
    python3 --version || {
        echo -e "${RED}[!] Python3 installation failed${NC}"
        exit 1
    }

    # Check Nmap installation
    nmap --version || {
        echo -e "${RED}[!] Nmap installation failed${NC}"
        exit 1
    }

    # Check Masscan installation
    masscan --version || {
        echo -e "${RED}[!] Masscan installation failed${NC}"
        exit 1
    }

    # Test Python virtual environment
    if [ -f ".venv/bin/python" ]; then
        echo -e "${GREEN}[✓] Python virtual environment setup successful${NC}"
    else
        echo -e "${RED}[!] Python virtual environment setup failed${NC}"
        exit 1
    fi
}

# Function to install Masscan
install_masscan() {
    echo -e "\n${BLUE}[*] Installing Masscan...${NC}"
    
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Create tools directory if it doesn't exist
    if [ ! -d "$INSTALL_DIR/tools" ]; then
        mkdir -p "$INSTALL_DIR/tools"
        chmod 755 "$INSTALL_DIR/tools"
        chown $SUDO_USER:$SUDO_USER "$INSTALL_DIR/tools"
    fi
    
    # Install dependencies
    apt-get install -y git libpcap-dev make gcc > /dev/null 2>&1 &
    show_progress $! "Installing Masscan dependencies"
    
    # Create temp directory for build
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Clone Masscan
    echo -e "${YELLOW}[*] Cloning Masscan repository...${NC}"
    git clone https://github.com/robertdavidgraham/masscan.git . > /dev/null 2>&1 &
    show_progress $! "Cloning Masscan"
    
    # Build Masscan
    echo -e "${YELLOW}[*] Building Masscan...${NC}"
    make -j$(nproc) > /dev/null 2>&1 &
    show_progress $! "Compiling Masscan"
    
    # Install Masscan
    if [ -f "bin/masscan" ]; then
        cp "bin/masscan" "$INSTALL_DIR/tools/" &
        show_progress $! "Installing Masscan binary"
        chmod +x "$INSTALL_DIR/tools/masscan"
        chown $SUDO_USER:$SUDO_USER "$INSTALL_DIR/tools/masscan"
    else
        echo -e "${RED}[✗] Masscan binary not found${NC}"
        cd - > /dev/null
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Cleanup
    cd - > /dev/null
    rm -rf "$temp_dir"
    
    # Verify installation
    if [ -x "$INSTALL_DIR/tools/masscan" ]; then
        echo -e "${GREEN}[✓] Masscan installed successfully${NC}"
        "$INSTALL_DIR/tools/masscan" --version
        return 0
    else
        echo -e "${RED}[✗] Masscan installation failed${NC}"
        return 1
    fi
}

# Update the uninstall function with a fixed prompt
uninstall_netspecter() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[!] Uninstallation requires sudo privileges${NC}"
        echo -e "${YELLOW}Usage: sudo ./install.sh -u${NC}"
        exit 1
    fi

    echo -e "\n${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}                   NetSpecter Uninstallation                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    echo -e "\n${RED}[!] This will remove:${NC}"
    echo -e "  ${YELLOW}• All NetSpecter files and directories in: $INSTALL_DIR${NC}"
    echo -e "  ${YELLOW}• Symbolic link in /usr/local/bin${NC}"
    echo -e "  ${YELLOW}• Python virtual environment${NC}"
    echo -e "  ${YELLOW}• All scan reports and configurations${NC}"
    
    # Fixed prompt without color codes in read
    echo -ne "\n${BLUE}[?] Are you sure you want to uninstall NetSpecter? (y/N): ${NC}"
    read confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo -e "\n${BLUE}[*] Starting uninstallation...${NC}"
        
        # Remove symbolic link
        if [ -L "/usr/local/bin/netspecter" ]; then
            rm -f "/usr/local/bin/netspecter"
            echo -e "${GREEN}[✓] Removed symbolic link${NC}"
        fi

        # Remove virtual environment
        if [ -d "$INSTALL_DIR/.venv" ]; then
            rm -rf "$INSTALL_DIR/.venv"
            echo -e "${GREEN}[✓] Removed virtual environment${NC}"
        fi

        # Remove all tool directories
        for dir in tools scripts reports logs config; do
            if [ -d "$INSTALL_DIR/$dir" ]; then
                rm -rf "$INSTALL_DIR/$dir"
                echo -e "${GREEN}[✓] Removed $dir directory${NC}"
            fi
        done

        echo -e "\n${GREEN}[✓] NetSpecter has been successfully uninstalled!${NC}"
        echo -e "${YELLOW}[*] You may now remove the NetSpecter directory manually if desired.${NC}"
    else
        echo -e "\n${YELLOW}[!] Uninstallation cancelled${NC}"
    fi
}

# Add to the main script, just before the main() function:
show_help() {
    echo -e "${CYAN}Usage:${NC}"
    echo -e "  sudo ./install.sh [option]"
    echo -e "\n${CYAN}Options:${NC}"
    echo -e "  -h, --help      Show this help message"
    echo -e "  -i, --install   Install NetSpecter (default)"
    echo -e "  -u, --uninstall Uninstall NetSpecter"
    echo -e "\n${YELLOW}Note: This script requires sudo privileges${NC}"
}

# Update the main part of the script
main() {
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -u|--uninstall)
            uninstall_netspecter
            exit 0
            ;;
        -i|--install|"")
            print_banner
            # Check for root privileges
            if [[ $EUID -eq 0 ]]; then
                echo -e "${RED}[!] Do not run this script as root${NC}"
                exit 1
            fi
            # Detect environment
            ENV=$(detect_environment)
            echo -e "${GREEN}[✓] Detected environment: $ENV${NC}"
            # Show installation configuration and get confirmation
            confirm_installation
            # Installation steps with progress indicators
            echo -e "\n${BLUE}[*] Starting NetSpecter installation...${NC}"
            # System dependencies
            echo -e "\n${BLUE}[*] Installing system dependencies...${NC}"
            install_system_dependencies $ENV &
            show_progress $!
            # RustScan installation
            echo -e "\n${BLUE}[*] Installing RustScan...${NC}"
            install_rustscan $ENV &
            show_progress $!
            # Python environment setup
            echo -e "\n${BLUE}[*] Setting up Python environment...${NC}"
            setup_python_env $ENV &
            show_progress $!
            # Project structure setup
            echo -e "\n${BLUE}[*] Setting up project structure...${NC}"
            setup_project_structure &
            show_progress $!
            # Final checks
            echo -e "\n${BLUE}[*] Performing final checks...${NC}"
            if ! perform_checks; then
                echo -e "${RED}[!] Installation failed during final checks${NC}"
                cleanup_incomplete_installation
                exit 1
            fi
            echo -e "\n${GREEN}[✓] Installation completed successfully!${NC}"
            # Show usage instructions
            echo -e "\n${YELLOW}Usage instructions:${NC}"
            echo -e "1. Activate the virtual environment:"
            echo -e "   ${CYAN}source .venv/bin/activate${NC}"
            echo -e "2. Run NetSpecter:"
            echo -e "   ${CYAN}./netspecter.py -h${NC}"
            # Show environment-specific notes
            case $ENV in
                "wsl")
                    echo -e "\n${YELLOW}WSL-specific notes:${NC}"
                    echo "1. Run with elevated privileges for network scanning"
                    echo "2. Some features may require additional WSL configuration"
                    ;;
                "linux")
                    echo -e "\n${YELLOW}Linux-specific notes:${NC}"
                    echo "1. Use sudo for privileged port scanning"
                    echo "2. Check firewall settings if scanning fails"
                    ;;
                "macos")
                    echo -e "\n${YELLOW}macOS-specific notes:${NC}"
                    echo "1. Some features may require System Preferences changes"
                    echo "2. Check Security & Privacy settings if scanning fails"
                    ;;
            esac
            echo -e "\n${BLUE}[*] You can press Ctrl+C at any time to cancel the installation${NC}"
            ;;
        *)
            echo -e "${RED}[!] Invalid option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Call main with all arguments
main "$@" 

# Add this function to verify paths configuration
verify_paths_config() {
    echo -e "\n${BLUE}[*] Verifying paths configuration...${NC}"
    
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    CONFIG_FILE="$INSTALL_DIR/config/paths.conf"
    
    # Check if config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}[✗] Configuration file not found: $CONFIG_FILE${NC}"
        return 1
    }
    
    # Display current configuration
    echo -e "\n${CYAN}Current Configuration:${NC}"
    echo -e "${YELLOW}----------------------------------------${NC}"
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ $line =~ ^#.*$ ]] || [[ -z $line ]] && continue
        
        # Extract key and value
        key=$(echo "$line" | cut -d'=' -f1)
        value=$(echo "$line" | cut -d'=' -f2-)
        
        # Verify if path exists
        if [[ $value == /* ]]; then  # Only check absolute paths
            if [ -e "$value" ]; then
                echo -e "${GREEN}[✓]${NC} $key = $value"
            else
                echo -e "${RED}[✗]${NC} $key = $value ${RED}(not found)${NC}"
            fi
        else
            echo -e "${BLUE}[*]${NC} $key = $value"
        fi
    done < "$CONFIG_FILE"
    echo -e "${YELLOW}----------------------------------------${NC}"
    
    # Verify permissions
    if [ -r "$CONFIG_FILE" ]; then
        echo -e "${GREEN}[✓] Configuration file is readable${NC}"
    else
        echo -e "${RED}[✗] Configuration file permissions error${NC}"
        return 1
    fi
    
    echo -e "\n${GREEN}[✓] Paths configuration verified${NC}"
    return 0
}

# Update the paths.conf creation in setup_tool_structure
setup_tool_structure() {
    echo -e "\n${BLUE}[*] Setting up tool structure...${NC}"
    
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Create all necessary directories
    DIRS=(
        "$INSTALL_DIR/tools"
        "$INSTALL_DIR/scripts"
        "$INSTALL_DIR/reports"
        "$INSTALL_DIR/logs"
        "$INSTALL_DIR/config"
        "$INSTALL_DIR/scripts/vulnerability"
        "$INSTALL_DIR/scripts/enumeration"
        "$INSTALL_DIR/scripts/custom"
    )
    
    for dir in "${DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            echo -e "${YELLOW}[*] Creating $dir${NC}"
            mkdir -p "$dir"
            chmod 755 "$dir"
            chown $SUDO_USER:$SUDO_USER "$dir"
        fi
    done
    
    echo -e "${GREEN}[✓] Directory structure created${NC}"
    return 0
}

# Update the fix_line_endings function
fix_line_endings() {
    echo -e "${BLUE}[*] Fixing script execution...${NC}"
    
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SCRIPT_PATH="$INSTALL_DIR/netspecter.py"
    
    # Create a new file with proper shebang and content
    cat > "$SCRIPT_PATH.tmp" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys

# Ensure we're running from the correct directory
if __name__ == '__main__':
    script_dir = os.path.dirname(os.path.realpath(__file__))
    os.chdir(script_dir)
    
    try:
        from netspecter.main import main
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nOperation cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nError: {str(e)}")
        sys.exit(1)
EOF

    # Copy the rest of the file (skipping the first line)
    tail -n +2 "$SCRIPT_PATH" | tr -d '\r' >> "$SCRIPT_PATH.tmp"
    mv "$SCRIPT_PATH.tmp" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    
    # Create proper symlink
    echo -e "${YELLOW}[*] Creating system-wide symlink...${NC}"
    sudo ln -sf "$SCRIPT_PATH" /usr/local/bin/netspecter
    sudo chmod +x /usr/local/bin/netspecter
    
    echo -e "${GREEN}[✓] Script execution fixed${NC}"
}

# Add a function to fix the banner display
fix_banner_display() {
    echo -e "${BLUE}[*] Updating banner display...${NC}"
    
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Create or update the banner configuration
    mkdir -p "$INSTALL_DIR/config"
    cat > "$INSTALL_DIR/config/banner.py" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from colorama import init, Fore, Style
import pyfiglet

def show_banner():
    init()  # Initialize colorama
    
    # Create figlet banner
    banner = pyfiglet.figlet_format("NetSpecter", font="slant")
    
    # Print colored banner
    print(f"{Fore.CYAN}{banner}{Style.RESET_ALL}")
    print(f"{Fore.YELLOW}Advanced Network Scanner{Style.RESET_ALL}")
    print(f"{Fore.BLUE}Version: 1.0.0{Style.RESET_ALL}")
    print("\n" + "="*60 + "\n")

if __name__ == "__main__":
    show_banner()
EOF

    # Update permissions
    chmod 644 "$INSTALL_DIR/config/banner.py"
    chown $SUDO_USER:$SUDO_USER "$INSTALL_DIR/config/banner.py"
    
    echo -e "${GREEN}[✓] Banner display updated${NC}"
}

# Add a function to verify the Python script
verify_python_script() {
    echo -e "${BLUE}[*] Verifying Python script...${NC}"
    
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SCRIPT_PATH="$INSTALL_DIR/netspecter.py"
    
    # Display first line for verification
    echo -e "${YELLOW}[*] Checking shebang line:${NC}"
    head -n1 "$SCRIPT_PATH" | xxd
    
    # Test script execution
    if ! python3 "$SCRIPT_PATH" --version > /dev/null 2>&1; then
        echo -e "${RED}[✗] Script verification failed${NC}"
        return 1
    fi
    
    echo -e "${GREEN}[✓] Python script verified${NC}"
    return 0
}

# Add function to create Python package structure
setup_python_package() {
    echo -e "${BLUE}[*] Setting up Python package structure...${NC}"
    
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Create package directories
    mkdir -p "$INSTALL_DIR/netspecter"
    
    # Create __init__.py
    cat > "$INSTALL_DIR/netspecter/__init__.py" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

__version__ = '1.0.0'
__author__ = 'Your Name'
__description__ = 'Advanced Network Scanner'
EOF

    # Create main.py
    cat > "$INSTALL_DIR/netspecter/main.py" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
from colorama import init, Fore, Style

def parse_arguments():
    parser = argparse.ArgumentParser(description='NetSpecter - Advanced Network Scanner')
    parser.add_argument('-t', '--target', help='Target IP address or hostname')
    parser.add_argument('-R', '--range', help='IP range to scan (e.g., 192.168.1.0/24)')
    parser.add_argument('-p', '--ports', help='Port range to scan (e.g., 80,443 or 1-1000)')
    parser.add_argument('-P', '--top-ports', help='Scan top N most common ports')
    parser.add_argument('-T', '--threads', type=int, default=10, help='Number of threads')
    parser.add_argument('-r', '--rate', type=int, help='Packet rate for scanning')
    parser.add_argument('-s', '--service', action='store_true', help='Detect service versions')
    parser.add_argument('-os', '--os-detect', action='store_true', help='Enable OS detection')
    parser.add_argument('-b', '--banner', action='store_true', help='Enable banner grabbing')
    parser.add_argument('-vuln', '--vulnerability', action='store_true', help='Check for vulnerabilities')
    parser.add_argument('-vs', '--vuln-script', help='Custom vulnerability script')
    parser.add_argument('-vc', '--vuln-category', help='Vulnerability category to scan')
    parser.add_argument('-sc', '--script', help='Custom Nmap script')
    parser.add_argument('-sc-list', '--script-list', action='store_true', help='List available scripts')
    parser.add_argument('-sc-add', '--sc-add', help='Add custom script')
    parser.add_argument('-sc-rm', '--sc-rm', help='Remove custom script')
    parser.add_argument('-o', '--output', help='Output file path')
    parser.add_argument('--format', choices=['txt', 'json', 'xml'], default='txt', help='Output format')
    parser.add_argument('-V', '--version', action='store_true', help='Show version')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose output')
    parser.add_argument('--update', choices=['all', 'scripts', 'fingerprints'], help='Update components')
    parser.add_argument('--config', nargs=2, metavar=('OPTION', 'VALUE'), help='Set configuration option')
    parser.add_argument('--speed', choices=['fast', 'balanced', 'careful'], default='balanced', help='Scan speed')
    
    return parser.parse_args()

def main():
    args = parse_arguments()
    
    if args.version:
        from netspecter import __version__
        print(f"NetSpecter version {__version__}")
        return 0
    
    # Add your main scanning logic here
    print(f"{Fore.YELLOW}[*] Starting scan...{Style.RESET_ALL}")
    
    return 0

if __name__ == '__main__':
    main()
EOF

    # Create scanner.py
    cat > "$INSTALL_DIR/netspecter/scanner.py" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

class Scanner:
    def __init__(self):
        pass
    
    def scan(self, target):
        pass
EOF

    # Set proper permissions
    chmod 644 "$INSTALL_DIR/netspecter/__init__.py"
    chmod 644 "$INSTALL_DIR/netspecter/main.py"
    chmod 644 "$INSTALL_DIR/netspecter/scanner.py"
    
    # Set ownership
    chown -R $SUDO_USER:$SUDO_USER "$INSTALL_DIR/netspecter"
    
    echo -e "${GREEN}[✓] Python package structure created${NC}"
}

# Add function to create setup.py
create_setup_py() {
    echo -e "${BLUE}[*] Creating setup.py...${NC}"
    
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    cat > "$INSTALL_DIR/setup.py" << 'EOF'
from setuptools import setup, find_packages

setup(
    name="netspecter",
    version="1.0.0",
    packages=find_packages(),
    install_requires=[
        'colorama',
        'pyfiglet',
        'argparse',
        'python-nmap',
        'scapy',
        'requests',
        'rich'
    ],
    entry_points={
        'console_scripts': [
            'netspecter=netspecter.main:main',
        ],
    },
)
EOF

    chmod 644 "$INSTALL_DIR/setup.py"
    chown $SUDO_USER:$SUDO_USER "$INSTALL_DIR/setup.py"
}

# Update the Python package installation
install_python_package() {
    echo -e "${BLUE}[*] Installing Python package...${NC}"
    
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "$INSTALL_DIR/.venv" ]; then
        python3 -m venv "$INSTALL_DIR/.venv"
    fi
    
    # Activate virtual environment
    source "$INSTALL_DIR/.venv/bin/activate"
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install the package in development mode
    pip install -e "$INSTALL_DIR"
    
    # Deactivate virtual environment
    deactivate
    
    echo -e "${GREEN}[✓] Python package installed${NC}"
}

# Update netspecter.py wrapper
update_wrapper_script() {
    echo -e "${BLUE}[*] Updating wrapper script...${NC}"
    
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    cat > "$INSTALL_DIR/netspecter.py" << EOF
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys

if __name__ == '__main__':
    # Activate virtual environment
    venv_path = os.path.join('${INSTALL_DIR}', '.venv')
    activate_script = os.path.join(venv_path, 'bin', 'activate_this.py')
    
    with open(activate_script) as file:
        exec(file.read(), dict(__file__=activate_script))
    
    try:
        from netspecter.main import main
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nOperation cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nError: {str(e)}")
        sys.exit(1)
EOF

    chmod +x "$INSTALL_DIR/netspecter.py"
    chown $SUDO_USER:$SUDO_USER "$INSTALL_DIR/netspecter.py"
} 