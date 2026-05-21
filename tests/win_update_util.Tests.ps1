# win_update_util.Tests.ps1
# Pester tests for win_update_util.ps1
#
# Requirements:
#   Pester (v5.x recommended, pre-installed on modern Windows 10/11)
#
# Run tests on Windows/macOS/Linux using:
#   Invoke-Pester .\tests\win_update_util.Tests.ps1

Describe "win_update_util.ps1 - Script CLI & Utility Tests" {
    BeforeAll {
        $ScriptPath = Resolve-Path "$PSScriptRoot\..\win_update_util.ps1"
        $PsExe = (Get-Process -Id $PID).Path

        # Define placeholders in the global scope of this test run session
        # so that Pester's mocking engine can locate and mock them in child contexts.
        New-Item -Path "function:global:Send-Notification" -Value { param($Message) } -Force | Out-Null
        New-Item -Path "function:global:Confirm-Action" -Value { param($Prompt) } -Force | Out-Null
    }

    Context "Script Version & Help Parameters" {
        It "Should display the correct version info via subshell to prevent process exit" {
            # Redirect all streams (*>&1) to capture Write-Host outputs in the result
            $result = & $PsExe -NoProfile -Command "& '$ScriptPath' -Version" *>&1
            ($result -join "`n") | Should -Match "System Update Utility \(Windows\) v2\.6"
        }

        It "Should display the help menu correctly via subshell" {
            # Redirect all streams (*>&1) to capture Write-Host outputs in the result
            $result = & $PsExe -NoProfile -Command "& '$ScriptPath' -Help" *>&1
            ($result -join "`n") | Should -Match "Usage: .\\win_update_util.ps1"
            ($result -join "`n") | Should -Match "A premium system update utility for Windows."
        }
    }

    Context "Low Storage Warning Alerts" {
        It "Should display a prominent red warning banner if system partition has < 10 GB free space" {
            # Mock Get-PSDrive to accept the parameters passed in the script
            Mock Get-PSDrive {
                [PSCustomObject]@{
                    Name = 'C'
                    Free = 5 * 1GB # 5 GB
                }
            }

            # Mock other dependent commands to prevent actual execution side-effects
            Mock Get-Command {
                return $false
            }
            Mock Send-Notification {}
            
            # Setup environment variable
            $env:SystemDrive = "C:"

            # Capture console output using dynamic parameter bindings
            $warnings = [System.Collections.Generic.List[string]]::new()
            Mock Write-Host {
                if ($Object) { $warnings.Add($Object) }
            }

            # Execute the script in dry-run/yes mode
            . $ScriptPath -Yes -DryRun

            # Assertions
            ($warnings -join "`n") | Should -Match "WARNING: Low Disk Space!"
            ($warnings -join "`n") | Should -Match "experience severe slowdowns"
        }

        It "Should NOT display any warning banner if system partition has >= 10 GB free space" {
            Mock Get-PSDrive {
                [PSCustomObject]@{
                    Name = 'C'
                    Free = 25 * 1GB # 25 GB
                }
            }

            Mock Get-Command {
                return $false
            }
            Mock Send-Notification {}
            $env:SystemDrive = "C:"

            $warnings = [System.Collections.Generic.List[string]]::new()
            Mock Write-Host {
                if ($Object) { $warnings.Add($Object) }
            }

            . $ScriptPath -Yes -DryRun

            # Assert warning was not printed
            ($warnings -join "`n") | Should -Not -Match "WARNING: Low Disk Space!"
        }
    }

    Context "Interactive Component Prompts & Dry-Run Flow" {
        It "Should skip winget upgrades if winget is not installed" {
            Mock Get-Command {
                if ($Name -eq 'winget') { return $false }
                return $false
            }
            Mock Get-PSDrive {
                [PSCustomObject]@{ Name = 'C'; Free = 50 * 1GB }
            }
            Mock Send-Notification {}

            $outputs = [System.Collections.Generic.List[string]]::new()
            Mock Write-Host {
                if ($Object) { $outputs.Add($Object) }
            }

            . $ScriptPath -Yes -DryRun

            ($outputs -join "`n") | Should -Match "Winget not found. Skipping package updates"
        }

        It "Should notify dry-run cleanup paths correctly for temp files without deleting actual files" {
            Mock Get-PSDrive {
                [PSCustomObject]@{ Name = 'C'; Free = 50 * 1GB }
            }
            Mock Get-Command {
                return $false
            }
            Mock Confirm-Action { return $true } # Force yes to temporary folder prompts
            Mock Send-Notification {}

            # Keep env variables safe
            $env:TEMP = "C:\MockTemp"
            $env:SystemRoot = "C:\Windows"

            $outputs = [System.Collections.Generic.List[string]]::new()
            Mock Write-Host {
                if ($Object) { $outputs.Add($Object) }
            }

            . $ScriptPath -Yes -DryRun

            ($outputs -join "`n") | Should -Match "Would clear folder: C:\\MockTemp"
            ($outputs -join "`n") | Should -Match "Would clear folder: C:\\Windows\\Temp"
        }
    }
}
