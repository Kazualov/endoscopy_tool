# build.ps1
Write-Host "Cleaning project: build, dist, __pycache__, *.pyc..."

Get-ChildItem -Recurse -Directory | Where-Object { $_.Name -in @("build", "dist") } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -Recurse -Directory -Filter "__pycache__" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -Recurse -Include *.pyc -File | Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host "Creating virtual environment (if not exists)..."
if (-Not (Test-Path "venv")) {
    python -m venv venv
}

Write-Host "Activating environment..."
.\venv\Scripts\activate

Write-Host "Installing dependencies..."
pip install --upgrade pip
pip install -r videoQueries\requirements.txt
pip install pyinstaller

Write-Host "Building EXE from main.spec..."
pyinstaller main.spec

Write-Host "Build complete! EXE is in dist\main\main.exe"
