param(
    [ValidateSet('Gemini', 'Gateway')]
    [string]$Mode = 'Gemini',
    [string]$GatewayUrl
)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
if ($Mode -eq 'Gemini') {
    # Hidden prompt: key is never written to source, disk, or command history.
    $coachSecret = Read-Host 'Enter your Gemini API key locally (hidden)' -AsSecureString
    $env:GEMINI_API_KEY = [System.Net.NetworkCredential]::new('', $coachSecret).Password
    if ([string]::IsNullOrWhiteSpace($env:GEMINI_API_KEY)) { throw 'A key is required for live Gemini.' }
    Remove-Item Env:COURSE_MODEL_GATEWAY_URL -ErrorAction SilentlyContinue
} else {
    if (-not $GatewayUrl.StartsWith('https://')) { throw 'Provide the course HTTPS gateway URL.' }
    $env:COURSE_MODEL_GATEWAY_URL = $GatewayUrl
    Remove-Item Env:GEMINI_API_KEY -ErrorAction SilentlyContinue
}
Remove-Item Env:QUEST_COACH_MODE -ErrorAction SilentlyContinue
$jdkPath = 'C:\Program Files\Java\jdk-21'
if (Test-Path -LiteralPath "$jdkPath\bin\java.exe") {
    $env:JAVA_HOME = $jdkPath
    $env:Path = "$jdkPath\bin;$env:Path"
}
try {
    & npx.cmd --yes firebase-tools emulators:start --project demo-cloud-quest --only 'auth,firestore,functions'
} finally {
    # Credentials last only for this run of the local emulators.
    Remove-Item Env:GEMINI_API_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:COURSE_MODEL_GATEWAY_URL -ErrorAction SilentlyContinue
}
