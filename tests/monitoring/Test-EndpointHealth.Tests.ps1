BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\..\automation\monitoring\Test-EndpointHealth.ps1'
}

Describe 'Test-EndpointHealth' {

    Context 'Parameter validation' {
        It 'Should require Url parameter' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['Url']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Mandatory | Should -Contain $true
        }

        It 'Should accept multiple URLs' {
            $cmd = Get-Command $scriptPath
            $param = $cmd.Parameters['Url']
            $param.ParameterType.Name | Should -Be 'String[]'
        }

        It 'Should have RetryCount parameter with default' {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.ContainsKey('RetryCount') | Should -Be $true
        }

        It 'Should have OutputJson parameter' {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.ContainsKey('OutputJson') | Should -Be $true
        }
    }

    Context 'Endpoint checking' {
        BeforeAll {
            Mock Invoke-WebRequest {
                [PSCustomObject]@{
                    StatusCode = 200
                }
            }
        }

        It 'Should return results for each URL' {
            $result = & $scriptPath -Url 'https://example.com','https://test.com'
            $result.Count | Should -Be 2
        }

        It 'Should include expected properties in output' {
            $result = & $scriptPath -Url 'https://example.com'
            $result[0].PSObject.Properties.Name | Should -Contain 'Url'
            $result[0].PSObject.Properties.Name | Should -Contain 'StatusCode'
            $result[0].PSObject.Properties.Name | Should -Contain 'ResponseTimeMs'
        }
    }
}
