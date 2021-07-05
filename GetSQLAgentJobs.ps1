#------------------------------------------------------------------------------------------
# Desc: Powershell to document SQL Agent Jobs from one or more SQL instances
# Auth: Brian Dill 2021-07-04
# GitHub: https://github.com/wbdill/PowerShell-sandbox01/blob/master/GetSQLAgentJobs.ps1
# Dependencies: Join module        # Install-Module -Name JoinModule  # need to Run Powershell as admin to be able to install
#               dbatools.io module # Install-Module -Name dbatools    # need to Run Powershell as admin to be able to install
#------------------------------------------------------------------------------------------
# ----- Primary cmdlets -----
# Get-DbaAgentJob         # https://docs.dbatools.io/Get-DbaAgentJob
# Get-DbaAgentJobStep     # https://docs.dbatools.io/#Get-DbaAgentJobStep
# Get-DbaAgentSchedule    # https://docs.dbatools.io/#Get-DbaAgentSchedule
# Get-DbaAgentJobHistory  # https://docs.dbatools.io/#Get-DbaAgentJobHistory
# Join-Object             # https://www.powershellgallery.com/packages/Join/

Clear-Host
#------------------------------------------------------------------------------------------
# Config Params
#------------------------------------------------------------------------------------------
$SqlInstances        = "ProdSQL01", "ProdSQL02", "ProdSQL03", "SomeSQLServer\Instancename"

$ShowJobsPopup         = 1   # Jobs only       1=Yes, 0=No
$ShowStepsPopup        = 0   # Steps Only
$ShowSchedulesPopup    = 0   # Schedules only

$ShowJobStepsPopup     = 0   # Join of Jobs and Steps (job data repeats for each step)
$ShowJobSchedulesPopup = 0   # Join of Jobs and Schedules (joining on first Schedule ONLY!  If a job has > 1 schedules, refer to SqlAgentSchedules.csv)

$SaveCsvFiles          = 1   # Save CSV files? # 1=Yes, 0=No
$CsvSaveFolder         = "C:\Tasks\"
$CsvJobsFile           = [System.IO.Path]::Combine($CsvSaveFolder, "SqlAgentJobs.csv")
$CsvStepsFile          = [System.IO.Path]::Combine($CsvSaveFolder, "SqlAgentJobSteps.csv")
$CsvSchedulesFile      = [System.IO.Path]::Combine($CsvSaveFolder, "SqlAgentSchedules.csv")
$CsvJobSchedJoinFile   = [System.IO.Path]::Combine($CsvSaveFolder, "SqlAgentJobSchedulesJoin.csv")


$JobsResult = @()
$StepsResult = @()
$SchedulesResult = @()
#------------------------------------------------------------------------------------------
Function BinaryWeekdaysToStringSatToSun {
    # Converts the decimal $DaysOfWeek value to a 7 digit binary value 0000000 which represents on/off for: Sa, F, Th, W, Tu, M, Su
    param([int]$DaysOfWeek)   # ex: 62 = 0111110 = M,Tu,W,Th,F.    ex: 9 = 0001001 = Su, W
    
    [string]$output = ""
    If ($DaysOfWeek -eq -1) { 
        $output = "No Trigger"
        Return $output;    
    }
    $WeekdaysBits7 = ([convert]::ToString([int32]$DaysOfWeek,2)).PadLeft(7, "0")
    If ($WeekdaysBits7.Substring(6,1) -eq "1") { $output += 'Su,' }
    If ($WeekdaysBits7.Substring(5,1) -eq "1") { $output += 'M,' }
    If ($WeekdaysBits7.Substring(4,1) -eq "1") { $output += 'Tu,' }
    If ($WeekdaysBits7.Substring(3,1) -eq "1") { $output += 'W,' }
    If ($WeekdaysBits7.Substring(2,1) -eq "1") { $output += 'Th,' }
    If ($WeekdaysBits7.Substring(1,1) -eq "1") { $output += 'F,' }
    If ($WeekdaysBits7.Substring(0,1) -eq "1") { $output += 'Sa,' }
    Return $output.TrimEnd(",")
}

#------------------------------------------------------------------------------------------
# Jobs
#------------------------------------------------------------------------------------------
$SqlInstances | ForEach-Object {
    $Jobs = Get-DbaAgentJob -SqlInstance $_
    $Jobs | ForEach-Object {
        $Job = $_
        $SqlInstance       = $Job.SqlInstance
        $JobName           = $Job.Name
        $JobEnabled        = If($Job.Enabled) { 1 } Else { 0 }
        $HasSchedule       = If($Job.HasSchedule) { 1 } Else { 0 }
        $JobLastRunDate    = $Job.LastRunDate
        $JobNextRunDate    = $Job.NextRunDate
        $JobLastRunOutcome = $Job.LastRunOutcome
        $StepCount         = $Job.JobSteps.Count
        $JobDescription    = $Job.Description
        $JobCreateDate     = $Job.CreateDate
        $ScheduleID        = $null
        $ScheduleIDs       = $null
        $NumOfSchedules    = 0

        If ($HasSchedule) {
            $NumOfSchedules  = $Job.JobSchedules.Count
            $ScheduleID      = $Job.JobSchedules[0].ID
            $ScheduleIDs     = $Job.JobSchedules | Select -ExpandProperty ID
            $ScheduleIDs     = $ScheduleIDs -join ","
        }

        $splat = @{
            'SqlInstance'         = $SqlInstance
            'JobName'             = $JobName
            'JobEnabled'          = $JobEnabled
            'StepCount'           = $StepCount
            'NumOfSchedules'      = $NumOfSchedules
            'HasSchedule'         = $HasSchedule
            'JobLastRunDate'      = $JobLastRunDate
            'JobNextRunDate'      = $JobNextRunDate
            'JobLastRunOutcome'   = $LastRunOutcome
            'ScheduleID'          = $ScheduleID
            'ScheduleIDs'         = $ScheduleIDs
            'JobCreateDate'       = $JobCreateDate
            'JobDescription'      = $JobDescription
        }
        $JobsResult += New-Object -TypeName PSObject -property $splat
    }
}
$JobsResult = $JobsResult | Select SqlInstance, JobName, StepCount, JobEnabled, HasSchedule, NumOfSchedules, ScheduleID, ScheduleIDs, JobLastRunDate, JobLastRunOutcome, JobNextRunDate, JobCreateDate, JobDescription |
    Sort-Object SqlInstance, JobName

#------------------------------------------------------------------------------------------
# Steps
#------------------------------------------------------------------------------------------
$SqlInstances | ForEach-Object {
    $Steps = Get-DbaAgentJobStep -SqlInstance $_
    $Steps | ForEach-Object {
        $Step                = $_
        $SqlInstance         = $Step.SqlInstance
        $JobName             = $Step.AgentJob
        $StepName            = $Step.Name
        $Command             = $Step.Command
        $SuccessCode         = $Step.CommandExecutionSuccessCode
        $Database            = $Step.DatabaseName
        $StepLastRunDate     = $Step.LastRunDate
        $StepLastRunDuration = $Step.LastRunDuration
        $StepLastRunOutcome  = $Step.LastRunOutcome
        $Subsystem           = $Step.SubSystem
        $StepID              = $Step.ID

        $splat = @{
            'SqlInstance'         = $SqlInstance
            'JobName'             = $JobName
            'StepID'              = $StepID
            'StepName'            = $StepName
            'Subsystem'           = $Subsystem
            'Command'             = $Command
            'SuccessCode'         = $SuccessCode
            'Database'            = $Database
            'StepLastRunDate'     = $StepLastRunDate
            'StepLastRunDuration' = $StepLastRunDuration
            'StepLastRunOutcome'  = $StepLastRunOutcome
        }
        $StepsResult += New-Object -TypeName PSObject -property $splat
    }
}
$StepsResult = $StepsResult | Select SqlInstance, JobName, StepID, StepName, Database, SubSystem, Command, StepLastRunDate, StepLastRunDuration, StepLastRunOutcome | 
    Sort-Object SqlInstance, JobName, StepID

#------------------------------------------------------------------------------------------
# Schedules
#------------------------------------------------------------------------------------------
$SqlInstances | ForEach-Object {
    $Schedules = Get-DbaAgentSchedule -SqlInstance $_
    $Schedules | ForEach-Object {
        $Schedule            = $_
        $SqlInstance         = $Schedule.SqlInstance
        $ScheduleName        = $Schedule.Name
        $ScheduleID          = $Schedule.ID
        $ScheduleEnabled     = If ($Schedule.IsEnabled) { 1 } Else { 0 }
        $StartTime           = $Schedule.ActiveStartTimeOfDay
        $ScheduleDescription = $Schedule.Description
        $JobCount            = $Schedule.JobCount
        $FreqInterval        = $Schedule.FrequencyInterval
        $FreqRecurFactor     = $Schedule.FrequencyRecurrenceFactor
        $FreqRelInterval     = $Schedule.FrequencyRelativeIntervals
        $FreqSubDayInterval  = $Schedule.FrequencySubDayInterval
        $FreqSubDayTypes     = $Schedule.FrequencySubDayTypes
        $FreqTypes           = $Schedule.FrequencyTypes
        $FreqDays            = If ($FreqTypes -eq "Daily") { "" } Else { BinaryWeekdaysToStringSatToSun $FreqInterval }
        $RepeatEvery         = If ($FreqSubDayTypes -ne "Once" -and $FreqSubDayTypes -ne "Unknown") { 
                                 "Repeat every $FreqSubDayInterval $FreqSubDayTypes`(s)" 
                               } Else { "" }
        $splat = @{
            'SqlInstance'         = $SqlInstance
            'ScheduleName'        = $ScheduleName
            'ScheduleID'          = $ScheduleID
            'ScheduleEnabled'     = $ScheduleEnabled
            'StartTime'           = $StartTime
            'ScheduleDescription' = $ScheduleDescription
            'JobCount'            = $JobCount
            'FreqInterval'        = $FreqInterval
            'FreqDays'            = $FreqDays
            'FreqRecurFactor'     = $FreqRecurFactor
            'FreqRelInterval'     = $FreqRelInterval
            'FreqSubDayInterval'  = $FreqSubDayInterval
            'FreqSubDayTypes'     = $FreqSubDayTypes
            'FreqTypes'           = $FreqTypes
            'RepeatEvery'         = $RepeatEvery
        }
        $SchedulesResult += New-Object -TypeName PSObject -property $splat
    }
}
$SchedulesResult = $SchedulesResult | 
    Select SqlInstance, ScheduleName, ScheduleID, ScheduleEnabled, FreqTypes, FreqDays, StartTime, RepeatEvery, JobCount, FreqInterval, FreqRecurFactor, FreqRelInterval, FreqSubDayInterval, FreqSubDayTypes, ScheduleDescription |
    Sort-Object SqlInstance, ScheduleName

#------------------------------------------------------------------------------------------
# Output


#------------------------------------------------------------------------------------------
# Show popus
If ($ShowJobsPopup) { $JobsResult | Out-GridView }
If ($ShowStepsPopup) { $StepsResult | Out-GridView }
If ($ShowSchedulesPopup) { $SchedulesResult | Out-GridView }

If ($ShowJobStepsPopup) {
    $JobSteps = $JobsResult | LeftJoin $StepsResult -On 'JobName', 'SqlInstance' | `
      Select SqlInstance, JobName, StepCount, NumOfSchedules, ScheduleID, ScheduleIDs, JobLastRunDate, StepID, StepName, Database, Subsystem, Command, StepLastRunDate, StepLastRunDuration, StepLastRunOutcome |
      Sort-Object SqlInstance, JobName, StepID
    $JobSteps | Out-GridView
}

If ($ShowJobSchedulesPopup) {
    $JobSchedules = $JobsResult | LeftJoin $SchedulesResult -On 'ScheduleID', 'SqlInstance' | 
        Select SqlInstance, JobName, StepCount, JobEnabled, NumOfSchedules, ScheduleID, ScheduleIDs, ScheduleName, ScheduleEnabled, FreqTypes, FreqDays, StartTime, RepeatEvery, ScheduleDescription, JobDescription |
        Sort-Object SqlInstance, JobName 
    $JobSchedules | Out-GridView
}
#------------------------------------------------------------------------------------------
# Save CSV files
If ($SaveCsvFiles) {
    Try {
        $JobsResult | Export-Csv -Path $CsvJobsFile -NoTypeInformation
        $StepsResult | Export-Csv -Path $CsvStepsFile -NoTypeInformation
        $SchedulesResult | Export-Csv -Path $CsvSchedulesFile -NoTypeInformation
        $CsvJobSchedJoinFile | Export-Csv $JobSchedules -NoTypeInformation
    }
    Catch {
        #Write-Host "  Error saving CSV file(s): $Error"
    }
}