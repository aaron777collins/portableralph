# compat-utils.ps1 - Windows compatibility wrappers for Unix commands
# Provides PowerShell equivalents for common Unix utilities
#
# Usage:
#   . .\lib\compat-utils.ps1
#   $winPath = Get-UnixStylePath "/home/user/file.txt"
#   Stop-ProcessByName "node"

# Get-UnixStylePath - Convert Unix-style paths to Windows paths
# Replaces forward slashes with backslashes and handles drive letters
# Args: $Path - Unix-style path (e.g., /c/Users/... or /home/...)
# Returns: Windows-style path (e.g., C:\Users\...)
function Get-UnixStylePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Path
    )

    process {
        if ([string]::IsNullOrEmpty($Path)) {
            return $Path
        }

        # Handle Git Bash style paths: /c/Users/... -> C:\Users\...
        if ($Path -match '^/([a-z])/(.*)$') {
            $driveLetter = $Matches[1].ToUpper()
            $restOfPath = $Matches[2]
            $windowsPath = "${driveLetter}:\$restOfPath"
            return $windowsPath.Replace('/', '\')
        }

        # Handle WSL paths: /mnt/c/Users/... -> C:\Users\...
        if ($Path -match '^/mnt/([a-z])/(.*)$') {
            $driveLetter = $Matches[1].ToUpper()
            $restOfPath = $Matches[2]
            $windowsPath = "${driveLetter}:\$restOfPath"
            return $windowsPath.Replace('/', '\')
        }

        # Handle standard Unix paths (no conversion)
        if ($Path -match '^/[^/]') {
            # This is a Unix absolute path, return as-is (may need manual mapping)
            return $Path.Replace('/', '\')
        }

        # Already a Windows path or relative path
        return $Path.Replace('/', '\')
    }
}

# Stop-ProcessByName - Stop processes by name or pattern
# Replaces: kill, pkill, killall
# Args: $Name - Process name or pattern
#       $Graceful - If true, try graceful shutdown first (default: $true)
#       $Timeout - Seconds to wait before force kill (default: 5)
# Returns: Number of processes stopped
function Stop-ProcessByName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [bool]$Graceful = $true,

        [Parameter(Mandatory=$false)]
        [int]$Timeout = 5
    )

    process {
        try {
            # Find matching processes
            $processes = Get-Process -Name $Name -ErrorAction SilentlyContinue

            if (-not $processes) {
                Write-Verbose "No processes found matching: $Name"
                return 0
            }

            $count = 0
            foreach ($proc in $processes) {
                try {
                    if ($Graceful) {
                        # Try graceful shutdown
                        Write-Verbose "Stopping process $($proc.Name) (PID: $($proc.Id)) gracefully..."
                        $proc.CloseMainWindow() | Out-Null

                        # Wait for process to exit
                        $waited = $proc.WaitForExit($Timeout * 1000)

                        if (-not $waited) {
                            # Force kill if still running
                            Write-Verbose "Force killing process $($proc.Name) (PID: $($proc.Id))..."
                            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                        }
                    } else {
                        # Force kill immediately
                        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                    }
                    $count++
                } catch {
                    Write-Warning "Failed to stop process $($proc.Name) (PID: $($proc.Id)): $_"
                }
            }

            return $count
        } catch {
            Write-Error "Failed to stop processes matching '$Name': $_"
            return 0
        }
    }
}

# Get-ProcessByName - Get processes by name or pattern
# Replaces: pgrep, ps aux | grep
# Args: $Name - Process name or pattern
#       $Full - If true, return full process objects (default: false, returns PIDs only)
# Returns: Array of PIDs or process objects
function Get-ProcessByName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [switch]$Full
    )

    process {
        try {
            $processes = Get-Process -Name $Name -ErrorAction SilentlyContinue

            if (-not $processes) {
                return @()
            }

            if ($Full) {
                return $processes
            } else {
                return $processes | Select-Object -ExpandProperty Id
            }
        } catch {
            Write-Verbose "No processes found matching: $Name"
            return @()
        }
    }
}

# Start-BackgroundProcess - Start a process in the background
# Replaces: nohup, &, disown
# Args: $Command - Command to run
#       $Arguments - Command arguments
#       $WorkingDirectory - Working directory (default: current)
#       $OutputFile - Redirect stdout to file (default: none)
#       $ErrorFile - Redirect stderr to file (default: same as OutputFile)
# Returns: Process object
function Start-BackgroundProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,

        [Parameter(Mandatory=$false)]
        [string[]]$Arguments = @(),

        [Parameter(Mandatory=$false)]
        [string]$WorkingDirectory = (Get-Location).Path,

        [Parameter(Mandatory=$false)]
        [string]$OutputFile = $null,

        [Parameter(Mandatory=$false)]
        [string]$ErrorFile = $null
    )

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Command
        $psi.Arguments = $Arguments -join ' '
        $psi.WorkingDirectory = $WorkingDirectory
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        # Configure output redirection
        if ($OutputFile) {
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
        }

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi

        # Start the process
        $null = $process.Start()

        # Handle output redirection
        if ($OutputFile) {
            $errorTarget = if ($ErrorFile) { $ErrorFile } else { $OutputFile }

            # Create background jobs to handle output
            Start-Job -ScriptBlock {
                param($proc, $outFile)
                while (-not $proc.StandardOutput.EndOfStream) {
                    $line = $proc.StandardOutput.ReadLine()
                    Add-Content -Path $outFile -Value $line -Encoding UTF8
                }
            } -ArgumentList $process, $OutputFile | Out-Null

            Start-Job -ScriptBlock {
                param($proc, $errFile)
                while (-not $proc.StandardError.EndOfStream) {
                    $line = $proc.StandardError.ReadLine()
                    Add-Content -Path $errFile -Value $line -Encoding UTF8
                }
            } -ArgumentList $process, $errorTarget | Out-Null
        }

        Write-Verbose "Started background process: $Command (PID: $($process.Id))"
        return $process
    } catch {
        Write-Error "Failed to start background process: $_"
        return $null
    }
}

# Search-FileContent - Search for patterns in file contents
# Replaces: grep
# Args: $Pattern - Regex pattern to search for
#       $Path - File or directory path
#       $Recurse - Search recursively (default: false)
#       $IgnoreCase - Case-insensitive search (default: false)
#       $LineNumbers - Show line numbers (default: false)
#       $FilesOnly - Only show file names (default: false)
#       $Context - Number of context lines to show (default: 0)
# Returns: Matching lines or file names
function Search-FileContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pattern,

        [Parameter(Mandatory=$false)]
        [string]$Path = ".",

        [Parameter(Mandatory=$false)]
        [switch]$Recurse,

        [Parameter(Mandatory=$false)]
        [switch]$IgnoreCase,

        [Parameter(Mandatory=$false)]
        [switch]$LineNumbers,

        [Parameter(Mandatory=$false)]
        [switch]$FilesOnly,

        [Parameter(Mandatory=$false)]
        [int]$Context = 0
    )

    try {
        $selectStringParams = @{
            Pattern = $Pattern
            Path = $Path
        }

        if ($Recurse) {
            # Get all files recursively
            $files = Get-ChildItem -Path $Path -File -Recurse -ErrorAction SilentlyContinue
            $selectStringParams['Path'] = $files.FullName
        }

        if ($IgnoreCase) {
            $selectStringParams['CaseSensitive'] = $false
        } else {
            $selectStringParams['CaseSensitive'] = $true
        }

        if ($Context -gt 0) {
            $selectStringParams['Context'] = $Context
        }

        $matches = Select-String @selectStringParams -ErrorAction SilentlyContinue

        if ($FilesOnly) {
            return $matches | Select-Object -ExpandProperty Path -Unique
        } elseif ($LineNumbers) {
            return $matches | ForEach-Object {
                "$($_.Path):$($_.LineNumber):$($_.Line)"
            }
        } else {
            return $matches | Select-Object -ExpandProperty Line
        }
    } catch {
        Write-Error "Failed to search file content: $_"
        return @()
    }
}

# Select-FilesByPattern - Find files by name pattern
# Replaces: find
# Args: $Path - Directory to search (default: current)
#       $Name - File name pattern (wildcards allowed)
#       $Type - File type: 'f' (file), 'd' (directory), 'l' (symlink)
#       $Recurse - Search recursively (default: false)
#       $MaxDepth - Maximum depth for recursive search (default: unlimited)
# Returns: Array of file paths
function Select-FilesByPattern {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Path = ".",

        [Parameter(Mandatory=$false)]
        [string]$Name = "*",

        [Parameter(Mandatory=$false)]
        [ValidateSet('f', 'd', 'l', 'a')]
        [string]$Type = 'a',

        [Parameter(Mandatory=$false)]
        [switch]$Recurse,

        [Parameter(Mandatory=$false)]
        [int]$MaxDepth = -1
    )

    try {
        $getChildItemParams = @{
            Path = $Path
            Filter = $Name
            ErrorAction = 'SilentlyContinue'
        }

        if ($Recurse) {
            if ($MaxDepth -gt 0) {
                $getChildItemParams['Depth'] = $MaxDepth
            }
            $getChildItemParams['Recurse'] = $true
        }

        $items = Get-ChildItem @getChildItemParams

        # Filter by type
        switch ($Type) {
            'f' {
                $items = $items | Where-Object { -not $_.PSIsContainer }
            }
            'd' {
                $items = $items | Where-Object { $_.PSIsContainer }
            }
            'l' {
                $items = $items | Where-Object { $_.LinkType -ne $null }
            }
            # 'a' returns all
        }

        return $items | Select-Object -ExpandProperty FullName
    } catch {
        Write-Error "Failed to find files: $_"
        return @()
    }
}

# Format-TextWithAwk - Process text with AWK-like functionality
# Replaces: awk
# Args: $InputObject - Input text or array of lines
#       $FieldSeparator - Field separator (default: whitespace)
#       $Fields - Array of field numbers to extract (1-based)
#       $ScriptBlock - Custom processing script block
# Returns: Processed text
function Format-TextWithAwk {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [object]$InputObject,

        [Parameter(Mandatory=$false)]
        [string]$FieldSeparator = '\s+',

        [Parameter(Mandatory=$false)]
        [int[]]$Fields = @(),

        [Parameter(Mandatory=$false)]
        [scriptblock]$ScriptBlock = $null
    )

    process {
        try {
            $lines = if ($InputObject -is [string]) {
                $InputObject -split "`n"
            } else {
                $InputObject
            }

            foreach ($line in $lines) {
                if ($ScriptBlock) {
                    # Execute custom script block with $_ as current line
                    $_ = $line
                    & $ScriptBlock
                } elseif ($Fields.Count -gt 0) {
                    # Extract specified fields
                    $parts = $line -split $FieldSeparator
                    $selected = foreach ($fieldNum in $Fields) {
                        if ($fieldNum -gt 0 -and $fieldNum -le $parts.Count) {
                            $parts[$fieldNum - 1]
                        }
                    }
                    $selected -join "`t"
                } else {
                    # Return line as-is
                    $line
                }
            }
        } catch {
            Write-Error "Failed to process text: $_"
        }
    }
}

# Set-FilePermission - Set file permissions using ACLs
# Replaces: chmod
# Args: $Path - File or directory path
#       $Owner - Set owner (username or SID)
#       $ReadOnly - Make file read-only
#       $Hidden - Make file hidden
#       $FullControl - Grant full control to user/group
#       $Modify - Grant modify permissions to user/group
#       $ReadExecute - Grant read & execute permissions to user/group
# Returns: $true if successful
function Set-FilePermission {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [string]$Owner = $null,

        [Parameter(Mandatory=$false)]
        [switch]$ReadOnly,

        [Parameter(Mandatory=$false)]
        [switch]$Hidden,

        [Parameter(Mandatory=$false)]
        [string]$FullControl = $null,

        [Parameter(Mandatory=$false)]
        [string]$Modify = $null,

        [Parameter(Mandatory=$false)]
        [string]$ReadExecute = $null
    )

    try {
        if (-not (Test-Path -Path $Path)) {
            Write-Error "Path does not exist: $Path"
            return $false
        }

        $item = Get-Item -Path $Path

        # Set file attributes
        if ($ReadOnly) {
            $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::ReadOnly
        }

        if ($Hidden) {
            $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden
        }

        # Set ACL permissions
        $acl = Get-Acl -Path $Path

        if ($Owner) {
            $acl.SetOwner([System.Security.Principal.NTAccount]::new($Owner))
        }

        # Add access rules
        if ($FullControl) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $FullControl, 'FullControl', 'Allow'
            )
            $acl.AddAccessRule($rule)
        }

        if ($Modify) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $Modify, 'Modify', 'Allow'
            )
            $acl.AddAccessRule($rule)
        }

        if ($ReadExecute) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $ReadExecute, 'ReadAndExecute', 'Allow'
            )
            $acl.AddAccessRule($rule)
        }

        # Apply ACL
        Set-Acl -Path $Path -AclObject $acl

        Write-Verbose "Set permissions on: $Path"
        return $true
    } catch {
        Write-Error "Failed to set permissions: $_"
        return $false
    }
}

# Get-FileStats - Get detailed file statistics
# Replaces: stat
# Args: $Path - File or directory path
#       $Format - Output format: 'object', 'table', 'list' (default: 'object')
# Returns: File statistics object
function Get-FileStats {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [ValidateSet('object', 'table', 'list')]
        [string]$Format = 'object'
    )

    process {
        try {
            if (-not (Test-Path -Path $Path)) {
                Write-Error "Path does not exist: $Path"
                return $null
            }

            $item = Get-Item -Path $Path
            $acl = Get-Acl -Path $Path

            $stats = [PSCustomObject]@{
                Path = $item.FullName
                Name = $item.Name
                Type = if ($item.PSIsContainer) { 'Directory' } else { 'File' }
                Size = if (-not $item.PSIsContainer) { $item.Length } else { 0 }
                SizeFormatted = if (-not $item.PSIsContainer) {
                    "{0:N2} KB" -f ($item.Length / 1KB)
                } else {
                    "N/A"
                }
                Created = $item.CreationTime
                Modified = $item.LastWriteTime
                Accessed = $item.LastAccessTime
                Attributes = $item.Attributes -join ', '
                Owner = $acl.Owner
                IsReadOnly = ($item.Attributes -band [System.IO.FileAttributes]::ReadOnly) -ne 0
                IsHidden = ($item.Attributes -band [System.IO.FileAttributes]::Hidden) -ne 0
                IsSystem = ($item.Attributes -band [System.IO.FileAttributes]::System) -ne 0
            }

            switch ($Format) {
                'table' {
                    return $stats | Format-Table -AutoSize
                }
                'list' {
                    return $stats | Format-List
                }
                default {
                    return $stats
                }
            }
        } catch {
            Write-Error "Failed to get file stats: $_"
            return $null
        }
    }
}

# Count-Lines - Count lines, words, and characters in files
# Replaces: wc
# Args: $Path - File path or array of paths
#       $Lines - Count lines only (default: false)
#       $Words - Count words only (default: false)
#       $Chars - Count characters only (default: false)
#       $Bytes - Count bytes only (default: false)
# Returns: Count object or formatted string
function Count-Lines {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]]$Path,

        [Parameter(Mandatory=$false)]
        [switch]$Lines,

        [Parameter(Mandatory=$false)]
        [switch]$Words,

        [Parameter(Mandatory=$false)]
        [switch]$Chars,

        [Parameter(Mandatory=$false)]
        [switch]$Bytes
    )

    process {
        foreach ($filePath in $Path) {
            try {
                if (-not (Test-Path -Path $filePath)) {
                    Write-Error "File does not exist: $filePath"
                    continue
                }

                $content = Get-Content -Path $filePath -Raw
                $item = Get-Item -Path $filePath

                $lineCount = ($content -split "`n").Count
                $wordCount = ($content -split '\s+' | Where-Object { $_ }).Count
                $charCount = $content.Length
                $byteCount = $item.Length

                # Return specific count if requested
                if ($Lines) {
                    return $lineCount
                } elseif ($Words) {
                    return $wordCount
                } elseif ($Chars) {
                    return $charCount
                } elseif ($Bytes) {
                    return $byteCount
                } else {
                    # Return all counts
                    return [PSCustomObject]@{
                        File = $filePath
                        Lines = $lineCount
                        Words = $wordCount
                        Characters = $charCount
                        Bytes = $byteCount
                    }
                }
            } catch {
                Write-Error "Failed to count file content: $_"
            }
        }
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Get-UnixStylePath',
    'Stop-ProcessByName',
    'Get-ProcessByName',
    'Start-BackgroundProcess',
    'Search-FileContent',
    'Select-FilesByPattern',
    'Format-TextWithAwk',
    'Set-FilePermission',
    'Get-FileStats',
    'Count-Lines'
)
