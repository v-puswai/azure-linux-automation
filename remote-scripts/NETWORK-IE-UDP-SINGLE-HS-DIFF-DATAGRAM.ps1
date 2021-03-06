﻿Import-Module .\TestLibs\RDFELibs.psm1 -Force
$Subtests= $currentTestData.SubtestValues
$SubtestValues = $Subtests.Split(",")
$resultSummary = ""
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{

	$hs1Name = $isDeployed
	$testServiceData = Get-AzureService -ServiceName $hs1Name

    #Get VMs deployed in the service..
	$testVMsinService = $testServiceData | Get-AzureVM

	$hs1vm1 = $testVMsinService[0]
	$hs1vm1Endpoints = $hs1vm1 | Get-AzureEndpoint

	$hs1VIP = $hs1vm1Endpoints[0].Vip
	$hs1ServiceUrl = $hs1vm1.DNSName
	$hs1ServiceUrl = $hs1ServiceUrl.Replace("http://","")
	$hs1ServiceUrl = $hs1ServiceUrl.Replace("/","")

	$hs1vm2 = $testVMsinService[1]
	$hs1vm2Endpoints = $hs1vm2 | Get-AzureEndpoint

	$hs1vm1tcpport = GetPort -Endpoints $hs1vm1Endpoints -usage tcp
	$hs1vm2tcpport = GetPort -Endpoints $hs1vm2Endpoints -usage tcp
	$hs1vm1udpport = GetPort -Endpoints $hs1vm1Endpoints -usage udp
	$hs1vm2udpport = GetPort -Endpoints $hs1vm2Endpoints -usage udp
	$hs1vm1sshport = GetPort -Endpoints $hs1vm1Endpoints -usage ssh
	$hs1vm2sshport = GetPort -Endpoints $hs1vm2Endpoints -usage ssh

	foreach ($Value in $SubtestValues)
	{
		foreach ($mode in $currentTestData.TestMode.Split(","))
		{   
			try
			{
                $testResult = $null
				$cmd1="./start-server.py -p $hs1vm1udpport -u yes && mv Runtime.log start-server.py.log -f"
				if ($mode -eq "VIP")
				{
					$cmd2="./start-client.py -c $($hs1vm1.IpAddress)  -p $hs1vm1udpport -t10 -u yes -l $Value" 
				}
				elseif($mode -eq "URL")
				{
					$cmd2="./start-client.py -c $($hs1vm1.IpAddress)  -p $hs1vm1udpport -t10 -u yes -l $Value"
				}
				LogMsg "Starting in $mode mode.."
				$a = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -nodeUdpPort $hs1vm1udpport -nodeIperfCmd $cmd1 -user $user -password $password -files $currentTestData.files -logDir $LogDir
				$b = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm2sshport -nodeUdpPort $hs1vm2udpport -nodeIperfCmd $cmd2 -user $user -password $password -files $currentTestData.files -logDir $LogDir
				LogMsg "Test Started for UDP Datagram size $Value"
				mkdir $LogDir\$Value -ErrorAction SilentlyContinue | out-null
				mkdir $LogDir\$Value\$mode -ErrorAction SilentlyContinue | out-null

				$b.logDir = $LogDir + "\$Value\$mode"
				$a.logDir = $LogDir + "\$Value\$mode"
				$server = $a
				$client = $b
				$testResult = IperfClientServerUDPDatagramTest -server $server -client $client
                LogMsg "$($currentTestData.testName) : $Value : $mode : $testResult"
			}
			catch
			{
				$ErrorMessage =  $_.Exception.Message
				LogErr "EXCEPTION : $ErrorMessage"   
			}
			Finally
			{
				$metaData = "$Value : $mode" 
				if (!$testResult)
				{
					$testResult = "Aborted"
				}
				$resultArr += $testResult
				$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
			}   
		}
	}
}
else
{
	$testResult = "Aborted"
	$resultArr += $testResult
}
$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed

#Return the result and summery to the test suite script..
return $result,$resultSummary
