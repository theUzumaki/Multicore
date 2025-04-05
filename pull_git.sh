#!/bin/bash

# Your GitHub repository URL (replace with your actual URL)
REPO_URL="github.com/theUzumaki/Multicore.git"

# GitHub credentials
GITHUB_USERNAME="theUzumaki"
GITHUB_TOKEN="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"  # Preferably use a token instead of your password for security

# Pull latest changes from GitHub repository using credentials
git pull https://$GITHUB_USERNAME:$GITHUB_TOKEN@$REPO_URL
