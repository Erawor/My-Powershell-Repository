@{                         
    SecureSetting = 'AzureStorageAccountName', 'AzureStorageAccountKey'
    
    Blog = @{
        Name = "Update-Web"
        Description = "PowerShell, Pipeworks and the Semantic Web"
        Link = "http://update-web.com/"                
    }
    
    GoogleSiteVerification  = 'xjCcGADm2Pnu7fF3WZnPj5UYND9SVqB3qzJuvhe0k1o'
    BingValidationKey = '7B94933EC8C374B455E8263FCD4FE5EF'
    
    Table = @{
        Name = 'Pipeworks'
        StorageAccountSetting = 'AzureStorageAccountName'
        StorageKeySetting = 'AzureStorageAccountKey'
    }
    
    Logo = "/Assets/PowershellPipeworks_150.png"
        
    
    Style = @{
        body = @{
            "font-family" = "'Segoe UI Symbol', Helvetica, Arial, sans-serif"            
            'color' = '#012456'
            'background' = '#FFFFFF'
        }
        'a' = @{
            'color' = '#012456'
        }
        
        'a:hover' = @{
            'text-decoration' ='none'
        }
        '.MajorMenuItem' = @{
            'font-size' = 'large'
        }
        '.MinorMenuItem' = @{
            'font-size' = 'medium'            
        }
        '.ExplanationParagraph' = @{
            'font-size' = 'medium'
            'text-indent' = '-10px'
        }
        '.ModuleWalkthruExplanation' = @{
            'font-size' = 'medium'           
        }
        '.PowerShellColorizedScript' = @{
            'font-size' = 'medium'
        }
        
    }
    UseJQueryUI = $true
    JQueryUITheme = 'Custom'
    WebCommand = @{
        "Write-Link" = @{
            HideParameter = "AmazonAccessKey", "AmazonSecretKey", "AmazonReturnUrl",  "AmazonInputUrl", 
                "AmazonIpnUrl", "UseOAth", "CollectShippingAddress", "AmazonAbandonUrl", "ToFacebookLogin", 
                "FacebookAppId", "ModuleServiceUrl", "FacebookLoginScope", "AmazonPaymentsAccountID", "GoogleCheckoutMerchantID", "SortedLinkTable"
            PlainOutput = $true
            
        }        
        "New-PipeworksManifest" = @{
            ContentType = 'text/plain'
        }
        
        "ConvertFrom-InlinePowerShell" = @{            
            HideParameter = @('MasterPage', 'CodeFile',  'Inherit', 'RunScriptMethod', 'FileName')            
            PlainOutput = $true
            ContentType = "text/plain"
            FriendlyName = "Write PowerShell in HTML"                        
        }
        "ConvertFrom-Markdown" = @{                        
            ParameterAlias = @{
                'm' = 'Markdown'
                'md' = 'Markdown'
            }
            FriendlyName = "Mess With Markdown"                        
        }
               
        "Write-ScriptHTML" = @{
            
            PlainOutput = $true
            HideParameter = @('Palette', 'Start', 'End', 'Script')
            ParameterOrder = 'Text'
            ParameterAlias = @{
                't'= 'Text'
                
            }
            FriendlyName = "Show Scripts as HTML"                        
        }
        "Write-ASPDotNetScriptPage" = @{
            
            PlainOutput = $true
            ContentType = "text/plain"         
            HideParameter = @('MasterPage', 'CodeFile',  'Inherit', 'RunScriptMethod', 'FileName')            
            FriendlyName = "PowerShell in ASP.NET"                        
        }

        "Write-Crud" = @{
            ContentType = "text/plain"         
            PlainOutput = $true
        }
        
    }

    CommandGroup = @{
        "Play with Pipeworks" = "Write-ASPDotNetScriptPage", "ConvertFrom-InlinePowerShell", "ConvertFrom-Markdown", "Write-Crud", "Write-ScriptHTML"
    }



    TopicGroup = @{
        "Getting Started" = "About PowerShell Pipeworks", "Pipeworks Quickstart", "Building Basic Websites With PowerShell Pipeworks", "Making Tables with Out-HTML"
        
    }, @{
        "Connecting the Clouds" = "Using Azure Table Storage in Pipeworks", "Writing CRUD in Pipeworks", "Managing Amazon Web Services with PowerShell"
    }


    TrustedWalkthrus = 'New-Region Billboard','Making Tables With Out-HTML', 'Using Write-Link', 
        'New-Region And JQueryUI','Write-Link Basics', 'Write-Link Rich Media', 'Write-Link -SortedLinkTable', 'Making Editing Easier with Markdown'
    WebWalkthrus = 'New-Region Billboard','Making Tables With Out-HTML', 'Using Write-Link', 
        'New-Region And JQueryUI', 'Write-Link Basics', 'Write-Link -SortedLinkTable', 'Write-Link Rich Media', 'Making Editing Easier with Markdown'
        
    
    AnalyticsId = 'UA-24591838-13'
    
   
    Facebook = @{
        AppId = '250363831747570'
    }
    
    DomainSchematics = @{
        "PowerShellPipeworks.com | www.PowerShellPipeworks.com" = "Default"
    }
    
    AllowDownload = $true


    Win8 = @{
        Identity = @{
            Name="Start-Automating.PowerShellPipeworks"
            Publisher="CN=3B09501A-BEC0-4A17-8A3D-3DAACB2346F3"
            Version="1.0.0.0"
        }
        Assets = @{
            "splash.png" = "/PowerShellPipeworks_Splash.png"
            "smallTile.png" = "/PowerShellPipeworks_Small.png"
            "wideTile.png" = "/PowerShellPipeworks_Wide.png"
            "storeLogo.png" = "/PowerShellPipeworks_Store.png"
            "squaretile.png" = "/PowerShellPipeworks_Tile.png"
        }
        ServiceUrl = "http://PowerShellPipeworks.com"

        Name = "PowerShell Pipeworks"

    }
    
} 
