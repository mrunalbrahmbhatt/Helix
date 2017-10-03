Function Build-Sln($path)
{
	    $msBuildExe = 'C:\Program Files (x86)\MSBuild\14.0\Bin\msbuild.exe'   

        Write-Host "Building $($path)" -foregroundcolor green
        & "$($msBuildExe)" "$($path)" /t:Build /m
}

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
    $files += @($bin)

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


Function Get-AllFilesForPublish($projItems)
{
	$contentItems= @();
	$projItems| Foreach {
	              $contentItems += @(extract-content $_)
			  }
		 
	$contentItems | Foreach {
				 Write-Host "content items  $($_)" -foregroundcolor green 
				}

	return $contentItems;  
}


Function Clean-Destination($destinationDir, $projects)
{
	$projects| Foreach {
	              $destinationToClean =  Join-Path $destinationDir $_
		           Get-ChildItem -Path $destinationToClean -Recurse| Foreach-object {Remove-item -Recurse -path $_.FullName }
			  }   
}

Function Copy-Files-ToDestination($destinationDir, $sourceFiles)
{

}

Function Build-Publish-All($sourceSlnDir, $slnName,  $destinationDir)
{
	$slnFullPath = Join-Path  $sourceSlnDir $slnName
	
	$projects = Get-ProjectsPaths $sourceSlnDir $slnName

	$filesToPublish = Get-AllFilesForPublish $projects

	}

Build-Publish-All -sourceSlnDir D:\Projects\Internal\Labs\Helix -slnName Helix.sln -destinationDir D:\TestDeploy