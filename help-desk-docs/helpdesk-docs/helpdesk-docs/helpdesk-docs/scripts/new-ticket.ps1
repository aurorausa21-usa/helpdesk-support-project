# creates a new ticket markdown file automatically

param(
    [string]$RequestedBy,
    [string]$Category,
    [string]$Priority = "Low"
)

$ticketId = Get-Random -Minimum 1000 -Maximum 9999
$date = Get-Date -Format "yyyy-MM-dd"
$path = "../helpdesk-docs/tickets/ticket-$ticketId.md"

$content = @"
# Help Desk Ticket $ticketId

**Date:** $date  
**Requested By:** $RequestedBy  
**Category:** $Category  
**Priority:** $Priority  

---

## Issue Description
(enter description here)

## Troubleshooting Steps
- 

## Resolution
- 

---

## Status  
Open
"@

New-Item -Path $path -ItemType File -Force -Value $content

Write-Host "Ticket $ticketId created at $path"
