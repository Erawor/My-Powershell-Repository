function Use-BlogSchematic
{
    <#
    .Synopsis
        Builds a web application according to a schematic
    .Description
        Use-Schematic builds a web application according to a schematic.
        
        Web applications should not be incredibly unique: they should be built according to simple schematics.        
    .Notes
    
        When ConvertTo-ModuleService is run with -UseSchematic, if a directory is found beneath either Pipeworks 
        or the published module's Schematics directory with the name Use-Schematic.ps1 and containing a function 
        Use-Schematic, then that function will be called in order to generate any pages found in the schematic.
        
        The schematic function should accept a hashtable of parameters, which will come from the appropriately named 
        section of the pipeworks manifest
        (for instance, if -UseSchematic Blog was passed, the Blog section of the Pipeworks manifest would be used for the parameters).
        
        It should return a hashtable containing the content of the pages.  Content can either be static HTML or .PSPAGE                
    #>
    [OutputType([Hashtable])]
    param(
    # Any parameters for the schematic
    [Parameter(Mandatory=$true)][Hashtable]$Parameter,
    
    # The pipeworks manifest, which is used to validate common parameters
    [Parameter(Mandatory=$true)][Hashtable]$Manifest,
    
    # The directory the schemtic is being deployed to
    [Parameter(Mandatory=$true)][string]$DeploymentDirectory,
    
    # The directory the schematic is being deployed from
    [Parameter(Mandatory=$true)][string]$InputDirectory     
    )
    
    process {
    
        if (-not $Parameter.Name) {
            Write-Error "No Blog name found in parameters"
            return
        }
        
        
        $blogName = $parameter.Name 
        if (-not $Parameter.Description) {
            Write-Error "No description found in parameters"
            return
        }
        
        
        if (-not $Manifest.Table.Name) {
            Write-Error "No table found in manifest"
            return
        }
        
        if (-not $Manifest.Table.StorageAccountSetting) {
            Write-Error "No storage account name setting found in manifest"
            return
        }
        
        if (-not $manifest.Table.StorageKeySetting) {
            Write-Error "No storage account key setting found in manifest"
            return
        }
        
        
        #$manifest.AcceptAnyUrl = $true
                                        
        
        $blogPage = {

#region Resolve the absolute URL
$protocol = ($request['Server_Protocol'] -split '/')[0]  # Split out the protocol
$serverName= $request['Server_Name']                     # And what it thinks it called the server
$shortPath = Split-Path $request['PATH_INFO']            # And the relative path beneath that URL
$remoteCommandUrl =                                      # Put them all together
    $Protocol + '://' + $ServerName.Replace('\', '/').TrimEnd('/') + '/' + $shortPath.Replace('\','/').TrimStart('/')

$absoluteUrl =        
    $remoteCommandUrl.TrimEnd("/") + $request['Url'].ToString().Substring(
        $request['Url'].ToString().LastIndexOf("/"))

#endregion Resolve the absolute URL

#region Unpack blog items
$unpackItem = 
    {
        $item = $_
        $item.psobject.properties |                         
            Where-Object { 
                ('Timestamp', 'RowKey', 'TableName', 'PartitionKey' -notcontains $_.Name) -and
                (-not "$($_.Value)".Contains(' ')) 
            }|                        
            ForEach-Object {
                try {
                    $expanded = Expand-Data -CompressedData $_.Value
                    $item | Add-Member NoteProperty $_.Name $expanded -Force
                } catch{
                    Write-Verbose $_
                
                }
            }
            
        $item.psobject.properties |                         
            Where-Object { 
                ('Timestamp', 'RowKey', 'TableName', 'PartitionKey' -notcontains $_.Name) -and
                (-not "$($_.Value)".Contains('<')) 
            }|                                   
            ForEach-Object {
                try {
                    $fromMarkdown = ConvertFrom-Markdown -Markdown $_.Value
                    $item | Add-Member NoteProperty $_.Name $fromMarkdown -Force
                } catch{
                    Write-Verbose $_
                
                }
            }

        $item                         
    }
#endregion Unpack blog items


#region Blog Metadata
$blogName = 
    if ($pipeworksManifest.Blog.Name) {
        $pipeworksManifest.Blog.Name
    } else {
        $module.Name
    }
    
$blogDescription = 
    if ($pipeworksManifest.Blog.Description) {
        $pipeworksManifest.Blog.Description
    } else {
        $module.Description
    }
$partitionKey = $blogName
#endregion

  
#region Blog Title Bar

$rssButton = Write-Link -Button -Style @{'font-size'='xx-small'} -Caption "<span class='ui-icon ui-icon-signal-diag'></span>" -Url "Module.ashx?rss=$BlogName"
$shareButton = 
    New-Region -AsPopdown -LayerID SharePopdown -Style @{
        'font-size' = 'xx-small'
    } -Layer @{
        "<span class='ui-icon ui-icon-mail-closed'></span>" = "
        $(Write-Link twitter:tweet)
        <br/>
        $(Write-Link google:plusone)
        "
    }
    
    
$searchButton = 
    New-Region -AsPopdown -LayerID SearchPopdown -Style @{
        'font-size' = 'xx-small'
    } -Layer @{
        "<span class='ui-icon ui-icon-search'></span>" = "
        <form>        
            <input name='term' value='$([Web.HttpUtility]::HtmlAttributeEncode($request['Term']))'type='text' style='width:80%' placeholder='Search $blogName' />
        </form>        
        "
    }

$titleBar = @"
<table style='margin-left:2%;margin-right:2%;width=70%'>
    <tr>
        <td style='width:20%'>
            $(Write-Link -Url '' -Button -Caption "<span style='font-size:large'>$blogName</span>")
        </td>
        <td style='width:50%;text-align:right'>
            $("<span style='font-size:medium;text-align:right'>$blogDescription</span>")
        </td>
        <td style='width:10%;text-align:right'>
        </td>
    </tr>
</table>

<br/>

<div style='text-align:right'>
    $rssButton 
    $shareButton
    $searchButton        
</div>

<br/>
<br/>
"@ | 
    New-Region -layerId Titlebar -AsWidget -CssClass clearfix, theme-group, corner-all -Style @{    
        "margin-top" = "1%"  
        "margin-left" = "12%"
        "margin-right" = "12%"    
    }
   
   
#region Generate output
$results = 
    if ($Request['Post']) { 
        #region Fetch a Specific Post
        $storageAccount = Get-WebConfigurationSetting -Setting $pipeworksManifest.Table.StorageAccountSetting
        $storageKey = Get-WebConfigurationSetting -Setting $pipeworksManifest.Table.StorageKeySetting
        $nameMatch  =([ScriptBLock]::Create("`$_.Name -eq '$($request['post'])'"))
        Search-AzureTable -Where $nameMatch -TableName $pipeworksManifest.Table.Name -StorageAccount $storageAccount -StorageKey $storageKey |
            ForEach-Object $unpackItem |
            ForEach-Object { 
                $_ | Out-HTML -ItemType http://schema.org/BlogPosting
            }           
        #endregion Fetch a Specific Post
    } elseif ($Request['Term']) {
        #region Look for a search term
        @"
<div id='OutputContainer' style='height:100%'>    
    Searching $($Module.Name) <progress max='100'> </progress>
</div>

<script>
    query = 'Module.ashx?Search=' + '$($Request['Term'])'
    `$(function() {
        `$.ajax({
            url: query,
            success: function(data){     
                `$('#OutputContainer').html(data);
            }, 
            error: function(data) {
                `$('#outputContainer').html("Post not found")
            }
        })
    })  
</script>
"@
        #endregion Look for a search term
    } else {
        #region Display the latest item

        $storageAccount = (Get-WebConfigurationSetting -Setting $pipeworksManifest.Table.StorageAccountSetting)
        $storageKey = (Get-WebConfigurationSetting -Setting $pipeworksManifest.Table.StorageKeySetting)                                                           

        Search-AzureTable -TableName $pipeworksManifest.Table.Name -Filter "PartitionKey eq '$partitionKey'" -Select Timestamp, DatePublished, PartitionKey, RowKey -StorageAccount $storageAccount -StorageKey $storageKey |
            Sort-Object -Descending {
                if ($_.DatePublished) {
                    [DateTime]$_.DatePublished
                } else {
                    [DateTime]$_.Timestamp
                }
            } |
            Select-Object -First 1 |
            Get-AzureTable -TableName $pipeworksManifest.Table.Name |
            ForEach-Object $UnpackItem |
            ForEach-Object { 
                $_ | Out-HTML -ItemType http://schema.org/BlogPosting
            }
        #endregion Display the latest item
    }             


$mainRegion ="
<div style='text-align:center'>
$($results |
    New-Region -layerId outputContent -Style @{
        "margin-left" = "2%"
        "margin-right" = "2%"
    })
</div> 
" | 
    New-Region -CssClass theme-group, ui-widget-content, clearfix -Style @{
        "margin-top" = "2%"  
        "margin-left" = "12%"
        "margin-right" = "12%"
        "min-height"='75%'    
    }



$adRegion = 
    if ($pipeworksManifest.AdSlot -and $pipeworksManifest.AdSenseId) {

        $adSenseId = $pipeworksManifest.AdSenseId
        $adslot = $pipeworksManifest.AdSlot
        @"
<br/>
<br/>
<script type='text/javascript'>
<!--
google_ad_client = 'ca-pub-$adSenseId';
/* AdSense Banner */
google_ad_slot = '$adslot';
google_ad_width = 728;
google_ad_height = 90;
//-->
</script>
<script type='text/javascript'
src='http://pagead2.googlesyndication.com/pagead/show_ads.js'>
</script>
"@     
    } else {
        ""
    }


$adRegion += 
    if ($pipeworksManifest.HidePipeworksBranding) {
""    
    } else {
@"
<br/>
<br/>
<div style='float:bottom'>
    <span style='font-size:xx-small'>Built with <a href='http://PowerShellPipeworks.com'>PowerShell Pipeworks</a>
</div>
"@    
    }

    

$advert = 
    $adRegion | 
        New-Region -Style @{
            "margin-top" = "1%"  
            "margin-left" = "12%"
            "margin-right" = "12%"
            "text-align" = "center" 
        }

$titleBar, $mainRegion, $advert |
        New-WebPage -Title $blogName -Rss @{
            $blogName = "Module.ashx?rss=$BlogName"
        } -UseJQueryUI

        }
        
        
        
$anyPage = {

    $storageAccount = (Get-WebConfigurationSetting -Setting $pipeworksManifest.Table.StorageAccountSetting)
    $storageKey = (Get-WebConfigurationSetting -Setting $pipeworksManifest.Table.StorageKeySetting)                                                           

    $originalUrl = $context.Request.ServerVariables["HTTP_X_ORIGINAL_URL"]

    $pathInfoUrl = $request.Url.ToString().Substring(0, $request.Url.ToString().LastIndexOf("/"))
            
        
        
    $pathInfoUrl = $pathInfoUrl.ToLower()
    $protocol = ($request['Server_Protocol'] -split '/')[0]  # Split out the protocol
    $serverName= $request['Server_Name']                     # And what it thinks it called the server

    $fullOriginalUrl = $protocol.ToLower() + "://" + $serverName + $request.Params["HTTP_X_ORIGINAL_URL"]
    
    $relativeUrl = $fullOriginalUrl.Replace("$pathInfoUrl", "")            
    
    
    
    if (-not $fullOriginalUrl) {
        "No Original URL"
        return    
    }
    $itemIdentifier = $relativeUrl -split "/" -ne ""
    $itemIdentifier = foreach ($i in $itemIdentifier) {
        [Web.httpUtility]::UrlDecode($i)
    }
    
    
    
    
    # If there's only one identifier, it's a post name
    # If there's two identifiers,
    # ... and the first ID is keyword, keywords, tag, tags, k, or t
    # ... and the first ID is posts, posts, names, name, p, or n
    # ... and the first ID is year or y
    # ... and the first ID is month or m
    # ... and the first ID is ID or i
    # ... or the posts are both numbers
    # ...... If one number has 4 digits, it's the year
    # If there's three identifiers
    # ... then treat them as year/month/day
    
    
    
        
    

    if ($itemIdentifier.Count) {
        $itemIdentifier
    } else {
        
        $selectItems = (@($itemSet.By) + "RowKey" + "Name") | Select-Object -Unique
        $tableItems = Search-AzureTable -TableName $pipeworksManifest.Table.Name -Filter "PartitionKey eq '$($itemSet.Partition)'" -StorageAccount $storageAccount -StorageKey $storageKey -Select $selectItems
        
        $depth = 0
        if ($request -and $request.Params["HTTP_X_ORIGINAL_URL"]) {
        
            $pathInfoUrl = $request.Url.ToString().Substring(0, $request.Url.ToString().LastIndexOf("/"))
            
            
            
            $pathInfoUrl = $pathInfoUrl.ToLower()
            $protocol = ($request['Server_Protocol'] -split '/')[0]  # Split out the protocol
            $serverName= $request['Server_Name']                     # And what it thinks it called the server

            $fullOriginalUrl = $protocol.ToLower() + "://" + $serverName + $request.Params["HTTP_X_ORIGINAL_URL"]
            
            $relativeUrl = $fullOriginalUrl.Replace("$pathInfoUrl", "")            
            
            if ($relativeUrl -like "*/*") {
                $depth = @($relativeUrl -split "/" -ne "").Count - 1
            } else {
                $depth  = 0
            }
            
        }
        
        
        
        foreach ($byTerm in $itemSet.By) {
            $tableItems |
                Sort-Object {
                    if ($_.DatePublished) {
                        [DateTime]$_.DatePublished 
                    } elseif ($_.Timestamp) {
                        [DateTime]$_.Timestamp
                    } 
                } -Descending | 
                Where-Object {
                    $_.$byTerm -like "*${itemIdentifier}*"
                } |
                ForEach-Object -Begin {
                    $popouts = @{}
                    $popoutUrls = @{}
                    
                    $order = @()
                } -Process {
                    $name = if ($_.Name) {
                        $_.Name
                    } else {
                        " " + ($order.Count + 1)
                    }
                    $popoutUrls[$name] = ("../" * $depth) + "Module.ashx?id=$($itemSet.Partition):$($_.RowKey)"
                    $popouts[$name] = " "
                    $order += $name
                } -End {
                    New-Region -LayerID InventoryItems -Order $order -Layer $popouts -LayerUrl $popoutUrls -AsPopout |
                        New-WebPage -Title "$($itemsetName) | $($itemIdentifier)" -UseJQueryUI 
                }
                
        }
           
    }



}
               
        
        
               
        @{
            "default.pspage" = "<| $blogPage |>"                         
            "${BlogName}.pspage" = "<| $blogPage |>"
            
        }                                   
    }        
} 

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU799w3JLZehCztU8N/dWfg7Yu
# MlSgggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFAXLyMdvCRfDCHlv
# 6xYxgDBGAOTzMA0GCSqGSIb3DQEBAQUABIIBAFCDbvIgZOvWu2+x2oR99fEx2hV4
# l2ElyxrIBXTmfT+uHEBgG8AwIJT+rnAHuUfBczdbiUIOgHtbuIPWyU49CfnoouK/
# tX/N4quSsgVQb3o/MSgnV7h1fIl85vaxZ85SmgciXVe4VkRHq2l2n5MNt0vwIa9B
# ZSVSvrpvBVjnHlZJ+kB3jhl0jJUxz8VtVw/2EfuFxUsGTGqLiFYhMG3xJPQ7JEpL
# 74dhdSqFlk+QWOQ1/ORnbsG7iV6Q0Pe1szi4rMRA7eVW+2eTYebpdFrsfUbwjDIJ
# iZJFFKIGgxM54//nR+ZV2QqGFvIikNmqezs12fISjGrJNYJqmlhwBf1W9Ms=
# SIG # End signature block
