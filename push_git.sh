#!/bin/bash

# Add all changes
git add .

# Commit with a message
git commit -m "Trying to revert to atomicAdd(pat_matches)"

REPO_URL="github.com/theUzumaki/Multicore.git"

# GitHub credentials
GITHUB_USERNAME="theUzumaki"
GITHUB_TOKEN="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"  # Preferably use a token instead of your password for security

# Push latest changes
git push https://$GITHUB_USERNAME:$GITHUB_TOKEN@$REPO_URL

