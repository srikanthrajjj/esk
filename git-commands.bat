@echo off
"C:\Program Files\Git\bin\git.exe" add .
"C:\Program Files\Git\bin\git.exe" commit -m "Add deployment configuration for Railway and Netlify"
"C:\Program Files\Git\bin\git.exe" push -u origin master 