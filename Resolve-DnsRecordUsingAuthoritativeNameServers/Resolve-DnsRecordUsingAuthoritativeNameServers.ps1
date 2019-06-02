################################################################################
# Copyright (C) 2019
# Adam Russell <adam[at]thecliguy[dot]co[dot]uk> 
# https://www.thecliguy.co.uk
# 
# Licensed under the MIT License.
#
################################################################################
# Development Log:
#
# 0.1.0 - 2019-06-02 (AR)
#   * First release.
#
################################################################################

Function Resolve-DnsRecordUsingAuthoritativeNameServers {
	<#
    .SYNOPSIS
        Performs a DNS query for the specified domain, record type and (optionally)
        record name against the domain's authoritative name server(s).
    .DESCRIPTION
        Queries the specified domain for its authoritative name server(s).
		Each authoritative name server is queried for the specified record.
        The function returns the result of each authoritative name server as an
		array of PSCustomObjects.
    .EXAMPLE
        $Query = Resolve-DnsRecordUsingAuthoritativeNameServers -Domain 'example.com' -RecordType 'a' -RecordName 'www' -Verbose
        $Query | Format-Table -AutoSize -Wrap
    #>
	
	[CmdletBinding()]
    param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$Domain,

        [parameter(Mandatory=$true)]
        [ValidateSet('A','ANY','CNAME','GID','HINFO','MB','MG','MINFO','MR','MX','NS','PTR','SOA','TXT','UID','UINFO','WKS')]
        [String]$RecordType,
		
		[parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [String]$RecordName,
		
		[parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [Switch]$UsePrimaryNameServerToObtainAuthoritativeNameServers = $True
    )
	
	# Ensure that nslookup is present.
	If (($PSVersionTable.PSEdition -eq 'Desktop') -or ($IsWindows)) {
		$NslookupPath = "$env:windir\System32\nslookup.exe"
	}
	ElseIf ($IsLinux) {
		$NslookupPath = '/usr/bin/nslookup'
	}
	
	Write-Verbose "Checking for presence of nslookup..."
	
	If (!(Test-Path $NslookupPath)) {
		Throw "File not found: $NslookupPath"
	}
		
	# Obtain the domain's SOA (Start of Authority) record.
	$qrySoaResult = ($null = nslookup -querytype=soa $Domain 2>&1)
	
	If ($UsePrimaryNameServerToObtainAuthoritativeNameServers) {
		# Extract Primary Name Server from the output.
		# The Windows native nslookup fork uses "primary name server = " whereas 
		# modern BIND nslookup releases use "origin = ".
		$PrimaryNameServer = $qrySoaResult | 
			Where-Object {
				$_ -Match '((?:^\s+primary name server = )|(?:^\s+origin = ))(?<PrimaryNS>.+)'
			} | 
			ForEach-Object {
				$Matches.PrimaryNS = $Matches.PrimaryNS
				[pscustomobject]$Matches.PrimaryNS
			}
		
		# If no result or more than one result was returned then something went 
		# wrong...
		If (!($PrimaryNameServer)) {
			$err = "No result returned for Primary Name Server."
			Throw $err
		}
		ElseIf ($PrimaryNameServer.GetType() -ne [string]) {
			$err = "More than one result returned for Primary Name Server:`n"
			$err = $err + ($PrimaryNameServer -join ", ")
			Throw $err
		}
		
		Write-Verbose "Primary Name Server: $PrimaryNameServer"
	}
	
	# Query domain for authoritative name servers.
	# Returns an array of strings.
	If ($UsePrimaryNameServerToObtainAuthoritativeNameServers) {
		$qryNameServersResult = ($null = nslookup -querytype=ns $Domain $PrimaryNameServer 2>&1)
	}
	Else {
		$qryNameServersResult = ($null = nslookup -querytype=ns $Domain $PrimaryNameServer 2>&1)
	}
	
	# Extract authoritative name server(s) from the output.
	$NameServers = $qryNameServersResult | 
		Where-Object {
			$_ -Match '(?:nameserver = )(?<ns>.+)'
		} | 
		ForEach-Object {
			# Modern BIND nslookup releases ends each name server result with a 
			# full stop, remove it.
			$Matches.ns = $Matches.ns.TrimEnd('.')
			[pscustomobject]$Matches.ns
		}
	
	If ($NameServers.count) {
		Write-Verbose "Authoritative Name Server(s): $($NameServers -join ", ")."
	}
	Else {
		Write-Verbose "Authoritative Name Server(s): None found."
		Write-Verbose ($qryNameServersResult | out-string | foreach-object {$_ -replace '(?m)^\s*\r?\n',''})
		Return $null
	}
	
	# Query each authoritative name server.
	$Result = $NameServers.ForEach({ 
		If ($PSBoundParameters.ContainsKey('RecordName')) {
			$qryRecordLookupResult = (nslookup -querytype="$($RecordType)" "$($RecordName).$($Domain)" $_ 2>&1)
		}
		Else {
			$qryRecordLookupResult = (nslookup -querytype="$($RecordType)" $Domain $_ 2>&1)
		}
		
		# Convert array of strings into a multi-line string.
		$qryRecordLookupResult = $qryRecordLookupResult | out-string
				
		# Remove blank lines.
		# https://stackoverflow.com/questions/25106675
		$qryRecordLookupResult = $qryRecordLookupResult -replace '(?m)^\s*\r?\n',''
		$qryRecordLookupResult = $qryRecordLookupResult.Trim()
		
		[pscustomobject]@{
			AuthoritativeNameServer = $_
			QueryResult = $qryRecordLookupResult
		}
	})

	Return $Result
}
