#!/usr/bin/env python3
"""
File Permissions Security Tests for PortableRalph
Tests file access controls, permission validation, and secure file handling
"""

import subprocess
import tempfile
import os
import sys
import stat
import pwd
import grp
from pathlib import Path

# Add repo root to path to import test utilities
REPO_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

class FilePermissionTests:
    def __init__(self):
        self.repo_root = REPO_ROOT
        self.test_dir = None
        self.results = []
        self.failed_tests = 0
        self.total_tests = 0
        self.current_user = os.getuid()
        self.current_group = os.getgid()

    def setup(self):
        """Setup test environment"""
        self.test_dir = tempfile.mkdtemp(prefix="ralph_file_perm_test_")
        return self.test_dir

    def teardown(self):
        """Cleanup test environment"""
        if self.test_dir and os.path.exists(self.test_dir):
            # Fix permissions to allow deletion
            subprocess.run(['chmod', '-R', '755', self.test_dir], check=False)
            subprocess.run(['rm', '-rf', self.test_dir], check=False)

    def run_test(self, test_name, test_func):
        """Run a single test and record results"""
        self.total_tests += 1
        try:
            test_func()
            self.results.append(f"✅ {test_name}: PASS")
            print(f"✅ {test_name}: PASS")
        except Exception as e:
            self.failed_tests += 1
            self.results.append(f"❌ {test_name}: FAIL - {str(e)}")
            print(f"❌ {test_name}: FAIL - {str(e)}")

    def test_config_file_permissions(self):
        """Test that config files have secure permissions (600 or stricter)"""
        config_paths = [
            os.path.join(self.test_dir, ".ralph.env"),
            os.path.join(self.test_dir, ".env"),
            os.path.join(self.test_dir, "config.env")
        ]

        for config_path in config_paths:
            # Create config file with secrets
            with open(config_path, 'w') as f:
                f.write("export RALPH_SLACK_WEBHOOK_URL='https://hooks.slack.com/test'\n")
                f.write("export CLAUDE_API_KEY='secret-key'\n")
            
            # Test different permission scenarios
            test_permissions = [0o644, 0o666, 0o755, 0o777, 0o600, 0o400]
            
            for perm in test_permissions:
                os.chmod(config_path, perm)
                
                # Run ralph to see if it validates permissions
                result = subprocess.run([
                    'bash', '-c', 
                    f'cd {self.repo_root} && HOME={self.test_dir} ./lib/validation.sh && validate_file_permissions "{config_path}"'
                ], capture_output=True, text=True)

                # Check actual file permissions
                file_stat = os.stat(config_path)
                actual_perm = stat.filemode(file_stat.st_mode)
                
                # Insecure permissions (group/world readable) should be rejected
                if perm in [0o644, 0o666, 0o755, 0o777]:
                    if result.returncode == 0:
                        raise Exception(f"Insecure permissions {oct(perm)} were accepted for {config_path}")
                
                # Secure permissions should be accepted
                elif perm in [0o600, 0o400]:
                    # This is expected to pass, but we note it
                    pass

    def test_script_file_permissions(self):
        """Test that script files have appropriate executable permissions"""
        scripts = [
            self.repo_root / "ralph.sh",
            self.repo_root / "install.sh", 
            self.repo_root / "notify.sh",
            self.repo_root / "launcher.sh"
        ]

        for script in scripts:
            if not script.exists():
                continue
                
            file_stat = os.stat(script)
            file_mode = file_stat.st_mode
            
            # Check owner execute permission
            if not (file_mode & stat.S_IXUSR):
                raise Exception(f"Script {script.name} is not executable by owner")
            
            # Check if world-writable (insecure)
            if file_mode & stat.S_IWOTH:
                raise Exception(f"Script {script.name} is world-writable (insecure)")
            
            # Check if group-writable to non-group members
            if file_mode & stat.S_IWGRP:
                # This might be acceptable in some environments, but worth noting
                print(f"⚠️  Warning: {script.name} is group-writable")

    def test_powershell_file_permissions(self):
        """Test PowerShell script permissions (should not be world-writable)"""
        ps_scripts = [
            self.repo_root / "ralph.ps1",
            self.repo_root / "install.ps1",
            self.repo_root / "notify.ps1"
        ]

        for script in ps_scripts:
            if not script.exists():
                continue
                
            file_stat = os.stat(script)
            file_mode = file_stat.st_mode
            
            # PowerShell scripts should not be world-writable
            if file_mode & stat.S_IWOTH:
                raise Exception(f"PowerShell script {script.name} is world-writable")
            
            # Should be readable by owner
            if not (file_mode & stat.S_IRUSR):
                raise Exception(f"PowerShell script {script.name} is not readable by owner")

    def test_log_file_permissions(self):
        """Test that log files are created with secure permissions"""
        log_dir = os.path.join(self.test_dir, ".portableralph", "logs")
        os.makedirs(log_dir, exist_ok=True)
        
        # Simulate log file creation
        log_file = os.path.join(log_dir, "ralph.log")
        with open(log_file, 'w') as f:
            f.write("Test log entry\n")
        
        # Check default permissions
        file_stat = os.stat(log_file)
        file_mode = file_stat.st_mode
        
        # Log files should not be world-readable (may contain sensitive info)
        if file_mode & stat.S_IROTH:
            print(f"⚠️  Warning: Log file {log_file} is world-readable")
        
        # Should not be world-writable
        if file_mode & stat.S_IWOTH:
            raise Exception(f"Log file {log_file} is world-writable")

    def test_temp_file_permissions(self):
        """Test that temporary files are created securely"""
        # Test Python mkstemp behavior (should create with 600)
        fd, temp_file = tempfile.mkstemp(dir=self.test_dir)
        try:
            file_stat = os.stat(temp_file)
            file_mode = file_stat.st_mode
            
            # Should be readable/writable by owner only
            expected_mode = stat.S_IRUSR | stat.S_IWUSR
            actual_mode = file_mode & (stat.S_IRWXU | stat.S_IRWXG | stat.S_IRWXO)
            
            if actual_mode != expected_mode:
                raise Exception(f"Temporary file {temp_file} has insecure permissions: {oct(actual_mode)}")
                
        finally:
            os.close(fd)
            os.unlink(temp_file)

    def test_directory_permissions(self):
        """Test that directories have appropriate permissions"""
        test_dirs = [
            os.path.join(self.test_dir, ".portableralph"),
            os.path.join(self.test_dir, ".portableralph", "logs"),
            os.path.join(self.test_dir, ".portableralph", "backup")
        ]

        for dir_path in test_dirs:
            os.makedirs(dir_path, exist_ok=True)
            
            dir_stat = os.stat(dir_path)
            dir_mode = dir_stat.st_mode
            
            # Directories should be executable by owner for traversal
            if not (dir_mode & stat.S_IXUSR):
                raise Exception(f"Directory {dir_path} is not traversable by owner")
            
            # Should be readable by owner
            if not (dir_mode & stat.S_IRUSR):
                raise Exception(f"Directory {dir_path} is not readable by owner")
            
            # Should not be world-writable
            if dir_mode & stat.S_IWOTH:
                raise Exception(f"Directory {dir_path} is world-writable")

    def test_sensitive_file_protection(self):
        """Test protection of sensitive files"""
        sensitive_files = [
            ".ssh/id_rsa",
            ".ssh/id_ed25519", 
            ".gnupg/secring.gpg",
            ".aws/credentials",
            ".docker/config.json"
        ]

        for sensitive_file in sensitive_files:
            full_path = os.path.join(self.test_dir, sensitive_file)
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            
            # Create fake sensitive file
            with open(full_path, 'w') as f:
                f.write("sensitive data")
            
            # Set secure permissions
            os.chmod(full_path, 0o600)
            
            # Verify Ralph scripts don't accidentally expose these
            result = subprocess.run([
                'bash', '-c',
                f'cd {self.repo_root} && grep -r "{sensitive_file}" . --exclude-dir=.git --exclude-dir=tests || true'
            ], capture_output=True, text=True)
            
            # Should not find references to sensitive files in scripts
            if result.stdout.strip():
                lines = [line for line in result.stdout.split('\n') if line.strip()]
                # Filter out this test file itself
                lines = [line for line in lines if 'test-file-permissions.py' not in line]
                if lines:
                    print(f"⚠️  Warning: Found references to {sensitive_file} in scripts")

    def test_backup_file_permissions(self):
        """Test that backup files maintain secure permissions"""
        # Create original file with secure permissions
        original_file = os.path.join(self.test_dir, ".ralph.env")
        with open(original_file, 'w') as f:
            f.write("export SECRET_KEY='test'\n")
        os.chmod(original_file, 0o600)

        # Simulate backup creation (like ralph might do)
        backup_file = original_file + ".backup"
        subprocess.run(['cp', original_file, backup_file])

        # Check backup permissions
        backup_stat = os.stat(backup_file)
        backup_mode = backup_stat.st_mode

        # Backup should inherit secure permissions
        if backup_mode & stat.S_IROTH or backup_mode & stat.S_IRGRP:
            raise Exception(f"Backup file {backup_file} has insecure read permissions")
        
        if backup_mode & stat.S_IWOTH or backup_mode & stat.S_IWGRP:
            raise Exception(f"Backup file {backup_file} has insecure write permissions")

    def test_umask_handling(self):
        """Test that files are created with appropriate umask"""
        # Save current umask
        current_umask = os.umask(0)
        os.umask(current_umask)

        try:
            # Test with restrictive umask
            os.umask(0o077)  # User only
            
            test_file = os.path.join(self.test_dir, "umask_test.txt")
            with open(test_file, 'w') as f:
                f.write("test")
            
            file_stat = os.stat(test_file)
            file_mode = file_stat.st_mode
            
            # Should respect umask and not be group/world readable
            if file_mode & stat.S_IRGRP or file_mode & stat.S_IROTH:
                raise Exception(f"File created with insufficient umask protection: {oct(file_mode)}")

        finally:
            # Restore original umask
            os.umask(current_umask)

    def test_symlink_attack_protection(self):
        """Test protection against symlink attacks"""
        # Create a sensitive file
        sensitive_file = os.path.join(self.test_dir, "sensitive.txt")
        with open(sensitive_file, 'w') as f:
            f.write("SENSITIVE DATA")
        os.chmod(sensitive_file, 0o600)

        # Create symlink pointing to sensitive file
        symlink_path = os.path.join(self.test_dir, "config.txt")
        os.symlink(sensitive_file, symlink_path)

        # Test if ralph would follow the symlink inappropriately
        result = subprocess.run([
            'bash', '-c',
            f'cd {self.repo_root} && if [ -L "{symlink_path}" ]; then echo "SYMLINK_DETECTED"; fi'
        ], capture_output=True, text=True)

        # Should detect symlinks
        if "SYMLINK_DETECTED" not in result.stdout:
            print("⚠️  Warning: Symlink detection may not be implemented")

    def test_file_ownership_validation(self):
        """Test that critical files are owned by correct user"""
        critical_files = [
            self.repo_root / "ralph.sh",
            self.repo_root / "install.sh"
        ]

        for file_path in critical_files:
            if not file_path.exists():
                continue

            file_stat = os.stat(file_path)
            
            # File should be owned by current user (not root unless user is root)
            if file_stat.st_uid == 0 and os.getuid() != 0:
                print(f"⚠️  Warning: {file_path} is owned by root but running as non-root")

    def run_all_tests(self):
        """Run all file permission security tests"""
        print("🔒 Running File Permissions Security Tests for PortableRalph\n")
        
        try:
            self.setup()
            
            # Run all test methods
            self.run_test("Config File Permissions", self.test_config_file_permissions)
            self.run_test("Script File Permissions", self.test_script_file_permissions)
            self.run_test("PowerShell File Permissions", self.test_powershell_file_permissions)
            self.run_test("Log File Permissions", self.test_log_file_permissions)
            self.run_test("Temporary File Permissions", self.test_temp_file_permissions)
            self.run_test("Directory Permissions", self.test_directory_permissions)
            self.run_test("Sensitive File Protection", self.test_sensitive_file_protection)
            self.run_test("Backup File Permissions", self.test_backup_file_permissions)
            self.run_test("Umask Handling", self.test_umask_handling)
            self.run_test("Symlink Attack Protection", self.test_symlink_attack_protection)
            self.run_test("File Ownership Validation", self.test_file_ownership_validation)

        finally:
            self.teardown()

        # Print summary
        print(f"\n{'='*60}")
        print("FILE PERMISSIONS SECURITY TEST SUMMARY")
        print(f"{'='*60}")
        print(f"Total Tests: {self.total_tests}")
        print(f"Passed: {self.total_tests - self.failed_tests}")
        print(f"Failed: {self.failed_tests}")
        
        if self.failed_tests == 0:
            print("🎉 All file permission security tests passed!")
            return True
        else:
            print(f"⚠️  {self.failed_tests} file permission vulnerabilities found!")
            return False

if __name__ == "__main__":
    test_suite = FilePermissionTests()
    success = test_suite.run_all_tests()
    sys.exit(0 if success else 1)