<#
.SYNOPSIS
Calls a web method and optionally tests the response.

.DESCRIPTION
Calls a specified web method with the specified parameters displaying the response and the 
results of any tests of the data received in the response.

.NOTES
Author:			Simon Elms
Requires:		PowerShell 5 (may work on earlier versions but untested)
Version:		2.0.0 
Date:			21 Dec 2018

This script is generic and will work with any XML-based web method.  It was designed to work 
with SOAP-based web services but will work with any web method that uses the POST HTTP method 
with an XML request body.  

Parameter sets are not used to separate mutually exclusive parameters -ProxyCredential and 
-ProxyUser/-ProxyPlainTextPassword.  This is to allow calling methods to pass parameters to 
both sets of parameters.  Parameter sets are used in the calling methods instead.

.PARAMETER BaseUrl
String.  The base URL of the web site hosting the web service.  

.PARAMETER WebServiceRelativeUrl
String.  The URL of the web service that is to be called.  The absolute URL of the web service 
will be $BaseUrl\$WebServiceRelativeUrl

.PARAMETER RequestHeaders 
Hash table.  Key-value pairs that each represent a header that will be added to the HTTP request 
to the web service.

.PARAMETER RequestBody
String.  The XML body of the HTTP request, represented as a string.

One way to generate the request body XML for ASP.NET 2 web methods is to browse to the web 
method in a browser, on the server that hosts the web services.  The browser will display 
the XML that should be sent in the request body, which can be copied with the argument 
placeholders replaced with the appropriate values.  Note you must browse to the web method 
on the server hosting the web services because, for security reasons, the XML will not be 
visible when browsing from remote machines.

.PARAMETER ResponseNamespaces
Hash table.  Key-value pairs representing namespace aliases and their associated namespaces.  
These namespaces are used in the XPathExpressions of the response body tests.

.PARAMETER ResponseBodyTests: 
List of hash tables.  Each hash table represents a test of a node in the XML returned from the 
web method in the HTTP response body.  Each hash table should have three key-value pairs:

    a) XPathExpression:  An XPath expression that selects a node of the response body to test;

    b) NodeDescription:  A short user-friendly phrase describing the node being tested;

    c) RegexPatternToMatch:  A regular expression pattern that must match the text of the 
        selected node.  The match will be case-insensitive.

.PARAMETER ProxyServerUrl
String.  The URL of the proxy server used to connect to the internet.

.PARAMETER ProxyCredential
System.Management.Automation.PSCredential object.  A PSCredential object that wraps a username 
and secure password to authenticate to the proxy server.

-ProxyCredential should not be set at the same time as -ProxyUser and -ProxyPlainTextPassword.

.PARAMETER ProxyUser
String.  The username for authentication to the proxy server.

-ProxyUser should be used with -ProxyPlainTextPassword.  It should not be set at the same time 
as -ProxyCredential.

.PARAMETER ProxyPlainTextPassword
String.  The password for authentication to the proxy server, in plain text.

-ProxyPlainTextPassword should be used with -ProxyUser.  It should not be set at the same time 
as -ProxyCredential.

.EXAMPLE
Call a web method, without using a proxy server:

    $baseUrl = 'http://localhost/Test'
    $webServiceRelativeUrl = 'ConsignmentService.asmx'

    $requestHeaders = @{
                            SOAPAction='http://edi.test.nz/WebService/Consignment/ReadConsignment'
                                                                    
                        }
    $requestBody = `
        '<?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:
        soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Header>
            <SecurityHeader xmlns="http://edi.test.nz/WebService/Consignment">
              <MessageID>763a3833-b888-481c-836f-a7273f79ac06</MessageID>
              <UserName>testUser</UserName>
              <PasswordHashMD5>336ca84eab53caf8b60ada65d4ee0fa1</PasswordHashMD5>
              <CreatedUtc>2018-03-21 01:13:18.790</CreatedUtc>
            </SecurityHeader>
          </soap:Header>
          <soap:Body>
            <ReadConsignment Key="10016" xmlns="http://edi.test.nz/WebService/Consignment" />
          </soap:Body>
        </soap:Envelope>'

    $responseNamespaces =  @{
                                soap='http://schemas.xmlsoap.org/soap/envelope/'
                                ns='http://edi.test.nz/WebService/Consignment'
                            }
    $responseBodyTests = @(
                                @{
                                    XPathExpression='./soap:Envelope/soap:Header/ns:ResponseInfo/ns:Result/text()'
                                    NodeDescription='Result'
                                    RegexPatternToMatch='Success'
                                }
                                @{
                                    XPathExpression='./soap:Envelope/soap:Body/ns:ReadConsignmentResponse/ns:Consignment/@Key'
                                    NodeDescription='ConsignmentID'
                                    RegexPatternToMatch="$consignmentID"
                                }
                            )

    Test-WebMethod -BaseUrl $baseUrl -WebServiceRelativeUrl $webServiceRelativeUrl `
        -RequestHeaders $requestHeaders -RequestBody $requestBody `
        -ResponseNamespaces $responseNamespaces -ResponseBodyTests $responseBodyTests

.EXAMPLE
Call a web method, using a proxy server and a PSCredential object to authenticate to the proxy 
server:

    $proxyServerUrl = 'http://localhost:8080'
    $proxyUser = 'domain\JoeBloggs'
    $proxyPlainTextPassword = 'Password123'
    $proxySecurePassword = ConvertTo-SecureString $ProxyPlainTextPassword -AsPlainText -Force
    $proxyCredential = New-Object System.Management.Automation.PSCredential `
                            -ArgumentList $proxyUser,$proxySecurePassword

    Test-WebMethod -BaseUrl $baseUrl -WebServiceRelativeUrl $webServiceRelativeUrl `
        -RequestHeaders $requestHeaders -RequestBody $requestBody `
        -ResponseNamespaces $responseNamespaces -ResponseBodyTests $responseBodyTests `
        -ProxyServerUrl $proxyServerUrl -ProxyCredential $proxyCredential

.EXAMPLE
Call a web method, using a proxy server and a username and password to authenticate to the proxy 
server:

    $proxyServerUrl = 'http://localhost:8080'
    $proxyUser = 'domain\JoeBloggs'
    $proxyPlainTextPassword = 'Password123'

    Test-WebMethod -BaseUrl $baseUrl -WebServiceRelativeUrl $webServiceRelativeUrl `
        -RequestHeaders $requestHeaders -RequestBody $requestBody `
        -ResponseNamespaces $responseNamespaces -ResponseBodyTests $responseBodyTests `
        -ProxyServerUrl $proxyServerUrl `
        -ProxyUser $ProxyUser -ProxyPlainTextPassword $ProxyPlainTextPassword
#>

function Join-UrlPath (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$BaseUrl,
    
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$RelativeUrl
    )
{
    if ([string]::IsNullOrWhiteSpace($BaseUrl))
    {
        # Want to raise a non-terminating error so use Write-Error not Throw.
        Write-Error "Base URL cannot be blank"
        return
    }

    if ([string]::IsNullOrWhiteSpace($RelativeUrl))
    {
        Write-Error "Relative URL cannot be blank"
        return
    }

    $charactersToTrim = @('/', '\')
    $BaseUrl = $BaseUrl.TrimEnd($charactersToTrim)
    $RelativeUrl = $RelativeUrl.TrimStart($charactersToTrim)

    return "$BaseUrl/$RelativeUrl" 
}

function Write-PrettyXmlDocument (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $XmlDocument
    )
{
    $sw = New-Object System.Io.Stringwriter
    $xmlPrettyWriter = New-Object System.Xml.XmlTextWriter($sw)
    $xmlPrettyWriter.Formatting = [System.Xml.Formatting]::Indented
    #$sw.Write($xmlText)
    $XmlDocument.WriteContentTo($xmlPrettyWriter)
    Write-Host $sw.ToString() -ForegroundColor Yellow
}

function Get-XmlNamespaceManager (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $XmlDocument,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]    
    [hashtable]$XmlNamespaces
    )
{
    $namespaceManager = New-Object System.Xml.XmlNamespaceManager($XmlDocument.NameTable)

    foreach($key in $XmlNamespaces.Keys)
    {
        $namespaceManager.AddNamespace($key, $XmlNamespaces[$key])
    }
    
    # Notice the leading "," in the return statement.
    # This is because, by default, Powershell converts a collection return type into an object[] array.
    # To preserve the type of the returned object force the function to return an array with a single 
    # object.  Hence the leading comma before the object being returned: "return ,$namespaceManager"
    #                                                                            ^
    return ,$namespaceManager
}

function Test-XmlNode (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $XmlDocument,
    
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $NamespaceManager,
    
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$XPathExpression,
    
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$NodeDescription,
    
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$RegexPatternToMatch
    )
{
    $node = $XmlDocument.SelectSingleNode($XPathExpression, $NamespaceManager)
    if (-not $node)
    {
        Write-Host "$NodeDescription node not found in XML" -ForegroundColor Red
        return
    }

    $consoleTextColor = "Green"
    $comment = "(matches specified regex pattern '$RegexPatternToMatch')"
    $result = $true

    $value = $node.Value
    if ($value -notmatch $RegexPatternToMatch)
    {
        $consoleTextColor = "Red"
        $comment = "(expected match to regex pattern '$RegexPatternToMatch')"
        $result = $false
    }
    Write-Host "$NodeDescription : '$value' $comment" -ForegroundColor $consoleTextColor

    return $result
}

function Test-XmlResponse (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $ResponseBodyXml,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]    
    [hashtable]$ResponseNamespaces,

    [Parameter(Mandatory=$False)]
    $ResponseBodyTests
    )
{
    $NamespaceManager = (Get-XmlNamespaceManager -XmlDocument $ResponseBodyXml `
                            -XmlNamespaces $ResponseNamespaces)    
    Write-Host

    Write-Host 'Tests of XML nodes in HTTP Response body:'

    $allTestsPassed = $True
    foreach($test in $ResponseBodyTests)
    {
        $result = Test-XmlNode -XmlDocument $ResponseBodyXml -NamespaceManager $NamespaceManager `
                    -XPathExpression $test.XPathExpression `
                    -NodeDescription $test.NodeDescription `
                    -RegexPatternToMatch $test.RegexPatternToMatch

        $allTestsPassed = $allTestsPassed -and $result
    }

    return $allTestsPassed
}

function Test-Response (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$ResponseBodyText,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]    
    [hashtable]$ResponseNamespaces,

    [Parameter(Mandatory=$False)]
    $ResponseBodyTests
    )
{
    if ($ResponseBodyText -eq $null)
    {
        Write-Host "No response received from web service" -ForegroundColor Red
        return
    }

    $responseBodyXml = new-object xml
    $responseBodyXml.LoadXml($ResponseBodyText)

    Write-Host
    Write-Host "Response:"
    Write-PrettyXmlDocument $responseBodyXml

    if (-not $ResponseBodyTests)
    {
        return $True
    }

    $allTestsPassed = Test-XmlResponse -responseBodyXml $responseBodyXml `
                        -ResponseNamespaces $ResponseNamespaces `
                        -ResponseBodyTests $ResponseBodyTests
    return $allTestsPassed
}

<#
.SYNOPSIS
Prevents error when connecting via HTTPS to a host that has a self-signed certificate.

.NOTES
By default, when connecting via HTTPS, Invoke-WebRequest will throw the following error when 
the host it is connecting to has a self-signed certificate:
    "The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel."

To get around this problem allow self-signed certificates.
#>
function Enable-HttpsWithSelfSignedCertificate ()
{

    add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
    $AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

<#
.SYNOPSIS
Function that calls a specified web service with the specified XML-based request body.

.NOTES
#>
function Test-WebMethod (
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$BaseUrl,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]    
    [string]$WebServiceRelativeUrl,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [hashtable]$RequestHeaders,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]    
    [string]$RequestBody,

    [Parameter(Mandatory=$False)]
    [ValidateNotNullOrEmpty()]    
    [hashtable]$ResponseNamespaces,

    [Parameter(Mandatory=$False)]
    [ValidateNotNullOrEmpty()]    
    $ResponseBodyTests,

    [Parameter(Mandatory=$False)]
    [string]$ProxyServerUrl,

    [Parameter(Mandatory=$False)]
    [System.Management.Automation.PSCredential]$ProxyCredential,

    [Parameter(Mandatory=$False)]
    [string]$ProxyUser,

    [Parameter(Mandatory=$False)]
    [string]$ProxyPlainTextPassword
    )
{
    $webServiceUrl = Join-UrlPath -BaseUrl $BaseUrl -relativeUrl $WebServiceRelativeUrl

    $startTime = Get-Date

    Clear-Host
    Write-Host "Host being called: $BaseUrl"
    Write-Host "Full URL: $webServiceUrl"

    Write-Host
    Write-Host "SOAP Request:"
    $requestBodyXml = new-object xml
    $requestBodyXml.LoadXml($RequestBody)
    Write-PrettyXmlDocument $requestBodyXml

    Write-Host
    Write-Host "Calling web service..."

    # If script cannot connect to endpoint it will use the $responseText from the last call.  So clear 
    # $responseText to ensure we're looking at the current results. 
    $responseText = $null

    if (-not $ProxyCredential -and $ProxyUser -and $ProxyPlainTextPassword)
    {
        $ProxyUser = $ProxyUser.Trim()
        $ProxyPlainTextPassword = $ProxyPlainTextPassword.Trim()
        $proxySecurePassword = ConvertTo-SecureString $ProxyPlainTextPassword -AsPlainText -Force
        $ProxyCredential = New-Object System.Management.Automation.PSCredential `
                                -ArgumentList $ProxyUser,$proxySecurePassword 
    }

    Enable-HttpsWithSelfSignedCertificate

    if ($ProxyServerUrl -and $ProxyCredential)
    {
        #[System.Net.Webrequest]::DefaultWebProxy = [System.Net.WebProxy]::new($ProxyServerUrl)
        #$credentialCache = [System.Net.CredentialCache]::new()
        #$networkCredentials = [System.Net.NetworkCredential]::new($ProxyUser, $ProxyPlainTextPassword, '')
        #$credentialCache.Add($ProxyServerUrl, 'Kerberos', $networkCredentials)
        #[System.Net.Webrequest]::DefaultWebProxy.Credentials = $credentialCache
        #[System.Net.Webrequest]::DefaultWebProxy.BypassProxyOnLocal = $true

        #[System.Net.Webrequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        
        $responseText = Invoke-WebRequest $webServiceUrl -Method POST -ContentType 'text/xml' `
                            -Body $RequestBody -Headers $RequestHeaders `
                            -Proxy $ProxyServerUrl -ProxyCredential $ProxyCredential
    }
    else
    {
        $responseText = Invoke-WebRequest $webServiceUrl -Method POST -ContentType 'text/xml' `
                            -Body $RequestBody -Headers $RequestHeaders
    }

    $allTestsPassed = Test-Response -ResponseBodyText $responseText `
                        -ResponseNamespaces $ResponseNamespaces `
                        -ResponseBodyTests $ResponseBodyTests

    $endTime = Get-Date
    $timeTaken = New-TimeSpan -Start $startTime -End $endTime
    $timeTakenSeconds = $timeTaken.TotalSeconds
    
    Write-Host
    $resultText = "OVERALL RESULT: SUCCESS"
    $consoleTextColor = "Green"
    if (-not $allTestsPassed)
    {
        $resultText = "OVERALL RESULT: FAILURE.  ONE OR MORE NODES IN THE HTTP RESPONSE WAS NOT AS EXPECTED"
        $consoleTextColor = "Red"
    }
    Write-Host $resultText -ForegroundColor $consoleTextColor
    Write-Host
    Write-Host "Finished in $timeTakenSeconds seconds"
}