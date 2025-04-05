#!/bin/bash

# Add all changes
git add .

# Commit with a message
git commit -m "General update"

REPO_URL="https://github.com/theUzumaki/WASA.git"

# GitHub credentials
GITHUB_USERNAME="theUzumaki"
GITHUB_TOKEN="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"  # Preferably use a token instead of your password for security

# Push latest changes
git push https:/$GITHUB_USERNAME:$GITHUB_TOKEN@$REPO_URL

