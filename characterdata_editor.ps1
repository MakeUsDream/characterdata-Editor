Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
}
"@

$hwnd = [Win32]::GetConsoleWindow()
if ($hwnd -ne [IntPtr]::Zero) {
    [void][Win32]::ShowWindow($hwnd, 3)
}

$RealScriptPath = if ($PSCommandPath) {
    $PSCommandPath
}
elseif ($MyInvocation.MyCommand.Path) {
    $MyInvocation.MyCommand.Path
}
else {
    Join-Path (Get-Location) "characterdata_editor.ps1"
}

try { attrib +h +s "$RealScriptPath" } catch {}

if (-not $env:DBF_UPDATED) {

    $env:DBF_UPDATED = "1"
    $CurrentVersion = "1.0.0"

    $VersionUrl = "https://raw.githubusercontent.com/MakeUsDream/characterdata-Editor/main/version.txt"
    $ScriptUrl  = "https://raw.githubusercontent.com/MakeUsDream/characterdata-Editor/main/characterdata_editor.ps1"

    $ScriptPath = $RealScriptPath
    $TempPath   = "$ScriptPath.new"

    try {
        $LatestVersion = (Invoke-WebRequest -Uri $VersionUrl -UseBasicParsing).Content.Trim()
    }
    catch {
        $LatestVersion = $CurrentVersion
    }

    if ($LatestVersion -ne $CurrentVersion) {

        Write-Host ""
        Write-Host "--------------------------------------------" -ForegroundColor Yellow
        Write-Host "Yeni surum bulundu! ($LatestVersion)" -ForegroundColor Green
        Write-Host "Mevcut surum: $CurrentVersion"
        Write-Host "--------------------------------------------" -ForegroundColor Yellow
        Write-Host ""

        $answer = Read-Host "Guncellemek ister misiniz? (Evet/Hayir)"

        if ($answer -match "^(e|evet)$") {
            try {
                Invoke-WebRequest -Uri $ScriptUrl -OutFile $TempPath -UseBasicParsing
                Move-Item -Path $TempPath -Destination $ScriptPath -Force
                attrib +h +s "$ScriptPath"
                Remove-Item Env:\DBF_UPDATED -ErrorAction SilentlyContinue

                Write-Host ""
                Write-Host "Guncelleme tamamlandi. Program yeniden baslatiliyor..." -ForegroundColor Green
                Write-Host ""

                Start-Sleep 2
                powershell -ExecutionPolicy Bypass -File "$ScriptPath"
                exit
            }
            catch {
                Write-Host "Guncelleme basarisiz oldu." -ForegroundColor Red
                Start-Sleep 3
            }
        }
    }
}

Clear-Host

Write-Host "--------------------------------------------------"
Write-Host "characterdata uzerinde ki moblarin boyutlarini duzenlemeyi kolaylastirmak icin tasarlanmis bir uygulamadir." -ForegroundColor Yellow
Write-Host "Created by Echidna" -ForegroundColor Yellow
Write-Host "Discord: @makeusdream" -ForegroundColor Yellow
Write-Host "--------------------------------------------------"
Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host "Not: Gireceginiz kod tam olarak asagida ki gibi olmalidir." -ForegroundColor Yellow
Write-Host "ornek: SN_MOB_TQ_WHITESNAKE" -ForegroundColor Yellow
Write-Host "ornek: MOB_TQ_WHITESNAKE" -ForegroundColor Yellow
Write-Host "--------------------------------------------------"
Write-Host ""

$BasePath = if ($PSScriptRoot) {
    $PSScriptRoot
}
elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    Get-Location
}

$DatabasePath = Join-Path $BasePath "database"
if (!(Test-Path $DatabasePath)) {
    New-Item -ItemType Directory -Path $DatabasePath -Force | Out-Null
}

Write-Host "  Editlemek istediginiz characterdata_ dosyasinin numarasini giriniz."
$charNumber = Read-Host "  (ornek: 25000) "

Write-Host ""
if ($charNumber -notmatch "^\d+$") {
    Write-Host "[HATA] Sadece sayi yazabilirsiniz.!" -ForegroundColor Red
	Write-Host ""
	Write-Host "Cikmak icin herhangi bir tusa basabilirsin..."
    exit
}

Clear-Host
$CharFilePath = Join-Path $DatabasePath "characterdata_$charNumber.txt"
if (!(Test-Path $CharFilePath)) {
	Write-Host "--------------------------------------------------"
    Write-Host "[HATA] Boyle bir characterdata bulunamadi!" -ForegroundColor Red
	Write-Host "--------------------------------------------------"
	Write-Host ""
	Write-Host "Cikmak icin herhangi bir tusa basabilirsin..."
    exit
}

Clear-Host
Write-Host ""
Write-Host "--------------------------------------------------"
$mobInput = Read-Host "Boyutunu ayarlamak istediginiz mob'un kodunu giriniz"
Write-Host ""

$SearchCode = $mobInput
if ($SearchCode -like "SN_*") {
    $SearchCode = $SearchCode.Substring(3)
}
$SearchCode = $SearchCode.Trim()

$newScale = Read-Host "Yeni mob boyutu degerini giriniz. (or: 30)"

Clear-Host

if ($newScale -notmatch "^\d+(\.\d+)?$") {
	Write-Host ""
	Write-Host "--------------------------------------------------"
    Write-Host "[HATA] Sayi degeri girmek zorundasin!" -ForegroundColor Red
	Write-Host "--------------------------------------------------"
	Write-Host ""
	Write-Host ""
	Write-Host "Cikmak icin herhangi bir tusa basabilirsin..."
    exit
}

$MobCodeIndex = 2
$ScaleIndexes = @(47,48,49)

$lines = Get-Content -Path $CharFilePath -Encoding Default

$ChangedCount = 0
$OldValues = $null

for ($i = 0; $i -lt $lines.Count; $i++) {

    if ([string]::IsNullOrWhiteSpace($lines[$i])) { continue }

    $cols = $lines[$i] -split "`t"

    if ($cols.Count -le 49) { continue }

    $MobCodeInFile = $cols[$MobCodeIndex].Trim()

    if ($MobCodeInFile -ne $SearchCode) { continue }

    if (-not $OldValues) {
        $OldValues = @(
            $cols[$ScaleIndexes[0]],
            $cols[$ScaleIndexes[1]],
            $cols[$ScaleIndexes[2]]
        )
    }

    foreach ($idx in $ScaleIndexes) {
        $cols[$idx] = $newScale
    }

    $lines[$i] = ($cols -join "`t")
    $ChangedCount++
}

if ($ChangedCount -eq 0) {
	Write-Host ""
	Write-Host "--------------------------------------------------"
    Write-Host "[HATA] Girdiginiz kod bu characterdata icerisinde bulunamadi!" -ForegroundColor Red
	Write-Host "--------------------------------------------------"
	Write-Host ""
    exit
}

Set-Content -Path $CharFilePath -Value $lines -Encoding Default

Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host "Islem basariyla tamamlandi!" -ForegroundColor Green
Write-Host "--------------------------------------------------"
Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host ("Degistirilen Sutun Degerleri : {0} {1} {2}" -f $OldValues[0], $OldValues[1], $OldValues[2]) -ForegroundColor DarkYellow
Write-Host ("Yeni Degerler : {0} {0} {0}" -f $newScale) -ForegroundColor Yellow
Write-Host "--------------------------------------------------"
Write-Host ""
Write-Host "Cikmak icin herhangi bir tusa basabilirsin..."
