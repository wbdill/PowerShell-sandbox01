# Lists folders in specified directly out to a CSV file and to the console if < than $MaxCount.
# $MaxCount used as a cutoff because it takes a long time to list 10's of thousands of folders.
# 2025-10-10 Brian Dill (twiter:@bdill, bluesky:@wbdill)
Function ListFolders {
    param(
        [Parameter(Mandatory = $true)] [string]$Path
        , [int]$MaxCount = 200
    )

    # Ensure the path exists
    if (-not (Test-Path $Path)) {
        Write-Error "The specified path does not exist: $Path"
        exit 1
    }

    # Get immediate subdirectories (no recursion)
    $folders = Get-ChildItem -Path $Path -Directory | Select-Object -ExpandProperty Name

    # Print folder names to console
    If ($folders.Count -lt $MaxCount) {
        Write-Host "Directories found in '$Path':"
        $folders | ForEach-Object { Write-Host "$_" }
    } else {
        Write-Host "More than $MaxCount folders found, so not listing in console.  Only saving to CSV"
    }
    # Save to CSV (single column)
    $outFile = Join-Path $Path "folder_list_$((Get-Date).ToString("yyyy-MM-dd_HH.mm.ss")).csv"
    $folders | ForEach-Object { [PSCustomObject]@{ FolderName = $_ } } | Export-Csv -Path $outFile -NoTypeInformation

    Write-Host "`nSaved folder list to: $outFile"
}
ListFolders "C:\temp" 100
