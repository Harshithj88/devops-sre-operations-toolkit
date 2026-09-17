BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\..\automation\monitoring\Get-ServiceHealth.ps1'
}

Describe 'Get-ServiceHealth' {

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

        It 'Should have default ServiceName list' {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.ContainsKey('ServiceName') | Should -Be $true
        }

        It 'Should have IncludeDisabled switch' {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters['IncludeDisabled'].SwitchParameter | Should -Be $true
        }

        It 'Should have OutputJson parameter' {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.ContainsKey('OutputJson') | Should -Be $true
        }
    }

    Context 'Output structure' {
        BeforeAll {
            Mock Invoke-Command {
                [PSCustomObject]@{
                    Name        = 'W3SVC'
                    DisplayName = 'World Wide Web Publishing Service'
                    Status      = 'Running'
                    StartType   = 'Automatic'
                    ProcessId   = 1234
                }
            }
        }

        It 'Should return objects with Healthy property' {
            $result = & $scriptPath -ComputerName 'MOCK-01'
            $result | Should -Not -BeNullOrEmpty
            $result[0].PSObject.Properties.Name | Should -Contain 'Healthy'
            $result[0].PSObject.Properties.Name | Should -Contain 'ComputerName'
            $result[0].PSObject.Properties.Name | Should -Contain 'ServiceName'
        }

        It 'Should mark running services as healthy' {
            $result = & $scriptPath -ComputerName 'MOCK-01'
            $result[0].Healthy | Should -Be $true
        }
    }

    Context 'Error handling' {
        BeforeAll {
            Mock Invoke-Command { throw 'Connection failed' }
        }

        It 'Should return error entry when server is unreachable' {
            $result = & $scriptPath -ComputerName 'OFFLINE-01' -WarningAction SilentlyContinue
            $result | Should -Not -BeNullOrEmpty
            $result[0].Status | Should -Be 'Error'
            $result[0].Healthy | Should -Be $false
        }
    }
}
