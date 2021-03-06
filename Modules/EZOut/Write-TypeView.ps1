function Write-TypeView
{
    <#
    .Synopsis
        Writes extended type view information
    .Description
        PowerShell has a robust, extensible types system.  With Write-TypeView, you can easily add extended type information to any type.
        This can include:  
            The default set of properties to display (-DefaultDisplay)
            Sets of properties to display (-PropertySet)
            Serialization Depth (-SerializationDepth)
            Virtual methods or properties to add onto the type (-ScriptMethod, -ScriptProperty and -NoteProperty)
            Method or property aliasing (-AliasProperty)
    .Link
        Out-TypeView
    .Link
        Add-TypeView
    #>
    [OutputType([string])]
    param(    
    # The name of the type
    #|Default MyCustomTypeName
    #|MaxLength 255
    [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=0)]
    [String]
    $TypeName,
    
    # A collection of virtual method names and the script blocks that will be used to run the virtual method.
    [ValidateScript({
        if ($_.Keys | ? {$_-isnot [string]}) {
            throw "Must provide the names of script methods"
        }
        if ($_.Values | ? {$_ -isnot [ScriptBlock]}) {
            throw "Must provide script blocks to handle each method"
        }
        return $true
    })]
    [Hashtable]$ScriptMethod,

    # A Collection of virtual property names and the script blocks that will be used to get the property values.
    [ValidateScript({
        if ($_.Keys | ? {$_ -isnot [string]}) {
            throw "Must provide the names of script properties"
        }
        if ($_.Values | ? {$_-isnot [ScriptBlock]} ) {
            throw "Must provide script blocks to handle each property"
        }
        return $true
    })]   
    [Hashtable]$ScriptProperty,    
    
    # A collection of fixed property values.
    [ValidateScript({
        if ($_.Keys | ? { $_-isnot [string] } ) {
            throw "Must provide the names of note properties"
        }
        return $true
    })]
    [Hashtable]$NoteProperty,

    # A collection of property aliases
    [ValidateScript({
        if ($_.Keys | ? { $_-isnot [string]}) {
            throw "Must provide the names of alias properties"
        }
        if ($_.Keys | ? {$_-isnot [string]}) {
            throw "Must provide the names of properties to alias"
        }
        return $true
    })]
    [Hashtable]$AliasProperty,

    # A collection of code methods.  A code method maps a 
    [ValidateScript({
        if ($_.Keys | ? {$_-isnot [string]}) {
            throw "Must provide the names of code methods"
        }
        if ($_.Values | ? {$_-isnot [Reflection.MethodInfo]}) {
            throw "Must provide the static method to run"
        }
        return $true
    })]
    [Hashtable]$CodeMethod,
    
    # Any code properties for an object
    [ValidateScript({
        if ($_.Keys |? {$_-isnot [string]}) {
            throw "Must provide the names of code properties"
        }
        if ($_.Values | ? {$_-isnot [Reflection.MethodInfo]}) {
            throw "Must provide the static method to run"
        }
        return $true
    })]
    [Hashtable]$CodeProperty,
    
    # The default display.  If only one propertry is used, 
    # this will set the default display property.  If more than one property is used, 
    # this will set the default display member set
    [string[]]$DefaultDisplay,
    
    # The ID property
    [string]$IdProperty,
    
    # The serialization depth.  If the type is deserialized, this is the depth of subpropeties
    # that will be stored.  For instance, a serialization depth of 3 would storage an object, it's
    # subproperties, and those objects' subproperties.  You can use the serialization depth 
    # to minimize the overhead of moving objects back and forth across the remoting boundary, 
    # or to ensure that you capture the correct information.      
    [int]$SerializationDepth = 2,
       
    # The reserializer type used for recreating a deserialized type
    [Type]$Reserializer,
    
    # Property sets define default views for an object.  A property set can be used with Select-Object
    # to display just that set of properties.
    [ValidateScript({
        if ($_.Keys | ? {$_ -isnot [string] } ) {
            throw "Must provide the names of property sets"
        }
        if ($_.Values | 
            Where-Object {$_ -isnot [string] -and  $_ -isnot [Object[]] }){
            throw "Must provide a name or list of names for each property set"
        }
        return $true
    })]
    [Hashtable]$PropertySet,
    
    
    # Will hide any properties in the list from a display
    [string[]]$HideProperty
    )
    
    
    process {
        $memberSetXml = ""
        
        #region Construct Member Set
        if ($psBoundParameters.ContainsKey('SerializationDepth') -or
            $psBoundParameters.ContainsKey('IdProperty') -or 
            $psBoundParameters.ContainsKey('DefaultDisplay')) {
            $defaultDisplayXml = if ($psBoundParameters.ContainsKey('DefaultDisplay')) {
$referencedProperties = "<Name>" + ($defaultDisplay -join "</Name>
                        <Name>") + "</Name>"
"                <PropertySet>
                    <Name>DefaultDisplayPropertySet</Name>
                    <ReferencedProperties>
                        $referencedProperties
                    </ReferencedProperties>
                </PropertySet>

"                            
            }
            $serializationDepthXml = if ($psBoundParameters.ContainsKey('SerializationDepth')) {
                "
                <NoteProperty>
                    <Name>SerializationDepth</Name>
                    <Value>$SerializationDepth</Value>
                </NoteProperty>"
            } else {$null } 
            
            $ReserializerXml = if ($psBoundParameters.ContainsKey('Reserializer'))  {
"
                <NoteProperty>
                    <Name>TargetTypeForDeserialization</Name>
                    <Value>$Reserializer</Value>
                </NoteProperty>

"                
            } else { $null }
            
            $memberSetXml = "
            <MemberSet>
                <Name>PSStandardMembers</Name>
                <Members>
                    $defaultDisplayXml
                    $serializationDepthXml
                    $reserializerXml                    
                </Members>
            </MemberSet>
            "
        }
        #endregion Construct Member Set
        
        #region PropertySetXml
        $propertySetXml  = if ($psBoundParameters.PropertySet) {
            foreach ($NameAndValue in $PropertySet.GetEnumerator()) {
                $referencedProperties = "<Name>" + ($NameAndValue.Value -join "</Name>
                    <Name>") + "</Name>"
            "<PropertySet>
                <Name>$([Security.SecurityElement]::Escape($NameAndValue.Key))</Name>
                <ReferencedProperties>
                    $referencedProperties
                </ReferencedProperties>
            </PropertySet>"                              
            }
        } else {
            ""
        }
        #endregion
                    


        #region Aliases        
        $aliasPropertyXml = if ($psBoundParameters.AliasProperty) {            
            foreach ($NameAndValue in $AliasProperty.GetEnumerator()) {
                $isHiddenChunk = if ($HideProperty -contains $NameAndValue.Key) {
                    'IsHidden="true"'
                } else { ""}
                
                "
            <AliasProperty $isHiddenChunk>
                <Name>$([Security.SecurityElement]::Escape($NameAndValue.Key))</Name>
                <ReferencedMemberName>$([Security.SecurityElement]::Escape($NameAndValue.Value))</ReferencedMemberName>
            </AliasProperty>"                              
            }
        } else {
            ""
        }
        #endregion Aliases
        $codeMethodXml = if ($psBoundParameters.CodeMethod) {
            foreach ($NameAndValue in $CodeMethod.GetEnumerator()) {
                $isHiddenChunk = if ($HideProperty -contains $NameAndValue.Key) {
                    'IsHidden="true"'
                } else { ""}
                
                "
            <CodeMethod $isHiddenChunk>
                <Name>$([Security.SecurityElement]::Escape($NameAndValue.Key))</Name>
                <CodeReference>
                    <TypeName>$($NameAndValue.Value.DeclaringType)</TypeName>
                    <MethodName>$($NameAndValue.Value.Name)</MethodName>
                </CodeReference>
            </CodeMethod>"                        
            }
        } else {
            ""
        }
        $codePropertyXml = if ($psBoundParameters.CodeProperty) {
            foreach ($NameAndValue in $CodeProperty.GetEnumerator()) {
                $isHiddenChunk = if ($HideProperty -contains $NameAndValue.Key) {
                    'IsHidden="true"'
                } else { ""}
                
                "
            <CodeProperty $IsHiddenChunk>
                <Name>$([Security.SecurityElement]::Escape($NameAndValue.Key))</Name>
                <CodeReference>
                    <TypeName>$($NameAndValue.Value.DeclaringType)</TypeName>
                    <MethodName>$($NameAndValue.Value.Name)</MethodName>
                </CodeReference>
            </CodeProperty>"                        
            }
        } else {
            ""
        }
        $NotePropertyXml = if ($psBoundParameters.NoteProperty) {
            foreach ($NameAndValue in $NoteProperty.GetEnumerator()) {
                $isHiddenChunk = if ($HideProperty -contains $NameAndValue.Key) {
                    'IsHidden="true"'
                } else { ""}
                
                "
            <NoteProperty $isHiddenChunk>
                <Name>$([Security.SecurityElement]::Escape($NameAndValue.Key))</Name>
                <Value>$([Security.SecurityElement]::Escape($NameAndValue.Value))</Value>
            </NoteProperty>"                        
            }
        } else {
            ""
        }               
        $scriptMethodXml = if ($psBoundParameters.ScriptMethod) {
            foreach ($methodNameAndCode in $ScriptMethod.GetEnumerator()) {
                $isHiddenChunk = if ($HideProperty -contains $methodNameAndCode.Key) {
                    'IsHidden="true"'
                } else { ""}
                "
            <ScriptMethod $isHiddenChunk>
                <Name>$($methodNameAndCode.Key)</Name>
                <Script>
                    $([Security.SecurityElement]::Escape($methodNameAndCode.Value))
                </Script>
            </ScriptMethod>"                        
            }
        } else {
            ""
        }
        
        #region Script Property
        $scriptPropertyXml = if ($psBoundParameters.ScriptProperty) {
            foreach ($propertyNameAndCode in $ScriptProperty.GetEnumerator()) {
                $isHiddenChunk = if ($HideProperty -contains $propertyNameAndCode.Key) {
                    'IsHidden="true"'
                } else { ""}
                "
            <ScriptProperty $isHiddenChunk>
                <Name>$($propertyNameAndCode.Key)</Name>
                <GetScriptBlock>
                    $([Security.SecurityElement]::Escape($propertyNameAndCode.Value))
                </GetScriptBlock>
            </ScriptProperty>"                        
            }
        }
        
        $innerXml = @($memberSetXml) + $propertySetXml + $aliasPropertyXml + $codePropertyXml + $codeMethodXml + $scriptMethodXml + $scriptPropertyXml + $NotePropertyXml
        
        $innerXml = ($innerXml  | ? {$_} ) -join ([Environment]::NewLine)
        "
    <Type>
        <Name>$TypeName</Name>
        <Members>
            $innerXml
        </Members>
    </Type>"                
    }

} 

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUtgW99DiwI3vAHOfey1lzahoD
# LmGgggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFM7MSWbbPCR8WXMn
# B9GK/a2n13urMA0GCSqGSIb3DQEBAQUABIIBAIIjkh123TzzOjaYAFt9OBxHqDFG
# iw+wXbPZ+8qaXK2oDpOlepUOgamx/vqea0FDCaxvCWZWSs8Uyv3CkJXGbFJJ0PFR
# NiSBtzPLvZ0LRqaJxe6mGl8LQW94CftFMOBHwIFgfACHleSgpf8wFo4rdLxfbwGu
# 4IlFZw1kgX/WY5Z8w1ceNLKawGPxR/xjw8euvIgS5E0W6zgVFITcvsj5GRA8sIZ1
# v4rHrbETNNf7tZqfEo/KyNoAL5pFMOyysAEQxt/imDt746MpP8Yn19i2/xUP29qz
# +upRg2yDjum3aJ9cpqDng60DY38ANWq0CX13WTt1HfxLSggFW1qNPqXFmu8=
# SIG # End signature block
