# bdill 2018-05-16
# Delete all Files in $Path older than $DaysBack
cls
$CurrentDate = Get-Date

function DelFiles {
    Param( [int]$DaysBack, [string]$Path )
    Echo "Deleting older than $DaysBack days of $Path"
    $DaysBack = -1 * $DaysBack
    $DatetoDelete = $CurrentDate.AddDays($Daysback)
    Get-ChildItem -File $Path | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item
}

DelFiles 15 "H:\SQL_Baks\SQL01\Adventureworks\LOG"
DelFiles 60 "H:\SQL_Baks\SQL01\DataWarehouse_Prod\LOG"
DelFiles 30 "H:\SQL_Baks\SQL01\Product02_Prod\LOG"
