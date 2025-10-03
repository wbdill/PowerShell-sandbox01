# Desc: Lists all scheduled tasks and important properties
# Auth: Brian Dill 2021-07-03
# URL:  https://github.com/wbdill/PowerShell-sandbox01/blob/master/GetSchedTasks.ps1
# Inspiration:  https://stackoverflow.com/questions/32731366/how-to-get-trigger-details-associated-with-a-task-in-task-scheduler-from-powersh
# Dependencies: https://dbatools.io/   # Install-Module -Name dbatools  # (must run Powershell as admin to install module)

Clear-Host
#------------------------------------------------------------------------------------------
# Config vars
#------------------------------------------------------------------------------------------
$TaskNameLike   = "*"              # "*" to get all tasks.     "Foo*" to get tasks that start with "Foo"
$TaskFolders    = "\" #, "\TOWER\"   # String array of folders.  "\" = tasks in root folder.  "\Bar\" = all tasks in Bar folder
$SaveToCsv      = 1                # 1 to save, 0 to n\ot save
$CsvSaveFolder  = "C:\Tasks\"      # Where you want to save the CSV output

$TasksResult = @()                 # var to hold results
#------------------------------------------------------------------------------------------
Function BinaryWeekdaysToString {
    param([int]$DaysOfWeek) 
    
    [string]$output = ""
    If ($DaysOfWeek -eq -1) { 
        $output = "No Trigger"
        Return $output;    
    }
    $WeekdaysBits7 = ([convert]::ToString([int32]$DaysOfWeek,2)).PadLeft(7, "0")
    If ($WeekdaysBits7.Substring(0,1) -eq "1") { $output += 'Su,' }
    If ($WeekdaysBits7.Substring(1,1) -eq "1") { $output += 'M,' }
    If ($WeekdaysBits7.Substring(2,1) -eq "1") { $output += 'Tu,' }
    If ($WeekdaysBits7.Substring(3,1) -eq "1") { $output += 'W,' }
    If ($WeekdaysBits7.Substring(4,1) -eq "1") { $output += 'Th,' }
    If ($WeekdaysBits7.Substring(5,1) -eq "1") { $output += 'F,' }
    If ($WeekdaysBits7.Substring(6,1) -eq "1") { $output += 'Sa,' }
    Return $output.TrimEnd(",")
}
#------------------------------------------------------------------------------------------
$TaskFolders | ForEach-Object {
    $TaskFolder= $_
    Get-ScheduledTask -TaskPath $TaskFolder | 
        Where-Object { $_.TaskName-like $TaskNameLike } | ForEach-Object {

        $Task = $_
        Write-Host $Task.TaskName

        Try {
            [string]$Name          = $Task.TaskName
            [string]$Author        = $Task.Author
            [string]$Description   = $Task.Description
            [bool]$Enabled         = $Task.Settings.Enabled
            [string]$Action        = $Task.Actions | Select -ExpandProperty Execute
            [string]$Arguments     = $Task.Actions | Select -ExpandProperty Arguments
            [string]$TaskPath      = $Task.TaskPath

            # Init vars in case no trigger
            [datetime]$Start       = (Get-Date -Month 1 -Day 1 -Year 1900 -Hour 0 -Minute 0 -Second 0) # bogus 1900-01-01 date
            [string]$StartTime     = ""
            [string]$Repetition    = "No Trigger"
            [string]$Duration      = "No Trigger"
            [string]$TriggerDays   = "No Trigger"
            [int]$DaysOfWeek       = -1  # -1 to indicate no trigger

            Try {
                # If the task has a triger, overwrite the trigger vars with valid values
                $Start         = $Task.Triggers | Select -ExpandProperty StartBoundary
                $StartTime     = $Start.ToString("hh:mm")
                #$DaysOfWeek    = $Task.Triggers | Select -Expandproperty DaysOfWeek       #$Task.Triggers[0].DaysOfWeek 
                $Repetition    = $Task.Triggers.Repetition | Select -ExpandProperty Interval
                $Duration      = $Task.triggers.Repetition | Select -ExpandProperty Duration
                #$TriggerDays   = $Task.Triggers | Select -ExpandProperty DaysInterval  #$Task.Triggers[0].DaysInterval
            } Catch {
                Write-Host "--- INFO: No Trigger found for $Name"
            }
            
            $splat = @{
                'TaskPath'    = $TaskPath
                'Name'        = $Name
                'Author'      = $Author
                'Description' = $Description
                'Action'      = $Action
                'Arguments'   = $Arguments
                'Start'       = $Start
                'StartTime'   = $StartTime
                'Duration'    = $Duration
                'Repetition'  = $Repetition
                'DaysOfWeek'  = BinaryWeekdaysToString $DaysOfWeek
                'TriggerDays' = If ($TriggerDays -eq 1) { "Daily" } else { $TriggerDays }
                'Enabled'     = If ($Enabled) { "Enabled" } Else { "-" }
            }

            $obj = New-Object -TypeName PSObject -property $splat
            $TasksResult += $obj
        }
        Catch {
            Write-Host "ERROR: $Error"
        }
    }
}
#------------------------------------------------------------------------------------------
# Output

# select specific columns
$TasksResult = $TasksResult | Select-Object TaskPath, Name, Enabled, DaysOfWeek, TriggerDays, StartTime, Repetition, Duration, Action, Arguments, Description, Author, Start | 
    Sort-Object TaskPath, Name
$TasksResult | Out-GridView

If ($SaveToCsv) {
    $SaveFullPath = [System.IO.Path]::Combine($CsvSaveFolder, "SchedTasks.csv")
    $TasksResult | Export-Csv $SaveFullPath -NoTypeInformation
}
