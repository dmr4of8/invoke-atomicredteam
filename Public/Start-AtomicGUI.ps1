function Start-AtomicGUI {
    param (
        [Int] $port = 8487,

        [String]$PathToAtomicsFolder = $( if ($IsLinux -or $IsMacOS) { $Env:HOME + "/AtomicRedTeam/atomics" } else { $env:HOMEDRIVE + "\AtomicRedTeam\atomics" })
    )
    # Install-Module UniversalDashboard if not already installed
    # TODO: Uncomment this later
    # $UDcommunityInstalled = Get-InstalledModule -Name "UniversalDashboard.Community" -ErrorAction:SilentlyContinue
    # $UDinstalled = Get-InstalledModule -Name "UniversalDashboard" -ErrorAction:SilentlyContinue
    # if (-not $UDcommunityInstalled -and -not $UDinstalled) { 
    #     Write-Host "Installing UniversalDashboard.Community"
    #     Install-Module -Name UniversalDashboard.Community -Scope CurrentUser -Force
    # }

    ############## Function Definitions Made Available to EndPoints
    function New-UDTextAreaX ($ID, $PlaceHolder) {
        New-UDElement -Tag div -Attributes @{class = "input-field col" } -Content {
            New-UDElement -Tag "textarea" -id  $ID -Attributes @{ class = "materialize-textarea ud-input" }
            New-UDElement -Tag Label -Attributes @{for = $ID } -Content { $PlaceHolder }
        }
    }

    function New-UDTextBoxX ($ID, $PlaceHolder) {
        New-UDElement -Tag div -Attributes @{class = "input-field col" } -Content {
            New-UDElement -Tag "input" -id $ID -Attributes @{ class = "ud-input"; type = "text" }
            New-UDElement -Tag Label -Attributes @{for = $ID } -Content { $PlaceHolder }
        }
    }

    $InputArgCards = @{ }
    $platform = "windows"
    if ($IsLinux) { $platform = "linux" }
    if ($IsMacOS) { $platform = "macos" }
    # Get list of tactics
    $index = Get-Content $PathToAtomicsFolder\Indexes\Indexes-CSV\index.csv | ConvertFrom-Csv
    $tactics = $index.tactic | get-unique
    # Get array of all tactics for quick access
    $AllTechniques = Get-ChildItem $PathToAtomicsFolder\* -Recurse -Include 'T*.yaml' | Get-AtomicTechnique

    function New-InputArgCard {
        $cardNumber = $InputArgCards.count + 1
        $newCard = New-UDCard -ID "InputArgCard$cardNumber" -Content {
            New-UDTextBoxX "InputArgCard$cardNumber-InputArgName" "Input Argument Name"
            New-UDTextAreaX "InputArgCard$cardNumber-InputArgDescription" "Description"        
            New-UDTextBoxX "InputArgCard$cardNumber-InputArgDefault" "Default Value" 
            New-UDLayout -columns 4 {
                New-UDSelect -ID "InputArgCard$cardNumber-InputArgType" -Label "Type" -Option {
                    New-UDSelectOption -Name "Path" -Value "path"
                    New-UDSelectOption -Name "String" -Value "string"
                    New-UDSelectOption -Name "Url" -Value "url"
                    New-UDSelectOption -Name "Integer" -Value "integer"
                }
            }
            New-UDButton -Text "Remove this Input Argument"  -OnClick (
                New-UDEndpoint -Endpoint {
                    Remove-UDElement -Id "InputArgCard$cardNumber"
                    $inputArgCards["InputArgCard$cardNumber"] = $true
                } -ArgumentList @($cardNumber, $inputArgCards)
            )
        }
        $InputArgCards.Add("InputArgCard$cardNumber", $false) | Out-Null
        $newCard
    }

    $depCards = @{ }
    function New-depCard {
        $cardNumber = $depCards.count + 1
        $newCard = New-UDCard -ID "depCard$cardNumber" -Content {
            New-UDTextBoxX "depCard$cardNumber-depDescription" "Prereq Description"
            New-UDTextAreaX "depCard$cardNumber-prereqCommand" "Check prereqs Command"        
            New-UDTextAreaX "depCard$cardNumber-getPrereqCommand" "Get Prereqs Command"        
            New-UDButton -Text "Remove this Prereq"  -OnClick (
                New-UDEndpoint -Endpoint {
                    Remove-UDElement -Id "depCard$cardNumber"
                    $depCards["depCard$cardNumber"] = $true
                } -ArgumentList @($cardNumber, $depCards)
            )
        }
        $depCards.Add("depCard$cardNumber", $false) | Out-Null
        $newCard
    }

    function New-UDSelectX ($Id, $Label) {
        New-UDSelect -Label $Label -Id $Id -Option {
            New-UDSelectOption -Name "PowerShell" -Value "PowerShell" -Selected
            New-UDSelectOption -Name "Command Prompt" -Value "CommandPrompt" 
            New-UDSelectOption -Name "Bash" -Value "Bash"
            New-UDSelectOption -Name "Sh" -Value "Sh"
        }
    }

    function Set-EnableButton {
        param (
            [switch]$disabled
        )
        Set-UDElement -Id "execute" -Attributes @{disabled = $disabled }
        Set-UDElement -Id "cleanup" -Attributes @{disabled = $disabled }
        Set-UDElement -Id "checkPrereqs" -Attributes @{disabled = $disabled }
        Set-UDElement -Id "getPrereqs" -Attributes @{disabled = $disabled }
    }

    function New-TechniqueSelected {
        param (
            $selectedTechnique,
            $techniques
        )
        # Clear dashboard
        Clear-UDElement -Id "testColumn"
        Clear-UDElement -Id "inputArgs"
        Clear-UDElement -Id "output"
        Set-EnableButton -disabled
        if ($selectedTechnique -eq "Select") {
            Show-UDToast -Message "You must select a technique"
            return;
        }
        # Get technique from select value string
        $splitArray = $selectedTechnique.Split(",")
        $selectedTechnique = $splitArray[0]
        Clear-UDElement -Id "testColumn"
        # Create test dropdown select
        $techniqueObject = $techniques | Where-Object { $_.display_name -eq $selectedTechnique }
        $techniqueName = $techniqueObject.display_name
        $atomicTestOptions = @()
        $atomicTestOptions += New-UDSelectOption -Name "Select" -Value "Select"
        foreach ($atomic in ($techniqueObject.atomic_tests | Where-Object { $_.supported_platforms -contains $platform })) {
            $atomicTestOptions += New-UDSelectOption -Name $atomic.name -Value "$($atomic.auto_generated_guid),$($techniqueName)" 
        }
        Add-UDElement -ParentId "testColumn" -Content {
            New-UDSelect -Label "Select MITRE ATT&CK Test" -Id "testSelectOptions" -Option { $atomicTestOptions
            } -OnChange { New-TestSelected -selectedTest $EventData -techniques $techniques }
        } 
        
    }

    function New-TestSelected {
        param (
            $selectedTest,
            $techniques
        )
        # Clear dashboard
        Clear-UDElement -Id "inputArgs"
        Clear-UDElement -Id "output"
        Set-EnableButton -disabled
        if ($selectedTest -eq "Select") {
            Show-UDToast -Message "You must select a test"
            return;
        }

        # Get test guid and selected technique from select value string
        $testGuid = $selectedTest.Split(",")[0]
        # Create input argument inputs
        $atomicTestObject = $AllTechniques.atomic_tests | where-object { $_.auto_generated_guid -eq $testGuid }
        $inputArguments = $atomicTestObject.input_arguments
        if ( $inputArguments.Length -gt 0) {
            Add-UDElement -ParentId "inputArgs" -Content {
                New-UDCard -Id "inputArgsCard" -TextAlignment 'center' -Content {
                    New-UDElement -Tag "h1" -Attributes @{ style = @{ fontWeight = "300"; fontSize = "24px"; margin = "10px" } } -Content { "Input Arguments" }
                }
            }
            foreach ($key in $inputArguments.keys) {
                $numInputArgs++
                Add-UDElement -ParentId "inputArgsCard" -Content {
                    New-UDRow  -Id "inputArgRows" -Columns {
                        New-UDColumn -Size 4 {}
                        New-UDColumn -Size 8 {
                            New-UDColumn -Size 4 {
                                New-UDElement -Tag 'h3' -Id "inputArg $($numInputArgs)" -Attributes @{ className = "$($inputArguments.Length),$key"; style = @{fontSize = "16px"; margin = "30px" } } -Content {
                                    $key
                                }
                            }
                            # New-UDColumn -Size 6 { 
                            #     New-UDTextBox -Label $inputArguments[$key].description -Id "$($numInputArgs) default" -Value $inputArguments[$key].default
                            # }
                            New-UDColumn -Size 8 { 
                                New-UDTextBox -Id "$($numInputArgs) default" -Label $inputArguments[$key].description -Value $inputArguments[$key].default
                            }    
                        }    
                    }
                }
            }
        }
        # Enable buttons
        Set-EnableButton
    }

    ############## End Function Definitions Made Available to EndPoints

    # EndpointInitialization defining which methods, modules, and variables will be available for use within an endpoint
    $ei = New-UDEndpointInitialization `
        -Function @("New-InputArgCard", "New-depCard", "New-UDTextAreaX", "New-UDTextBoxX", "New-UDSelectX", "New-TechniqueSelected", "New-TestSelected", "Set-EnableButton") `
        -Variable @("InputArgCards", "depCards", "yaml", "tactics", "AllTechniques", "platform") `
        -Module @("..\Invoke-AtomicRedTeam.psd1")

    ############## EndPoint (ep) Definitions: Dynamic code called to generate content for an element or perfrom onClick actions
    $BuildAndDisplayYamlScriptBlock = {   
        $testName = (Get-UDElement -Id atomicName).Attributes['value']
        $testDesc = (Get-UDElement -Id atomicDescription).Attributes['value']
        $platforms = @()
        if ((Get-UDElement -Id spWindows).Attributes['checked']) { $platforms += "Windows" }
        if ((Get-UDElement -Id spLinux).Attributes['checked']) { $platforms += "Linux" }
        if ((Get-UDElement -Id spMacOS).Attributes['checked']) { $platforms += "macOS" }
        $attackCommands = (Get-UDElement -Id attackCommands).Attributes['value']
        $executor = (Get-UDElement -Id executorSelector).Attributes['value']
        $elevationRequired = (Get-UDElement -Id elevationRequired).Attributes['checked']
        $cleanupCommands = (Get-UDElement -Id cleanupCommands).Attributes['value']
        if ("" -eq $executor) { $executor = "PowerShell" }
        # input args
        $inputArgs = @()
        $InputArgCards.GetEnumerator() | ForEach-Object {
            if ($_.Value -eq $false) {
                # this was not deleted
                $prefix = $_.key
                $InputArgName = (Get-UDElement -Id "$prefix-InputArgName").Attributes['value']
                $InputArgDescription = (Get-UDElement -Id "$prefix-InputArgDescription").Attributes['value']
                $InputArgDefault = (Get-UDElement -Id "$prefix-InputArgDefault").Attributes['value']
                $InputArgType = (Get-UDElement -Id "$prefix-InputArgType").Attributes['value']
                if ("" -eq $InputArgType) { $InputArgType = "String" }
                $NewInputArg = New-AtomicTestInputArgument -Name $InputArgName -Description $InputArgDescription -Type $InputArgType -Default $InputArgDefault -WarningVariable +warnings
                $inputArgs += $NewInputArg
            }
        }
        # dependencies
        $dependencies = @()
        $preReqEx = ""
        $depCards.GetEnumerator() | ForEach-Object {
            if ($_.Value -eq $false) {
                # a value of true means the card was deleted, so only add dependencies from non-deleted cards
                $prefix = $_.key
                $depDescription = (Get-UDElement -Id "$prefix-depDescription").Attributes['value']
                $prereqCommand = (Get-UDElement -Id "$prefix-prereqCommand").Attributes['value']
                $getPrereqCommand = (Get-UDElement -Id "$prefix-getPrereqCommand").Attributes['value']
                $preReqEx = (Get-UDElement -Id "preReqEx").Attributes['value']
                if ("" -eq $preReqEx) { $preReqEx = "PowerShell" }
                $NewDep = New-AtomicTestDependency -Description $depDescription -PrereqCommand $prereqCommand -GetPrereqCommand $getPrereqCommand -WarningVariable +warnings
                $dependencies += $NewDep
            }
        }
        $depParams = @{ }
        if ($dependencies.count -gt 0) {
            $depParams.add("DependencyExecutorType", $preReqEx)
            $depParams.add("Dependencies", $dependencies)
        }
        if (($cleanupCommands -ne "") -and ($null -ne $cleanupCommands)) { $depParams.add("ExecutorCleanupCommand", $cleanupCommands) }
        $depParams.add("ExecutorElevationRequired", $elevationRequired)

        $AtomicTest = New-AtomicTest -Name $testName -Description $testDesc -SupportedPlatforms $platforms -InputArguments $inputArgs -ExecutorType $executor -ExecutorCommand $attackCommands -WarningVariable +warnings @depParams                                           
        $yaml = ($AtomicTest | ConvertTo-Yaml) -replace "^", "- " -replace "`n", "`n  "
        foreach ($warning in $warnings) { Show-UDToast $warning -BackgroundColor LightYellow -Duration 10000 }
        New-UDElement -ID yaml -Tag pre -Content { $yaml }
    } 

    $epYamlModal = New-UDEndpoint -Endpoint {
        Show-UDModal -Header { New-UDHeading -Size 3 -Text "Test Definition YAML" } -Content {
            new-udrow -endpoint $BuildAndDisplayYamlScriptBlock
            # Left arrow button (decrease indentation)
            New-UDButton -Icon arrow_circle_left -OnClick (
                New-UDEndpoint -Endpoint {
                    $yaml = (Get-UDElement -Id "yaml").Content[0]
                    if (-not $yaml.startsWith("- ")) {
                        Set-UDElement -Id "yaml" -Content {
                            $yaml -replace "^  ", "" -replace "`n  ", "`n"
                        }
                    }
                }
            )
            # Right arrow button (increase indentation)
            New-UDButton -Icon arrow_circle_right -OnClick (
                New-UDEndpoint -Endpoint {
                    $yaml = (Get-UDElement -Id "yaml").Content[0]
                    Set-UDElement -Id "yaml" -Content {
                        $yaml -replace "^", "  " -replace "`n", "`n  "
                    }
                }
            )
            # Copy Yaml to clipboard
            New-UDButton -Text "Copy" -OnClick (
                New-UDEndpoint -Endpoint {
                    $yaml = (Get-UDElement -Id "yaml").Content[0]
                    Set-UDClipboard -Data $yaml
                    Show-UDToast -Message "Copied YAML to the Clipboard" -BackgroundColor YellowGreen 
                }
            )
        }
    }

    $epFillTestData = New-UDEndpoint -Endpoint {
        Add-UDElement -ParentId "inputCard" -Content { New-InputArgCard }        
        Add-UDElement -ParentId "depCard"   -Content { New-depCard }
        Start-Sleep 1
        Set-UDElement -Id atomicName -Attributes @{value = "My new atomic" }
        Set-UDElement -Id atomicDescription -Attributes @{value = "This is the atomic description" }
        Set-UDElement -Id attackCommands -Attributes @{value = "echo this`necho that" }
        Set-UDElement -Id cleanupCommands -Attributes @{value = "cleanup commands here`nand here..." }
        # InputArgs
        $cardNumber = 1
        Set-UDElement -Id "InputArgCard$cardNumber-InputArgName" -Attributes @{value = "input_arg_1" }
        Set-UDElement -Id "InputArgCard$cardNumber-InputArgDescription" -Attributes @{value = "InputArg1 description" }        
        Set-UDElement -Id "InputArgCard$cardNumber-InputArgDefault" -Attributes @{value = "this is the default value" }        
        # dependencies
        Set-UDElement -Id "depCard$cardNumber-depDescription" -Attributes @{value = "This file must exist" }
        Set-UDElement -Id "depCard$cardNumber-prereqCommand" -Attributes @{value = "if (this) then that" }       
        Set-UDElement -Id "depCard$cardNumber-getPrereqCommand" -Attributes @{value = "iwr" }       
        
    }

    $epNewTacticSelected = New-UDEndpoint -Endpoint {
        $selectedTactic = (Get-UDElement -Id tacticSelector).Attributes['value']
        # Clear dashboard
        Clear-UDElement -Id "inputArgs"
        Clear-UDElement -Id "output"
        Set-EnableButton -disabled
        Clear-UDElement -Id "techniqueColumn"
        Clear-UDElement -Id "testColumn"
        if ($selectedTactic -eq "Select") {
            Show-UDToast -Message "You must select a tactic"
            return;
        }
        # Create technique select dropdown
        $techiqueIDs = ($index | where-object { $_.Tactic -eq $selectedTactic }).'Technique #' | Get-Unique
        $techniques = $AllTechniques | Where-Object { $techiqueIDs -contains $_.attack_technique }
        $techniqueOptions = $techniques | ForEach-Object { New-UDSelectOption -Name $_.display_name -Value "$($_.display_name),$($_.attack_technique)" }
        $mitreTechniqueOptions = @()
        $mitreTechniqueOptions += New-UDSelectOption -Name "Select" -Value "Select"
        $mitreTechniqueOptions += $techniqueOptions
        Add-UDElement -ParentId "techniqueColumn" -Content {
            New-UDSelect -Label "Select MITRE ATT&CK Technique" -Id "techniqueSelectOptions" -Option {
                $mitreTechniqueOptions
            } -OnChange { New-TechniqueSelected -selectedTechnique $EventData -techniques $techniques }
        } 
    }
    $epRunAtomicTest = New-UDEndpoint -Endpoint {
        Clear-UDElement -Id "output"
        $inputArgs = @{}
        $numArgs = 0
        try {
            # Calculates the number of input arguments (stored in className of the first input argument)
            $classString = (Get-UDElement -Id 'inputArg 1').Attributes['className']
            $classSplit = $classString.Split(",")
            $numArgsString = $classSplit[0]
            $inputArgName = $classSplit[1]
            $numArgs = [int]$numArgsString
        }
        catch {
            # If there is no first input argument, sets the number of args to 0
            $numArgs = 0
        }
        # If there are input arguments, creates a hashmap of the arguments and their values
        if ($numArgs -gt 0) {
            for ($i = 1; $i -le $numArgs; $i++) {
                $inputArgValue = (Get-UDElement -Id "$i default").Attributes['value']
                $inputArgs["$inputArgName"] = "$inputArgValue"
            }
        }
        # Gets the tNumber and testGuid from inputs
        $selectedTechnique = (Get-UDElement -Id 'techniqueSelectOptions').Attributes['value']
        $techniqueSplit = $selectedTechnique.Split(",")
        $tNumber = $techniqueSplit[1]
        $testGuidString = (Get-UDElement -Id "testSelectOptions").Attributes['value']
        $testSplit = $testGuidString.Split(",")
        $testGuid = $testSplit[0]
        # Executes atomic test and outputs result to a new card
        # Output is currently formatted in UTF-16, needs to be encoded to ascii
        $output = (Invoke-AtomicTest $tNumber -TestGuids $testGuid  -InputArgs $inputArgs *>&1 )
        Set-UDElement -Id "output" -Content { 
            New-UDCard -Id 'outputCard' -Content {
                New-UDElement -Tag 'span' -Attributes  @{ style = @{whiteSpace = "pre-wrap" } } -Content {
                    Out-String -InputObject $output -Width 100
                }
            }
        }
    }

    $epCleanupAtomicTest = New-UDEndpoint -Endpoint {
        Clear-UDElement -Id "output"
        # Gets the tNumber and testGuid from inputs
        $testGuidString = (Get-UDElement -Id "testSelectOptions").Attributes['value']
        $testSplit = $testGuidString.Split(",")
        $testGuid = $testSplit[0]
        $selectedTechnique = (Get-UDElement -Id 'techniqueSelectOptions').Attributes['value']
        $techniqueSplit = $selectedTechnique.Split(",")
        $tNumber = $techniqueSplit[1]
        # Runs cleanup and outputs result to a new card
        $output = (Invoke-AtomicTest $tNumber -TestGuids $testGuid -Cleanup *>&1)
        Set-UDElement -Id "output" -Content { 
            New-UDCard -Id 'outputCard' -Content {
                New-UDElement -Tag 'span' -Attributes  @{ style = @{whiteSpace = "pre-wrap" } } -Content {
                    Out-String -InputObject $output -Width 100
                }
            }
        }
    }

    $epResetDashboard = New-UDEndpoint -Endpoint {
        # This is currently not functioning, it should reset the tactic select to 'Select'
        Set-UDElement -Id "tacticSelector" -Attributes @{name = "Select" }
        # Clears all data except the first select
        Clear-UDElement -Id "techniqueColumn"
        Clear-UDElement -Id "testColumn"
        Clear-UDElement -Id "inputArgs"
        Clear-UDElement -Id "output"
        Set-EnableButton -disabled
    }
    $epCheckPrereqs = New-UDEndpoint -Endpoint {
        Clear-UDElement -Id "output"
        # Gets the tNumber and testGuid from inputs
        $testGuidString = (Get-UDElement -Id "testSelectOptions").Attributes['value']
        $testSplit = $testGuidString.Split(",")
        $testGuid = $testSplit[0]
        $selectedTechnique = (Get-UDElement -Id 'techniqueSelectOptions').Attributes['value']
        $techniqueSplit = $selectedTechnique.Split(",")
        $tNumber = $techniqueSplit[1]
        # Runs checkPrereqs and outputs result to a new card
        $output = (Invoke-AtomicTest $tNumber -TestGuids $testGuid -CheckPrereqs *>&1)
        Set-UDElement -Id "output" -Content { 
            New-UDCard -Id 'outputCard' -Content {
                New-UDElement -Tag 'span' -Attributes  @{ style = @{whiteSpace = "pre-wrap" } } -Content {
                    Out-String -InputObject $output -Width 100
                }
            }
        }
    }
    $epGetPrereqs = New-UDEndpoint -Endpoint {
        Clear-UDElement -Id "output"
        # Gets the tNumber and testGuid from inputs
        $testGuidString = (Get-UDElement -Id "testSelectOptions").Attributes['value']
        $testSplit = $testGuidString.Split(",")
        $testGuid = $testSplit[0]
        $selectedTechnique = (Get-UDElement -Id 'techniqueSelectOptions').Attributes['value']
        $techniqueSplit = $selectedTechnique.Split(",")
        $tNumber = $techniqueSplit[1]
        # Runs getPrereqs and outputs result to a new card
        $output = (Invoke-AtomicTest $tNumber -TestGuids $testGuid -GetPrereqs *>&1 )
        Set-UDElement -Id "output" -Content { 
            New-UDCard -Id 'outputCard' -Content {
                New-UDElement -Tag 'span' -Attributes  @{ style = @{whiteSpace = "pre-wrap" } } -Content {
                    Out-String -InputObject $output -Width 100
                }
            }
        }
    }

    ############## End EndPoint (ep) Definitions

    ############## Static Definitions
    $supportedPlatforms = New-UDLayout -Columns 4 {
        New-UDElement -Tag Label -Attributes @{ style = @{"font-size" = "15px" } } -Content { "Supported Platforms:" } 
        New-UDCheckbox -FilledIn -Label "Windows" -Checked -Id spWindows
        New-UDCheckbox -FilledIn -Label "Linux" -Id spLinux
        New-UDCheckbox -FilledIn -Label "macOS"-Id spMacOS
    }

    $executorRow = New-UDLayout -Columns 4 {
        New-UDSelectX 'executorSelector' "Executor for Attack Commands"
        New-UDCheckbox -ID elevationRequired -FilledIn -Label "Requires Elevation to Execute Successfully?" 
    }

    $genarateYamlButton = New-UDRow -Columns {
        New-UDColumn -Size 8 -Content { }
        New-UDColumn -Size 4 -Content {
            New-UDButton -Text "Generate Test Definition YAML" -OnClick ( $epYamlModal )
        }
    }
    # Default select to be first option on all selects
    $defaultSelect = New-UDSelectOption -Name "Select" -Value "Select"
    # Format tactics to be options for new select
    $tacticSelectOptions = $tactics | ForEach-Object { New-UDSelectOption -Name $_ -Value $_ }
    # Add defaultSelect and tacticSelectOptions to an array
    $mitreTacticOptions = New-Object System.Collections.ArrayList($null)
    $null = $mitreTacticOptions.Add($defaultSelect)
    $mitreTacticOptions += $tacticSelectOptions
    # Set content of Create Atomic Test page
    $page2 = New-UDPage -Name "createAtomic" -Content {
        New-UDCard -Id "mainCard" -Content {
            New-UDCard -Content {
                New-UDTextBoxX 'atomicName' "Atomic Test Name"
                New-UDTextAreaX "atomicDescription" "Atomic Test Description"
                $supportedPlatforms
                New-UDTextAreaX "attackCommands" "Attack Commands"
                $executorRow
                New-UDTextAreaX "cleanupCommands" "Cleanup Commands (Optional)"
                $genarateYamlButton  
            }

            # input args
            New-UDCard -Id "inputCard" -Endpoint {
                New-UDButton -Text "Add Input Argument (Optional)" -OnClick (
                    New-UDEndpoint -Endpoint { Add-UDElement -ParentId "inputCard" -Content { New-InputArgCard } }
                )
            }

            # prereqs
            New-UDCard -Id "depCard" -Endpoint {
                New-UDLayout -columns 4 {
                    New-UDButton -Text "Add Prerequisite (Optional)" -OnClick (
                        New-UDEndpoint -Endpoint { Add-UDElement -ParentId "depCard" -Content { New-depCard } }
                    )
                    New-UDSelectX 'preReqEx' "Executor for Prereq Commands" 
                }
            }  
    
            # button to fill form with test data for development purposes
            if ($false) { New-UDButton -Text "Fill Test Data" -OnClick ( $epFillTestData ) }
        }
    }
    # Set content of Run Atomic Test page
    $page1 = New-UDPage -Name "runAtomic" -DefaultHomePage -Content {
        New-UDCard -Id "attackSelection" -Content {
                    New-UDElement -Tag "div" -Attributes @{ style = @{ width = "30%"; marginLeft = "3%"; display = "inline-block" } } -Content {
                        New-UDSelect -Label "Select MITRE ATT&CK Tactic" -Id "tacticSelector" -Option {
                            $mitreTacticOptions
                        } -OnChange  $epNewTacticSelected 
                    }
                    New-UDElement -Tag "div" -Id "techniqueColumn" -Attributes @{ style = @{ width = "30%"; marginLeft = "3%"; display = "inline-block" } } -Content {}
                    New-UDElement -Tag "div" -Id "testColumn" -Attributes @{ style = @{ width = "30%"; marginLeft = "3%"; display = "inline-block" } } -Content {}
        }
        #
        # The following comment is for adding functionality to select multiple tests
        #

        # New-UDCard -Id "addTest" -Content {
        #     New-UDRow -Columns {
        #         New-UDColumn -Size 6 {
        #             New-UDElement -Tag "div" -Attributes @{ style = @{border = "2px solid black"; padding = "5px 20px"; minHeight = "300px" } } -Content {
        #                 New-UDCollapsible -Items {
        #                     New-UDCollapsibleItem -Title "Item 1" -Icon arrow_circle_right -Content {
        #                         "Some content"
        #                     }
        #                 }
        #             }
        #         }
        #         New-UDColumn -Size 1 {
        #             New-UDLayout -Columns 2 -Content {
        #                 New-UDRow -Columns {
        #                     New-UDColumn -SmallOffset 6 -Content {
        #                         New-UDButton -Icon plus -style @{"margin" = "100px 0px 10px 0px" }
        #                     }
        #                     New-UDColumn -SmallOffset 6 -Content {
        #                         New-UDButton -Icon minus
        #                     }
        #                 }
        #             }
        #         }
        #         New-UDColumn -Size 5 {
        #             New-UDElement -Tag "div" -Attributes @{ style = @{border = "2px solid black"; padding = "5px 20px"; minHeight = "300px" } } -Content {
        #                 New-UDCollapsible -Items {
        #                     New-UDCollapsibleItem -Title "Item 1" -Icon arrow_circle_right -Content {
        #                         "Some content"
        #                     }
        #                 }
        #             }
        #         }
        #     }
        # }
        New-UDElement -Tag 'div' -Id "inputArgs" -Content {}
        New-UDCard -Id "executeButtons" -TextAlignment "right" -Content {
            New-UDButton -Id "checkPrereqs" -Text "Check Prereqs" -Disabled -OnClick $epCheckPrereqs
            New-UDButton -Id "getPrereqs" -Text "Get Prereqs" -Style @{"margin-left" = "20px" } -Disabled -OnClick $epGetPrereqs
            New-UDButton -Id "execute" -Text "Execute" -Style @{"margin-left" = "20px" } -Disabled -OnClick $epRunAtomicTest
            New-UDButton -Id "cleanup" -Text "Cleanup" -Style @{"margin-left" = "20px" } -Disabled -OnClick $epCleanupAtomicTest
            New-UDButton -Text "Reset Dashboard" -Style @{"margin-left" = "20px" } -OnClick $epResetDashboard
        }
        New-UDElement -Tag 'div' -Id "output" -Content {
        }
    } 
    $sidenav = New-UDSideNav -Content {
        New-UDSideNavItem -Text "Run Atomic Test" -PageName "runAtomic" -icon running
        New-UDSideNavItem -Text "Create Atomic Test" -PageName "createAtomic" -Icon palette
    }

    ############## End Static Definitions

    ############## The Dashboard
    $idleTimeOut = New-TimeSpan -Minutes 10080
    $db = New-UDDashboard -Title "Atomic Red Team GUI" -IdleTimeout $idleTimeOut -EndpointInitialization $ei -Pages @($page1, $page2) -Navigation $sidenav
    ############## End of the Dashboard

    Stop-AtomicGUI
    Start-UDDashboard -port $port -Dashboard $db -Name "AtomicGUI" -ListenAddress 127.0.0.1
    start-process http://localhost:$port
}

function Stop-AtomicGUI {
    Get-UDDashboard -Name 'AtomicGUI' | Stop-UDDashboard
    Write-Host "Stopped all AtomicGUI Dashboards"
}