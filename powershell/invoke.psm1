# powershell\invoke.psm1 --->

$parameter = @{
	ResourceGroupName	= "$TEXT_INVOKE_RG_NAME"
	VMName				= "$TEXT_INVOKE_VM_NAME"
	CommandId			= "$TEXT_INVOKE_COMMAND_ID"
	ErrorAction			= 'SilentlyContinue'
	ScriptPath			= "$TEXT_INVOKE_SCRIPT_PATH"
}

$myContext = Get-AzContext -ListAvailable |
	Where-Object {$_.Subscription.Name -eq "$TEXT_INVOKE_SUB_NAME"} |
	Where-Object {$_.Account.Id -eq "$TEXT_INVOKE_USER_NAME"} |
	Where-Object {$_.Tenant.Id -eq "$TEXT_INVOKE_TENANT"}

Set-AzContext $myContext `
	-WarningAction 'SilentlyContinue' `
	-ErrorAction 'SilentlyContinue' | Out-Null

if (!$?) {
	Write-Host "INVOKE_STATUS='Missing Az-Context'"
}
else {
	$result = Invoke-AzVMRunCommand @parameter
	if (!$?) {
		Write-Host $error
		Write-Host "INVOKE_STATUS='Failed'"
	}
	elseif ($result.Status -ne 'Succeeded') {
		Write-Host "INVOKE_STATUS='$($result.Status)'"
	}
	else {
		$messages = $result.Value[0].Message
		Write-Host $messages
		if ($messages -like "*Last script execution didn't finish*") {
			Write-Host "INVOKE_STATUS='Failed'"
		}
		else {
			Write-Host "INVOKE_STATUS='Succeeded'"
		}
	}
}
