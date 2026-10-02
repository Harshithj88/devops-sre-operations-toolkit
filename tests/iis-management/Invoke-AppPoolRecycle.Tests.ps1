BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\..\automation\iis-management\Invoke-AppPoolRecycle.ps1'
}

Describe 'Invoke-AppPoolRecycle' {

    Context 'Parameter validation' {
        It 'Should require ComputerName parameter' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['ComputerName']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Mandatory | Should -Contain $true
        }

        It 'Should require AppPoolName parameter' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['AppPoolName']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Mandatory | Should -Contain $true
        }

        It 'Should expose a DrainTimeoutSeconds parameter' {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain 'DrainTimeoutSeconds'
        }

        It 'Should default DrainTimeoutSeconds to 30' {
            $cmd = Get-Command $scriptPath
            $ast = $cmd.ScriptBlock.Ast
            $params = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.ParameterAst] }, $true)
            $drainParam = $params | Where-Object { $_.Name.VariablePath.UserPath -eq 'DrainTimeoutSeconds' }
            $drainParam.DefaultValue.Extent.Text | Should -Be '30'
        }

        It 'Should support ShouldProcess (WhatIf/Confirm)' {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain 'WhatIf'
            $cmd.Parameters.Keys | Should -Contain 'Confirm'
        }
    }

    Context 'WhatIf behavior' {
        BeforeAll {
            Mock Invoke-Command { }
        }

        It 'Should not invoke remote recycle when -WhatIf is supplied' {
            & $scriptPath -ComputerName 'MOCK-01' -AppPoolName 'MyPool' -WhatIf
            Should -Invoke Invoke-Command -Times 0 -Scope It
        }
    }

    Context 'Recycle execution' {
        BeforeAll {
            Mock Invoke-Command { }
            Mock Start-Sleep { }
        }

        It 'Should invoke remote command once per server' {
            & $scriptPath -ComputerName 'MOCK-01', 'MOCK-02' -AppPoolName 'MyPool' -Confirm:$false
            Should -Invoke Invoke-Command -Times 2 -Scope It
        }

        It 'Should not throw when health URL verification fails' {
            Mock Invoke-WebRequest { throw 'connection refused' }
            { & $scriptPath -ComputerName 'MOCK-01' -AppPoolName 'MyPool' -HealthUrl 'https://MOCK-01/health' -Confirm:$false -WarningAction SilentlyContinue } |
                Should -Not -Throw
        }
    }

    Context 'Error handling' {
        It 'Should warn and continue when recycle fails' {
            Mock Invoke-Command { throw 'app pool not found' }
            { & $scriptPath -ComputerName 'BROKEN-01' -AppPoolName 'Missing' -Confirm:$false -WarningAction SilentlyContinue } |
                Should -Not -Throw
        }
    }
}
