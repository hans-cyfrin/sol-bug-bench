# Solidity Bug Bench

## Purpose
This repository contains a collection of intentionally vulnerable Solidity smart contracts designed for educational and testing purposes. It serves as a resource for developers, security researchers, and students to learn about common vulnerabilities in smart contracts and practice vulnerability detection and analysis.

The project is designed to be a growing collection of vulnerable contracts. We plan to continuously add more contracts with diverse vulnerability types in the future to create a comprehensive benchmark for smart contract security tools and training.


## Vulnerability Management

### GitHub Issues as Vulnerability Documentation
All vulnerabilities in this codebase are documented as GitHub issues in this repository. This approach provides:
- Structured vulnerability reports with consistent formatting
- Severity classification using GitHub labels
- Community discussion and feedback capabilities
- Version control for vulnerability discoveries and fixes
- Easy integration with security tools and workflows

### Issues Folder
The `/issues` folder contains tooling for managing vulnerability data:

#### Structure
```
issues/
├── fetch_issues.py     # Python script to fetch vulnerabilities from GitHub API
├── requirements.txt    # Python dependencies
├── issues.json        # All GitHub issues data in JSON format
└── findings.json      # Template for security findings
```

#### Issue Fetching Script
The `fetch_issues.py` script automatically pulls all open vulnerabilities from the GitHub repository:

```bash
cd issues
python3 -m pip install -r requirements.txt
python3 fetch_issues.py
```

**Features:**
- Fetches all open GitHub issues via API
- Extracts severity levels from issue labels
- Saves clean JSON data with only essential fields (id, title, body, severity)
- Handles pagination for repositories with many issues
- Filters out pull requests automatically

**Output:** The script generates `issues.json` containing all vulnerability data in a simple array format, making it easy to integrate with security analysis tools or create custom reports.


## Educational Use

This repository is designed for:
- Smart contract security training and workshops
- Vulnerability research and detection tool testing
- Security tool benchmarking and validation
- Bug bounty preparation and practice
- Academic research in blockchain security
- Developing and testing automated vulnerability scanners

## Future Expansion

We plan to expand this benchmark with:
- Additional contract types (DeFi protocols, NFTs, DAOs, etc.)
- More diverse vulnerability categories
- Contracts of varying complexity levels
- Integration with popular testing frameworks
- Automated vulnerability classification tools

## Contributing

When adding new vulnerabilities:
1. Create a GitHub issue with detailed vulnerability description
2. Use appropriate severity labels (Critical, High, Medium, Low)
3. Include proof of concept and recommended mitigation
4. Follow the established issue template format

**⚠️ Warning**: These contracts contain intentional vulnerabilities and should never be deployed to mainnet or used with real funds.