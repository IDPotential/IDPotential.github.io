$files = Get-ChildItem -Path "d:\APK\id_diagnostic_app\video" -Filter "AnimРоль *.mp4"
foreach ($file in $files) {
    if ($file.Name -match "AnimРоль (\d+).mp4") {
        $number = $matches[1]
        $newName = "role_$number.mp4"
        Rename-Item -Path $file.FullName -NewName $newName
        Write-Host "Renamed $($file.Name) to $newName"
    }
}
