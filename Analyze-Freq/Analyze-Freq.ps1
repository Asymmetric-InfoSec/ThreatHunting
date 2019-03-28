<#

.SYNOPSIS
    Analyze-Freqs.ps1
    
.Description
    This script is a PowerShell wrapper to Mark Baggett's Freq.py (freq.exe). The primary
    purpose of the script is to find anomalous DNS data from a CSV of domains that is imported
    and then analyzed, however, any data can be analyzed (just dont use the API switches for 
    non domain data). Please see details on Mark Baggett's tool located at 
    https://github.com/sans-blue-team/freq.py.

    This script streamlines the use of freq.py and allows analysts to process an entire
    CSV file and output the results to a CSV output file in a directory of your choosing. The
    resultant data will be a CSV that has details on the entropy associated with analyzed 
    entries and, if analyzing domains and using an XML WhoIs api, WhoIs data to help your hunt.

    Setup
    1. Create a directory called "Normal" in a directory you have dedicated to Analyze-Freq.ps1
        a. Place the files you will normalize with in this directory
    2. Create a directory called "Input" in a directory you have dedicated to Analyze-Freq.ps1
        a. Place the files you will use as iput in this directory
    3. Create a directory called "Bin" in a directory you have dedicated to Analyze-Freq.ps1
        a. Place freq.exe and freq.py in this directory
    4. Requires access to an XML based API to collect WhoIs data. 
        a. Example: https://www.whoisxmlapi.com/ (free tier is 500 queries per month)

.EXAMPLE
   
    Parameters:
   
    OutputPath -> The path where CSV output will be placed (Defaults to $PSScriptRoot\Output)
    NormalPath -> The path to the documents that you will use to normalize freq.py (Defaults to $PSScriptRoot\Normal)
    InputPath -> The Path to your CSV input (Defaults to $PSScriptRoot\Input and will process all documents in this directory)
    BinPath -> The path to where you store freq.exe or freq.py (if you have Python installed) (Defaults to $PSScriptRoot\Bin)
    Exe -> Swtich parameter to run with freq.exe
    Py -> Swithc parameter to run with freq.py
    APIKey -> Specifies the API key to collect WhoIs data with
    MaxAge -> Specified the maximum age a domain can be and still be processed (defaults to 180 days)

    Execution (With WhoIs Lookups)

    .\Analyze-Freq.ps1 -Exe -APIKey ABCDEFGHIJKLMNOPQRSTUVWXYZ

    Execution (Without WhoIs Lookups)

    .\Analyze-Freq.ps1 -Exe

.NOTES
    Author: Drew Schmitt
    Date Created: 3/22/2015
    Twitter: @5ynax
    
    Last Modified By:
    Last Modified Date:
    Twitter:
  
#>

param(
    [Parameter(ParameterSetName = "Exe", Position = 0, Mandatory = $false)]
    [Parameter(ParameterSetName = "Py", Position = 0, Mandatory = $false)]
    [string]$OutputPath = "$PSScriptRoot\Output",

    [Parameter(ParameterSetName = "Exe", Position = 1 , Mandatory = $false)]
    [Parameter(ParameterSetName = "Py", Position = 1, Mandatory = $false)]
    [string]$NormalPath = "$PSScriptRoot\Normal\",

    [Parameter(ParameterSetName = "Exe", Position = 2, Mandatory = $false)]
    [Parameter(ParameterSetName = "Py", Position = 2, Mandatory = $false)]
    [string]$InputPath = "$PSScriptRoot\Input\",

    [Parameter(ParameterSetName = "Exe", Position = 3, Mandatory = $false)]
    [Parameter(ParameterSetName = "Py", Position = 3, Mandatory = $false)]
    [string]$BinPath = "$PSScriptRoot\Bin\",

    [Parameter(ParameterSetName = "Exe", Position = 4, Mandatory = $true)]
    [switch]$Exe,

    [Parameter(ParameterSetName = "Py", Position = 4, Mandatory = $true)]
    [switch]$Py,

    [Parameter(ParameterSetName = "Exe", Position = 5, Mandatory = $false)]
    [Parameter(ParameterSetName = "Py", Position = 5, Mandatory = $false)]
    [String]$APIKey,

    [Parameter(ParameterSetName = "Exe", Position = 6, Mandatory = $false)]
    [Parameter(ParameterSetName = "Py", Position = 6, Mandatory = $false)]
    [Int]$MaxAge = 180

)

process {

    function WhoisAPI{

        param (
            
            [Parameter(Mandatory=$true,Position=0)]
            [String]$Domain,

            [Parameter(Mandatory=$true,Position=1)]
            [String]$APIKey
        )

        process {

            $APIBase = 'https://www.whoisxmlapi.com/whoisserver/WhoisService'

            $Uri = "{0}?apiKey={1}&domainName={2}" -f $APIBase,$APIKey,$Domain
            
            $Response = Invoke-RestMethod -Uri $Uri -Method Get

            $Response.WhoisRecord

        }
    }

    #Verify that all parameter requirements are met
    #Determine if $OutputPath exists and create if not
    if (!(Test-Path $OutputPath)){

        Write-Host ("OutputPath not detected. Creating ...") -ForegroundColor "Yellow" -BackgroundColor "Black"
        New-Item -Path $OutputPath -Type Directory | Out-Null
    }

    #Determine if $NormalPath exists and, if so, verify the directory has contents
    if (!(Test-Path $NormalPath)){

        Write-Warning "NormalPath not detected and will be created. Populate with files to normalize with and run again."
        New-Item -Path $NormalPath -Type Directory | Out-Null
        Exit

    }

    if ((Get-ChildItem $NormalPath).count -lt 1){

        Write-Warning "$NormalPath is empty. Quitting..."
        Exit 
    }

    #Determine if $InputPath exists and, if so, verify the directory have contents
    if (!(Test-Path $InputPath)){

        Write-Warning "InputPath not detected and will be created. Populate with files to ingest into freq and run again."
        New-Item -Path $InputPath -Type Directory | Out-Null
        Exit

    }

    if ((Get-ChildItem $InputPath).count -lt 1){

        Write-Warning "$InputPath is empty. Quitting..."
        Exit 
    }

    #Determine if $BinPath exists
    if (!(Test-Path $BinPath)){

        Write-Warning "BinPath not detected and will be created. Populate with freq.exe and/or freq.py and run again."
        New-Item -Path $BinPath -Type Directory | Out-Null
        Exit

    }

    #Determine if exe or py will be used - based on parameter set name
    switch ($PSCmdlet.ParameterSetName) {

        "Exe" {$Freq = "freq.exe"}
        "Py" {$Freq = "freq.py"}

    }

    #Create table for use with freq.exe 
    $FreqTable = ("{0}\{1}.freq" -f $PSScriptRoot, $(Get-Date).ToString('yyMMdd'))

    if (!(Test-Path $FreqTable)){

        Invoke-Expression -Command ("{0}\{1} --create {2}" -f $BinPath, $Freq, $FreqTable)

        #Fill frequency table with normal text
        $NormalFiles = Get-ChildItem $NormalPath -File 

        foreach ($NormalFile in $NormalFiles){

            Invoke-Expression -Command ("{0}\{1} --normalfile {2}\{3} {4}" -f $BinPath, $Freq, $NormalPath, $NormalFile, $FreqTable)
        
        }
    }

    #Loop through each input file and Import CSV Contents, then process through freq
    $InputFiles = Get-ChildItem -Path $InputPath -File

    #Processes all input and does not compare to age of domain
    if (!($APIKey)){

        foreach ($InputFile in $Inputfiles){
        
            $CSV = Import-CSV "$InputPath\$InputFile"
            $FirstProp = $CSV | Get-Member -MemberType NoteProperty | Select -First 1 -ExpandProperty Name
            $DataPoints = $CSV | Select -ExpandProperty $FirstProp

            foreach ($DataPoint in $DataPoints) {

                try {

                    $Output = Invoke-Expression -Command ("{0}\{1} --measure {2} {3}" -f $BinPath, $Freq, $DataPoint, $FreqTable) 

                    $OutputCSV = ("{0}_Ouptut.csv" -f $InputFile)

                    $OutputHash = @{

                        Input = $DataPoint
                        Score = $Output
                    }

                    [PSCustomObject]$OutputHash | Select Input, Score | Export-CSV "$OutputPath\$OutputCSV" -NoTypeInformation -Append
                
                }catch {

                    continue
                }
            }    
        }

    }

    #Only processes domains that are under $Max Age
    if ($APIKey){

        foreach ($InputFile in $Inputfiles){
            
            $CSV = Import-CSV "$InputPath\$InputFile"
            $FirstProp = $CSV | Get-Member -MemberType NoteProperty | Select -First 1 -ExpandProperty Name
            $DataPoints = $CSV | Select -ExpandProperty $FirstProp

            foreach ($DataPoint in $DataPoints) {

                try {

                    $WhoisData = WhoisAPI $DataPoint $APIKey
                    $WhoisDate = $WhoisData.CreatedDateNormalized -replace '\sUTC$', 'Z'
                    
                    if ($WhoisDate){

                        $DateDiff = (Get-Date) - [DateTime]$WhoisDate

                        if ($DateDiff.Days -le $MaxAge){

                            $Output = Invoke-Expression -Command ("{0}\{1} --measure {2} {3}" -f $BinPath, $Freq, $DataPoint, $FreqTable) 

                            $OutputCSV = ("{0}_WhoIs_Ouptut.csv" -f $InputFile)

                            $OutputHash = @{

                                Input = $DataPoint
                                Score = $Output
                                Created = $WhoisData.CreatedDateNormalized
                                Updated = $WhoisData.UpdatedDateNormalized
                                Registrant = $WhoisData.Registrant.Organization
                                RegistrantState = $WhoisData.Registrant.State
                                RegistrantCountry = $WhoisData.Registrant.Country
                            }

                        [PSCustomObject]$OutputHash | Select Input, Score, Created, Updated, Registrant, RegistrantCountry, RegistrantState | Export-CSV "$OutputPath\$OutputCSV" -NoTypeInformation -Append

                        } 
                    
                    } else {

                        $Output = Invoke-Expression -Command ("{0}\{1} --measure {2} {3}" -f $BinPath, $Freq, $DataPoint, $FreqTable) 

                        $OutputCSV = ("{0}_WhoIs_Ouptut.csv" -f $InputFile)

                        $OutputHash = @{

                            Input = $DataPoint
                            Score = $Output
                            Created = $Null
                            Updated = $Null
                            Registrant = $WhoisData.Registrant.Organization
                            RegistrantState = $WhoisData.Registrant.State
                            RegistrantCountry = $WhoisData.Registrant.Country
                        }

                        [PSCustomObject]$OutputHash | Select Input, Score, Created, Updated, Registrant, RegistrantState, RegistrantCountry | Export-CSV "$OutputPath\$OutputCSV" -NoTypeInformation -Append

                    }

                } catch {

                    continue 
                }   
            }
        }
    }
}