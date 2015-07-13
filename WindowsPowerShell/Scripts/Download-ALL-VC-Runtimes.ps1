﻿<#
 ##################################################################################
 #  Script name: DownloadAll.ps1
 #  Created:		2012-12-26
 #  version:		v1.0
 #  Author:      Mikael Nystrom
 #  Homepage:    http://deploymentbunny.com/
 ##################################################################################
 
 ##################################################################################
 #  Disclaimer:
 #  -----------
 #  This script is provided "AS IS" with no warranties, confers no rights and 
 #  is not supported by the authors or DeploymentBunny.
 ##################################################################################
#>
Param(
    [Parameter(mandatory=$false,HelpMessage="Name and path of XML file")]
    [ValidateNotNullOrEmpty()]
    $DownloadFile = '.\downloads.xml',

    [Parameter(mandatory=$False,HelpMessage="Name and path of download folder")]
    [ValidateNotNullOrEmpty()]
    $DownloadFolder = 'E:\Downloads'
)
Function Logit()
{
    $TextBlock1 = $args[0]
    $TextBlock2 = $args[1]
    $TextBlock3 = $args[2]
    $Stamp = Get-Date
    Write-Host "[$Stamp] [$Section - $TextBlock1]"
}

# Main
$Section = "Main"
Logit "DownLoadFolder - $DownLoadFolder"
Logit "DownloadFile - $DownloadFile"

#Read content
$Section = "Reading datafile"
Logit "Reading from $DownloadFile"
[xml]$Data = Get-Content $DownloadFile
$TotalNumberOfObjects = $Data.Download.DownloadItem.Count

# Start downloading
$Section = "Downloading"
Logit "Downloading $TotalNumberOfObjects objects"
$Count = (0)
foreach($DataRecord in $Data.Download.DownloadItem)
    {
    $FullName = $DataRecord.FullName
    $Count = ($Count + 1)
    $Source = $DataRecord.Source
    $DestinationFolder = $DataRecord.DestinationFolder
    $DestinationFile = $DataRecord.DestinationFile
    Logit "Working on $FullName ($Count/$TotalNumberOfObjects)"
    $DestinationFolder = $DownloadFolder + "\" + $DestinationFolder
    $Destination = $DestinationFolder + "\" + $DestinationFile
    $Downloaded = Test-Path $Destination
    if($Downloaded -like 'True'){}
        else
        {
            Logit "$DestinationFile needs to be downloaded."
            Logit "Creating $DestinationFolder"
            New-Item -Path $DestinationFolder -ItemType Directory -Force | Out-Null
            Logit "Downloading $Destination"
        Try
        {
            Start-BitsTransfer -Destination $Destination -Source $Source -Description "Download $FullName" -ErrorAction Continue
        }
        Catch
        {
            $ErrorMessage = $_.Exception.Message
            Logit "Fail: $ErrorMessage"
        }
    }
}

# Start Proccessing downloaded files
$Section = "Process files"
Logit "Checking $TotalNumberOfObjects objects"
$Count = (0)
foreach($DataRecord in $Data.Download.DownloadItem){
    $CommandType = $DataRecord.CommandType
        if($CommandType -like 'NONE')
        {}
        else
        {
            $FullName = $DataRecord.FullName
            $Count = ($Count + 1)
            $Source = $DataRecord.Source
            $Command = $DataRecord.Command
            $CommandLineSwitches = $DataRecord.CommandLineSwitches
            $VerifyAfterCommand = $DataRecord.VerifyAfterCommand
            $DestinationFolder = $DataRecord.DestinationFolder
            $DestinationFile = $DataRecord.DestinationFile
            $DestinationFolder = $DownLoadFolder + "\" + $DestinationFolder
            $Destination = $DestinationFolder + "\" + $DestinationFile
            $CheckFile = $DestinationFolder + "\" + $VerifyAfterCommand
            Logit "Working on $FullName ($Count/$TotalNumberOfObjects)"
            Logit "Looking for $CheckFile"
            $CommandDone = Test-Path $CheckFile
        if($CommandDone -like 'True')
        {
             Logit "$FullName is already done"
        }
            else
        {
            Logit "$FullName needs to be fixed."
            #Selecting correct method to extract data 
            Switch($CommandType){
                EXEType01{
                    $Command = $DestinationFolder + "\" + $Command
                    $DownLoadProcess = Start-Process """$Command""" -ArgumentList ($CommandLineSwitches + " " + """$DestinationFolder""") -Wait
                    $DownLoadProcess.HasExited
                    $DownLoadProcess.ExitCode
                }
                NONE{
                }
                default{
                }
            }
        }
    }
}

#Done
$Section = "Finish"
Logit "All Done"
# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUDk5Zs7CKCGlD+qLfF5Eyol9s
# tgSgggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFP1lj20ZciAgplvn
# A1i1w42xdRSnMA0GCSqGSIb3DQEBAQUABIIBAIenWFxgY5qN8NQ6L7qnFFyftJ+E
# BXKbiOWScxsaY1CPPJRFUEvsCWQFc9fTmJkhHkqPjCWHw2hhETwxcw499iu1TIec
# obur7P2exHYZlJ4Q22ZyQ7YE49pPKW22HHFjpTkuLbbc11cL1seKdi+UNxwJq15u
# P5MnHlBw3pY2/QL8INoXfQMvTnP3MI/+14EvE4zdCn5mXl97p1uqRn0S0Ey5i1XB
# L4aQijZQzm28ec2+UUUF1mznHCSzkL8YmJDxNzKS6sSpqiw8l81CYhYADu6aHTNA
# 6sYWIXTSNAzOUXG++7wxAp93sHwEKyhibNrjPO9B/JTfqBkQRbUvOU8Irf8=
# SIG # End signature block
