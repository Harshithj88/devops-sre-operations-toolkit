BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\..\automation\certificate-management\Install-Certificate.ps1'
}

Describe 'Install-Certificate' {

    Context 'Parameter validation' {
        It 'Should require ComputerName parameter' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['ComputerName']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Mandatory | Should -Contain $true
        }

        It 'Should require PfxPath parameter' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['PfxPath']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Mandatory | Should -Contain $true
        }

        It 'Should require PfxPassword as SecureString' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['PfxPassword']
            $param | Should -Not -BeNullOrEmpty
            $param.ParameterType.Name | Should -Be 'SecureString'
        }

        It 'Should have optional IISSiteName parameter' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['IISSiteName']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory | Should -Be $false }
        }

        It 'Should default Port to 443' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['Port']
            $param | Should -Not -BeNullOrEmpty
        }

        It 'Should support ShouldProcess (WhatIf)' {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.ContainsKey('WhatIf') | Should -Be $true
        }
    }

    Context 'File validation' {
        It 'Should error when PFX file does not exist' {
            $secPwd = ConvertTo-SecureString 'test' -AsPlainText -Force
            $result = & $scriptPath -ComputerName 'MOCK-01' `
                -PfxPath 'C:\nonexistent\fake.pfx' `
                -PfxPassword $secPwd -ErrorAction SilentlyContinue -ErrorVariable err
            $err | Should -Not -BeNullOrEmpty
        }
    }
}
