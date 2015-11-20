Existing Demo requires machine to be hyper-v capable as well as changing state of the Host which is not desirable.
This is the alternative by configuring the host first using PS cmdlets:


    $networkName = "Unidentified network"
    $interfaceAlias = "vEthernet (SqlDemoInternal)"
    $prefixLength = 24
    $ipAddress = "192.168.100.100"

#Step1: Add an Internal Switch (if one doesn't exist).
    $profile=Get-NetConnectionProfile -InterfaceAlias $interfaceAlias -ErrorAction SilentlyContinue -ErrorVariable ev
    if($ev -eq $null)
    {
  	Set-NetConnectionProfile -Name $networkName  -InterfaceAlias $interfaceAlias -InterfaceIndex $prefixLength
        Get-NetConnectionProfile -InterfaceAlias $interfaceAlias | Set-NetConnectionProfile -NetworkCategory private
    }

#Step2: Add a static ipaddress (192.168.100.100) to this switch and mark it private.

$staticIP=Get-NetIPAddress -IPAddress 192.168.100.100 -Ev var -ErrorAction SilentlyContinue
if( $var -eq $null)
{
    New-NetIPAddress -IPAddress $ipAddress -PrefixLength $prefixLength -InterfaceAlias $interfaceAlias
}

