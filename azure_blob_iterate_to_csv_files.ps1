# Desc: Connect to a SAS URL blob container and iterate through all the files.
#       Saves a numbered csv file for each 5000 files.  Easy on RAM even for containers with millions of files
#       CSV file contains: FileName, FilePath, FileSizeBytes
# ================================
# Settings
# ================================
Clear-Host
$containerSasUrl = "https://my-storage-acct.blob.core.windows.net/my-container?sp=rl&st=2025-08-13T19:48:50Z&se=2025-08-22T04:03:50Z&spr=https&sv=2024-11-04&sr=c&sig=***********"
$outputDir       = "C:\logs"
$chunkSize       = 5000

# ================================
# Vars
# ================================
$chunkIndex      = 1
$rowBuffer       = @()
$marker          = ""
$totalCount      = 0
# ================================

$StartDate = Get-Date
Write-Host $StartDate.ToString("yyyy-MM-dd HH:mm:ss")


# Ensure output directory exists
if (-not (Test-Path $outputDir)) { New-Item -Path $outputDir -ItemType Directory | Out-Null }

do {
    $url = "$containerSasUrl&restype=container&comp=list&maxresults=5000"
    if ($marker) { $url += "&marker=$marker" }

    Write-Host "Getting chunk $chunkIndex with marker: $marker"
    # Use Invoke-WebRequest to get raw content
    $rawContent = (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
    $cleanXml = $rawContent -replace "^[^\<]+",""    # Strip any junk characters before <?xml
    [xml]$xml = $cleanXml

    foreach ($blob in $xml.EnumerationResults.Blobs.Blob) {
        $fileName = $blob.Name.Split('/')[-1]
        $filePath = ($blob.Name -replace "/$fileName$","")
        $fileSize = [int64]$blob.Properties."Content-Length"

        $rowBuffer += [PSCustomObject]@{
            FileName      = $fileName
            FilePath      = $filePath
            FileSizeBytes = $fileSize
        }

        $totalCount++

        if ($rowBuffer.Count -ge $chunkSize) {
            $chunkFile = Join-Path $outputDir ("files_{0:D4}.csv" -f $chunkIndex)
            $rowBuffer | Export-Csv -Path $chunkFile -NoTypeInformation
            Write-Host "Wrote chunk $chunkIndex with $($rowBuffer.Count) rows. Total: $totalCount"
            $chunkIndex++
            $rowBuffer = @()
        }
    }

    $marker = $xml.EnumerationResults.NextMarker  # Update marker for next page
} while ($marker -ne "")

# Write any remaining rows
if ($rowBuffer.Count -gt 0) {
    $chunkFile = Join-Path $outputDir ("files_{0:D4}.csv" -f $chunkIndex)
    $rowBuffer | Export-Csv -Path $chunkFile -NoTypeInformation
    Write-Host "Wrote final chunk $chunkIndex with $($rowBuffer.Count) rows. Total: $totalCount"
}

Write-Host "Done! CSVs saved to $outputDir"

$ts = (Get-Date) - $StartDate
Write-Host "Finished: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "Elapsesd time: $ts"
