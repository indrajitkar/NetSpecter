#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import asyncio
import json
import logging
import os
import sys
import xml.etree.ElementTree as ET
import traceback
import subprocess
import shlex
import platform
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional
from rich.console import Console
from rich.table import Table
from rich import print as rprint
from colorama import Fore, Back, Style, init
import nmap
from scapy.all import *
import pyfiglet
import textwrap
import re
import shutil

# Initialize colorama
init(autoreset=True)

class DependencyChecker:
    def __init__(self):
        self.required_tools = {
            'python3': 'Python 3.x',
            'pip3': 'Python package manager'
        }
        
        self.required_packages = {
            'colorama': 'Terminal color support',
            'rich': 'Rich text formatting',
        }
        
        self.install_script = Path('./install.sh')
        self.installation_complete_marker = Path('./tools/.installation_complete')

    def check_installation_status(self):
        """Check if the installation script has been run successfully"""
        if not self.installation_complete_marker.exists():
            print(f"\n{Fore.RED}[!] NetSpecter installation is not complete!{Style.RESET_ALL}")
            print(f"{Fore.YELLOW}[*] Please run the installation script first:{Style.RESET_ALL}")
            print(f"{Fore.CYAN}    ./install.sh -i{Style.RESET_ALL}")
            sys.exit(1)

    def check_python_packages(self):
        """Check if required Python packages are installed"""
        missing_packages = []
        for package in self.required_packages:
            try:
                __import__(package)
            except ImportError:
                missing_packages.append(package)
        
        if missing_packages:
            print(f"\n{Fore.RED}[!] Missing required Python packages:{Style.RESET_ALL}")
            for package in missing_packages:
                print(f"{Fore.YELLOW}    - {package}: {self.required_packages[package]}{Style.RESET_ALL}")
            print(f"\n{Fore.CYAN}[*] Install missing packages with:{Style.RESET_ALL}")
            print(f"    pip3 install {' '.join(missing_packages)}")
            sys.exit(1)

    def check_system_tools(self):
        """Check if required system tools are installed"""
        missing_tools = []
        for tool in self.required_tools:
            if not shutil.which(tool):
                missing_tools.append(tool)
        
        if missing_tools:
            print(f"\n{Fore.RED}[!] Missing required system tools:{Style.RESET_ALL}")
            for tool in missing_tools:
                print(f"{Fore.YELLOW}    - {tool}: {self.required_tools[tool]}{Style.RESET_ALL}")
            print(f"\n{Fore.CYAN}[*] Please install the missing tools before continuing.{Style.RESET_ALL}")
            sys.exit(1)

    def check_all(self):
        """Run all dependency checks"""
        print(f"\n{Fore.CYAN}[*] Checking NetSpecter dependencies...{Style.RESET_ALL}")
        
        # Check if installation is complete
        self.check_installation_status()
        
        # Check system tools
        self.check_system_tools()
        
        # Check Python packages
        self.check_python_packages()
        
        print(f"{Fore.GREEN}[✓] All dependencies are satisfied.{Style.RESET_ALL}\n")

class Banner:
    def __init__(self):
        self.console = Console()
        self.terminal_width = shutil.get_terminal_size().columns
        self.box_width = min(80, self.terminal_width - 2)

    def display(self):
        """Display the banner"""
        # Clear screen
        os.system('cls' if os.name == 'nt' else 'clear')
        
        # Banner text
        banner_text = f"""{Fore.CYAN}
███╗   ██╗███████╗████████╗███████╗██████╗ ███████╗ ██████╗████████╗███████╗██████╗ 
████╗  ██║██╔════╝╚══██╔══╝██╔════╝██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔════╝██╔══██╗
██╔██╗ ██║█████╗     ██║   ███████╗██████╔╝█████╗  ██║        ██║   █████╗  ██████╔╝
██║╚██╗██║██╔══╝     ██║   ╚════██║██╔═══╝ ██╔══╝  ██║        ██║   ██╔══╝  ██╔══██╗
██║ ╚████║███████╗   ██║   ███████║██║     ███████╗╚██████╗   ██║   ███████╗██║  ██║
╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚══════╝ ╚═════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
{Style.RESET_ALL}"""
        
        # Info box
        info_box = f"""
{Style.BRIGHT}🚀 NetSpecter - Advanced Network Scanner and Enumeration Tool

{Style.BRIGHT}🔷 Developer: Indrajit Karmakar
{Style.BRIGHT}🔷 GitHub: https://github.com/indrajitkar
{Style.BRIGHT}🔷 Version: 1.0.0
{Style.BRIGHT}🔷 OS: {platform.system()} - {platform.release()}
{Style.BRIGHT}🔷 Python: {platform.python_version()}
{Style.BRIGHT}🔷 Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}{Style.RESET_ALL}"""

        # Features
        features = f"""
{Fore.GREEN}[+] Features:{Style.RESET_ALL}
{Fore.CYAN}├─⚡ Ultra-fast port scanning{Style.RESET_ALL}
{Fore.CYAN}├─🔍 Advanced service detection{Style.RESET_ALL}
{Fore.CYAN}├─🌐 Mass network scanning{Style.RESET_ALL}
{Fore.CYAN}├─🛡️ Vulnerability assessment{Style.RESET_ALL}
{Fore.CYAN}├─🔧 Custom script support{Style.RESET_ALL}
{Fore.CYAN}├─🔄 Auto-update system{Style.RESET_ALL}
{Fore.CYAN}└─📊 Detailed reporting{Style.RESET_ALL}
"""

        print(banner_text)
        print(info_box)
        print(features)
        print("\n")

    def print_scan_start(self, target: str, scan_type: str):
        """Print scan start banner"""
        print(f"\n{Fore.GREEN}{'='*60}{Style.RESET_ALL}")
        print(f"{Fore.CYAN}[*] Starting {scan_type} Scan{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}[*] Target: {target}{Style.RESET_ALL}")
        print(f"{Fore.GREEN}{'='*60}{Style.RESET_ALL}\n")

    def print_scan_complete(self, duration: float):
        """Print scan completion banner"""
        print(f"\n{Fore.GREEN}{'='*60}{Style.RESET_ALL}")
        print(f"{Fore.GREEN}[✓] Scan Completed{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}[*] Duration: {duration:.2f} seconds{Style.RESET_ALL}")
        print(f"{Fore.GREEN}{'='*60}{Style.RESET_ALL}\n")

    def print_result_header(self, header: str):
        """Print result section header"""
        print(f"\n{Fore.CYAN}{'─'*60}{Style.RESET_ALL}")
        print(f"{Fore.GREEN}[+] {header}{Style.RESET_ALL}")
        print(f"{Fore.CYAN}{'─'*60}{Style.RESET_ALL}")

class NetSpecter:
    def __init__(self):
        self.version = "1.0.0"
        self.console = Console()
        self.terminal_width = shutil.get_terminal_size().columns
        self.box_width = min(80, self.terminal_width - 2)
        self.parser = self.setup_argument_parser()
        self.config_path = Path.home() / ".netspecter" / "config.json"
        self.scripts_path = Path.home() / ".netspecter" / "scripts"
        
        # Check requirements before proceeding
        self.check_requirements()
        
        self.logger = self._setup_logging()
        self.config = self._load_config()
        self.banner = Banner()
        self.scan_engine = AdvancedScanEngine(self.config)
        self.nm = nmap.PortScanner()  # Add nmap scanner
        self.dependency_checker = DependencyChecker()

    def setup_argument_parser(self):
        """Setup argument parser with all available options"""
        parser = argparse.ArgumentParser(
            description=f'{Fore.CYAN}NetSpecter - Advanced Network Scanner and Enumeration Tool{Style.RESET_ALL}',
            formatter_class=argparse.RawDescriptionHelpFormatter,
            add_help=True
        )
        
        # Fast Port Scanning
        port_group = parser.add_argument_group(f'{Fore.GREEN}Fast Port Scanning{Style.RESET_ALL}')
        port_group.add_argument('-t', '--target', help='Target IP or hostname')
        port_group.add_argument('-p', '--ports', help='Specific ports to scan (e.g., 80,443,22)')
        port_group.add_argument('-P', '--top-ports', type=int, help='Scan top N most common ports')
        port_group.add_argument('-r', '--speed', default='balanced', choices=['fast', 'balanced', 'careful'], help='Adjust scanning speed')
        port_group.add_argument('-T', '--threads', type=int, default=10, help='Set number of concurrent threads')
        
        # Service & OS Detection
        detection_group = parser.add_argument_group(f'{Fore.GREEN}Service & OS Detection{Style.RESET_ALL}')
        detection_group.add_argument('-s', '--service', action='store_true', help='Detect running services and versions')
        detection_group.add_argument('-os', '--os-detect', action='store_true', help='Identify operating system')
        detection_group.add_argument('-b', '--banner', action='store_true', help='Fetch service banners')
        detection_group.add_argument('-a', '--all', action='store_true', help='Perform full service and OS enumeration')
        
        # Mass Scanning
        mass_group = parser.add_argument_group(f'{Fore.GREEN}Mass Scanning{Style.RESET_ALL}')
        mass_group.add_argument('-R', '--range', help='IP range for mass scanning')
        
        # Vulnerability Scanning
        vuln_group = parser.add_argument_group(f'{Fore.GREEN}Vulnerability Scanning{Style.RESET_ALL}')
        vuln_group.add_argument('-vuln', '--vulnerability', action='store_true', help='Run all vulnerability checks')
        vuln_group.add_argument('-vs', '--vuln-script', help='Run a specific vulnerability script')
        vuln_group.add_argument('-vc', '--vuln-category', help='Run scripts by category (e.g., web, smb, ssl)')
        
        # Custom Scripting
        script_group = parser.add_argument_group(f'{Fore.GREEN}Custom Scripting{Style.RESET_ALL}')
        script_group.add_argument('-sc', '--script', nargs='+', 
                                help='Script operations (list, run <script>, add <file>, rm <script>)')
        
        # Output & Logging
        output_group = parser.add_argument_group(f'{Fore.GREEN}Output & Logging{Style.RESET_ALL}')
        output_group.add_argument('-o', '--output', help='Save output to file')
        output_group.add_argument('--format', default='txt', choices=['txt', 'json', 'xml'], help='Output format')
        output_group.add_argument('-V', '--verbose', action='store_true', help='Show detailed scan output')
        output_group.add_argument('--update', choices=['scripts', 'fingerprints', 'all'],
                                help='Update scripts, fingerprints, or all components')
        
        return parser

    def print_examples(self):
        """Print usage examples"""
        examples = f"""
{Fore.YELLOW}Examples:{Style.RESET_ALL}
  Fast Port Scanning:
    {Fore.CYAN}./netspecter.py -t 192.168.1.1{Style.RESET_ALL}
    {Fore.CYAN}./netspecter.py -t 192.168.1.1 -p 80,443,22{Style.RESET_ALL}
    {Fore.CYAN}./netspecter.py -t 192.168.1.1 -P 100{Style.RESET_ALL}
    
  Service & OS Detection:
    {Fore.CYAN}./netspecter.py -t 192.168.1.1 -s -os{Style.RESET_ALL}
    {Fore.CYAN}./netspecter.py -t 192.168.1.1 -a{Style.RESET_ALL}
    
  Mass Scanning:
    {Fore.CYAN}./netspecter.py -R 192.168.1.0/24{Style.RESET_ALL}
    {Fore.CYAN}./netspecter.py -R 192.168.1.0/24 -p 80,443 -o results.json{Style.RESET_ALL}
    
  Vulnerability Scanning:
    {Fore.CYAN}./netspecter.py -t 192.168.1.1 -vuln{Style.RESET_ALL}
    {Fore.CYAN}./netspecter.py -t 192.168.1.1 -vc web{Style.RESET_ALL}
    
  Custom Scripts:
    {Fore.CYAN}./netspecter.py -sc list{Style.RESET_ALL}
    {Fore.CYAN}./netspecter.py -sc run custom_script.py{Style.RESET_ALL}
"""
        print(examples)

    def parse_arguments(self):
        """Parse and validate command line arguments"""
        args = self.parser.parse_args()
        
        # Show examples if no arguments provided
        if len(sys.argv) == 1:
            self.banner.display()
            self.parser.print_help()
            self.print_examples()
            sys.exit(0)
            
        return args

    def _setup_logging(self) -> logging.Logger:
        logger = logging.getLogger("NetSpecter")
        logger.setLevel(logging.INFO)
        
        # Create console handler with custom formatting
        ch = logging.StreamHandler()
        formatter = logging.Formatter(
            f'{Fore.YELLOW}%(asctime)s {Fore.GREEN}[%(levelname)s] {Fore.CYAN}%(message)s{Style.RESET_ALL}'
        )
        ch.setFormatter(formatter)
        logger.addHandler(ch)
        
        return logger

    def _load_config(self) -> Dict:
        if not self.config_path.exists():
            default_config = {
                "threads": 10,
                "timeout": 5,
                "default_ports": "1-1000",
                "scan_speed": "balanced"
            }
            self.config_path.parent.mkdir(parents=True, exist_ok=True)
            with open(self.config_path, 'w') as f:
                json.dump(default_config, f, indent=4)
            return default_config
        
        with open(self.config_path) as f:
            return json.load(f)

    def _execute_script(self, script_path: Path, target: str) -> Dict:
        """Execute a vulnerability scanning script"""
        try:
            result = subprocess.run(
                ['python3', str(script_path), target],
                capture_output=True,
                text=True,
                timeout=30
            )
            return {
                'script': script_path.stem,
                'target': target,
                'output': result.stdout,
                'errors': result.stderr,
                'returncode': result.returncode
            }
        except subprocess.TimeoutExpired:
            return {'script': script_path.stem, 'error': 'Timeout'}
        except Exception as e:
            return {'script': script_path.stem, 'error': str(e)}

    def update_system(self, component: str = "all") -> bool:
        """Update system components"""
        if component in ["all", "scripts"]:
            self._update_scripts()
        if component in ["all", "fingerprints"]:
            self._update_fingerprints()
        if component == "all":
            self._update_core()
        return True

    def _update_scripts(self):
        """Update vulnerability scanning scripts"""
        self.logger.info("Updating vulnerability scripts...")

    def _update_fingerprints(self):
        """Update OS and service fingerprints"""
        self.logger.info("Updating OS and service fingerprints...")

    def _update_core(self):
        """Update core components"""
        self.logger.info("Updating core components...")

    def save_output(self, data: Dict, output_file: str, format: str = "txt"):
        """Save scan results to file"""
        output_path = Path(output_file)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        if format == "json":
            with open(output_file, 'w') as f:
                json.dump(data, f, indent=4)
        elif format == "xml":
            root = ET.Element("scan_results")
            self._dict_to_xml(data, root)
            tree = ET.ElementTree(root)
            tree.write(output_file)
        else:
            with open(output_file, 'w') as f:
                self._write_txt_output(data, f)
        
        self.logger.info(f"Results saved to {output_file}")

    def _dict_to_xml(self, data: Dict, parent: ET.Element):
        """Convert dictionary to XML format"""
        for key, value in data.items():
            child = ET.SubElement(parent, str(key))
            if isinstance(value, dict):
                self._dict_to_xml(value, child)
            else:
                child.text = str(value)

    def _write_txt_output(self, data: Dict, file):
        """Write scan results in text format"""
        for key, value in data.items():
            file.write(f"{key}: {value}\n")

    async def run(self, args):
        """Main execution method"""
        if not args.target and not args.range:
            self.logger.error(f"{Fore.RED}No target specified. Use -h for help.{Style.RESET_ALL}")
            return

        try:
            # Show scan start banner
            scan_type = "Network Range" if args.range else "Target"
            target = args.range if args.range else args.target
            self.banner.print_scan_start(target, scan_type)

            # Execute scan
            start_time = datetime.now()
            results = await self.scan_engine.smart_scan(
                target=target,
                ports=args.ports,
                speed=args.speed
            )

            # Additional scans if requested
            if args.os_detect or args.all:
                results['os'] = await self.scan_engine.os_detection(target)

            if args.vulnerability or args.all:
                results['vulnerabilities'] = await self.scan_engine.os_detection(target)

            # Show results
            if results:
                duration = (datetime.now() - start_time).total_seconds()
                self.banner.print_scan_complete(duration)
                self._display_results(results, args.format)
                
                # Save output if requested
                if args.output:
                    self.save_output(results, args.output, args.format)

        except KeyboardInterrupt:
            print(f"\n{Fore.RED}Scan interrupted by user{Style.RESET_ALL}")
            sys.exit(1)
        except Exception as e:
            self.logger.error(f"{Fore.RED}Error during scan: {str(e)}{Style.RESET_ALL}")
            if args.verbose:
                self.logger.error(traceback.format_exc())

    def _display_results(self, results: Dict, output_format: str):
        """Display scan results in the specified format"""
        if output_format == "json":
            print(json.dumps(results, indent=4))
            return

        # Create rich table for ports
        if 'open_ports' in results:
            self.banner.print_result_header("Open Ports")
            if results.get('open_ports'):
                for port in results['open_ports']:
                    print(f"{Fore.CYAN}Port {port}{Style.RESET_ALL}")
            else:
                print(f"{Fore.YELLOW}No open ports found{Style.RESET_ALL}")

        # Display other results
        if 'os' in results and results['os'].get('os_match'):
            self.banner.print_result_header("OS Detection")
            for os_match in results['os'].get('os_match', []):
                print(f"{Fore.CYAN}OS: {Fore.GREEN}{os_match['name']} {Fore.YELLOW}(Accuracy: {os_match.get('accuracy', 'N/A')}%){Style.RESET_ALL}")

        if 'vulnerabilities' in results and results['vulnerabilities']:
            self.banner.print_result_header("Vulnerabilities")
            for vuln in results['vulnerabilities']:
                print(f"{Fore.RED}• {vuln}{Style.RESET_ALL}")

    def check_requirements(self):
        """Check if all required tools and modules are installed"""
        missing_tools = []
        
        # Check for nmap
        try:
            subprocess.run(['nmap', '-V'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5)
        except (FileNotFoundError, subprocess.TimeoutExpired):
            missing_tools.append('nmap')

        # Check for Python modules
        required_modules = {
            'scapy': 'scapy',
            'python-nmap': 'nmap',
            'rich': 'rich',
            'colorama': 'colorama'
        }

        for module_name, import_name in required_modules.items():
            try:
                __import__(import_name)
            except ImportError:
                missing_tools.append(module_name)

        if missing_tools:
            print(f"\n{Fore.RED}[!] Missing required tools/modules:{Style.RESET_ALL}")
            for tool in missing_tools:
                print(f"{Fore.YELLOW}    • {tool}{Style.RESET_ALL}")
            
            print(f"\n{Fore.CYAN}[*] You can install the missing components by:{Style.RESET_ALL}")
            print(f"{Fore.GREEN}    1. Running: ./install.sh{Style.RESET_ALL}")
            print(f"{Fore.GREEN}    2. Or manually installing them using your package manager:{Style.RESET_ALL}")
            print(f"{Fore.YELLOW}       sudo apt install nmap{Style.RESET_ALL}")
            print(f"{Fore.YELLOW}       pip3 install -r requirements.txt{Style.RESET_ALL}")
            
            response = input(f"\n{Fore.BLUE}[?] Would you like to continue anyway? (y/n): {Style.RESET_ALL}")
            if response.lower() not in ['y', 'yes']:
                sys.exit(1)

        return True

class ScannerPaths:
    def __init__(self):
        self.config_dir = os.path.expanduser('~/.netspecter/config')
        self.paths = self._load_paths()
        
    def _load_paths(self) -> dict:
        """Load tool paths from configuration"""
        paths = {
            'rustscan': shutil.which('rustscan') or '/opt/netspecter/tools/rustscan',
            'nmap': shutil.which('nmap') or 'nmap',
            'masscan': shutil.which('masscan') or 'masscan'
        }
        
        # Load custom paths if configured
        path_config = os.path.join(self.config_dir, 'paths.conf')
        if os.path.exists(path_config):
            with open(path_config, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        if key.endswith('_PATH'):
                            tool_name = key.replace('_PATH', '').lower()
                            paths[tool_name] = value.strip()
        
        return paths

class AdvancedScanEngine:
    def __init__(self, config: Dict):
        self.config = config
        self.scanner_paths = ScannerPaths()
        self.logger = logging.getLogger("NetSpecter.ScanEngine")

    async def smart_scan(self, target: str, ports: Optional[str] = None, 
                        speed: str = "balanced") -> Dict:
        """
        Smart scanning that combines advantages of RustScan, Masscan, and Nmap
        
        Strategy:
        - Single host: Nmap
        - Multiple hosts: Nmap with threading
        """
        try:
            results = {
                'open_ports': [],
                'services': {},
                'scan_info': {
                    'start_time': datetime.now().isoformat()
                }
            }

            # Determine scan type based on target
            if self._is_ip_range(target):
                self.logger.info("Detected IP range, using mass scanning strategy")
                results.update(await self._nmap_fallback_scan(target, ports, speed))
            else:
                self.logger.info("Detected single host, using standard nmap")
                results.update(await self._nmap_fallback_scan(target, ports, speed))

            results['scan_info']['end_time'] = datetime.now().isoformat()
            return results

        except Exception as e:
            self.logger.error(f"Smart scan failed: {str(e)}")
            raise

    async def _nmap_fallback_scan(self, target: str, ports: Optional[str], 
                                 speed: str) -> Dict:
        """Fallback to Nmap for port scanning"""
        nmap_path = self.scanner_paths.paths['nmap']
        timing = {
            "fast": "-T4",
            "balanced": "-T3",
            "careful": "-T2"
        }.get(speed, "-T3")

        cmd = [
            nmap_path,
            timing,
            "-sV",
            "-p", ports if ports else "1-1000",
            target
        ]

        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=300)
            
            return self._parse_nmap_output(stdout.decode())
        except asyncio.TimeoutError:
            self.logger.error("Nmap scan timed out")
            return {'open_ports': [], 'services': {}}
        except Exception as e:
            self.logger.error(f"Nmap execution failed: {str(e)}")
            return {'open_ports': [], 'services': {}}

    def _is_ip_range(self, target: str) -> bool:
        """Check if target is an IP range or multiple hosts"""
        return any(x in target for x in ['/', ',', '-'])

    def _parse_nmap_output(self, output: str) -> Dict:
        """Parse Nmap output"""
        results = {
            'open_ports': [],
            'services': {},
            'vulnerabilities': []
        }
        
        for line in output.splitlines():
            # Parse open ports
            if '/tcp' in line or '/udp' in line:
                parts = line.split()
                if len(parts) >= 2 and 'open' in line:
                    try:
                        port = int(parts[0].split('/')[0])
                        service = parts[2] if len(parts) > 2 else 'unknown'
                        results['open_ports'].append(port)
                        results['services'][port] = {'state': 'open', 'service': service}
                    except (IndexError, ValueError):
                        continue
            
            # Parse vulnerabilities from scripts
            if '|_' in line or '|' in line:
                vuln_info = line.split('|_')[-1].strip() if '|_' in line else line.strip()
                if vuln_info and len(vuln_info) > 5:
                    results['vulnerabilities'].append(vuln_info)
                    
        return results

    async def os_detection(self, target: str) -> Dict:
        """Nmap OS detection"""
        try:
            nmap_path = self.scanner_paths.paths['nmap']
            cmd = [
                nmap_path,
                "-O",
                "-T4",
                "--osscan-guess",
                target
            ]
            
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=300)
            
            return self._parse_nmap_os_output(stdout.decode())
        except asyncio.TimeoutError:
            self.logger.error("OS detection timed out")
            return {'os_match': []}
        except Exception as e:
            self.logger.error(f"OS detection failed: {str(e)}")
            return {'os_match': []}

    def _parse_nmap_os_output(self, output: str) -> Dict:
        """Parse Nmap OS detection output"""
        os_info = {
            'os_match': []
        }
        
        for line in output.splitlines():
            if 'OS match:' in line or 'OS guessed' in line:
                parts = line.split()
                match_text = ' '.join(parts[2:]) if len(parts) > 2 else line
                accuracy = 0
                
                for part in parts:
                    if '%' in part:
                        try:
                            accuracy = int(part.replace('%', ''))
                            break
                        except ValueError:
                            pass
                
                if match_text:
                    os_info['os_match'].append({
                        'name': match_text,
                        'accuracy': accuracy
                    })
                
        return os_info

def main():
    try:
        # Display banner
        banner = Banner()
        banner.display()
        
        # Initialize scanner
        netspecter = NetSpecter()
        args = netspecter.parse_arguments()
        
        # Handle update command
        if args.update:
            netspecter.update_system(args.update)
            return
        
        # Run async scan
        asyncio.run(netspecter.run(args))
        
    except KeyboardInterrupt:
        print(f"\n{Fore.RED}[!] Operation cancelled by user{Style.RESET_ALL}")
        sys.exit(1)
    except Exception as e:
        print(f"\n{Fore.RED}[!] Error: {str(e)}{Style.RESET_ALL}")
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
