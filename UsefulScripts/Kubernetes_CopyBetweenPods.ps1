<#
.SYNOPSIS
Copy file or directory between pods in a Kubernetes cluster.

.DESCRIPTION
Kubectl cp command can only copy between a pod and a user's machine, or vice versa.  To copy 
between pods requires a two-step process: Copy from source pod to user's machine, then copy 
back up from the user's machine to the destination pod.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5.1 or later (confirmed to work with PowerShell 7.1)
                kubectl Kubernetes command line utility
Version:		1.0.0 
Date:			4 Nov 2021

WARNING: Do not run this script in PowerShell ISE.  PowerShell ISE is unable to run kubectl. 
See https://stackoverflow.com/questions/57622459/kubectl-exec-command-not-working-from-powershell-ise-works-from-powershell-i
#>

$k8sContext = 'k8sdemo'
$k8sSource = @{
                namespace   = 'production'
                pod         = 'pgset-primary-0'
                path        = '/backrestrepo/backup/db/20211105-160002F'
            }
$k8sTarget = @{
                namespace   = 'production'
                pod         = 'pgset-primary-1'
                path        = '/backrestrepo/backup/db'
            }

$localTemp = @{
                path        = 'C:\Temp'
            }

# -------------------------------------------------------------------------------------------------
# NO NEED TO CHANGE ANYTHING BELOW THIS POINT, THE REMAINDER OF THE CODE IS GENERIC.
# -------------------------------------------------------------------------------------------------

#region Functions ---------------------------------------------------------------------------------

function Copy-ToFromK8s 
    (
        $Source,
        $Target
    )
{

    Write-Host "Starting copy from $Source to $Target ..."

    $startTime = get-date

    kubectl cp $Source $Target

    $endTime = Get-Date
    $timeElapsed = New-TimeSpan -Start $startTime -End $endTime
    
    Write-Host "Copy completed in $($timeElapsed.Hours)h $($timeElapsed.Minutes)m $($timeElapsed.Seconds)s"
}

#endregion

# ---------------------------------------------
# Main body of script
# ---------------------------------------------

$fullK8sSource = "$($k8sSource.namespace)/$($k8sSource.pod):$($k8sSource.path)"
$targetDirectory = (Split-Path $k8sSource.path -Leaf)

# Have to use relative path for the local path, not absolute, since kubectl cp sees the colon 
# in a Windows drive as the separator between the pod name and path, eg it would see 
# "C:\Temp\K8sDownloads" as a pod named "C" with a path "/Temp/K8sDownloads".
# NOTE: A pull request fixing this issue in kubectl was approved in October 2021.  So an  
# updated version of kubectl which fixes this issue is likely to be released in late 2021 or 
# early 2022.  See https://github.com/kubernetes/kubernetes/pull/94165
$localRelativePath = Resolve-Path -Path $localTemp.path -Relative

# kubectl cp only understands forward slashes (at least in the source path), whereas Join-Path 
# uses back slashes as the path separator (hold over from Windows PowerShell).  Hence the replace.
$localRelativePath = (Join-Path -Path $localRelativePath -ChildPath $targetDirectory) -replace '\\', '/'
$fullK8sTarget = "$($k8sTarget.namespace)/$($k8sTarget.pod):$($k8sTarget.path)"

kubectl config use-context $k8sContext

$startTime = get-date

Copy-ToFromK8s -Source $fullK8sSource -Target $localRelativePath

Write-Host "Creating destination directory $($k8sTarget.path) on Kubernetes target if it doesn't exist..."
kubectl exec -n $k8sTarget.namespace $k8sTarget.pod -- /bin/sh -c "mkdir -p $($k8sTarget.path)"

Copy-ToFromK8s -Source $localRelativePath -Target $fullK8sTarget

$endTime = Get-Date
$timeElapsed = New-TimeSpan -Start $startTime -End $endTime

Write-Host "Copy between pods completed in $($timeElapsed.Hours)h $($timeElapsed.Minutes)m $($timeElapsed.Seconds)s"
