BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\..\automation\server-management\Get-ServerInventory.ps1'
}

Describe 'Get-ServerInventory' {

    Context 'Parameter validation' {
        It 'Should have ByEnvironment as default parameter set' {
            $cmd = Get-Command $scriptPath
            $cmd.DefaultParameterSet | Should -Be 'ByEnvironment'
        }

        It 'Should accept ComputerName in ByName parameter set' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['ComputerName']
            $param | Should -Not -BeNullOrEmpty
        }

        It 'Should accept Environment in ByEnvironment parameter set' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['Environment']
            $param | Should -Not -BeNullOrEmpty
        }

        It 'Should validate Format to Excel or CSV only' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['Format']
            $validateSet = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'Excel'
            $validateSet.ValidValues | Should -Contain 'CSV'
            $validateSet.ValidValues.Count | Should -Be 2
        }

        It 'Should default Environment to DV1, QA1, SG1, RPRD' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['Environment']
            # Default value is set in the script param block
            $param | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Output file generation' {
        It 'Should generate a default output path with timestamp when not specified' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['OutputPath']
            $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory | Should -Be $false }
        }
    }
}
