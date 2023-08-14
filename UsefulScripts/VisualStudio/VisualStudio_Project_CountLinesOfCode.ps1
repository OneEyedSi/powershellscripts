$rootFolder = "C:\Temp\Proj"
Clear-Host
(Get-ChildItem -path $rootFolder -include *.cs, *.rpx, *.aspx, *ascx, *.cpp, *.h, *.sql -recurse | select-string .).Count