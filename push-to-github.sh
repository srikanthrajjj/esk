#!/bin/bash

echo "===== Preparing to push changes to GitHub ====="

# Add all changed files
git add .

# Commit the changes
git commit -m "Configure application for Render deployment"

# Push to GitHub
git push origin main

echo "===== Changes pushed to GitHub ====="
echo "You can now deploy this application on Render using the instructions in the README.md" 