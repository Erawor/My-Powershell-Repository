Function Update-WUModule
{
	<#
	.SYNOPSIS
		Invoke Get-WUInstall remotely.

	.DESCRIPTION
		Use Invoke-WUInstall to invoke Windows Update install remotly. It Based on TaskScheduler because 
		CreateUpdateDownloader() and CreateUpdateInstaller() methods can't be called from a remote computer - E_ACCESSDENIED.
		
		Note:
		Because we do not have the ability to interact, is recommended use -AcceptAll with WUInstall filters in script block.
	
	.PARAMETER ComputerName
		Specify computer name.

	.PARAMETER PSWUModulePath	
		Destination of PSWindowsUpdate module. Default is C:\Windows\system32\WindowsPowerShell\v1.0\Modules\PSWindowsUpdate
	
	.PARAMETER OnlinePSWUSource
		Link to online source on TechNet Gallery.
		
	.PARAMETER LocalPSWUSource	
		Path to local source on your machine. If you cant use [System.IO.Compression.ZipFile] you must manualy unzip source and set path to it.
			
	.PARAMETER CheckOnly
		Only check current version of PSWindowsUpdate module. Don't update it.
		
	.EXAMPLE
		PS C:\> Update-WUModule

	.EXAMPLE
		PS C:\> Update-WUModule -LocalPSWUSource "C:\Windows\system32\WindowsPowerShell\v1.0\Modules\PSWindowsUpdate" -ComputerName PC2,PC3,PC4
		
	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/

	.LINK
		Get-WUInstall
	#>
	[CmdletBinding(
		SupportsShouldProcess=$True,
		ConfirmImpact="High"
	)]
	param
	(
		[Parameter(ValueFromPipeline=$True,
					ValueFromPipelineByPropertyName=$True)]
		[String[]]$ComputerName = "localhost",
		[String]$PSWUModulePath = "C:\Windows\system32\WindowsPowerShell\v1.0\Modules\PSWindowsUpdate",
		[String]$OnlinePSWUSource = "http://gallery.technet.microsoft.com/2d191bcd-3308-4edd-9de2-88dff796b0bc",
		[String]$SourceFileName = "PSWindowsUpdate.zip",
		[String]$LocalPSWUSource,
		[Switch]$CheckOnly,
		[Switch]$Debuger
	)

	Begin 
	{
		If($PSBoundParameters['Debuger'])
		{
			$DebugPreference = "Continue"
		} #End If $PSBoundParameters['Debuger']
		
		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

		if(!$Role)
		{
			Write-Warning "To perform some operations you must run an elevated Windows PowerShell console."	
		} #End If !$Role
		
		if($LocalPSWUSource -eq "")
		{
			Write-Debug "Prepare temp location"
			$TEMPDentination = [environment]::GetEnvironmentVariable("Temp")
			#$SourceFileName = $OnlinePSWUSource.Substring($OnlinePSWUSource.LastIndexOf("/")+1)
			$ZipedSource = Join-Path -Path $TEMPDentination -ChildPath $SourceFileName
			$TEMPSource = Join-Path -Path $TEMPDentination -ChildPath "PSWindowsUpdate"
			
			Try
			{
				$WebClient = New-Object System.Net.WebClient
				$WebSite = $WebClient.DownloadString($OnlinePSWUSource)
				$WebSite -match "/file/41459/\d*/PSWindowsUpdate.zip" | Out-Null
				
				$OnlinePSWUSourceFile = $OnlinePSWUSource + $matches[0]
				Write-Debug "Download latest PSWindowsUpdate module from website: $OnlinePSWUSourceFile"	
				#Start-BitsTransfer -Source $OnlinePSWUSource -Destination $TEMPDentination
				
				$WebClient.DownloadFile($OnlinePSWUSourceFile,$ZipedSource)
			} #End Try
			catch
			{
				Write-Error "Can't download the latest PSWindowsUpdate module from website: $OnlinePSWUSourceFile" -ErrorAction Stop
			} #End Catch
			
			Try
			{
				if(Test-Path $TEMPSource)
				{
					Write-Debug "Cleanup old PSWindowsUpdate source"
					Remove-Item -Path $TEMPSource -Force -Recurse
				} #End If Test-Path $TEMPSource
				
				Write-Debug "Unzip the latest PSWindowsUpdate module"
				[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
				[System.IO.Compression.ZipFile]::ExtractToDirectory($ZipedSource,$TEMPDentination)
				$LocalPSWUSource = Join-Path -Path $TEMPDentination -ChildPath "PSWindowsUpdate"
			} #End Try
			catch
			{
				Write-Error "Can't unzip the latest PSWindowsUpdate module" -ErrorAction Stop
			} #End Catch
			
			Write-Debug "Unblock the latest PSWindowsUpdate module"
			Get-ChildItem -Path $LocalPSWUSource | Unblock-File
		} #End If $LocalPSWUSource -eq ""

		$ManifestPath = Join-Path -Path $LocalPSWUSource -ChildPath "PSWindowsUpdate.psd1"
		$TheLatestVersion = (Test-ModuleManifest -Path $ManifestPath).Version
		Write-Verbose "The latest version of PSWindowsUpdate module is $TheLatestVersion"
	}
	
	Process
	{
		ForEach($Computer in $ComputerName)
		{
			if($Computer -eq [environment]::GetEnvironmentVariable("COMPUTERNAME") -or $Computer -eq ".")
			{
				$Computer = "localhost"
			} #End If $Computer -eq [environment]::GetEnvironmentVariable("COMPUTERNAME") -or $Computer -eq "."
			
			if($Computer -eq "localhost")
			{
				$ModuleTest = Get-Module -ListAvailable -Name PSWindowsUpdate
			} #End if $Computer -eq "localhost"
			else
			{
				if(Test-Connection $Computer -Quiet)
				{
					Write-Debug "Check if PSWindowsUpdate module exist on $Computer"
					Try
					{
						$ModuleTest = Invoke-Command -ComputerName $Computer -ScriptBlock {Get-Module -ListAvailable -Name PSWindowsUpdate} -ErrorAction Stop
					} #End Try
					Catch
					{
						Write-Warning "Can't access to machine $Computer. Try use: winrm qc"
						Continue
					} #End Catch
				} #End If Test-Connection $Computer -Quiet
				else
				{
					Write-Warning "Machine $Computer is not responding."
				} #End Else Test-Connection -ComputerName $Computer -Quiet
			} #End Else $Computer -eq "localhost"
			
			If ($pscmdlet.ShouldProcess($Computer,"Update PSWindowsUpdate module from $($ModuleTest.Version) to $TheLatestVersion")) 
			{
				if($Computer -eq "localhost")
				{
					if($ModuleTest.Version -lt $TheLatestVersion)
					{
						if($CheckOnly)
						{
							Write-Verbose "Current version of PSWindowsUpdate module is $($ModuleTest.Version)"
						} #End If $CheckOnly
						else
						{
							Write-Verbose "Copy source files to PSWindowsUpdate module path"
							Get-ChildItem -Path $LocalPSWUSource | Copy-Item -Destination $ModuleTest.ModuleBase -Force
							
							$AfterUpdateVersion = [String]((Get-Module -ListAvailable -Name PSWindowsUpdate).Version)
							Write-Verbose "$($Computer): Update completed: $AfterUpdateVersion" 
						}#End Else $CheckOnly
					} #End If $ModuleTest.Version -lt $TheLatestVersion
					else
					{
						Write-Verbose "The newest version of PSWindowsUpdate module exist"
					} #ed Else $ModuleTest.Version -lt $TheLatestVersion
				} #End If $Computer -eq "localhost"
				else
				{
					Write-Debug "Connection to $Computer"
					if($ModuleTest -eq $null)
					{
						$PSWUModulePath = $PSWUModulePath -replace ":","$"
						$DestinationPath = "\\$Computer\$PSWUModulePath"

						if($CheckOnly)
						{
							Write-Verbose "PSWindowsUpdate module on machine $Computer doesn't exist"
						} #End If $CheckOnly
						else
						{
							Write-Verbose "PSWindowsUpdate module on machine $Computer doesn't exist. Installing: $DestinationPath"
							Try
							{
								New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
								Get-ChildItem -Path $LocalPSWUSource | Copy-Item -Destination $DestinationPath -Force
								
								$AfterUpdateVersion = [string](Invoke-Command -ComputerName $Computer -ScriptBlock {(Get-Module -ListAvailable -Name PSWindowsUpdate).Version} -ErrorAction Stop)
								Write-Verbose "$($Computer): Update completed: $AfterUpdateVersion" 								
							} #End Try	
							Catch
							{
								Write-Warning "Can't install PSWindowsUpdate module on machine $Computer."
							} #End Catch
						} #End Else $CheckOnly
					} #End If $ModuleTest -eq $null
					elseif($ModuleTest.Version -lt $TheLatestVersion)
					{
						$PSWUModulePath = $ModuleTest.ModuleBase -replace ":","$"
						$DestinationPath = "\\$Computer\$PSWUModulePath"
						
						if($CheckOnly)
						{
							Write-Verbose "Current version of PSWindowsUpdate module on machine $Computer is $($ModuleTest.Version)"
						} #End If $CheckOnly
						else
						{
							Write-Verbose "PSWindowsUpdate module version on machine $Computer is ($($ModuleTest.Version)) and it's older then downloaded ($TheLatestVersion). Updating..."							
							Try
							{
								Get-ChildItem -Path $LocalPSWUSource | Copy-Item -Destination $DestinationPath -Force	
								
								$AfterUpdateVersion = [string](Invoke-Command -ComputerName $Computer -ScriptBlock {(Get-Module -ListAvailable -Name PSWindowsUpdate).Version} -ErrorAction Stop)
								Write-Verbose "$($Computer): Update completed: $AfterUpdateVersion" 
							} #End Try
							Catch
							{
								Write-Warning "Can't updated PSWindowsUpdate module on machine $Computer"
							} #End Catch
						} #End Else $CheckOnly
					} #End ElseIf $ModuleTest.Version -lt $TheLatestVersion
					else
					{
						Write-Verbose "Current version of PSWindowsUpdate module on machine $Computer is $($ModuleTest.Version)"
					} #End Else $ModuleTest.Version -lt $TheLatestVersion
				} #End Else $Computer -eq "localhost"
			} #End If $pscmdlet.ShouldProcess($Computer,"Update PSWindowsUpdate module")
		} #End ForEach $Computer in $ComputerName
	}
	
	End 
	{
		if($LocalPSWUSource -eq "")
		{
			Write-Debug "Cleanup PSWindowsUpdate source"
			if(Test-Path $ZipedSource -ErrorAction SilentlyContinue)
			{
				Remove-Item -Path $ZipedSource -Force
			} #End If Test-Path $ZipedSource
			if(Test-Path $TEMPSource -ErrorAction SilentlyContinue)
			{
				Remove-Item -Path $TEMPSource -Force -Recurse
			} #End If Test-Path $TEMPSource	
		}
	}

}
# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQULcI5gK5jgbXqBh+y6vD5IRDd
# nd6gggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFK7v9V7FId4AvszD
# SUwxG3qIZJPTMA0GCSqGSIb3DQEBAQUABIIBAGfqUsvaJCUHEnU88WmNRXMtzKhg
# e+/P9jNHhvLXFCxl763f1inBNx2iv5xzHWhdgDzS2/MDAlDbCqChPZ+TJl1QoAwx
# QD4bbDYUHFXq6J8MK7isu7xAVK2h0TOgmdC8Dx4PNLjw5KEDJXgos4OhGWHkJJ3i
# 9Lw1+XT8Gxnj+9NjA+AmVctN5zXalmHASWyIhadoCbu9vWXPWeH90oSikxN8vhvp
# vFLbaH+XOHx49fwEHuf+tjUwQsNK/RKCRNaiOOS3p36lBQEamby5iRBaCJ47TjYk
# Fnl8BoejqvB/IZl83rt1JjBaBYIaJhg/UgZlBo5ZmqZUr95+eW1MHPxlseE=
# SIG # End signature block
