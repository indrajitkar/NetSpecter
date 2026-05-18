#!/usr/bin/env python3
"""
Security Validation Module for NetSpecter
Implements input validation and security checks
"""

import re
import ipaddress
from typing import Tuple, Optional
from pathlib import Path


class InputValidator:
    """Validates all user inputs for security vulnerabilities"""
    
    @staticmethod
    def validate_target(target: str) -> Tuple[bool, str]:
        """
        Validate target IP/hostname
        
        Args:
            target: Target IP address or hostname
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        target = target.strip()
        
        if not target:
            return False, "Target cannot be empty"
        
        if len(target) > 255:
            return False, "Target exceeds maximum length (255 characters)"
        
        # Try to parse as IP address or CIDR
        try:
            ipaddress.ip_address(target)
            return True, ""
        except ValueError:
            pass
        
        try:
            ipaddress.ip_network(target, strict=False)
            return True, ""
        except ValueError:
            pass
        
        # Validate as hostname
        if not re.match(r'^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z]{2,}$', target):
            return False, "Invalid IP address, CIDR range, or hostname format"
        
        return True, ""
    
    @staticmethod
    def validate_ports(ports: Optional[str]) -> Tuple[bool, str]:
        """
        Validate port specification
        
        Args:
            ports: Port specification (e.g., "80,443" or "1-1000")
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if not ports:
            return True, ""  # Empty is valid (use defaults)
        
        ports = ports.strip()
        
        # Check for suspicious characters
        if not re.match(r'^[\d,\-\s]+$', ports):
            return False, "Invalid characters in port specification"
        
        # Parse individual ports and ranges
        try:
            for part in ports.split(','):
                part = part.strip()
                if '-' in part:
                    start, end = part.split('-', 1)
                    start_port = int(start.strip())
                    end_port = int(end.strip())
                    
                    if not (1 <= start_port <= 65535):
                        return False, f"Port {start_port} out of range (1-65535)"
                    if not (1 <= end_port <= 65535):
                        return False, f"Port {end_port} out of range (1-65535)"
                    if start_port > end_port:
                        return False, f"Invalid port range: {start_port}-{end_port}"
                else:
                    port = int(part)
                    if not (1 <= port <= 65535):
                        return False, f"Port {port} out of range (1-65535)"
        except ValueError as e:
            return False, f"Invalid port specification: {str(e)}"
        
        return True, ""
    
    @staticmethod
    def validate_script_path(script_path: str) -> Tuple[bool, str]:
        """
        Validate script file path for security
        
        Args:
            script_path: Path to script file
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        script_path = script_path.strip()
        
        if not script_path:
            return False, "Script path cannot be empty"
        
        # Check for path traversal attempts
        if '..' in script_path or script_path.startswith('/etc/') or script_path.startswith('/'):
            return False, "Path traversal or absolute paths not allowed"
        
        # Verify path exists
        path_obj = Path(script_path)
        if not path_obj.exists():
            return False, f"Script file not found: {script_path}"
        
        if not path_obj.is_file():
            return False, f"Path is not a file: {script_path}"
        
        # Verify it's a Python script
        if not script_path.endswith('.py'):
            return False, "Only Python (.py) scripts are allowed"
        
        # Check file size (prevent massive files)
        if path_obj.stat().st_size > 10_000_000:  # 10MB limit
            return False, "Script file exceeds maximum size (10MB)"
        
        return True, ""
    
    @staticmethod
    def validate_output_path(output_path: str) -> Tuple[bool, str]:
        """
        Validate output file path for security
        
        Args:
            output_path: Path to output file
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        output_path = output_path.strip()
        
        if not output_path:
            return False, "Output path cannot be empty"
        
        # Check for path traversal
        if '..' in output_path:
            return False, "Path traversal attempts not allowed"
        
        # Don't allow absolute paths
        if output_path.startswith('/') or output_path.startswith('~'):
            return False, "Absolute paths not allowed for output files"
        
        # Validate filename
        if not re.match(r'^[a-zA-Z0-9_\-./]+\.(txt|json|xml)$', output_path):
            return False, "Invalid output filename or format"
        
        return True, ""
    
    @staticmethod
    def validate_speed(speed: str) -> Tuple[bool, str]:
        """
        Validate scan speed parameter
        
        Args:
            speed: Scan speed (fast, balanced, careful)
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        valid_speeds = ['fast', 'balanced', 'careful']
        
        if speed not in valid_speeds:
            return False, f"Invalid speed. Must be one of: {', '.join(valid_speeds)}"
        
        return True, ""
    
    @staticmethod
    def validate_threads(threads: Optional[int]) -> Tuple[bool, str]:
        """
        Validate thread count
        
        Args:
            threads: Number of threads
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if threads is None:
            return True, ""
        
        if not isinstance(threads, int):
            return False, "Threads must be an integer"
        
        if threads < 1 or threads > 1000:
            return False, "Threads must be between 1 and 1000"
        
        return True, ""


class ConfigValidator:
    """Validates configuration files"""
    
    ALLOWED_KEYS = {
        'threads': int,
        'timeout': int,
        'default_ports': str,
        'scan_speed': str
    }
    
    @staticmethod
    def validate_config(config: dict) -> Tuple[bool, str]:
        """
        Validate configuration dictionary
        
        Args:
            config: Configuration dictionary
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if not isinstance(config, dict):
            return False, "Config must be a dictionary"
        
        # Check for extra keys
        extra_keys = set(config.keys()) - set(ConfigValidator.ALLOWED_KEYS.keys())
        if extra_keys:
            return False, f"Unknown configuration keys: {', '.join(extra_keys)}"
        
        # Validate each key-value pair
        for key, expected_type in ConfigValidator.ALLOWED_KEYS.items():
            if key in config:
                value = config[key]
                
                if not isinstance(value, expected_type):
                    return False, f"Config key '{key}' must be {expected_type.__name__}, got {type(value).__name__}"
                
                # Type-specific validation
                if key == 'threads':
                    if not (1 <= value <= 1000):
                        return False, "threads must be between 1 and 1000"
                
                elif key == 'timeout':
                    if not (1 <= value <= 3600):
                        return False, "timeout must be between 1 and 3600 seconds"
                
                elif key == 'scan_speed':
                    if value not in ['fast', 'balanced', 'careful']:
                        return False, "scan_speed must be 'fast', 'balanced', or 'careful'"
        
        return True, ""


class PathValidator:
    """Validates file and directory paths for security"""
    
    @staticmethod
    def is_secure_path(path: str, allow_relative: bool = True) -> Tuple[bool, str]:
        """
        Check if a path is secure to use
        
        Args:
            path: File or directory path
            allow_relative: Whether to allow relative paths
            
        Returns:
            Tuple of (is_secure, error_message)
        """
        path = path.strip()
        
        if not path:
            return False, "Path cannot be empty"
        
        # Check for null bytes (common exploitation technique)
        if '\0' in path:
            return False, "Null bytes not allowed in paths"
        
        # Check for suspicious sequences
        if '..' in path:
            return False, "Path traversal attempts detected"
        
        # Check for common injection attempts
        if any(char in path for char in [';', '|', '&', '`', '$', '(', ')']):
            return False, "Special shell characters not allowed in paths"
        
        # Check if absolute path when not allowed
        if not allow_relative and (path.startswith('/') or path.startswith('~')):
            return False, "Absolute paths not allowed"
        
        # Verify directory permissions for parent
        try:
            parent = Path(path).parent
            if parent.exists():
                if not os.access(parent, os.W_OK):
                    return False, f"No write permission for parent directory: {parent}"
        except Exception as e:
            return False, f"Error checking path permissions: {str(e)}"
        
        return True, ""

    @staticmethod
    def is_writable_world_accessible(path: str) -> bool:
        """
        Check if a path is world-writable (security risk)
        
        Args:
            path: File or directory path
            
        Returns:
            True if world-writable, False otherwise
        """
        try:
            path_obj = Path(path)
            if path_obj.exists():
                stat_info = path_obj.stat()
                # Check if world-writable (0o002 permission)
                return bool(stat_info.st_mode & 0o002)
        except Exception:
            pass
        
        return False


# Add missing import
import os


if __name__ == "__main__":
    # Test cases
    print("Testing Input Validator...")
    
    # Test IP validation
    print(InputValidator.validate_target("192.168.1.1"))
    print(InputValidator.validate_target("192.168.1.0/24"))
    print(InputValidator.validate_target("google.com"))
    print(InputValidator.validate_target("'; DROP TABLE users;--"))
    
    # Test port validation
    print(InputValidator.validate_ports("80,443,22"))
    print(InputValidator.validate_ports("1-1000"))
    print(InputValidator.validate_ports("65536"))
    
    print("\nValidators ready!")
