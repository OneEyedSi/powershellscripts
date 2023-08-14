$filePath = 'C:\Working\MiscellaneousIssues\Booking_FindUnAllocated_201611_28-29_AUCK_Parcels.xml'

Clear-Host
$xmlDoc = new-object xml
$xmlDoc.load($filePath)
# SelectSingleNode selects only Delivery or Pickup steps which have been completed (completed_at node is not empty).
# Have to include null check in where clause because complains of null errors if don't (not sure why).
$xmlDoc.ArrayOfBookingSummaryWithEvents.BookingSummaryWithEvents.SelectNodes('./Consignment/Key')