# Monitoring

Scripts for proactive health monitoring of endpoints and Windows services.

## Scripts

| Script | Description |
|--------|-------------|
| `Test-EndpointHealth.ps1` | Tests HTTP(S) endpoint availability with retry logic, response time tracking, and optional JSON export. |
| `Get-ServiceHealth.ps1` | Checks Windows service status on remote servers. Reports healthy/unhealthy state with optional JSON output. |

## Usage

```powershell
# Check endpoint health with retries
.\Test-EndpointHealth.ps1 -Url "https://api.example.com/health","https://web.example.com" -RetryCount 3

# Check Windows services
.\Get-ServiceHealth.ps1 -ComputerName "APP-01","APP-02" -ServiceName "W3SVC","WAS" -OutputJson ".\services.json"
```
