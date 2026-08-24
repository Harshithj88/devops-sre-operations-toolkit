BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\..\automation\server-management\Test-ServerHealth.ps1'
}

Describe 'Test-ServerHealth' {

    Context 'Parameter validation' {
        It 'Should require ComputerName parameter' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['ComputerName']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Mandatory | Should -Contain $true
        }

        It 'Should accept pipeline input for ComputerName' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['ComputerName']
            $param.Attributes.ValueFromPipeline | Should -Contain $true
        }

        It 'Should have default disk warning threshold of 80' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['DiskWarningThresholdPercent']
            $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                Should -Not -BeNullOrEmpty
        }

        It 'Should have default disk critical threshold of 90' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['DiskCriticalThresholdPercent']
            $param | Should -Not -BeNullOrEmpty
        }

        It 'Should have default cert expiry days of 30' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['CertExpiryDays']
            $param | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Output structure' {
        BeforeAll {
            # Mock all remote calls to simulate a healthy server
            Mock Test-Connection { $true }
            Mock Get-CimInstance {
                [PSCustomObject]@{
                    LastBootUpTime = (Get-Date).AddDays(-5)
                    Size           = 500GB
                    FreeSpace      = 300GB
                    DeviceID       = 'C:'
                    DriveType      = 3
                }
            }
            Mock Invoke-Command {
                param($ComputerName, $ScriptBlock)
                if ($ScriptBlock.ToString() -match 'Get-ChildItem Cert') {
                    return $null  # No expiring certs
                }
                return 'Running'  # IIS status
            }
        }

        It 'Should return objects with expected properties' {
            $result = & $scriptPath -ComputerName 'MOCK-01'
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'ComputerName'
            $result.PSObject.Properties.Name | Should -Contain 'OverallStatus'
            $result.PSObject.Properties.Name | Should -Contain 'Uptime'
            $result.PSObject.Properties.Name | Should -Contain 'DiskStatus'
            $result.PSObject.Properties.Name | Should -Contain 'CertStatus'
            $result.PSObject.Properties.Name | Should -Contain 'IISStatus'
            $result.PSObject.Properties.Name | Should -Contain 'CheckedAt'
        }

        It 'Should mark unreachable servers correctly' {
            Mock Test-Connection { $false }

            $result = & $scriptPath -ComputerName 'OFFLINE-01'
            $result.OverallStatus | Should -Be 'Unreachable'
            $result.Reachable | Should -Be $false
        }
    }
}
