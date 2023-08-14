Clear-Host
$filePath = 'C:\Temp\XmlParsingExample\Jobs.xml'
$xmlDoc = new-object xml
$xmlDoc.load($filePath)
$xmlDoc.jobs.job.SelectSingleNode("./worker_third_party_id/preceding-sibling::*[1]") `
    | select @{Name="Job ID"; Expression={$_.parentnode.id.innertext}}, `
        @{Name="Previous Node Name"; Expression={$_.name}}, `
        @{Name="Previous Node Value"; Expression={$_.innertext}}