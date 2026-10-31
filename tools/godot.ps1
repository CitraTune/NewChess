param(
    [ValidateSet('Editor','Import','Run','Test','Rules','NetworkTest','Verify','Export','TestExport','PlayExport','Version')]
    [string]$Action = 'Run',
    [switch]$Headless
)
$ErrorActionPreference = 'Stop'
$repoDir = Split-Path -Parent $PSScriptRoot
$projectDir = Join-Path $repoDir 'godot'
$engineDir = Join-Path $env:LOCALAPPDATA 'NewChess\tools\godot-4.7.2'
$engine = Join-Path $engineDir 'Godot_v4.7.2-stable_win64_console.exe'
if ($env:NEWCHESS_GODOT) { $engine = $env:NEWCHESS_GODOT }
if (-not (Test-Path -LiteralPath $engine)) { throw 'Run tools/setup-godot.ps1 first, or set NEWCHESS_GODOT.' }
$buildDir = Join-Path $repoDir 'dist'
$exe = Join-Path $buildDir 'DreamChessII.exe'
$reportDir = Join-Path $projectDir 'test-output'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
Set-Content -LiteralPath (Join-Path $reportDir '.gdignore') -Value ''

function Get-ProjectEditor {
    Get-CimInstance Win32_Process -Filter "Name = 'Godot_v4.7.2-stable_win64.exe'" | Where-Object {
        $_.CommandLine -match '--editor' -and $_.ExecutablePath -like "$engineDir*"
    }
}

function Invoke-CheckedEngine([string[]]$EngineArguments, [string]$LogName, [string]$PassMarker = '') {
    $outPath = Join-Path $reportDir ($LogName + '.out.log')
    $errPath = Join-Path $reportDir ($LogName + '.err.log')
    $quotedArgs = $EngineArguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
    $process = Start-Process -FilePath $engine -ArgumentList $quotedArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $outPath -RedirectStandardError $errPath
    $null = $process.Handle
    if (-not $process.WaitForExit(60000)) { Stop-Process -Id $process.Id; throw "$LogName timed out; see $outPath" }
    $process.Refresh()
    $output = (Get-Content -Raw -LiteralPath $outPath) + (Get-Content -Raw -LiteralPath $errPath)
    $output | Write-Output
    if ($process.ExitCode -ne 0 -or $output -match 'SCRIPT ERROR:|SELF_TEST_FAILED|NETWORK_TEST_FAILED|ERROR:' -or ($PassMarker -and $output -notmatch [regex]::Escape($PassMarker))) {
        throw "$LogName failed; see $outPath and $errPath"
    }
}

function Invoke-RuleTests {
    Invoke-CheckedEngine @('--headless','--path',$projectDir,'--script','res://tests/rules_test.gd') 'rules' 'RULES_TEST_PASS'
}
function Invoke-SceneTests {
    $testArgs = @('--path',$projectDir,'--resolution','1920x1080')
    if ($Headless) { $testArgs += '--headless' }
    $testArgs += @('--','--self-test',"--test-output=$reportDir")
    Invoke-CheckedEngine $testArgs 'ui' 'SELF_TEST_PASS'
}
function Invoke-NetworkTests {
    $hostOut = Join-Path $reportDir 'network-host.out.log'
    $hostErr = Join-Path $reportDir 'network-host.err.log'
    $hostArgs = @('--headless','--path',('"' + $projectDir + '"'),'--script','res://tests/network_test.gd','--','--host')
    $server = Start-Process -FilePath $engine -ArgumentList $hostArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $hostOut -RedirectStandardError $hostErr
    $null = $server.Handle
    try {
        Invoke-CheckedEngine @('--headless','--path',$projectDir,'--script','res://tests/network_test.gd') 'network-client' 'NETWORK_CLIENT_PASS'
        if (-not $server.WaitForExit(20000)) { throw 'Network host test timed out' }
        $server.Refresh()
        $hostOutput = (Get-Content -Raw -LiteralPath $hostOut) + (Get-Content -Raw -LiteralPath $hostErr)
        $hostOutput | Write-Output
        if ($server.ExitCode -ne 0 -or $hostOutput -notmatch 'NETWORK_HOST_PASS' -or $hostOutput -match 'ERROR:') { throw 'Network host test failed' }
    } finally { if (-not $server.HasExited) { Stop-Process -Id $server.Id } }
    $hostArgs = @('--headless','--path',('"' + $projectDir + '"'),'--','--network-app-host')
    $server = Start-Process -FilePath $engine -ArgumentList $hostArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $hostOut -RedirectStandardError $hostErr
    $null = $server.Handle
    try {
        Invoke-CheckedEngine @('--headless','--path',$projectDir,'--','--network-app-client') 'app-network-client' 'APP_NETWORK_PASS'
        if (-not $server.WaitForExit(20000)) { throw 'App network host timed out' }
        $server.Refresh()
        $hostOutput = (Get-Content -Raw -LiteralPath $hostOut) + (Get-Content -Raw -LiteralPath $hostErr)
        $hostOutput | Write-Output
        if ($server.ExitCode -ne 0 -or $hostOutput -notmatch 'APP_NETWORK_PASS' -or $hostOutput -match 'ERROR:') { throw 'App network host failed' }
    } finally { if (-not $server.HasExited) { Stop-Process -Id $server.Id } }
}
switch ($Action) {
    'Version' { & $engine --version; exit $LASTEXITCODE }
    'Import' {
        if (Get-ProjectEditor) {
            Write-Output 'Editor already open; using its live asset import and language server. No second editor is started.'
            exit 0
        }
        Invoke-CheckedEngine @('--headless','--path',$projectDir,'--import') 'import'
    }
    'Editor' {
        if (Get-ProjectEditor) { Write-Output 'The NewChess Godot editor is already running.'; exit 0 }
        & $engine --editor --path $projectDir --lsp-port 6005 --dap-port 6006
        exit $LASTEXITCODE
    }
    'Run' { & $engine --path $projectDir; exit $LASTEXITCODE }
    'Rules' { Invoke-RuleTests }
    'NetworkTest' { Invoke-NetworkTests }
    'Test' { Invoke-SceneTests }
    'Verify' { Invoke-RuleTests; Invoke-NetworkTests; Invoke-SceneTests }
    'Export' {
        if (Get-ProjectEditor) { throw 'Close the Godot editor before exporting to prevent external-project-file modal conflicts.' }
        New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
        Invoke-CheckedEngine @('--headless','--path',$projectDir,'--export-release','Windows Desktop',$exe) 'export'
        $noticePath = Join-Path $buildDir 'THIRD-PARTY-NOTICES.txt'
        $notices = @('GODOT ENGINE', (Get-Content -Raw (Join-Path $projectDir 'assets\GODOT-LICENSE.txt')), 'ATKINSON HYPERLEGIBLE', (Get-Content -Raw (Join-Path $projectDir 'assets\fonts\Atkinson-OFL.txt')), 'KREFELD CONDENSED / RAILWAY 1901', (Get-Content -Raw (Join-Path $projectDir 'assets\fonts\Hypersalesman-NOTICE.txt')), 'GATSBY ROUGE (ARCHIVED)', 'Source: https://hypersalesman.com/folders/#font-139', (Get-Content -Raw (Join-Path $projectDir 'assets\fonts\GatsbyRouge-README.txt'))) -join "`r`n`r`n"
        Set-Content -LiteralPath $noticePath -Value $notices -Encoding UTF8
        Compress-Archive -LiteralPath @($exe,$noticePath) -DestinationPath (Join-Path $buildDir 'DreamChessII-Windows.zip') -Force
        Write-Output "Ready to play: $exe"
        Write-Output "Ready to share: $(Join-Path $buildDir 'DreamChessII-Windows.zip')"
    }
    'TestExport' {
        if (-not (Test-Path -LiteralPath $exe)) { throw 'Export the game first.' }
        $exportReports = Join-Path $reportDir 'export'
        New-Item -ItemType Directory -Force -Path $exportReports | Out-Null
        $oldEngine = $engine
        $engine = $exe
        try { Invoke-CheckedEngine @('--resolution','1920x1080','--','--self-test',"--test-output=$exportReports") 'release' 'SELF_TEST_PASS' }
        finally { $engine = $oldEngine }
    }
    'PlayExport' {
        if (-not (Test-Path -LiteralPath $exe)) { throw 'Export the game first.' }
        $game = Start-Process -FilePath $exe -WorkingDirectory $buildDir -PassThru
        Write-Output "Started Dream Chess II (PID $($game.Id)): $exe"
    }
}
exit 0
