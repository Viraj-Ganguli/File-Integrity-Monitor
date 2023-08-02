
Function GetPath() {
    Write-Host ""
    # aks user what folder to monitor 
    $folderPath = Read-Host -Prompt "Please enter the path that contains the folder you want to monitor"
    Write-Host ""

    # Ensure the path is correct 
    if ($(Test-Path -Path $folderPath) -eq $false) {
        Write-Host "Please enter a real path"
        GetPath
    } 

    else {
        Set-Location -Path $folderPath
        $folderName = pwd | Select-Object | %{$_.ProviderPath.Split("\")[-2]}
        Write-Host $folderName
        #Set-Location -Path .. -PassThru
       
        
        
      }
 }

    

GetPath


Write-Host ""
Write-Host "    A) Collect New Baseline"
Write-Host "    B) Begin monitoring files with saved Baseline"
Write-Host ""
$response = Read-Host -Prompt "Please enter 'A' or 'B'"
Write-Host ""

Function Calculate-File-Hash($filepath) {
   $filehash = Get-FileHash -Path $filepath -Algorithm SHA512
   return $filehash
}

Function Erase-Baseline-If-Already-Exists() {
    $baselineExists = Test-Path -Path .\baseline.txt 

    if ($baselineExists) {
        #delete it
        Remove-Item -Path .\baseline.txt
    }
    
}




if ($response -eq "A".ToUpper()){
    #Delete baseline
    Erase-Baseline-If-Already-Exists
    # Calculate Hash of target files and store in baseline.txt
    # Collect files in target folder
    $files = Get-ChildItem $folderName
    Write-Host "Files have been found"
    # Calculate the hashes of each file and append to baseline.txt
    foreach ($f in $files) {
        $hash = Calculate-File-Hash $f.FullName 
        "$($hash.Path)|$($hash.Hash)" | Out-File -FilePath .\baseline.txt -Append
    }
    Move-Item -Path .\baseline.txt -Destination C:\Users\~\Desktop\FIMTest
}
elseif ($response -eq "B".ToUpper()){
    

    $fileHashDictionary = @{}

    #Load file|hash from baseline.txt and store them in a dictionary 
    $filePathsAndHashes = Get-Content C:\Users\~\Desktop\FIMTest\baseline.txt
    
    foreach ($f in $filePathsAndHashes) {
        $fileHashDictionary.add($f.Split("|")[0],$f.Split("|")[1])
    }

    #Begin continously monitoring files with saved Baseline 
    while ($true) {
        Start-Sleep -Seconds 1
        
        $files = Get-ChildItem $folderName
        

        # Calculate the hashes of each file and append to baseline.txt
        foreach ($f in $files) {
            $hash = Calculate-File-Hash $f.FullName 
            #"$($hash.Path)|$($hash.Hash)" | Out-File -FilePath .\baseline.txt -Append   
            
            # Notify if a new file has been created 
            if ($fileHashDictionary[$hash.Path] -eq $null) {
                #A new file has been created
                Write-Host "$($hash.Path) has been created!" -ForegroundColor Green
            }
            else {

                # Notify if a new file has been changed 
                if ($fileHashDictionary[$hash.Path] -eq $hash.Hash) {
                #the file has not changed
                }
                else {
                    #the file has been changed, notify the user
                    Write-Host "$($hash.Path) has been changed!" -ForegroundColor Yellow
                }
             
              } 
              

              }
        
        foreach ($key in $fileHashDictionary.Keys) {
            $baselineFileStillExists = Test-Path -Path $key
            if (-Not $baselineFileStillExists) {
               # One of the baseline files must have been deleted, notify user
               Write-Host "$($key) has been deleted!" -ForegroundColor Red
              }

            }

          }

        }

  
 

