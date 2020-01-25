# PowerShell-Scripts
My PowerShell scripts

## Resolve-DnsRecordUsingAuthoritativeNameServers

DESCRIPTION
-----------
Queries a DNS record using the specified domain's authoritative name server(s).

The function returns the result of each authoritative name server as an array of 
PSCustomObjects.

Suitable for use with Windows PowerShell 5.x and PowerShell Core on Windows and 
GNU/Linux.

This script wasn't intended to win any design awards, it was created to ease 
the diagnosis of a particular DNS problem I was experiencing, the details of 
which can be found here: [Cross-Platform Usage of Nslookup](https://www.thecliguy.co.uk/2019/06/02/cross-platform-usage-of-nslookup/). It would have been overkill to write a series of general purpose 
DNS functions, so I went for a single monolithic function to achieve a single 
objective. It gets the job done.

EXAMPLE USAGE
-------------
```PowerShell
. .\Resolve-DnsRecordUsingAuthoritativeNameServers.ps1

$DnsArguments = @{
  Domain = 'example.com'
  RecordType = 'a'
  RecordName = 'www'
  Verbose = $true
}

Resolve-DnsRecordUsingAuthoritativeNameServers @DnsArguments | Format-Table -AutoSize -Wrap
```
```
VERBOSE: Checking for presence of nslookup...
VERBOSE: Primary Name Server: sns.dns.icann.org
VERBOSE: Authoritative Name Server(s): a.iana-servers.net, b.iana-servers.net.

AuthoritativeNameServer QueryResult
----------------------- -----------
b.iana-servers.net      Server:  b.iana-servers.net
                        Address:  199.43.133.53
                        Name:    www.example.com
                        Address:  93.184.216.34
a.iana-servers.net      Server:  a.iana-servers.net
                        Address:  199.43.135.53
                        Name:    www.example.com
                        Address:  93.184.216.34
```
