<#

.SYNOPSIS
    Analyze-Freqs.ps1
    
.Description
    This script is a PowerShell wrapper to Mark Baggett's Freq.py that was compiled.
    Please see details on Mark Baggett's tool located at 
    https://github.com/sans-blue-team/freq.py.

    This script streamlines the use of freq.py and allows analysts to process an entire
    CSV file and output the results to a CSV output file in a directory of your choosing.

    Setup
    1. Create a directory called "Normal" in a directory you have dedicated to Analyze-Freq.ps1
        a. Place the files you will normalize with in this directory
    2. Create a directory called "Input" in a directory you have dedicated to Analyze-Freq.ps1
        a. Place the files you will use as iput in this directory
    3. Create a directory called "Bin" in a directory you have dedicated to Analyze-Freq.ps1
        a. Place freq.exe and freq.py in this directory

.EXAMPLE
   
    Parameters:
   
    OutputPath -> The path where CSV output will be placed (Defaults to $PSScriptRoot\Output)
    NormalPath -> The path to the documents that you will use to normalize freq.py (Defaults to $PSScriptRoot\Normal)
    InputPath -> The Path to your CSV input (Defaults to $PSScriptRoot\Input and will process all documents in this directory)
    BinPath -> The path to freq.exe or freq.py (if you have Python installed) (Defaults to $PSScriptRoot\Bin and looks for freq.exe)

    Simple Execution (Executes with all default params)

    .\Analyze-Freq.ps1

    Custom Parameter Execution

    .\Analyze-Freq.ps1 -OutputPath C:\tools\freq\output -NormalPath C:\tools\freq\normal -InputPath C:\data\input.csv -BinPath C:\Tools\freq.exe

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
    [Parameter(Mandatory = $false)]
    [switch]$Py

)

process {

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