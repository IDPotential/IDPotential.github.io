$path = "d:\APK\id_diagnostic_app\assets\images\"
$files = Get-ChildItem -Path $path -Filter "*.jpg"
foreach ($file in $files) {
    if ($file.Name -match "Владимир") {
        Rename-Item -Path $file.FullName -NewName "vladimir_papushin.jpg" -Force
        Write-Host "Renamed $($file.Name)"
    }
}
