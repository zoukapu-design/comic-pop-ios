# COMIC POP! / Windows 10-11 / GitHub upload helper
# 1. Extract COMIC_POP_iOS_v21_GitHub_Ready.zip into any folder.
# 2. Right click this script > Run with PowerShell, or:
#       powershell -ExecutionPolicy Bypass -File .\upload_to_github.ps1
# 3. Git for Windows must be installed; sign in via the browser when Git Credential Manager asks.
# This script never accepts or stores a GitHub access token.
$ErrorActionPreference = 'Stop'
$repoUrl = 'https://github.com/zoukapu-design/comic-pop-ios.git'
$source = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $source '_github_checkout'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw 'Git for Windows がありません。https://git-scm.com/downloads/win からインストールしてください。'
}
if (-not (Test-Path (Join-Path $source 'ios/project.yml'))) {
  throw 'ios/project.yml が見つかりません。ZIPを先にすべて展開してください。'
}
if (-not (Test-Path $target)) {
  & git clone $repoUrl $target
  if ($LASTEXITCODE -ne 0) {throw 'GitHubのcloneに失敗しました。GitHubへログインしてください。'}
}
Push-Location $target
try {
  & git pull --ff-only origin main
  if ($LASTEXITCODE -ne 0) {throw 'リモートのmainブランチ取得に失敗しました。'}
  foreach($name in @('ios','tests','codemagic.yaml','.gitignore','README.md','NEXT_STEPS.md','PORTFOLIO_NOTES.md','extract_cards.js')) {
    $item = Join-Path $source $name
    if(Test-Path $item) { Copy-Item -LiteralPath $item -Destination $target -Force -Recurse }
  }
  # Do not publish compiled test binaries or captured videos.
  $testBin = Join-Path $target 'tests/model_tests'
  if (Test-Path $testBin) {Remove-Item $testBin -Force}
  & git add -A
  if ($LASTEXITCODE -ne 0) {throw 'git add failed'}
  & git diff --cached --quiet
  if ($LASTEXITCODE -ne 0) {
    & git commit -m 'feat: import native COMIC POP iOS prototype v2.1.1'
    if ($LASTEXITCODE -ne 0) {throw 'git commit failed: Gitのuser.name/user.emailを設定してください。'}
    & git push origin main
    if ($LASTEXITCODE -ne 0) {throw 'git push failed: GitHub権限・ブラウザログインを確認してください。'}
  } else { Write-Host 'No changes to upload.' }
  Write-Host 'GitHubへソースを同期しました。次にCodemagicで ios-unsigned-check を起動してください。' -ForegroundColor Green
  Write-Host 'https://github.com/zoukapu-design/comic-pop-ios'
} finally { Pop-Location }
