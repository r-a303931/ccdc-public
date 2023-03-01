#!/usr/bin/env pwsh

$compUrl = ""
while ($true) {
    $years = (Invoke-WebRequest "https://archive.wrccdc.org/images/").Links
        | Where { $_.Href -like "*/" -and $_.Href -ne "../" -and (-not ($_.Href -like "http://*")) }
        | ForEach { $_.Href }

    $yearInput = ""

    Write-Host "=== Select a year ==="
    $years | % {
        Write-Host $_.Substring(0, $_.Length - 1)
    }

    while (-not (($yearInput + "/") -in $years)) {
        $yearInput = (Read-Host -Prompt "Enter your selection")
    }

    $comps = ("invitationals", "qualifiers", "regionals")
    $compInput = ""

    Write-Host "=== Select a competition ==="
    $comps | % { Write-Host $_ }

    while (-not ($compInput -in $comps) -and ($compInput -ne "q")) {
        $compInput = (Read-Host -Prompt "Enter your selection (or q to go back)")
    }

    if ($compInput -ne "q") {
        $comp = "wrccdc-$yearInput-$compInput"
    } else {
        continue;
    }

    $compUrl = "https://archive.wrccdc.org/images/$yearInput/$comp/"
    break;
}

$compArchive = Invoke-WebRequest $compUrl

if (($compArchive.Links | ? { $_.Href -Like "*readme*" }).Length -ge 0) {
    $compUrl = ($compUrl + ($compArchive.Links | ? { -not ($_.Href -like "*C=*") })[1].Href)
    $compArchive = Invoke-WebRequest -Uri $compUrl
}

$compUrl | Write-Host

$ovaFiles = $compArchive.Links | ? { $_.Href -like '*.ova' }

# run on Linux
if ((Get-Command).Count -le 300) {
    rm -rf "tmp-ovas"
    rm -rf "tmp-vmx"
    mkdir -p "tmp-ovas"
    mkdir -p "tmp-vmx"
} else {
    rm -ErrorAction SilentlyContinue "tmp-ovas"
    rm -ErrorAction SilentlyContinue "tmp-vmx"
    mkdir -ErrorAction SilentlyContinue "tmp-ovas"
    mkdir -ErrorAction SilentlyContinue "tmp-vmx"
}

$ovaFiles
    | % { $compUrl + $_.Href }
    | % {
        function Run-Ovftool {
            param([string]$In, [string]$Out)

            $ToolOnWindows = (Get-Command).Count -ge 300

            if ($ToolOnWindows) {
                if ([System.IO.Path]::Exists("C:\Program Files (x86)\VMware\VMware Workstation\OVFTool\ovftool.exe")) {
                    & "C:\Program Files (x86)\VMware\VMware Workstation\OVFTool\ovftool.exe" $In $Out
                } elseif ([System.IO.Path]::Exists("C:\Program Files\VMware\VMware Workstation\OVFTool\ovftool.exe")) {
                    & "C:\Program Files\VMware\VMware Workstation\OVFTool\ovftool.exe" $In $Out
                } else {
                    Write-Host "Error! Could not find ovftool! Please install VMWare Workstation 17"
                    exit 1
                }
            } else {
                $ovftool = which "ovftool"
                & $ovftool $In $Out
            }
        }

        "Downloading $_..." | Write-Host
        $ova = [System.IO.Path]::GetFileName($_)
        $tmpOvaPath = Join-Path $pwd.Path "tmp-ovas" $ova
        Invoke-WebRequest $_ -OutFile $tmpOvaPath
        $ovaName = [System.IO.Path]::GetFileNameWithoutExtension($ova)
        $vmxName = $ovaName + ".vmx"
        $tmpVmxPath = Join-Path $pwd.Path "tmp-vmx" $vmxName

        Run-Ovftool -In $tmpOvaPath -Out $tmpVmxPath

        (Get-Content -Path $tmpVmxPath -Raw).Replace('virtualhw.version = "14"','virtualhw.version = "13"').Replace('virtualhw.version = "15"','virtualhw.version = "13"') | Set-Content -Path $tmpVmxPath

        Run-Ovftool -In $tmpVmxPath -Out $ova
    }
