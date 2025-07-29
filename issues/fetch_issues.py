#!/usr/bin/env python3
"""
Script to fetch all open issues from hans-cyfrin/sol-bug-bench GitHub repository
and save them to issues.json file.
"""

import json
import requests
import sys
from typing import List, Dict, Any

def extract_severity_from_labels(labels: List[Dict]) -> str:
    """Extract severity from issue labels."""
    for label in labels:
        label_name = label.get('name', '').lower()
        if 'severity:' in label_name:
            return label_name.split('severity:')[1].strip()
    return 'unknown'

def fetch_github_issues(repo_owner: str, repo_name: str) -> List[Dict[str, Any]]:
    """
    Fetch all open issues from a GitHub repository.
    
    Args:
        repo_owner: GitHub repository owner
        repo_name: GitHub repository name
        
    Returns:
        List of issues
    """
    base_url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/issues"
    all_issues = []
    page = 1
    per_page = 100

    while True:
        params = {
            'state': 'open',
            'per_page': per_page,
            'page': page
        }

        print(f"Fetching page {page}...")
        response = requests.get(base_url, params=params)

        if response.status_code != 200:
            print(f"Error fetching issues: {response.status_code}")
            print(f"Response: {response.text}")
            sys.exit(1)

        issues = response.json()

        # Filter out pull requests (GitHub API includes PRs in issues endpoint)
        issues = [issue for issue in issues if 'pull_request' not in issue]

        if not issues:
            break

        all_issues.extend(issues)

        # If we got less than per_page items, we're on the last page
        if len(issues) < per_page:
            break

        page += 1

    return all_issues

def process_issues(issues: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Process GitHub issues to extract only essential information.
    
    Args:
        issues: Raw GitHub issues data
        
    Returns:
        Simplified issues data with only id, title, body, severity
    """
    processed_issues = []

    for issue in issues:
        severity = extract_severity_from_labels(issue.get('labels', []))

        processed_issue = {
            'id': issue['number'],
            'title': issue['title'],
            'body': issue['body'],
            'severity': severity
        }

        processed_issues.append(processed_issue)

    return processed_issues

def main():
    """Main function to fetch and save GitHub issues."""
    repo_owner = "hans-cyfrin"
    repo_name = "sol-bug-bench"

    print(f"Fetching issues from {repo_owner}/{repo_name}...")

    try:
        # Fetch issues
        issues = fetch_github_issues(repo_owner, repo_name)
        print(f"Found {len(issues)} open issues")

        # Process issues
        processed_issues = process_issues(issues)

        # Save to JSON file as simple array
        output_file = "issues.json"
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(processed_issues, f, indent=2, ensure_ascii=False)

        print(f"Issues saved to {output_file}")

        # Print summary
        severity_counts = {}
        for issue in processed_issues:
            severity = issue['severity']
            severity_counts[severity] = severity_counts.get(severity, 0) + 1

        print("\nSeverity breakdown:")
        for severity, count in sorted(severity_counts.items()):
            print(f"  {severity}: {count}")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()