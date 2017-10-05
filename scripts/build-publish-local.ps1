Function Extract-Content($projectFile)
{
	$files = @();
	$absolutePathToParent = Split-Path $projectFile

	[xml]$xml = Get-Content $projectFile
    $xml.Project.ItemGroup.Content | %{
        $path = $_.Include	

        If ($path -ne $null)
        {
			$files += @(Join-Path  $absolutePathToParent $path)
        }
    }

	$bin = Join-Path  $absolutePathToParent "bin"
	#$files += @($bin)
	$binFiles = Get-ChildItem $bin -Recurse | ForEach-Object{		 
		 if (Test-Path $_.FullName -pathType leaf){			
			 $files += @($_.FullName)
		 }		 
	}  

	return $files
}

Function Get-ProjectsPaths($slnDir, $slnName)
{
	  $slnFilePath = Join-Path $slnDir $slnName

		Write-Host "Get All Content Items from Projects of  $($slnFilePath)" -foregroundcolor green  	

		$slnfiles = @();
		Get-Content $slnFilePath |
          Select-String 'Project\(' |
            ForEach-Object {
              $projectParts = $_ -Split '[,=]' | 

				ForEach-Object { $_.Trim('[ "{}]') };           

			    $slnfiles += @($projectParts[2])
            }			 

			$csprojs = $slnfiles | ?{ $_ -match ".csproj$" } 			

			$projItems= @();
			$csprojs| Foreach {
				$filePath = Join-Path $slnDir $_

				Write-Host "file path  $($filePath)" -foregroundcolor green 				
				$projItems += @($filePath)
			  }
		 
		  
			  return $projItems;
}


Function Get-AllFilesPathsToPublish($sourceSlnDir, $slnName)
{
	$projItems = Get-ProjectsPaths $sourceSlnDir $slnName

	$contentItems= @();
	$projItems| Foreach {
	              $contentItems += @(extract-content $_)
			  }
		 
	$contentItems | Foreach {
				 Write-Host "content items  $($_)" -foregroundcolor green 
				}

	return $contentItems;  
}

Function Ensure-Dir($destinationFolder)
{
	if (!(Test-Path $destinationFolder -PathType Container)) {
                      New-Item -ItemType Directory -Force -Path $destinationFolder
                  } 
}

Function Copy-FilesToDestination($destinationDir, $sourceFiles, $segmentMarker)
{
	 $sourceFiles| Foreach {
		          $sourceFolder = Split-Path $_	 
		         
		          $pathSegments = $sourceFolder -Split $segmentMarker 	          
		         
		          $destinationFolder = Join-Path $destinationDir $pathSegments[1]
		          
		          Ensure-Dir $destinationFolder

		          Copy-Item $_ $destinationFolder -Recurse 
			  }   
}

Function Delete-DirIfExists($dirPath){
	if (Test-Path $dirPath ) {
	Remove-Item $dirPath -Recurse -Force
		}
}


Function Get-TempDirPath($destinationDir)
{
	$tempDestinationPath = Split-Path $destinationDir

	$tempDestinationPath = Join-Path $tempDestinationPath "Temp"		

	return $tempDestinationPath
}

Function Publish-AllToDir($sourceSlnDir, $slnName,  $destinationDir, $segmentMarker)
{
	$tempDestinationPath = Get-TempDirPath $destinationDir	

	Delete-DirIfExists $tempDestinationPath

	$filesToPublish = Get-AllFilesPathsToPublish $sourceSlnDir $slnName	

	Copy-FilesToDestination $tempDestinationPath $filesToPublish $segmentMarker	

	Copy-Item $tempDestinationPath $destinationDir -Recurse -Force
}

Import-Module -Name "C:\Program Files (x86)\WindowsPowerShell\Modules\Invoke-MsBuild\2.6.0\Invoke-MsBuild.psm1"
Function Build-Publish-Local($sourceSlnDir, $slnName,  $destinationDir, $segmentMarker)
{
	$slnPath = Join-Path $sourceSlnDir $slnName
	Write-Host "Executing MSBuild for $($slnPath)..."
	$build = Invoke-MsBuild -Path $slnPath -MsBuildParameters "/target:Build" 

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

	Publish-AllToDir $sourceSlnDir $slnName $destinationDir $segmentMarker
}

Build-Publish-Local -sourceSlnDir D:\Projects\Internal\Labs\Helix -slnName Helix.sln -destinationDir D:\Sitecore\labs.local\Website -segmentMarker code 