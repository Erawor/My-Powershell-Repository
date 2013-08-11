<#
.SYNOPSIS
       The purpose of this script is to generate a crawl status report for each content source and email the report
.DESCRIPTION
       The purpose of this script is to generate a crawl status report for each content source and email the report
	   
.EXAMPLE
.\Report-ContentStatus.ps1 -GenerateSampleReport
Generates a sample report
.EXAMPLE
.\Report-ContentStatus.ps1 -GenerateSampleConfigurationFile 
Generate a sample configuration file
.EXAMPLE
.\Report-ContentStatus.ps1 -ConfigurationFile ..\GR06.config -DebugMode -reportsFromEmail testemailfrom -farmName testfarmname -reportsToEmail testtoemail -smtpserver testsmtpserver -fastContentSSAName FASTContent
Specify a config file and override the values
.EXAMPLE
.\Report-ContentStatus.ps1 -DebugMode
Run in debug mode

.EXAMPLE
.\Report-ContentStatus.ps1 -ConfigurationFile .\Report-ContentStatus.config
Run using a specific config file
.LINK
This Script - http://gallery.technet.microsoft.com/scriptcenter/a89e11a0-cbe3-4ac9-b0fb-81cc2837ffbe
.NOTES
  File Name : Report-ContentStatus.ps1
  Author    : Ben Lin, Brent Groom 
#>

# TODO - implement uninstall and validate

param
  (
	
    [switch]
    # Signifies whether the script should send an email
    $SendEmail, 
    
	[switch]
    # Signifies that the script should output debug statements
    $DebugMode, 
    
    [string]
    # Specifies confuguration file name. The default is "this script name".config. i.e. 
    # Report-ContentStatus.config
    $ConfigurationFile="", 
    
    [switch]
    # Specifies whether the script should generate a sample configuration file. If you specify this flag, 
    # the script will generate the file and exit.
    $GenerateSampleConfigurationFile,
	
	[switch]
    # Allows you to generate a sample report
    $GenerateSampleReport,
	
    [string]
    # Allows you to specify the From: email address from the command line 
	$reportsFromEmail = "",
    
	[string]
    # Allows you to specify the To: email address from the command line 
	$reportsToEmail = "",
    
	[string]
    # Allows you to specify the SMTP Server from the command line 
	$smtpserver = "",
    
	[string]
    # Allows you to specify the Farm name from the command line 
	$farmName = "",
    
	[string]
    # Allows you to specify the FAST Content SSA from the command line 
	$fastContentSSAName = ""

    
    )

Add-PSSnapin AdminSnapIn -erroraction SilentlyContinue 
Add-PsSnapin Microsoft.SharePoint.PowerShell -erroraction SilentlyContinue 
Add-PSSnapin Microsoft.FASTSearch.PowerShell -erroraction SilentlyContinue 

# reference: 
# This script: http://gallery.technet.microsoft.com/scriptcenter/a89e11a0-cbe3-4ac9-b0fb-81cc2837ffbe

$global:configurationname = $myinvocation.mycommand.name.Substring(0, $myinvocation.mycommand.name.IndexOf('.'))
$debug = $false

$global:currentFarm = Get-SPFarm

$global:reportsFromEmail = ""
$global:reportsToEmail = ""
$global:smtpserver = ""
$global:farmName = ""
$global:fastContentSSAName = ""

<#

# you can set the farm properties by using the Set-FarmProperties Powershell script

#>


Function FunctionGenerateSampleConfigurationFile()
{
    $funcname = "FunctionGenerateSampleConfigurationFile"
    if ($DebugMode) { "Starting  $funcname " }

"Writing file $configurationname.config"
$selfdocumentingxml = @" 
<Configuration>
  <configurationSection>
      <Report-ContentStatus> 
       <properties>
	      <!-- These name/value pairs allow you to use a different name in the property bag 
		       and the script will match it up. -->
          <property name="FarmName"           value = "FarmName"/>
          <property name="ReportsFromEmail"   value = "ReportsFromEmail"/>
          <property name="ReportsToEmail"     value = "ReportsToEmail"/>
          <property name="smtpserver"         value = "smtpserver"/>
          <property name="FastContentSSA"     value = "FastContentSSA"/>		  
        </properties>
      </Report-ContentStatus>       
  </configurationSection>
 </Configuration>
"@ | Out-File "$configurationname.config"
    if ($DebugMode) { "Finished $funcname " }

} 

Function FunctionGenerateSampleReport()
{
    $funcname = "FunctionGenerateSampleReport"
    if ($DebugMode) { "Starting  $funcname " }

"Writing file $configurationname.sample.html"
$selfdocumentingxml = @" 
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"> 
<html xmlns="http://www.w3.org/1999/xhtml">
<head> <title>HTML TABLE</title> </head>
<body> <h3>Content Status Report for Farm: GR06 Farm</h3> 
<h4>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Friday, June 03, 2011 10:02:43 AM</h4> 
<table border="1" cellpadding="4" > <colgroup> <col/> <col/> <col/> <col/> <col/> <col/> <col/> </colgroup>
<tr><th>Name</th><th>Duration</th><th>Started</th><th>Completed</th><th>Success</th><th>Warnings</th><th>Errors</th></tr> 
<tr><td>UT100</td><td align="center">00:01:40</td><td align="center">06/01 12:23</td><td align="center">06/01 12:25</td>
<td align="center">3</td><td align="center">0</td><td align="center">0</td></tr> <tr><td>spsite</td>
<td align="center">00:03:22</td><td align="center">05/26 08:55</td><td align="center">05/26 08:59</td>
<td align="center">67</td><td align="center">7</td><td align="center">0</td></tr> <tr><td>y</td>
<td align="center">00:11:46</td><td align="center">03/10 13:47</td><td align="center">03/10 13:59</td>
<td align="center">38</td><td align="center">0</td><td align="center">0</td></tr> <tr><td>Golden Set</td>
<td align="center">00:02:22</td><td align="center">03/04 14:31</td><td align="center">03/04 14:33</td>
<td align="center">26</td><td align="center">0</td><td align="center">0</td></tr> 
<tr><td>xmlmappercontent</td><td align="center">00:01:50</td><td align="center">11/10 15:04</td>
<td align="center">11/10 15:06</td><td align="center">16</td><td align="center">0</td><td align="center">0</td></tr> 
<tr><td>Oracle Scott 4</td><td align="center">00:02:42</td><td align="center">09/27 12:38</td>
<td align="center">09/27 12:40</td><td align="center">16</td><td align="center">0</td><td align="center">0</td></tr> 
</table> </body></html>
"@ | Out-File "$configurationname.sample.html"
    if ($DebugMode) { "Finished $funcname " }

} 



Function scriptSetup([xml]$thedata)
{

	$funcname = "scriptSetup"
	if ($DebugMode) { write-host ("Starting  $funcname" ) -Foregroundcolor Green }

	$props = $thedata.SelectNodes("Configuration/configurationSection/Report-ContentStatus/properties/property")

	# Check to see if any of the properties are already set
	
	if(!$props -or $props -eq $null -or $props.length -eq 0)
	{
		"No properties set. Using defaults"
		if ($reportsFromEmail.Length -eq 0)	{ $global:reportsFromEmail = $currentFarm.Properties["ReportsFromEmail"] }
		$global:reportsToEmail = $currentFarm.Properties["ReportsToEmail"]
		$global:smtpserver = $currentFarm.Properties["smtpserver"]
		$global:farmName = $currentFarm.Properties["FarmName"]		  
		$global:fastContentSSAName = $currentFarm.Properties["FastContentSSA"]		  
		if ($DebugMode) { " Using the following properties and values: `n  farmName:$farmName `n  smtpserver:$smtpserver  "  }
		if ($DebugMode) { " `n  reportsToEmail:$reportsToEmail  `n  reportsFromEmail:$reportsFromEmail"  }

	}

	if ($DebugMode) { "  Using the following properties and values: "  }

	foreach ($prop in $props)
	{ 
	
		$propname = $prop.name
		$propvalue = $prop.value
      
		if ($DebugMode) { "  $configurationname.$funcname() property name="+$propname +" value="+$propvalue  }

	
	
		if($prop.name -eq "FarmName") 
		{
			$global:farmName = $currentFarm.Properties[$propvalue]		  
			if ($DebugMode) { "`n  farmName:$farmName"  }
		}
		if($prop.name -eq "FastContentSSA") 
		{
			$global:fastContentSSAName = $currentFarm.Properties[$prop.value]		  
			if ($DebugMode) { "`n  "+$prop.value+":$fastContentSSAName"  }
		}
		if($prop.name -eq "smtpserver") 
		{
			$global:smtpserver = $currentFarm.Properties[$prop.value]		  
			if ($DebugMode) { "smtpserver:$smtpserver  "  }
		}
		if($prop.name -eq "ReportsToEmail") 
		{
			$global:reportsToEmail = $currentFarm.Properties[$prop.value]		  
			if ($DebugMode) { "`n  reportsToEmail:$reportsToEmail"  }
		}
		if($prop.name -eq "ReportsFromEmail") 
		{
			if ($reportsFromEmail.Length -eq 0)	{ $global:reportsFromEmail = $currentFarm.Properties[$prop.value] }
			if ($DebugMode) { "`n  reportsFromEmail:$reportsFromEmail"  }
		}      
    
	}
	
	if ($DebugMode) { write-host ("Finished  $funcname" ) -Foregroundcolor Red }
}


Function main()
{

    $funcname = "main"


    if ($DebugMode) { write-host ("  Starting  $funcname" ) -Foregroundcolor Green }
	if ($DebugMode) { write-host ("  DebugMode = $DebugMode" ) -Foregroundcolor Green }

	write-host ("Configuration file set to: $ConfigurationFile" )  -Foregroundcolor Green
	
    [xml]$xmldata = [xml](Get-Content $ConfigurationFile)
    if($DebugMode)
    {
      $xmldata.get_InnerXml()
      $ConfigurationFile
	}

    scriptSetup $xmldata
	
    $reportTitle = "Content Status Report for Farm: $farmName"

	$f = "Report-ContentStatus.htm"
	$currDate = get-date -format F
	
	$searchapp = Get-SPEnterpriseSearchServiceApplication $fastContentSSAName
	$contentsources = Get-SPEnterpriseSearchCrawlContentSource -SearchApplication $searchapp 

	$contentsourcelist = Get-SPEnterpriseSearchCrawlContentSource -SearchApplication $searchapp | sort -descending CrawlCompleted | select-object Name, @{Expression={$_.CrawlCompleted - $_.CrawlStarted};Label="Duration"} , @{Expression={Get-Date $_.CrawlStarted -format "MM/dd HH:mm"};Label="Started"}, @{Expression={Get-Date $_.CrawlCompleted -format "MM/dd HH:mm"};Label="Completed"}, @{Expression={$_.SuccessCount };Label="Success"}, @{Expression={$_.WarningCount };Label="Warnings"}, @{Expression={$_.ErrorCount };Label="Errors"} |convertto-html -Pre "<h3>$reportTitle</h3> <h4>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$currDate</h4>"
	$contentsourcelist > $f 
	
	#"Mailed to " + $reportsToEmail >> $f 

	$bodyText = Get-Content $f 
	$bodyText | foreach {$_ -replace "</td><td>", "</td><td align=""center"">"} | Set-Content $f
	$bodyText = Get-Content $f 
	$bodyText | foreach {$_ -replace "<table>", "<table border=""1"" cellpadding=""4"" >"} | Set-Content $f
	$bodyText = Get-Content $f 
	#$bodyText 
	#$contentsourcelist

	#"send-mailmessage -to $reportsToEmail -from $reportsFromEmail -subject $reportTitle -Body $bodyText -smtpserver $smtpserver" >> $f

	# TODO check for valid farm property settings

	if($SendMail) 
	{
		send-mailmessage -to $reportsToEmail -from $reportsFromEmail -subject "$reportTitle" -BodyAsHtml "$bodyText" -smtpserver $smtpserver 
	}
	if ($DebugMode)
	{
		Write-host "send-mailmessage -to $reportsToEmail -from $reportsFromEmail -subject ""$reportTitle"" -BodyAsHtml ""$bodyText"" -smtpserver $smtpserver" 
	}
	  
    
    if ($DebugMode) { write-host ("Finished  $funcname" ) -Foregroundcolor Red }
	
	
}


if($ConfigurationFile.length -eq 0)
{
	$global:ConfigurationFile = "$configurationname.config"
	
}

if($GenerateSampleConfigurationFile)
{
  FunctionGenerateSampleConfigurationFile
}
if($GenerateSampleReport)
{
  FunctionGenerateSampleReport
}
if (!$GenerateSampleReport -and !$GenerateSampleConfigurationFile)
{
  main 
}



  



