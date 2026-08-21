# Contributing

Thanks for your interest in contributing to the DevOps & SRE Operations Toolkit!

## Local Development Setup

### Prerequisites

- [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (for Bicep and Azure commands)
- [Azure Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)
- [Git](https://git-scm.com/)
- [Pester 5+](https://pester.dev/) (for running tests)

### Getting Started

```bash
git clone https://github.com/Harshithj88/devops-sre-operations-toolkit.git
cd devops-sre-operations-toolkit
```

### Running Tests

```powershell
Invoke-Pester -Path ./tests -Output Detailed
```

### Validating Bicep

```bash
az bicep lint --file infra/bicep/main.bicep
```

## How to Contribute

1. **Fork** the repository
2. Create a **feature branch** (`git checkout -b feat/your-feature`)
3. Make your changes
4. Run tests and linting locally
5. **Commit** with a descriptive message (`git commit -m "feat: add disk space alerting"`)
6. **Push** and open a Pull Request

## Commit Message Format

Use conventional commit prefixes:

- `feat:` — new feature or script
- `fix:` — bug fix
- `docs:` — documentation only
- `refactor:` — code restructuring without behavior change
- `test:` — adding or updating tests
- `chore:` — maintenance (CI, configs, dependencies)

## Code Style

- PowerShell scripts should follow [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) defaults
- Use `PascalCase` for function names and parameters (PowerShell convention)
- Include comment-based help (`<# .SYNOPSIS ... #>`) in all public functions
- Bicep files should pass `az bicep lint` without warnings

## Reporting Issues

Use the [issue templates](.github/ISSUE_TEMPLATE/) to report bugs or request features.
