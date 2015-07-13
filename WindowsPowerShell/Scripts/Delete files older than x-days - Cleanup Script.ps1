﻿# ------------------------------------------------------------------
# Title: Delete files older than x-days - Cleanup Script
# Author: Jaap Brasser
# Description: Script to delete files older than x-days. The script is built to be used as a scheduled task, it automatically generates a logfile name based on the copy location and the current date/time. There are various levels of logging available and the script can also run in -listonly m
# Date Published: 05-Mar-12 8:36:00 AM
# Source: http://gallery.technet.microsoft.com/scriptcenter/Delete-files-older-than-x-13b29c09
# Tags: Powershell;CleanUp;file
# Rating: 4.6 rated by 5
# ------------------------------------------------------------------

#-------------------------------------------------------------------------------
# DELETEOLD.ps1          ::      Script to delete or list old files in a folder
#-------------------------------------------------------------------------------
#                        Written by Jaap Brasser
#-------------------------------------------------------------------------------
#                 *NOTE* :: -folderpath -fileage <x> and -logfile are required
#                           parameters for DELETEOLD.ps1 to run
#
#
#          -folderpath   :: The path that will be scanned for old files
#          -fileage      :: Filter for age of file, entered in days. Use -1 for all
#
#::
#:: Logging options :
#::
#          -logfile      :: Specifies the full path and filename of the logfile
#                        :: only path is required when using in conjunction with -autolog
#::
#:: Exclusions :
#::
#          -exclude      :: Specifies a path or multiple paths in quotes seperated by
#                        :: commas. Full paths are required, relative paths will not work
#::
#:: Switches :
#::
#          -listonly     :: Only lists, does not remove or modify files
#          -verboselog   :: Logs all delete operations to log, default is failed only
#          -autolog      :: Automatically generates filename at path specified in -logfile
#
#::
#:: Examples :
#::
#          deleteold.ps1 -folderpath h:\scripts -fileage 100 -listonly -logfile h:\log.log
#                        :: Searches through the h:\scripts folder and writes a logfile
#                        :: containing files older than 100 days
#
#          deleteold.ps1 -folderpath h:\scripts -fileage 30 -logfile h:\log.log -verboselog
#                        :: Searches through the h:\scripts folder and deletes files,
#                        :: writes all operations, success and failed, to logfile
#
#          deleteold.ps1 -folderpath c:\docs -fileage 30 -logfile h:\log.log -exclude "c:\docs\finance\","c:\docs\hr\"
#                        :: Searches through the c:\docs folder and deletes files,
#                        :: exluding the finance and hr folders in c:\docs
#
#          deleteold.ps1 -help
#                        :: Displays this screen
#
#          powershell.exe deleteold.ps1 -folderpath 'h:\adm_jaap' -fileage 10 -logfile c:\ltemp.log -verboselog
#                        :: Launches the script from batchfile or command prompt, note
#                        :: quotes '' used for the path

# Defines the parameters used to run this script
param(
[string]$folderpath,
[string]$fileage,
[string]$logfile,
[string[]]$exclude,
[switch]$help,
[switch]$listonly,
[switch]$verboselog,
[switch]$autolog
)

# This functions sets up variables used in this script
function F_SetupVars {
	$script:Startdate = get-date
	$script:LastWrite = $Startdate.AddDays(-$fileage)
	$script:starttime = $startdate.toshortdatestring()+", "+$startdate.tolongtimestring()
	$script:switches = "-folderpath`r`n`t`t`t$folderpath`r`n`t`t-fileage $fileage`r`n`t`t-logfile`r`n`t`t`t$logfile"
	if ($exclude) {
		$script:switches+= "`r`n`t`t-exclude "
		for ($j=0;$j -lt $exclude.count;$j++) {$script:switches+= "`r`n`t`t`t";$script:switches+= $exclude[$j]}
	}
	if ($listonly) {$script:switches+="`r`n`t`t-listonly"}
	if ($verboselog) {$script:switches+="`r`n`t`t-verboselog"}
	if ($autolog) {$script:switches+="`r`n`t`t-autolog"}
	[long]$script:filessize = 0
	[long]$script:failedsize = 0
	[int]$script:filesnumber = 0
	[int]$script:filesfailed = 0
	[int]$script:foldersnumber = 0
	[int]$script:foldersfailed = 0
}

# Function that is triggered when the -autolog switch is active
function F_Autolog {
	# Gets date and reformats to be used in log filename
	$tempdate = get-date
	$tempdate = $tempdate.tostring("dd-MM-yyyy_HHmm.ss")
	# Reformats $folderpath so it can be used in the log filename
	$tempfolderpath = $folderpath -replace '\\','_'
	$tempfolderpath = $tempfolderpath -replace ':',''
	$tempfolderpath = $tempfolderpath -replace ' ',''
	# Checks if the logfile is either pointing at a folder or a logfile and removes
	# Any trailing backslashes
	$testlogpath = Test-Path $logfile -pathtype container
	if (-not $testlogpath) {$logfile = split-path $logfile -Erroraction SilentlyContinue}
	if ($logfile.substring($logfile.length-1,1) -eq "\") {$logfile = $logfile.substring(0,$logfile.length-1)}
	# Combines the date and the path scanned into the log filename
	$script:logfile = "$logfile\Autolog_$tempfolderpath$tempdate.log"
}

# Displays the available variables for the script
function F_Help {
	$starttime = get-date;$starttime = $starttime.toshortdatestring()+", "+$starttime.tolongtimestring()
	write-host "`n"
	write-host ("-"*79)
	write-host " DELETEOLD.ps1`t`t::`tScript to delete or list old files in a folder"
	write-host ("-"*79)
	write-host "`t`t`tWritten by Jaap Brasser"
	write-host ("-"*79)
	write-host "`t`t *NOTE* :: -folderpath -fileage <x> and -logfile are required`n`t`t`t   parameters for deleteold.ps1 to run"
	write-host "`n`n:: Started : $starttime`n`n"
	write-host "`t  -folderpath`t:: The path that will be scanned for old files"
	write-host "`t  -fileage`t:: Filter for age of file, entered in days. Use -1 for all`n"
	write-host "::"
	write-host ":: Logging options :"
	write-host "::"
	write-host "`t  -logfile`t:: Specifies the full path and filename of the logfile`n`t`t`t:: only path is required when using in conjunction with -autolog"
	write-host "::"
	write-host ":: Exclusions :"
	write-host "::"
	write-host "`t  -exclude`t:: Specifies a path or multiple paths in quotes seperated by`n`t`t`t:: commas. Full paths are required, relative paths will not work"
	write-host "::"
	write-host ":: Switches :"
	write-host "::"
	write-host "`t  -listonly`t:: Only lists, does not remove or modify files"
	write-host "`t  -verboselog`t:: Logs all delete operations to log, default is failed only"
	write-host "`t  -autolog`t:: Automatically generates filename at path specified in -logfile`n"
	write-host "::"
	write-host ":: Examples :"
	write-host "::"
	write-host "`t  deleteold.ps1 -folderpath h:\scripts -fileage 100 -listonly -logfile h:\log.log"
	write-host "`t`t`t:: Searches through the h:\scripts folder and writes a logfile`n`t`t`t:: containing files older than 100 days`n"
	write-host "`t  deleteold.ps1 -folderpath h:\scripts -fileage 30 -logfile h:\log.log -verboselog"
	write-host "`t`t`t:: Searches through the h:\scripts folder and deletes files,`n`t`t`t:: writes all operations, success and failed, to logfile`n"	
	write-host "`t  deleteold.ps1 -folderpath c:\docs -fileage 30 -logfile h:\log.log -exclude `"c:\docs\finance\`",`"c:\docs\hr\`""
	write-host "`t`t`t:: Searches through the c:\docs folder and deletes files,`n`t`t`t:: exluding the finance and hr folders in c:\docs`n"	
	write-host "`t  deleteold.ps1 -help"
	write-host "`t`t`t:: Displays this screen`n"
	write-host "`t  powershell.exe deleteold.ps1 -folderpath 'h:\adm_jaap' -fileage 10 -logfile c:\ltemp.log -verboselog"
	write-host "`t`t`t:: Launches the script from batchfile or command prompt, note`n`t`t`t:: quotes '' used for the path`n"
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit
}

# Function which contains the loop in which files are deleted. If a file fails to be deleted
# an error is logged and the error message is written to the log
# $count is used to speed up the delete fileloop and will also be used for other large loops in the script
function F_Deleteoldfiles {
	$count = $filelist.count
	for ($j=0;$j -lt $count;$j++) {
		$tempfile = $filelist[$j].fullname
		$tempsize = $filelist[$j].length
		if(-not $listonly) {remove-item $tempfile -force -ErrorAction SilentlyContinue}
		if (-not $?) {
			$tempvar = $error[0].tostring()
			"`tFAILED FILE`t`t$tempvar" >> $logfile
			$script:filesfailed++
			$script:failedsize+=$tempsize
		}
			else {
				if (-not $listonly) {$script:filesnumber++;$script:filessize+=$tempsize;if ($verboselog) {"`tDELETED FILE`t$tempfile" >> $logfile}}
			}
		if($listonly) {"`tLISTONLY`t`t$tempfile" >> $logfile
			$script:filesnumber++
			$script:filessize+=$tempsize
		}
	}
}

# Checks whether folder is empty and uses temporary variables
# Main loop goes through list of folders, only deleting the empty folders
# The if(-not $tempfolder) is the verification whether the folder is empty
function F_Checkforemptyfolder {
	$folderlist = $folderlist | sort-object @{Expression={$_.fullname.length}; Ascending=$false}
	$count = $folderlist.count
	for ($j=0;$j -lt $count;$j++) {
		$tempfolder = get-childitem $folderlist[$j].fullname -ErrorAction SilentlyContinue
		if (-not $tempfolder) {
		$tempname = $folderlist[$j].fullname
		remove-item $tempname -force -recurse -ErrorAction SilentlyContinue
			if(-not $?) {
				$tempvar = $error[0].tostring()
				"`tFAILED FOLDER`t$tempvar" >> $logfile
				$script:foldersfailed++
			}
				else {
					if ($verboselog) {"`tDELETED FOLDER`t$tempname" >> $logfile}
					$script:foldersnumber++
				}
		}
	}
}

# Writes footer to the logfile
function F_Writefooterlog {
	" " >> $logfile
	("-"*79) >> $logfile
	" " >> $logfile
	"   Files               : $filesnumber" >> $logfile
	"   Filesize(MB)        : $filessize" >> $logfile
	"   Files Failed        : $filesfailed" >> $logfile
	"   Failedfile Size(MB) : $failedsize" >> $logfile
	"   Folders             : $foldersnumber" >> $logfile
	"   Folders Failed      : $foldersfailed" >> $logfile
	" " >> $logfile
	"   Finished Time       : $enddate" >> $logfile
	"   Time Taken          : $timetaken" >> $logfile
	" " >> $logfile
	("-"*79) >> $logfile
}

# Check if correct parameters are used
if ($help) {F_help}
if (-not $folderpath) {F_help}
if (-not $fileage) {F_help}
if (-not $logfile) {F_help}
if ($autolog) {F_Autolog}

# Sets up the variables
F_SetupVars

# Output text to console and write log header
write-host ("-"*79)
write-host "  Deleteold`t::`tScript to delete old files from folders"
write-host ("-"*79)
write-host "`n   Started  :   $starttime`n   Folder   :`t$folderpath`n   Switches :`t$switches`n"
if ($listonly){write-host "`t*** Running in Listonly mode, no files will be modified ***`n"}
write-host ("-"*79)
("-"*79) > $logfile
"  Deleteold`t::`tScript to delete old files from folders" >> $logfile
("-"*79) >> $logfile
" " >> $logfile
"   Started  :   $starttime" >> $logfile
" " >> $logfile
"   Folder   :   $folderpath" >> $logfile
" " >> $logfile
"   Switches :   $switches" >> $logfile
" " >> $logfile
("-"*79) >> $logfile
" " >> $logfile

# Checks if all values in $exclude end with \, if not present it will add it
# Reformats the $exclude so the -notmatch command works, all slashes are repeat twice
# eg: c:\temp\ becomes c:\\temp\\
for ($j=0;$j -lt $exclude.count;$j++) {
	if ($exclude[$j].substring($exclude[$j].length-1,1) -ne "\") {$exclude[$j] = $exclude[$j] + "\"}
}
$exclude = $exclude -replace '\\','\\'

# Get the complete list of files and save to array
write-host "`n   Retrieving list of files and folders from: $folderpath"
$checkerror = $error.count
$fullarray = @(get-childitem $folderpath -recurse -ErrorAction SilentlyContinue -force | select-object Fullname,LastWriteTime,Attributes,Length,PSIsContainer)

# Catches errors during read stage and writes to log, mostly catches permissions errors
$checkerror = $error.count - $checkerror
if ($checkerror -gt 0) {
	for ($j=0;$j -lt $checkerror;$j++) {
		$temperror = $error[$j].tostring()
		"`tFAILED ACCESS`t$temperror" >> $logfile
	}
}

# Split the complete list of items into three seperate lists $folderlist, $filelist
$folderlist = @($fullarray | Where-Object {$_.PSIsContainer -eq $True})
$filelist = @($fullarray | Where-Object {$_.PSIsContainer -eq $False})

# If the exclusion parameter is included then this loop will run. This will clear out the 
# excluded paths for both the filelist as well as the folderlist. After cleaning up filelist
# this loop removes trailing backslash for folder verification
if ($exclude)
{
	for ($j=0;$j -lt $exclude.count;$j++) {
		$filelist = $filelist | ? {$_.fullname -notmatch $exclude[$j]}
		$exclude[$j] = $exclude[$j].substring(0,$exclude[$j].length-2)
		$folderlist = $folderlist | ? {$_.fullname -notmatch $exclude[$j]}
	}
}

# Counter for prompt output
$allfilecount = $filelist.count

# Clear original array containing files and folders and create array with list of older files
$fullarray = ""
$filelist = @($filelist | where {$_.LastWriteTime -le $LastWrite})

# Write totals to console
write-host 	"`n   Files`t: $allfilecount`n   Folders`t:"$folderlist.count"`n   Old files`t:"$filelist.count

# Execute main functions of script
if (-not $listonly) {write-host "`n   Starting with removal of old files..."}
	else {write-host "`n   Listing files..."}
F_Deleteoldfiles
if (-not $listonly) {write-host "   Finished deleting files`n"}
	else {write-host "   Finished listing files`n"}
if (-not $listonly)
{
	write-host "   Check/remove empty folders started..."
	F_Checkforemptyfolder
	write-host "   Empty folders deleted`n"
}

# Pre-format values for footer
$enddate = get-date
$timetaken = $enddate - $startdate
$timetaken = $timetaken.tostring()
$timetaken = $timetaken.substring(0,8)
$filessize = $filessize/1MB
[string]$filessize = $filessize.ToString()
$failedsize = $failedsize/1MB
[string]$failedsize = $failedsize.ToString()
$enddate = $enddate.toshortdatestring()+", "+$enddate.tolongtimestring()

# Output results to console
write-host ("-"*79)
write-host " "
write-host "   Files               : $filesnumber"
write-host "   Filesize(MB)        : $filessize"
write-host "   Files Failed        : $filesfailed"
write-host "   Failedfile Size(MB) : $failedsize"
write-host "   Folders             : $foldersnumber"
write-host "   Folders Failed      : $foldersfailed`n"
write-host "   Finished Time       : $enddate"
write-host "   Total Time          : $timetaken`n"
write-host ("-"*79)

# Write footer to logfile
F_Writefooterlog

# Clean up variables at end of script
$filelist = ""
$folderlist = ""
# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUgvCC7egYHyzqonCPubxLpPUP
# QFWgggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTE0MDcxNzAwMDAwMFoXDTE1MDcy
# MjEyMDAwMFowaTELMAkGA1UEBhMCQ0ExCzAJBgNVBAgTAk9OMREwDwYDVQQHEwhI
# YW1pbHRvbjEcMBoGA1UEChMTRGF2aWQgV2F5bmUgSm9obnNvbjEcMBoGA1UEAxMT
# RGF2aWQgV2F5bmUgSm9obnNvbjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
# ggEBAM3+T+61MoGxUHnoK0b2GgO17e0sW8ugwAH966Z1JIzQvXFa707SZvTJgmra
# ZsCn9fU+i9KhC0nUpA4hAv/b1MCeqGq1O0f3ffiwsxhTG3Z4J8mEl5eSdcRgeb+1
# jaKI3oHkbX+zxqOLSaRSQPn3XygMAfrcD/QI4vsx8o2lTUsPJEy2c0z57e1VzWlq
# KHqo18lVxDq/YF+fKCAJL57zjXSBPPmb/sNj8VgoxXS6EUAC5c3tb+CJfNP2U9vV
# oy5YeUP9bNwq2aXkW0+xZIipbJonZwN+bIsbgCC5eb2aqapBgJrgds8cw8WKiZvy
# Zx2qT7hy9HT+LUOI0l0K0w31dF8CAwEAAaOCAbswggG3MB8GA1UdIwQYMBaAFFrE
# uXsqCqOl6nEDwGD5LfZldQ5YMB0GA1UdDgQWBBTnMIKoGnZIswBx8nuJckJGsFDU
# lDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwdwYDVR0fBHAw
# bjA1oDOgMYYvaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1j
# cy1nMS5jcmwwNaAzoDGGL2h0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFz
# c3VyZWQtY3MtZzEuY3JsMEIGA1UdIAQ7MDkwNwYJYIZIAYb9bAMBMCowKAYIKwYB
# BQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwgYQGCCsGAQUFBwEB
# BHgwdjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME4GCCsG
# AQUFBzAChkJodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEy
# QXNzdXJlZElEQ29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG
# 9w0BAQsFAAOCAQEAVlkBmOEKRw2O66aloy9tNoQNIWz3AduGBfnf9gvyRFvSuKm0
# Zq3A6lRej8FPxC5Kbwswxtl2L/pjyrlYzUs+XuYe9Ua9YMIdhbyjUol4Z46jhOrO
# TDl18txaoNpGE9JXo8SLZHibwz97H3+paRm16aygM5R3uQ0xSQ1NFqDJ53YRvOqT
# 60/tF9E8zNx4hOH1lw1CDPu0K3nL2PusLUVzCpwNunQzGoZfVtlnV2x4EgXyZ9G1
# x4odcYZwKpkWPKA4bWAG+Img5+dgGEOqoUHh4jm2IKijm1jz7BRcJUMAwa2Qcbc2
# ttQbSj/7xZXL470VG3WjLWNWkRaRQAkzOajhpTCCBTAwggQYoAMCAQICEAQJGBtf
# 1btmdVNDtW+VUAgwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIG
# A1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTEzMTAyMjEyMDAw
# MFoXDTI4MTAyMjEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGln
# aUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAPjTsxx/DhGvZ3cH0wsxSRnP0PtFmbE620T1
# f+Wondsy13Hqdp0FLreP+pJDwKX5idQ3Gde2qvCchqXYJawOeSg6funRZ9PG+ykn
# x9N7I5TkkSOWkHeC+aGEI2YSVDNQdLEoJrskacLCUvIUZ4qJRdQtoaPpiCwgla4c
# SocI3wz14k1gGL6qxLKucDFmM3E+rHCiq85/6XzLkqHlOzEcz+ryCuRXu0q16XTm
# K/5sy350OTYNkO/ktU6kqepqCquE86xnTrXE94zRICUj6whkPlKWwfIPEvTFjg/B
# ougsUfdzvL2FsWKDc0GCB+Q4i2pzINAPZHM8np+mM6n9Gd8lk9ECAwEAAaOCAc0w
# ggHJMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQM
# MAoGCCsGAQUFBwMDMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8E
# ejB4MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1
# cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsME8GA1UdIARIMEYwOAYKYIZIAYb9
# bAACBDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BT
# MAoGCGCGSAGG/WwDMB0GA1UdDgQWBBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAfBgNV
# HSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQsFAAOCAQEA
# PuwNWiSz8yLRFcgsfCUpdqgdXRwtOhrE7zBh134LYP3DPQ/Er4v97yrfIFU3sOH2
# 0ZJ1D1G0bqWOWuJeJIFOEKTuP3GOYw4TS63XX0R58zYUBor3nEZOXP+QsRsHDpEV
# +7qvtVHCjSSuJMbHJyqhKSgaOnEoAjwukaPAJRHinBRHoXpoaK+bp1wgXNlxsQyP
# u6j4xRJon89Ay0BEpRPw5mQMJQhCMrI2iiQC/i9yfhzXSUWW6Fkd6fp0ZGuy62ZD
# 2rOwjNXpDd32ASDOmTFjPQgaGLOBm0/GkxAG/AeB+ova+YJJ92JuoVP6EpQYhS6S
# kepobEQysmah5xikmmRR7zGCAigwggIkAgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# MTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcg
# Q0ECEALqUCMY8xpTBaBPvax53DkwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwx
# CjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGC
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFNhJefreW9jrderW
# eVJAUyh66Pe0MA0GCSqGSIb3DQEBAQUABIIBAJ0dOpleDjMHTWFuYIkwm6FPe/2b
# zFcLVf9AhXuUimCIs5N2mMzY6tQ/ocsnl58gsML1ZO7664RS/PBJ/7a8+cMdAoBd
# iNUe1f6xktJA7lcYM/w70xlwCPTch/+PKjebSIMSdHSboQzHOdky6thdIM9XmgVx
# MbZGC3trlvaAJeofmXWr3hRhvULauOXfpt0iCJBsXBLMUraQnLMLvpylSk7cZWjf
# S7cGQ9gRas5dA+q6y3+lD+i+SMGQetNdFG5sDqoKq8KVXVdvnxmayrtqrIPgyGxS
# WjzQQn8jTCYcC8jRybDojBoPBHwD7FYO2QBLlaKQann3iM+nIlblbD4+6aU=
# SIG # End signature block
