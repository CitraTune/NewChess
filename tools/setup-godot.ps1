param([switch]$SkipEditorIntegration)

# Portable, per-user Windows setup. Versions and download checksums are pinned.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$repoDir = Split-Path -Parent $PSScriptRoot
$engineDir = Join-Path $env:LOCALAPPDATA 'NewChess\tools\godot-4.7.2'
if (Get-CimInstance Win32_Process -Filter "Name = 'Godot_v4.7.2-stable_win64.exe'" | Where-Object { $_.CommandLine -match '--editor' -and $_.ExecutablePath -like "$engineDir*" }) {
    throw 'Close the NewChess Godot editor before setup to avoid external-change and quit-dialog collisions.'
}
$releaseUrl = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable'
New-Item -ItemType Directory -Force -Path $engineDir | Out-Null

function Get-VerifiedArchive([string]$Name, [string]$Hash) {
    $target = Join-Path $engineDir $Name
    if (-not (Test-Path -LiteralPath $target) -or (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $Hash) {
        Write-Host "Downloading $Name"
        Invoke-WebRequest "$releaseUrl/$Name" -OutFile $target -UseBasicParsing
    }
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $Hash) {
        throw "Checksum mismatch for $Name"
    }
    return $target
}

$engineZip = Get-VerifiedArchive 'Godot_v4.7.2-stable_win64.exe.zip' '731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953'
$engine = Join-Path $engineDir 'Godot_v4.7.2-stable_win64_console.exe'
$guiEngine = Join-Path $engineDir 'Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $engine) -or -not (Test-Path -LiteralPath $guiEngine)) {
    Expand-Archive -LiteralPath $engineZip -DestinationPath $engineDir -Force
}

$vsSettingsPath = Join-Path $repoDir '.vscode\settings.json'
$vsSettings = Get-Content -Raw -LiteralPath $vsSettingsPath | ConvertFrom-Json
# godot-tools 2.7.1 truncates a path after an ${env:...} placeholder: use a full path.
$vsSettings | Add-Member -NotePropertyName 'godotTools.editorPath.godot4' -NotePropertyValue $guiEngine.Replace('\', '/') -Force
$vsSettings | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $vsSettingsPath -Encoding UTF8
$launchPath = Join-Path $repoDir '.vscode\launch.json'
$launchSettings = Get-Content -Raw -LiteralPath $launchPath | ConvertFrom-Json
foreach ($profile in $launchSettings.configurations) {
    if ($profile.type -eq 'godot') {
        $profile | Add-Member -NotePropertyName editor_path -NotePropertyValue $guiEngine.Replace('\', '/') -Force
    }
}
$launchSettings | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $launchPath -Encoding UTF8

$codeCommand = Get-Command code.cmd -ErrorAction SilentlyContinue
if ($codeCommand -and -not $SkipEditorIntegration) {
    & $codeCommand.Source --install-extension geequlim.godot-tools
    if ($LASTEXITCODE -ne 0) { throw 'VS Code extension installation failed' }
}

& $engine --headless --path (Join-Path $repoDir 'godot') --import
if ($LASTEXITCODE -ne 0) { throw 'Godot project import failed' }

$editorSettingsPath = Join-Path $env:APPDATA 'Godot\editor_settings-4.7.tres'
if ($codeCommand -and -not $SkipEditorIntegration -and (Test-Path -LiteralPath $editorSettingsPath)) {
    $backup = Join-Path $engineDir 'editor-settings-before-setup.tres'
    if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $editorSettingsPath -Destination $backup }
    $editorSettings = Get-Content -Raw -LiteralPath $editorSettingsPath
    $entries = @{
        'text_editor/external/exec_path' = '"' + $codeCommand.Source.Replace('\', '/') + '"'
        'text_editor/external/exec_flags' = '"--reuse-window {project}/.. --goto {file}:{line}:{col}"'
        'text_editor/external/use_external_editor' = 'true'
        'text_editor/behavior/files/auto_reload_scripts_on_external_change' = 'true'
        'network/language_server/remote_port' = '6005'
        'interface/editor/save_on_focus_loss' = 'true'
        'interface/editor/import_resources_when_unfocused' = 'true'
    }
    foreach ($key in $entries.Keys) {
        $pattern = '(?m)^' + [regex]::Escape($key) + ' = .*\r?$'
        $line = $key + ' = ' + $entries[$key]
        if ($editorSettings -match $pattern) { $editorSettings = [regex]::Replace($editorSettings, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $line }) }
        else { $editorSettings += "`n$line`n" }
    }
    Set-Content -LiteralPath $editorSettingsPath -Value $editorSettings -Encoding UTF8
}
& $engine --version
Write-Output 'Ready. Use the Godot tasks in VS Code or tools/godot.ps1.'
