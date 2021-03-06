function ConvertFrom-Markdown
{
    <#
    .Synopsis
        Converts from markdown to HTML format
    .Description
        Converts from the lightweight markup format Markdown into HTML
    .Link
        http://daringfireball.net/projects/markdown/
    .Link
        http://en.wikipedia.org/wiki/Markdown
    .Example
        ConvertFrom-MarkDown '
# Heading #
## Subheading
### Another Subheading ###

Header 1 
=========

Header 2
--------

***

---
*italics*
* * *
**bold**
- - -
_moreitalics_
- - -
__morebold__
******
Some text with `some code` inline 

    some code
    plain old indented code


! [Show Logo](http://show-logo.com/?Show-Logo_Text=Show-Logo&Show-Logo_RandomFont=true)
! [Show Logo][2]

[wikipedia](http://wikipedia.org)

[start-automating][1]
[start-automating][]
--------

[1]: http://start-automating.com/
[2]: http://show-logo.com/?Show-Logo_Text=Show-Logo&Show-Logo_RandomFont=true
[start-automating]: http://start-automating.com/

'    

    #>
    [OutputType([string])]
    param(
    # The Markdown text that will be converted into HTML
    #|LinesForInput 20
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=0)]
    [Alias('Md')]
    [String]$Markdown,
    
    # If set, will convert links to Write-Link.  
    # This will automatically embed richer content
    [Switch]$ConvertLink,
    
    # If set, will convert PRE tag content into colorized PowerShell 
    [Switch]$ScriptAsPowerShell    
    )
    
    process {
        $markDown = $markdown -ireplace "$([Environment]::NewLine)", " $([Environment]::NewLine)" 
        #region Multiline Regex Replacement
        $replacements = @{
            Find = '^#{6}([^#].+)#{6}', '^#{6}([^#].+)'
            Replace = '<h6>$1</h6>
'
        }, @{
            Find = '^#{5}([^#].+)#{5}', '^#{5}([^#].+)'
            Replace = '<h5>$1</h5>
'
        }, @{
            Find = '^#{4}([^#].+)#{4}', '^#{4}([^#].+)'
            Replace = '<h4>$1</h4>
'
        }, @{
            Find = '^#{3}([^#].+)#{3}', '^#{3}([^#].+)'
            Replace = '<h3>$1</h3>
'
        }, @{
            Find = '^#{2}([^#].+)#{2}', '^#{2}([^#].+)'
            Replace = '<h2>$1</h2>
'
        }, @{
            Find = '^#{1}([^#].+)#{1}', '^#{1}([^#].+)'
            Replace = '<h1>$1</h1>
'
        }, @{
            # Horizontal rules
            Find = '^\* \* \*', '^- - -'
            Replace = "$([Environment]::NewLine)<HR/>$([Environment]::NewLine)"
        }, @{
            Find = '^(.+)\s={3,}'
            Replace = '<h1>$1</h1>'
        }, @{
            Find = '^(.+)\s-{3,}'
            Replace = '<h2>$1</h2>'
        } 
                             
        foreach ($r in $replacements) {
            foreach ($f in $r.find) {
                $regex =New-Object Regex $f, "Multiline, IgnoreCase"
                $Markdown  = $regex.Replace($markdown, $r.Replace)
            }            
        }
        #endregion Multiline Regex Replacement
        
        #region Singleline Regex Replacement
        $markdown = $markdown -ireplace 
            "$([Environment]::NewLine) $([Environment]::NewLine) $([Environment]::NewLine)", "$([Environment]::NewLine)<BR/><BR/>$([Environment]::NewLine)" -ireplace            
            '-{3,}', "$([Environment]::NewLine)<HR/>$([Environment]::NewLine)" -ireplace
            '\*{3,}', "$([Environment]::NewLine)<HR/>$([Environment]::NewLine)" -ireplace
            '\*\*(.+?)\*\*', '<b>$1</b>' -ireplace 
            '__(.+?)__', '<b>$1</b>' -ireplace 
            '\*(.+?)\*', '<i>$1</i>' -ireplace 
            '\s_(.+?)_\s', '<i>$1</i>' -ireplace 
            '`(.+)` ', '<span style="font-family:Consolas, Courier New, monospace">$1</span>&nbsp;'          
        #endregion Singleline Regex Replacement
        
        # build link dictionary
        $linkrefs = @{}
        $re_linkrefs = [regex]"\[(?<ref>[0-9]+)\]\:\s*(?<url>https?[^\s]+)"
        $markdown = $re_linkrefs.Replace($Markdown, {
            param($linkref)
            $linkrefs[$linkref.groups["ref"].value] = $linkref.groups["url"].value            
        })
        
        # handle links, images - embedded or referenced
        $re_links = [regex]"(?<image>!\s?)?\[(?<text>[^\]]+)](?:\((?<url>[^)]+)\)|\[(?<ref>\d+)])"
        $markdown = $re_links.Replace($markdown, {
            param($link);
            $url = $link.groups["url"].value
            if (-not $url) {
                # url did not match, so grab from dictionary
                $url = $linkrefs[$link.groups["ref"].value]
            }
            $text = $link.groups["text"].value

            if ($link.groups["image"].success) {
                # image
                $format = '<img src="{0}" alt="{1}" />'
                $format -f $url, $text
            } else {
                # href
                $format = '<a href="{0}">{1}</a>'
                if (-not $ConvertLink) {
                    $format -f $url, $text
                } else {
                    Write-Link -Url $url -Caption $text -Button -Style @{
                        "font-size" = "small"
                    }
                }

            }
                        
        })

        $replacements = @(@{
            Find = '^>(.+)<BR/>'
            Replace = '<blockquote>$1</blockquote><br/>'
        })
        
        
        foreach ($r in $replacements) {
            foreach ($f in $r.find) {
                $regex =New-Object Regex $f, "Multiline, IgnoreCase"
                $Markdown  = $regex.Replace($markdown, $r.Replace)
            }            
        }
        
        $lines = @($Markdown -split ("[$([Environment]::NewLine)]") -ne "")
        $toReplace = @{}
        $inBlockQuote = $false
        $inNumberedList = $false
        $inList = $false
        #region Fix Links and Code Sections
        $lines = @(foreach ($l in $lines) {
            
            if ($l -notlike "*#LinkTo*") {
                if ($l -match "^\d{1,}\.") {
                    if (-not $inNumberedList) {
                        "<ol>"
                    }  else {
                        "</li>"
                    }
                    $numberedListItemOpen = $true
                    "<li>" + $l.Substring($l.IndexOf(".") + 1) 
                    $inNumberedList = $true
                    continue
                } else {
                    if ($numberedListItemOpen) {
                        "</li></ol>"
                        $inList = $false
                        $numberedListItemOpen = $false
                    }
                }
                
                if ($l -match "^\s{0,3}\*{1}") {
                    if (-not $inList) {
                        "<ul>"
                    } else {
                        "</li>"
                    }
                    $listItemOpen = $true
                    "<li>" + $l.Substring($l.IndexOf("*") + 1)
                    $inList = $true
                    continue
                } else {
                    if ($listItemOpen) {
                        "</li></ul>"
                        $inList = $false
                        $listItemOpen = $false
                    }
                }               
                if ($l.StartsWith(">")) {
                    if (-not $inBlockQuote) {
                        "<blockquote>" + $l.TrimStart(">")                        
                    } else {
                        $l.TrimStart(">")
                    }
                    $inBlockQuote = $true
                    continue
                }
                                 
                if ($inBlockquote) {
                    if ($l -like "*<br/>*") {
                        $l -ireplace "<br/>", "</blockquote><br/>"
                        $inBlockQuote = $false
                    } else {
                        $l
                    }
                } elseif ($inNumberedList) {
                    if ($l -notlike "    *") {
                        if ($l -ne '<BR/>') {
                            "$l</ol>"   
                            $inNumberedList = $false
                        }
                    } else {
                        $l
                    }
                } elseif ($inList) {
                    if ($l -and $l -notlike "    *") {
                        if ($l -ne '<BR/>') {
                            "$l</ul>" 
                            $inList = $false
                        }                          
                    } else {
                        $l
                    }
                } else {
                    if ($l.StartsWith("    ")) {
                        if (-not $inCodeChunk) {
                            "<pre>"
                        }
                        $l.TrimStart("    ")
                        $inCodeChunk = $true
                        continue
                    } elseif ($InCodeChunk) {
                        $inCodeChunk = $false
                        "</pre>"
                    }
                    
                    if ($inCodeChunk) {
                        $inCodeChunk = $false
                        "</pre>"
                    }
                    $l                
                }
                
            } else {
                $first, $rest = $l -split ":"   
                $first = $first.Replace("#LinkTo", "").Trim()             
                $toReplace."@LinkTo${first}" = "$(($rest -join ':').Trim())"
            }
            
            
        }
        
        if ($numberedListItemOpen) {
            "</li></ol>"
            $inList = $false
            $numberedListItemOpen= $false
        }
        if ($listItemOpen) {            
            "</li></ul>"
            $inList = $false
            $listItemOpen = $false            
        })
        
        if ($inCodeChunk) {
            $inCodeChunk = $false
            $lines += "</pre>"
        }
        
        
        
        $markdown = $lines -join ([Environment]::NewLine)
        
        foreach ($tr in $toReplace.Getenumerator()) {
            if (-not $tr) {continue }
            $markDown = $markDown -ireplace "$($tr.Key)", $tr.Value
        }
        #endregion Fix Links and Code Sections


        
        if ($scriptAsPowershell) {
            [Regex]::Replace($markdown, 
                "<pre[^>]*>([.\s\W\w\S]+)</pre>", 
                {
                    $scriptHtml = Write-ScriptHTML -Script $args[0].Groups[1] -ErrorAction SilentlyContinue
                    if ($scriptHtml) {
                        $scriptHtml
                    } else {
                        $args[0].Groups[1]
                    }
                }, 
                "Multiline,IgnoreCase")

        } else {
            $markdown        
        }      
                                
			            
    }
} 
# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUnrAtn3nNrzsCKP0vXZefI15i
# YVCgggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFDX2ADnCKNXjl/HQ
# 1/Eype4tGwSYMA0GCSqGSIb3DQEBAQUABIIBAJ5+NgJnM1EbwpFPNCcj+WRzaEFI
# sv6r+DOU1Fv/BkkN1RADZQQjMihbvuYKpzXSkeA0igHnNlErny2phwbWITgRZWeS
# JwFOPlduztl41Zq8VHWyRlGJCcMVFYrcCX3dc0PbLxlwss+F/dtzOxI7OvsDm/F1
# n9RC76kBPBCFFUmkM6N254ddBvBPvBsUoYFBFi5wAN17yRWy1sRyeqzTzxJcl7W2
# VgPB1iQdmyGR3jrS7g3LWIuITTxaQ7AVTh2w+I7N252nTKW8H9hlNSGxUaF5HMpQ
# 5FB5mFE6JpcoWZZ38XxcrDWTIKtHa5EOJFpojaMwfHohl4S4YdTlBGUuClY=
# SIG # End signature block
