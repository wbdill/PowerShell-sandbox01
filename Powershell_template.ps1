# Desc:      PowerShell template
# Auth:      Brian Dill 2021-01-26
# License:   Shoutout-ware.  If you find this script useful give me a shout out on Twitter @bdill
# GitHubURL: https://github.com/wbdill/PowerShell-sandbox01/blob/master/Powershell_template.ps1
# Other useful stuff: https://pastebin.com/u/bdill

Clear-Host
$Script:error.clear()
#-------------------------------------------------------------------------------
# CONFIG PARAMS
#-------------------------------------------------------------------------------
$CurDate             = Get-Date -Format yyyy-MM-dd_hhmm
$ScriptName          = "My_Powershell_script.ps1"
$LocalPath           = "C:\Tasks\"
$LogFile             = [System.IO.Path]::Combine($LocalPath, "$ScriptName.log")
$SessionLogContainer = ""  #Holding tank for all session LogLine data
#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------
function LogLine { 
	param ( $s )
	$d2 = Get-Date -format "yyyy-MM-dd HH:mm:ss";
	$s = "$d2 - $s";
	Write-Host $s
	$s | Out-File $LogFile -append -Encoding unicode;
	$script:SessionLogContainer += $s + "`n"
}
#-------------------------------------------------------------------------------
# Inline code
#-------------------------------------------------------------------------------



# Do Stuff



#-------------------------------------------------------------------------------
# Email results
#-------------------------------------------------------------------------------
$Smtp = "mail.mycompany.com"  
$From = "MyServer <ITStaff@mycompany.com>"  
$To = "sqldba@mycompany.com"
$Subject = "[PSOps]: SUCCESS - $ScriptName completed $CurDate"
If ($Script:error) {
	IgnoreThisErrorMessage = "If you get a benign Powershell error, but can't figure out how to fix it and don't want to be emailed about it as an error every time, enter the exact error message here"
	If (($Script:error.Count -eq 1) -and ($Script:error[0].Exception.Message -eq $IgnoreThisErrorMessage)) {
		# Do nothing.  Don't care about this specific error, but if any other error happens I still want an email
	} else {
		Logline "The following error(s) were received"
		Logline $Script:error
		$subject = "[PSOps]: ERROR - $ScriptName failed $CurDate"
		Send-MailMessage -SmtpServer $smtp -From $from -To $to -Subject $subject -Body "$SessionLogContainer"
	}
}