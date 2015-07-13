# List available Snap-ins and load them
Get-PSSnapin �Registered
Add-PSSnapin SqlServerCmdletSnapin100
Add-PSSnapin SqlServerProviderSnapin100

# Alternatively you can use this 
Add-PSSnapin *SQL*


# Listing 1 
$server = "localhost"
$instance = "default"
$dbname = "AdventureWorks"
$tblname = "HumanResources.Employee"
$path="SQLSERVER:\SQL\$server\$instance\Databases\$dbname\Tables\$tblname"
If(Test-Path $path)
{
	Get-Item $path
}

# Listing 2
function Load-SQLSnapins
{
	[CmdletBinding()]
	Param()
	$ErrorActionPreference = "Stop"
	$sqlpsreg="HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps"
	if (Get-ChildItem $sqlpsreg -ErrorAction "SilentlyContinue")
	{
		throw "SQL Server Provider for Windows PowerShell is not installed."
	}
	else
	{
		$item = Get-ItemProperty $sqlpsreg
		$sqlpsPath = [System.IO.Path]::GetDirectoryName($item.Path)
	}
	Set-Variable -scope Global -name SqlServerMaximumChildItems -Value 0
	Set-Variable -scope Global -name SqlServerConnectionTimeout -Value 30
	Set-Variable -scope Global -name SqlServerIncludeSystemObjects -Value $false
	Set-Variable -scope Global -name SqlServerMaximumTabCompletion -Value 1000
	Push-Location
	cd $sqlpsPath
	if (!(Get-PSSnapin -Name SQLServerCmdletSnapin100 -ErrorAction SilentlyContinue))
	{
		Add-PSSnapin SQLServerCmdletSnapin100
		Write-Verbose "Loading SQLServerCmdletSnapin100..."
	}
	else
	{
		Write-Verbose "SQLServerCmdletSnapin100 already loaded"
	}
	if (!(Get-PSSnapin -Name SqlServerProviderSnapin100 -ErrorAction SilentlyContinue))
	{
		Add-PSSnapin SqlServerProviderSnapin100
		Write-Verbose "Loading SqlServerProviderSnapin100..."
	}
	else
	{
		Write-Verbose "SqlServerProviderSnapin100 already loaded"
	}
	Update-TypeData -PrependPath SQLProvider.Types.ps1xml
	update-FormatData -prependpath SQLProvider.Format.ps1xml
	Pop-Location
}
<#
namespaces based on
http://msdn.microsoft.com/en-ca/library/ms182491(v=sql.105).aspx

SQL2005
root\Microsoft\SqlServer\ComputerManagement"

SQL2008
root\Microsoft\SqlServer\ComputerManagement10"

SQL2012
\\.\root\Microsoft\SqlServer\ComputerManagement11\instance_name
#>
function Prepare-SQLProvider
{
	[CmdletBinding()]
	Param()
	$namespace = "root\Microsoft\SqlServer\ComputerManagement"
	if ((Get-WmiObject -Namespace $namespace -Class SqlService -ErrorAction SilentlyContinue))
	{
		Write-Verbose "Running SQL Server 2005"
		#load Snapins
		Load-SQLSnapins
	}
	elseif ((Get-WmiObject -Namespace "$($namespace)10" -Class SqlService -ErrorAction SilentlyContinue))
	{
		Write-Verbose "Running SQL Server 2008/R2"
		#load Snapins
		Load-SQLSnapins
	}
	elseif ((Get-WmiObject �Namespace "$($namespace)11" -Class SqlService -ErrorAction SilentlyContinue))
	{
		Write-Verbose "Running SQL Server 2012"
		Write-Verbose "Loading SQLPS Module ... "
		Import-Module SQLPS
	}
}

# Listing 3
Prepare-SQLProvider
cd SQLSERVER:\SQL\localhost\default
cd Databases
Get-Childitem | Select Name

# Listing 4
Prepare-SQLProvider
CD SQLSERVER:\SQL\localhost\default\Databases\AdventureWorks\Tables
Get-ChildItem | Select DisplayName
Get-ChildItem | Where-Object { $_.DisplayName �match "HumanResources[.]" | Select DisplayName


# Listing 5
Prepare-SQLProvider
$server = Get-Item SQLSERVER:\SQL\localhost\default
$server.GetType() | Format-Table �Auto
$server | Get-Member

# Listing 6
function Get-DatabaseCounts
{
	[CmdletBinding()]
	Param(
		[Parameter(Position=0,Mandatory=$true)]
		[alias("server")]
		[string]$serverName,

		[Parameter(Position=1,Mandatory=$true)]
		[alias("instance")]
		[string]$instanceName
	)
	$results = @()
	(Get-Item SQLSERVER:\SQL\$serverName\$instanceName).Databases |
	  Foreach-Object {
		$db = $_
		$db.Tables |
			Foreach-Object {
				$table = $_
				$hash = @{
					"Database" = $db.Name
					"Schema" = $table.Schema
					"Table" = $table.Name
					"RowCount" = $table.RowCount
					"Replicated" = $table.Replicated
				}
				$item = New-Object PSObject -Property $hash
				$results += $item
			}
	}
	$results
}

Prepare-SQLProvider -Verbose
Get-DatabaseCounts -server "localhost" -instance "DEFAULT" | Out-GridView

# Listing 7
Function Get-SQLTableInDB {
	[CmdletBinding()]
	Param(
		[Parameter(Position=0,Mandatory=$true)]
		[alias("server")]
		[string]$serverName,

		[Parameter(Position=1,Mandatory=$true)]
		[alias("instance")]
		[string]$instanceName,

		[Parameter(Position=2,Mandatory=$true)]
		[alias("table")]
		[string]$tableName
	)

	(Get-Item SQLSERVER:\SQL\$serverName\$instanceName).Databases |
	  Foreach-Object {
		$db = $_
		$db.Tables |
			Foreach-Object {
				$sqltable = $_
				If($tableName �eq $($sqltable.Name)) {
					Return $db.Name
				}
			}
 	  }
}
Prepare-SQLProvider
Get-SQLTableInDatabases �server "localhost" �instance "DEFAULT" �table "Table1"


# Listing 8
Prepare-SQLProvider
$servername = "localhost"
$instance = "default"
$tableName = "backupset"
$schema = "dbo"
$instpath = "SQL\$servername\$instance\Databases"
foreach($db in (Get-ChildItem SQLSERVER:\SQL\$instpath)) 
{
	$dbname = $db.Name
	if(!(Test-Path SQLSERVER:\$instpath\$dbname\Tables\$schema`.$tableName))
	{
		Write-Output $db.Name
	}
}


# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUZThNhJQao1bj3Fk0iNu8tGPZ
# 4UmgggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFISLTNJEn8FL7OY3
# aYNETErul0obMA0GCSqGSIb3DQEBAQUABIIBAIwDRaOmB9Zpahe9jbcMA/4m9bOW
# 2GeF7RMCI+1G9/btfloSDwR02GUuv3HnLnvHHkj8tJxdTuTgiSfjn/dam0QKaCEN
# i869JM42JigK6k5ibmov87F90aPzO01GjljIrZfTNWQSEHWiVztV9N7n+JPHRgW5
# MrOXbVxwif3rVBE0iGhA70LAbvUu0Z9TY8Bia0AvCUASN/ZJBEn9/f2iyo4rrMRP
# 0F2dQTP29GqkVRBHjC7N5In/NvAd6eC1Fg632AydbXCjqWIsrtU63ijlOHL22UQJ
# t0n5Cm5PqDBNP0xfkL0OSUOGdJdoVR/opGILXYFkva1R6WlaUjxIaYpm8Lg=
# SIG # End signature block
