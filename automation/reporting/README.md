# Reporting

Scripts for generating operational reports from Azure DevOps and infrastructure data.

## Scripts

| Script | Description |
|--------|-------------|
| `Export-PipelineRunReport.ps1` | Queries Azure DevOps pipeline runs and exports build analytics (status, duration, success rate) to CSV or JSON. |

## Usage

```powershell
# Export last 30 days of pipeline runs
.\Export-PipelineRunReport.ps1 -Organization "myorg" -Project "myproject"

# Export specific pipeline to JSON
.\Export-PipelineRunReport.ps1 -Organization "myorg" -Project "myproject" -PipelineId 42 -OutputPath ".\report.json"
```

## Prerequisites

- Azure DevOps PAT with **Build (read)** scope
- Set `AZURE_DEVOPS_PAT` environment variable or pass `-PersonalAccessToken`
