Clear-Host

$pecmdUrl = "https://github.com/NoDiff-del/JARs/releases/download/Jar/PECmd.exe"
$xxstringsUrl = "https://github.com/NoDiff-del/JARs/releases/download/Jar/xxstrings64.exe"

$pecmdPath = "$env:TEMP\PECmd.exe"
$xxstringsPath = "$env:TEMP\xxstrings64.exe"

Invoke-WebRequest -Uri $pecmdUrl -OutFile $pecmdPath
Invoke-WebRequest -Uri $xxstringsUrl -OutFile $xxstringsPath

$logonTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime

$prefetchFolder = "C:\Windows\Prefetch"
$files = Get-ChildItem -Path $prefetchFolder -Filter *.pf
$filteredFiles = $files | Where-Object { 
    ($_.Name -match "java|javaw") -and ($_.LastWriteTime -gt $logonTime)
}

function Is-JarFile {
    param (
        [string]$filePath
    )

    try {
        $zipFile = [System.IO.Compression.ZipFile]::OpenRead($filePath)
        $manifestExists = $false
        
        foreach ($entry in $zipFile.Entries) {
            if ($entry.FullName -eq "META-INF/MANIFEST.MF") {
                $manifestExists = $true
                break
            }
        }

        $zipFile.Dispose()

        return $manifestExists
    } catch {
        return $false
    }
}

if ($filteredFiles.Count -gt 0) {
    Write-Host "PF files found after logon time.." -ForegroundColor Gray
    $filteredFiles | ForEach-Object { 
        Write-Host " "
        Write-Host $_.FullName
        $prefetchFilePath = $_.FullName
        $pecmdOutput = & $pecmdPath -f $prefetchFilePath
        $filteredImports = $pecmdOutput | Where-Object { $_ -match "\\VOLUME{(.+?)}" }

        if ($filteredImports.Count -gt 0) {
            Write-Host "Imports found:" -ForegroundColor DarkYellow
            $filteredImports | ForEach-Object {
                $line = $_
                if ($line -match '\\VOLUME{(.+?)}') {
                    $line = $line -replace '\\VOLUME{(.+?)}', 'C:'
                }
                $line = $line -replace '^\d+: ', ''
                if (Is-JarFile -filePath $line) {
                    if ($line -match '\.jar$') {
                        Write-Host "Valid .jar file:" -NoNewline -ForegroundColor Green
                        Write-Host "  $line"
                    } else {
                        Write-Host "File .jar modified extension" -NoNewline -ForegroundColor Red
                        Write-Host "  $line"
                    }
                }
            }
        } else {
            Write-Host "No imports found for the file $($_.Name)." -ForegroundColor Red
        }
    }
} else {
    Write-Host "No PF files containing 'java' or 'javaw' and modified after logon time were found." -ForegroundColor Red
}

Write-Output " "
Write-Host "Searching for DcomLaunch PID..." -ForegroundColor Gray

$pidDcomLaunch = (Get-CimInstance -ClassName Win32_Service | Where-Object { $_.Name -eq 'DcomLaunch' }).ProcessId

$xxstringsOutput = & $xxstringsPath -p $pidDcomLaunch -raw | findstr /C:"-jar"

if ($xxstringsOutput) {
    Write-Host "Strings found in DcomLaunch process memory containing '-jar':" -ForegroundColor DarkYellow
    $xxstringsOutput | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "No strings containing '-jar' were found in DcomLaunch process memory." -ForegroundColor Red
}
