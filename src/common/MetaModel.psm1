function Get-XMLTaskNodes{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)][xml] $Xml
    )
    return Select-Xml -Xml $xml -XPath //Task | % {$_.Node}
}

function FilterTasksByCategory{
    param ([string] $Category)
    { ($_.Categories -split ',') -contains $Category }.GetNewClosure()
}

$Global:MetaModelPath = "$Global:NAV\Eng\Core\DMEModels\MetaModels\snap.meta.model.xml"
$Global:ExtendedModelPath = "$Global:NAV\Eng\Core\DMEModels\Models\buddybuild.extended.model.xml"

function Get-MetaModel {
    [xml] (Get-Content -Path $Global:MetaModelPath)
}

function Get-ExtendedModel {
    [xml] (Get-Content -Path $Global:ExtendedModelPath)
}

function Query-AppTestCommands {
    Get-MetaModel | 
        Get-XmlTaskNodes | 
        ? (FilterTasksByCategory -Category "AppTest") |
        % {$_|Select-Object -Property Name, Command} |
        % {$_.Command = $_.Command.Trim(); $_}
}

function Get-AppTestTasks{
    param (
        [Parameter()]
        [string]
        $ModelName='extended'
    )
    [xml] $Model = Get-Content -Path "$Global:NAV\Eng\Core\DMEModels\Models\buddybuild.$($ModelName).model.xml"
    Get-XMLTaskNodes -Xml $Model | 
        ? (FilterTasksByCategory -Category 'AppTest') | 
        % { $_.Name }
}

function Get-AppTestTasksRegex {
    $MetaModel = Get-MetaModel
    $global:Countries = ($MetaModel.root.define | ? {$_.match -eq "countries"}).replace
    $global:Countries = "W1,$global:Countries" -split ','

    Get-XmlTaskNodes -Xml $MetaModel |
        ? (FilterTasksByCategory -Category 'AppTest') |
        % {TaskMatchRegex -TaskName $_.Name} 
}

function CountryForTaskName {
    param(
        [string] $TaskName
    )
    if($null -eq $global:AppTestTasksRegex){
        $global:AppTestTasksRegex = Get-AppTestTasksRegex
    }
    foreach ($Regex in $global:AppTestTasksRegex) {
        if($TaskName -match $Regex){
            $PotentialCountryCodes = $Matches.Clone()
            $PotentialCountryCodes.Remove(0)
            foreach ($MaybeCC in $PotentialCountryCodes.Values) {
                if($global:Countries -contains $MaybeCC){
                    return $MaybeCC
                }
            }
            return "ALL"
        }
    }
    return "ALL"
}
