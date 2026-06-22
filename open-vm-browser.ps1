# Run this as Administrator to access the VM in your browser
# Right-click → "Run as Administrator"

# Add port forwarding from localhost:8080 → VM:80
netsh interface portproxy add v4tov4 listenport=8080 listenaddress=127.0.0.1 connectport=80 connectaddress=10.0.1.1

Write-Host "Opening http://localhost:8080 in browser..."
Start-Process "http://localhost:8080"
