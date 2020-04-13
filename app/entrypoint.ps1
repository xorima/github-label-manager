[CmdletBinding()]
param (
  [Parameter()]
  [String]
  [ValidateNotNullOrEmpty()]
  $SourceRepoOwner = $ENV:GLM_SOURCE_REPO_OWNER,
  [Parameter()]
  [String]
  [ValidateNotNullOrEmpty()]
  $SourceRepoName = $ENV:GLM_SOURCE_REPO_NAME,
  [Parameter()]
  [String]
  [ValidateNotNullOrEmpty()]
  $SourceRepoPath = $ENV:GLM_SOURCE_REPO_PATH,
  [String]
  [ValidateNotNullOrEmpty()]
  $DestinationRepoOwner = $ENV:GLM_DESTINATION_REPO_OWNER,
  [String]
  [ValidateNotNullOrEmpty()]
  $DestinationRepoTopicsCsv = $ENV:GLM_DESTINATION_REPO_TOPICS,
  [boolean]
  $deleteUnmanaged = $ENV:GLM_DELETE_MODE
)

try {
  import-module ./app/modules/github
  import-module ./app/modules/logging

}
catch {
  Write-Error "Unable to import modules" -ErrorAction Stop
  exit 1
}

if (!($ENV:GITHUB_TOKEN)) {
  Write-Log -Level Error -Source 'entrypoint' -Message "No GITUB_TOKEN env var detected"
}

# Setup the git config first, if env vars are not supplied this will do nothing.
Set-GitConfig -gitName $GitName -gitEmail $GitEmail

try {
  Write-Log -Level Info -Source 'entrypoint' -Message "Getting repository information for $sourceRepoOwner/$sourceRepoName"
  $SourceRepo = Get-GithubRepository -owner $SourceRepoOwner -repo $SourceRepoName -errorAction Stop
}
catch {
  Write-Log -Level Error -Source 'entrypoint' -Message "Unable to get information about $sourceRepoOwner/$sourceRepoName"
}

try {
  Write-Log -Level Info -Source 'entrypoint' -Message "Setting up file paths for $sourceRepoOwner/$sourceRepoName"
  $SourceRepoCheckoutLocation = 'source-repo'
  $SourceRepoDiskPath = Join-Path $SourceRepoCheckoutLocation $SourceRepoPath
  Remove-PathIfExists -Path $SourceRepoCheckoutLocation
}
catch {
  Write-Log -Level Error -Source 'entrypoint' -Message "Unable to setup file paths for $sourceRepoOwner/$sourceRepoName"
}

if ($SourceRepo) {
  try {
    Write-Log -Level Info -Source 'entrypoint' -Message "Cloning $sourceRepoOwner/$sourceRepoName"
    New-GitClone -HttpUrl $SourceRepo.clone_url -Directory $SourceRepoCheckoutLocation
  }
  catch {
    Write-Log -Level Error -Source 'entrypoint' -Message "Unable to clone $sourceRepoOwner/$sourceRepoName"
  }
}
if (!(Test-Path $SourceRepoDiskPath)) {
  Write-Log -Level Error -Source 'entrypoint' -Message "Source Path for file management: $SourceRepoPath was not found"
}

Write-Log -Level Info -Source 'entrypoint' -Message "Finding all repositories in the destination"
$searchQuery = "org:$DestinationRepoOwner"
foreach ($topic in $DestinationRepoTopicsCsv.split(',')) {
  $searchQuery += " topic:$topic"
}
try {
  $DestinationRepositories = Get-GithubRepositorySearchResults -Query $searchQuery
}
catch {
  Write-Log -Level Error -Source 'entrypoint' -Message "Unable to find destination repositories for $searchQuery"
}

try {
  $definitions = Get-ChildItem $SourceRepoDiskPath -Filter *.json

  if (!$definitions) {
    Write-Log -Level Error -Source 'entrypoint' -Message "Unable to find definitions in $sourceRepoPath"
  }

  $DesiredRepositoryLabels = @()
  foreach ($definition in $definitions) {
    Write-Log -Level INFO -Source 'entrypoint' -Message "Processing definition for desired repo label: $($definition.FullName)"
    $DesiredRepositoryLabels += ConvertFrom-Json (Get-Content $definition.FullName | Out-String)
  }

  foreach ($repository in $DestinationRepositories) {
    Write-Log -Level INFO -Source 'entrypoint' -Message "Processing repository $($repository.name)"
    try {
      Write-Log -Level INFO -Source 'entrypoint' -Message "Getting current labels for $($repository.name)"
      $CurrentRepositoryLabels = Get-GithubRepositoryLabels -repo $repository.name -owner $DestinationRepoOwner -ErrorAction Stop
    }
    catch {
      Write-Log -Level ERROR -Source 'entrypoint' -Message "Unable to get current labels for $($repository.name)"
    }

    foreach ($DesiredRepositoryLabel in $DesiredRepositoryLabels) {
      Write-Log -Level INFO -Source 'entrypoint' -Message "Processing label $($desiredRepositoryLabel.name)"
      # Label already exists?
      if ($DesiredRepositoryLabel.name -in $CurrentRepositoryLabels.name) {
        Write-Log -Level INFO -Source 'entrypoint' -Message "Label $($desiredRepositoryLabel.name) already exists, checking colour and description"
        $labelToValidateAgainst = $CurrentRepositoryLabels | Where-Object { $_.name -eq $DesiredRepositoryLabel.name }
        if ($labelToValidateAgainst.color -ne $DesiredRepositoryLabel.color.Replace('#', '')) {
          Write-Log -Level INFO -Source 'entrypoint' -Message "Label $($desiredRepositoryLabel.name) color does not match, currently $($labelToValidateAgainst.color)"
          $UpdateRequired = $true
        }
        if ($labelToValidateAgainst.description -ne $DesiredRepositoryLabel.description) {
          Write-Log -Level INFO -Source 'entrypoint' -Message "Label $($desiredRepositoryLabel.name) description does not match, currently '$($labelToValidateAgainst.description)'"
          $UpdateRequired = $true
        }

        if ($UpdateRequired) {
          try {
          Write-Log -Level INFO -Source 'entrypoint' -Message "Label $($desiredRepositoryLabel.name) is being updated"
          Set-GithubRepositoryLabel -Owner $owner -Repo $repo -Name $DesiredRepositoryLabel.name -Color $DesiredRepositoryLabel.color -Description $DesiredRepositoryLabel.description -ErrorAction Stop
          }
          catch {
            Write-Log -Level Error -Source 'entrypoint' -Message "Label $($desiredRepositoryLabel.name) could not be updated"
          }
        }
      }
      else {
        try {
          Write-Log -Level INFO -Source 'entrypoint' -Message "Label $($desiredRepositoryLabel.name) does not exist, creating"
          New-GithubRepositoryLabel -Owner $owner -Repo $repo -Name $DesiredRepositoryLabel.name -Color $DesiredRepositoryLabel.color -Description $DesiredRepositoryLabel.description -ErrorAction Stop
        }
        catch {
          Write-Log -Level Error -Source 'entrypoint' -Message "Label $($desiredRepositoryLabel.name) could not be created"
        }
      }
    }

    if ($deleteUnmanaged) {
      Write-Log -Level INFO -Source 'entrypoint' -Message "Delete mode is enable, unknown labels will be removed"
      # Now we remove all labels we did not know about...
      $CurrentRepositoryLabelsToRemove = $CurrentRepositoryLabels | ? { $_.name -notin $DesiredRepositoryLabels.name }

      foreach ($CurrentRepositoryLabelToRemove in $CurrentRepositoryLabelsToRemove) {

        try {
          Write-Log -Level INFO -Source 'entrypoint' -Message "Deleting unrequired label $($CurrentRepositoryLabelToRemove.name)"
          Remove-GithubRepositoryLabel -owner $owner -repo $repo -name $CurrentRepositoryLabelToRemove.name -erroraction stop
        }
        catch
        {
          Write-Log -Level Error -Source 'entrypoint' -Message "Unable to delete label $($CurrentRepositoryLabelToRemove.name)"
        }
      }
    }
  }
}

}
