BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\..\automation\iis-management\Get-AppPoolStatus.ps1'
}

Describe 'Get-AppPoolStatus' {

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

        It 'Should accept an AppPoolName filter' {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain 'AppPoolName'
        }

        It 'Should default AppPoolName to wildcard' {
            $cmd = Get-Command $scriptPath
            $ast = $cmd.ScriptBlock.Ast
            $defaults = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.ParameterAst] }, $true)
            $appPoolParam = $defaults | Where-Object { $_.Name.VariablePath.UserPath -eq 'AppPoolName' }
            $appPoolParam.DefaultValue.Extent.Text | Should -Match "\*"
        }
    }

    Context 'Output structure' {
        BeforeAll {
            Mock Invoke-Command {
                @(
                    [PSCustomObject]@{
                        Name           = 'MyAppPool'
                        State          = 'Started'
                        ManagedRuntime = 'v4.0'
                        StartMode      = 'OnDemand'
                        PipelineMode   = 'Integrated'
                        ProcessId      = '1234'
                        AutoStart      = $true
                    },
                    [PSCustomObject]@{
                        Name           = 'StoppedPool'
                        State          = 'Stopped'
                        ManagedRuntime = 'v4.0'
                        StartMode      = 'OnDemand'
                        PipelineMode   = 'Integrated'
                        ProcessId      = ''
                        AutoStart      = $true
                    }
                )
            }
        }

        It 'Should return objects with expected properties' {
            $result = & $scriptPath -ComputerName 'MOCK-01'
            $result | Should -Not -BeNullOrEmpty
            $result[0].PSObject.Properties.Name | Should -Contain 'ComputerName'
            $result[0].PSObject.Properties.Name | Should -Contain 'AppPoolName'
            $result[0].PSObject.Properties.Name | Should -Contain 'State'
            $result[0].PSObject.Properties.Name | Should -Contain 'ManagedRuntime'
            $result[0].PSObject.Properties.Name | Should -Contain 'ProcessId'
        }

        It 'Should tag results with the queried computer name' {
            $result = & $scriptPath -ComputerName 'MOCK-01'
            $result.ComputerName | Should -Contain 'MOCK-01'
        }

        It 'Should return one entry per app pool' {
            $result = & $scriptPath -ComputerName 'MOCK-01'
            $result.Count | Should -Be 2
        }
    }

    Context 'Error handling' {
        It 'Should warn and continue when a server query fails' {
            Mock Invoke-Command { throw 'WinRM failure' }
            { & $scriptPath -ComputerName 'BROKEN-01' -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }
}
