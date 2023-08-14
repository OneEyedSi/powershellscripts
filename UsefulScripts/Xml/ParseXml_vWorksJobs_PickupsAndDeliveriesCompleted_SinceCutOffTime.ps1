$filePath = 'C:\Temp\vWorksJobUpdates_20160920_1158_Since20160920_0000.xml'
$cutOffTimeText = "2016-09-19T12:00:00+00:00"

Clear-Host
$cutOffTime = [datetime]$cutOffTimeText
$xmlDoc = new-object xml
$xmlDoc.load($filePath)
# SelectSingleNode selects only Delivery or Pickup steps which have been completed (completed_at node is not empty).
# Have to include null check in where clause because complains of null errors if don't (not sure why).
$xmlDoc.jobs.job.SelectSingleNode('./steps/step[(name="Delivery" or name="Pickup") and completed_at/node()]') `
    | where {$_.completed_at.innertext -eq $null -or [datetime]($_.completed_at.innertext) -ge $cutOffTime} `
    | select @{Name="Job ID"; Expression={$_.parentnode.parentnode.id.innertext}}, `
        @{Name="Step ID"; Expression={$_.id.innertext}}, `
        @{Name="Step Type"; Expression={$_.name}}, `
        @{Name="Completed At"; Expression={$_.completed_at.innertext}}