<#
.SYNOPSIS
    Mostra Team, canali e chat disponibili con i relativi ID.
    Usare per recuperare TeamId, ChannelId, ChatId da passare a Export-TeamsMessages.ps1

.EXAMPLE
    # Lista tutti i Team
    .\Get-TeamsIds.ps1 -What Teams

.EXAMPLE
    # Lista canali di un Team
    .\Get-TeamsIds.ps1 -What Channels -TeamId "aaaa-bbbb-..."

.EXAMPLE
    # Lista chat di un utente
    .\Get-TeamsIds.ps1 -What Chats -UserId "mario.rossi@intrawelt.com"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Teams","Channels","Chats")]
    [string]$What,

    [string]$TeamId,
    [string]$UserId
)

$scriptRoot      = $PSScriptRoot
$configPath      = Join-Path $scriptRoot "config.json"
$configLocalPath = Join-Path $scriptRoot "config.local.json"
if (Test-Path $configLocalPath) { $configPath = $configLocalPath }
$config       = Get-Content $configPath -Raw | ConvertFrom-Json
$TenantId     = $config.TenantId
$ClientId     = $config.ClientId
$ClientSecret = $config.ClientSecret

function Get-Token {
    $body = @{
        grant_type    = "client_credentials"
        scope         = "https://graph.microsoft.com/.default"
        client_id     = $ClientId
        client_secret = $ClientSecret
    }
    (Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method POST -Body $body).access_token
}

function Invoke-Graph {
    param([string]$Uri, [string]$Token)
    $headers  = @{ Authorization = "Bearer $Token" }
    $all      = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    do {
        $r = Invoke-RestMethod -Uri $nextLink -Headers $headers -Method GET
        if ($r.value) { foreach ($i in $r.value) { $all.Add($i) } }
        $nextLink = $r.'@odata.nextLink'
    } while ($nextLink)
    return $all
}

$token = Get-Token

switch ($What) {
    "Teams" {
        Write-Host "`n=== TEAM DISPONIBILI ===" -ForegroundColor Yellow
        $teams = Invoke-Graph -Uri "https://graph.microsoft.com/v1.0/teams?`$top=100" -Token $token
        $teams | Select-Object @{N="Nome";E={$_.displayName}}, @{N="TeamId";E={$_.id}} | Format-Table -AutoSize
    }
    "Channels" {
        if (-not $TeamId) { Write-Error "Specificare -TeamId"; exit 1 }
        Write-Host "`n=== CANALI DEL TEAM $TeamId ===" -ForegroundColor Yellow
        $channels = Invoke-Graph -Uri "https://graph.microsoft.com/v1.0/teams/$TeamId/channels" -Token $token
        $channels | Select-Object @{N="Nome";E={$_.displayName}}, @{N="ChannelId";E={$_.id}} | Format-Table -AutoSize
    }
    "Chats" {
        if (-not $UserId) { Write-Error "Specificare -UserId"; exit 1 }
        Write-Host "`n=== CHAT DI $UserId ===" -ForegroundColor Yellow
        $chats = Invoke-Graph -Uri "https://graph.microsoft.com/v1.0/users/$UserId/chats?`$top=50" -Token $token
        $chats | Select-Object @{N="Tipo";E={$_.chatType}}, @{N="Tema";E={$_.topic}}, @{N="ChatId";E={$_.id}} | Format-Table -AutoSize
    }
}
