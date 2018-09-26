<#
    .SYNOPSIS
    This script contains the Add-Feature and Add-Foundation methods which can be used to add a new module to a Sitecore Helix based Visual Studio solution.
    
    The Visual Studio solution should contain a add-helix-module-configuration.json file containing variables which this script will use.
    
    The Add-Feature and Add-Foundation methods can be run from the Pacakge Console Manager as long as this script is loaded in the relevant PowerShell profile. 
    Run $profile in the Pacakge Manager Console to verify the which profile is used.
#>

# Some hardcoded values
$buildPublishConfigFile = "build-publish-configuration.json"   # Used in Add-Module.

<#
    .SYNOPSIS
    Creates a config object which is used in the other functions in this script file.

    .DESCRIPTION
    This function should be considered private and is called from the Add-Module function.

    .Parameter JsonConfigFilePath
    The path of the json based configuration file which contains the path to the module-template folder,
    namespaces and tokens to replace.   

#>
function Create-Config-Build
{
    Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$JsonConfigFilePath       
    )

    $jsonFile = Get-Content -Raw -Path "$JsonConfigFilePath" | ConvertFrom-Json
    
    if ($jsonFile)
    {
        $config = New-Object psobject
        Add-Member -InputObject $config -Name SlnName -Value $jsonFile.config.slnName -MemberType NoteProperty
		Add-Member -InputObject $config -Name PublistTargetsFilePath -Value $jsonFile.config.publishSettingsFilePath -MemberType NoteProperty
        Add-Member -InputObject $config -Name SegmentMarker -Value $jsonFile.config.segmentMarker -MemberType NoteProperty
		
        [System.Collections.ArrayList]$arrList=@()
		$arrList +=@($jsonFile.config.filesToExclude)      
		
        Add-Member -InputObject $config -Name FilesToExclude  -Value $arrList -MemberType NoteProperty 
        
        return $config
    }
}
<#
    .SYNOPSIS
    The main function that parses $ProjectFile and returns Array of paths to [ContentItems + all inside of bin folder].

    .DESCRIPTION
    This function should be considered private and is called from the  function.

    .PARAMETER ProjectFile
    The full path of the ProjectFile file. This is used to parse ProjectFile as xml and extract path's to files from <ItemGroup><Content>.

#>
function Get-DestinationPathFromPublishTargets
{
	 Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$PublishTargetsFile
    )	

	[xml]$xml = Get-Content $PublishTargetsFile
    $publishPath = $xml.Project.PropertyGroup.publishUrl

	return $publishPath
}
<#
    .SYNOPSIS
    The main function that parses $ProjectFile and returns Array of paths to [ContentItems + all inside of bin folder].

    .DESCRIPTION
    This function should be considered private and is called from the  function.

    .PARAMETER ProjectFile
    The full path of the ProjectFile file. This is used to parse ProjectFile as xml and extract path's to files from <ItemGroup><Content>.

#>
function Extract-Content
{
	 Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$ProjectFile
    )

	$files = @();
	$absolutePathToParent = Split-Path $ProjectFile

	[xml]$xml = Get-Content $ProjectFile
    $xml.Project.ItemGroup.Content | %{
        $path = $_.Include	

        If ($path -ne $null)
        {
			$files += @(Join-Path  $absolutePathToParent $path)
        }
    }

	$bin = Join-Path  $absolutePathToParent "bin"
	$binFiles = Get-ChildItem $bin -Recurse | ForEach-Object{		 
		 if (Test-Path $_.FullName -pathType leaf)
		 {			
			 $files += @($_.FullName)
		 }		 
	}  

	return $files
}
<#
    .SYNOPSIS
    The main function that is filtering out FilterArray from ArrayToBeFiltered.

    .DESCRIPTION
    This function should be considered private and is called from the function.

    .PARAMETER ArrayToBeFiltered
    Array that has to be filtered.

	.PARAMETER FilterArray

#>
function ArrayFilter () 
{
   Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string[]]$ArrayToBeFiltered,
	    [Parameter(Position=1, Mandatory=$True)]
        [string[]]$FilterArray
    )

   return $ArrayToBeFiltered | select-string -pattern $FilterArray -simplematch -notmatch
}
<#
    .SYNOPSIS
    The main function that is filtering out FilterArray from ArrayToBeFiltered.

    .DESCRIPTION
    This function should be considered private and is called from the function.

    .PARAMETER SlnDir
    Array that has to be filtered.

	 .PARAMETER SlnName
    Array that has to be filtered.

	 .PARAMETER FilesToExclude
    Array that has to be filtered.
#>
function Get-ProjectsPaths
{
	 Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$SlnDir,
	    [Parameter(Position=1, Mandatory=$True)]
        [string]$SlnName,
		[Parameter(Position=2, Mandatory=$True)]
        [string[]]$FilesToExclude
     )

	  $slnFilePath = Join-Path $SlnDir $SlnName		

	  $slnfiles = @();

	  Get-Content $slnFilePath |
          Select-String 'Project\(' |
            ForEach-Object {
              $projectParts = $_ -Split '[,=]' | 

				ForEach-Object { $_.Trim('[ "{}]') };           

			    $slnfiles += @($projectParts[2])
            }			 

	 $filteredArray = ArrayFilter $slnfiles $FilesToExclude			

	 $csprojs = $filteredArray | ?{ $_ -match ".csproj$" }			

	 

	 $projItems= @();
	 $csprojs| 
		Foreach {
			$filePath = Join-Path $SlnDir $_

			Write-Host "$($filePath)" 				
			$projItems += @($filePath)
		}		 
		  
	return $projItems;
}
<#
    .SYNOPSIS
    The main function that is filtering out FilterArray from ArrayToBeFiltered.

    .DESCRIPTION
    This function should be considered private and is called from the function.

    .PARAMETER ArrayToBeFiltered
    Array that has to be filtered.
#>
function Get-AllFilesPathsToPublish
{
	 Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$SlnDir,
	    [Parameter(Position=1, Mandatory=$True)]
        [string]$SlnName,
		[Parameter(Position=2, Mandatory=$True)]
        [string[]]$FilesToExclude
     )

    $projItems = Get-ProjectsPaths $SlnDir $SlnName $FilesToExclude

	$contentItems= @();
	$projItems| Foreach {
	              $contentItems += @(extract-content $_)
			  }
	
	Write-Host "Files that will be published: " 
	$contentItems | Foreach {
				 Write-Host "$($_)" -foregroundcolor green  
				}

	return $contentItems;  
}
<#
    .SYNOPSIS
    The main function that is filtering out FilterArray from ArrayToBeFiltered.

    .DESCRIPTION
    This function should be considered private and is called from the function.

    .PARAMETER DestinationFolder
    Array that has to be filtered.
#>
function Ensure-Dir()
{
	 Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$DestinationFolder
	    
     )

	if (!(Test-Path $DestinationFolder -PathType Container)) {
                      New-Item -ItemType Directory -Force -Path $DestinationFolder
                  } 
}
<#
    .SYNOPSIS
    The main function that is filtering out FilterArray from ArrayToBeFiltered.

    .DESCRIPTION
    This function should be considered private and is called from the function.

    .PARAMETER DestinationDir
    Array that has to be filtered.

	 .PARAMETER SourceFiles
    Array that has to be filtered.

	 .PARAMETER SegmentMarker
    Array that has to be filtered.
#>
function Copy-FilesToDestination
{
	Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$DestinationDir,
		[Parameter(Position=1, Mandatory=$True)]
        [string[]]$SourceFiles,
		[Parameter(Position=2, Mandatory=$True)]
        [string]$SegmentMarker	    
     )

	 $SourceFiles| Foreach {
		          $sourceFolder = Split-Path $_	 
		         
		          $pathSegments = $sourceFolder -Split $SegmentMarker 	          
		         
		          $destinationFolder = Join-Path $DestinationDir $pathSegments[1]
		          
		          Ensure-Dir $destinationFolder

		          Copy-Item $_ $destinationFolder -Recurse 
			  }   
}
<#
    .SYNOPSIS
    The main function that is filtering out FilterArray from ArrayToBeFiltered.

    .DESCRIPTION
    This function should be considered private and is called from the function.

    .PARAMETER SourceSlnDir
    Array that has to be filtered.	
	.PARAMETER SlnName
    Array that has to be filtered.	
	.PARAMETER DestinationDir
    Array that has to be filtered.	
	.PARAMETER SegmentMarker
    Array that has to be filtered.	
	.PARAMETER FilesToExclude
    Array that has to be filtered.	
#>
function Publish-AllToDir
{
	Param
	(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$SourceSlnDir,
		[Parameter(Position=1, Mandatory=$True)]
        [string]$SlnName,	
		[Parameter(Position=2, Mandatory=$True)]
        [string]$DestinationDir,	
		[Parameter(Position=3, Mandatory=$True)]
        [string]$SegmentMarker,	
		[Parameter(Position=4, Mandatory=$True)]
        [string[]]$FilesToExclude		
     )	

	$filesToPublish = Get-AllFilesPathsToPublish $SourceSlnDir $SlnName	$FilesToExclude

	Copy-FilesToDestination $DestinationDir $filesToPublish $SegmentMarker		
}

function Run
{
   try
   {
        # Do a check if there is a solution active in Visual Studio.
        # If there is no active solution the Add-Projects function would fail.

		Write-Output "Solution is found. Solution name is $($dte.Solution.FullName)"

		$solutionFullPath = $dte.Solution.FullName
        if (-not $solutionFullPath)
        {
            throw [System.ArgumentException] "There is no active solution."
        }

        # The only reason I do this check is because I need a path to start searching for the json based config file. 
        $solutionRootFolder = [System.IO.Path]::GetDirectoryName($solutionFullPath)

		Write-Output "Solution folder is $($solutionRootFolder)"

        if (-not (Test-Path "$solutionRootFolder"))
        {
            throw [System.IO.DirectoryNotFoundException] "$solutionRootFolder folder not found."
        }

        $configJsonFile = Get-ChildItem -Path "$solutionRootFolder" -File -Filter "$buildPublishConfigFile" -Recurse | Select-Object -First 1 | Select-Object -ExpandProperty FullName
        if (-not (Test-Path $configJsonFile))
        {
            throw [System.IO.DirectoryNotFoundException] "$configJsonFile not found."
        }

        # Create a config object we can use throughout the other functions.
        $config = Create-Config-Build -JsonConfigFilePath "$configJsonFile" 

		Write-Output "Script configuration is found. $($config)"		
	   
		Write-Output  "Executing MSBuild for $($solutionFullPath)..."

	    $build = Invoke-MsBuild -Path $solutionFullPath -MsBuildParameters "/target:Build" 

	    if ($build.BuildSucceeded -eq $true)
        {
          Write-Output "Build completed successfully!"
        }
        else
        {
          Write-Output "Build failed!"
          Write-Host (Get-Content -Path $build.BuildLogFilePath)

          Exit 1
        }
	     
	    $publishTargetsFilePath = Join-Path -Path $solutionRootFolder -ChildPath $config.PublistTargetsFilePath
	    $publishDestinationPath = Get-DestinationPathFromPublishTargets $publishTargetsFilePath

	    Write-Output "Publishing is started...."
		Publish-AllToDir $solutionRootFolder $config.SlnName $publishDestinationPath $config.SegmentMarker $config.FilesToExclude

		Write-Output "Publishing to $($publishDestinationPath) is successfully finished."
	}
	catch
	{
		Write-Output "Exception... "
		Write-Error $error[0]
        exit
	}
}

