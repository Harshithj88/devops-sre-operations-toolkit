BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\..\automation\certificate-management\Get-ExpiringCertificates.ps1'
}

Describe 'Get-ExpiringCertificates' {

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

        It 'Should have default DaysUntilExpiry of 30' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['DaysUntilExpiry']
            $param | Should -Not -BeNullOrEmpty
        }

        It 'Should have an IncludeExpired switch parameter' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['IncludeExpired']
            $param.SwitchParameter | Should -Be $true
        }
    }

    Context 'Output structure' {
        BeforeAll {
            Mock Invoke-Command {
                [PSCustomObject]@{
                    Subject       = 'CN=*.example.com'
                    Issuer        = 'CN=Internal CA'
                    Thumbprint    = 'AABBCCDD1234567890'
                    NotBefore     = (Get-Date).AddYears(-1)
                    NotAfter      = (Get-Date).AddDays(10)
                    DaysRemaining = 10
                }
            }
        }

        It 'Should return objects with expected properties' {
            $result = & $scriptPath -ComputerName 'MOCK-01'
            $result | Should -Not -BeNullOrEmpty
            $result[0].PSObject.Properties.Name | Should -Contain 'ComputerName'
            $result[0].PSObject.Properties.Name | Should -Contain 'Subject'
            $result[0].PSObject.Properties.Name | Should -Contain 'Thumbprint'
            $result[0].PSObject.Properties.Name | Should -Contain 'DaysRemaining'
            $result[0].PSObject.Properties.Name | Should -Contain 'Status'
        }

        It 'Should classify certificates expiring within 7 days as Critical' {
            Mock Invoke-Command {
                [PSCustomObject]@{
                    Subject       = 'CN=*.example.com'
                    Issuer        = 'CN=Internal CA'
                    Thumbprint    = 'AABBCCDD1234567890'
                    NotBefore     = (Get-Date).AddYears(-1)
                    NotAfter      = (Get-Date).AddDays(5)
                    DaysRemaining = 5
                }
            }

            $result = & $scriptPath -ComputerName 'MOCK-01'
            $result[0].Status | Should -Be 'Critical'
        }

        It 'Should classify already-expired certificates as Expired' {
            Mock Invoke-Command {
                [PSCustomObject]@{
                    Subject       = 'CN=*.example.com'
                    Issuer        = 'CN=Internal CA'
                    Thumbprint    = 'AABBCCDD1234567890'
                    NotBefore     = (Get-Date).AddYears(-2)
                    NotAfter      = (Get-Date).AddDays(-3)
                    DaysRemaining = -3
                }
            }

            $result = & $scriptPath -ComputerName 'MOCK-01' -IncludeExpired
            $result[0].Status | Should -Be 'Expired'
        }
    }

    Context 'No expiring certificates' {
        BeforeAll {
            Mock Invoke-Command { return $null }
        }

        It 'Should return empty results when no certificates are expiring' {
            $result = & $scriptPath -ComputerName 'MOCK-01'
            $result | Should -BeNullOrEmpty
        }
    }
}
