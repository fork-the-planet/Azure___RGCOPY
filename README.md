# RGCOPY

RGCOPY (**R**esource **G**roup **COPY**) is a tool that copies the most important resources of an Azure resource group (**source RG**) to a new resource group (**target RG**). It can copy a whole landscape consisting of many servers within a single Azure resource group to a new resource group. The target RG might be in a different region or subscription. RGCOPY has been tested on **Windows**, **Linux** and in **Azure Cloud Shell**.

The first example demonstrates the user interface of RGCOPY

```powershell
$rgcopyParameter = @{
    sourceRG        = 'sap_vmss_zone'
    targetRG        = 'sap_vmss_zone_copy'
    targetLocation  = 'eastus'
    setVmSize       = 'Standard_E4ds_v4'
    setDiskSku      = 'Premium_LRS'
}
.\rgcopy.ps1 @rgcopyParameter
```

!["RGCOPY"](/images/RGCOPY.png)

The following examples show the usage of RGCOPY. In all examples, a source RG with the name 'SAP_master' is copied to the target RG 'SAP_copy'. For better readability, the examples use parameter splatting, see <https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting>. Before starting RGCOPY, you must run the PowerShell cmdlet `Connect-AzAccount`.

```powershell
# connect to Azure
Update-AzConfig -EnableLoginByWam $true
Connect-AzAccount `
    -AuthScope 'Storage' `
    -TenantId '7b5ebd57-e5fd-445f-a920-55897cd71921' `
    -Subscription 'Contoso Subscription'


# start RGCOPY using cached credentials
$rgcopyParameter = @{
    sourceRG        = 'SAP_master'
    targetRG        = 'SAP_copy'
    targetLocation  = 'westus'
}
.\rgcopy.ps1 @rgcopyParameter
```

You might have cached credentials for different subscriptions and users. In this case, you must specify user and subscription using RGCOPY parameters:


```powershell
$rgcopyParameter = @{
    # parameters for subscription and user 
    sourceSub       = 'Contoso Subscription'
    sourceSubUser   = 'user@contoso.com'
    sourceSubTenant = '7b5ebd57-e5fd-445f-a920-55897cd71921'

    sourceRG        = 'SAP_master'
    targetRG        = 'SAP_copy'
    targetLocation  = 'westus'
}
.\rgcopy.ps1 @rgcopyParameter
```

You can store often used parameters in a separate parameter file and pass the filename to RGCOPY. The example above looks like this when having the parameter file `parameterFiles\contoso.json` 

```powershell
$rgcopyParameter = @{
    # using a parameter file
    parameterFile   = 'parameterFiles\contoso.json'

    sourceRG        = 'SAP_master'
    targetRG        = 'SAP_copy'
    targetLocation  = 'westus'
}
.\rgcopy.ps1 @rgcopyParameter
```

```json
{
    // file 'parameterFiles\contoso.json'
    "sourceSub": "Contoso Subscription",
    "sourceSubUser": "user@contoso.com",
    "sourceSubTenant": "7b5ebd57-e5fd-445f-a920-55897cd71921",

    "targetSub": "Contoso Subscription",
    "targetSubUser": "user@contoso.com",
    "targetSubTenant": "7b5ebd57-e5fd-445f-a920-55897cd71921"
}
```

You can change almost all properties of VMs and disks in the target RG. The following example changes the VM size to Standard_M16ms (for VMs HANA1 and HANA2), Standard_M8ms (for VM SAPAPP) and Standard_D2s_v4 (for all other VMs):
```powershell
$rgcopyParameter = @{
    sourceRG        = 'SAP_master'
    targetRG        = 'SAP_copy'
    targetLocation  = 'westus'

    setVmSize = @(
        'Standard_M16ms @ HANA1, HANA2',
        'Standard_M8ms @ SAPAPP',
        'Standard_D2s_v4'
    )	
}
.\rgcopy.ps1 @rgcopyParameter
```

## Using RGCOPY for moving an (SAP) system to a different region
RGCOPY was originally a Microsoft internal test tool for coping an SAP system inside a single Azure resource group. RGCOPY did not copy *all* resource types in this resource group and did it not copy *all* properties of these resources.

In the latest version, the scope of RGCOPY has changed from a specialized tool (that supports only features needed Microsoft internally) to a more universal tool. The following improvements have been implemented:
- The number of supported resource types has grown. RGCOPY can even copy storage accounts including the content of BLOB containers and SMB/NFS shares. The full **list of supported resource types** is included in the **[documentation](./rgcopy-docu.md#Supported-Azure-Resources)**.
- The most important resource properties are copied. If a resource property is not copied then RGCOPY gives a **warning regarding the missing property**. As a starting point, run RGCOPY with parameter `simulate` and check all yellow warnings.
- RGCOPY still requires a single source resource group that contains all VMs and all disks within a single region. However, **referenced resources in different resource groups** (e.g. VNETs and NICs) are also copied.
- Copying disks to other regions became much faster. RGCOPY can start multiple instances of AzCopy in parallel. This is much faster compared with parallel running snapshot copies.

Using RGCOPY for moving SAP systems still has some limitations:
- Nature of copy
    - RGCOPY performs a ***copy***, not a ***move***. The original system still exists if anything fails.
    - RGCOPY does not change anything inside the VMs like changing the server name at the OS level or applying SAP license keys.
- User Interface
    - RGCOPY is a command-line tool optimized for automation. You can change almost every property in the target (compared with the source),  resulting in about 200 RGCOPY parameters. However, RGCOPY is not integrated into Azure portal and there is no other GUI.
- Downtime
    - If you want to *copy* a productive system to a test system then the downtime is very short: You just need to stop your productive servers for creating the disk snapshots.
    - However, the downtime for *moving* a productive system is much longer. It includes the **time needed for copying the disks** to a different region, deploying the new resource group and **performing manual follow-up steps** like applying license keys. 
- Support
    - RGCOPY has been developed and is maintained by a single developer. It is an Open Source tool available in GitHub, not an official Microsoft product. Microsoft Product Support will not provide support for RGCOPY. However, you can suggest future features and report bugs using GitHub Issues.

## Open Source version of RGCOPY
RGCOPY has been released as Open Source Software (OSS) in
- **https://github.com/Azure/RGCOPY**

There also exists a Microsoft internal version of RGCOPY with additional features. It is stored in a different repository. 

## Documentation
The complete documentation is contained in file **[rgcopy-docu.md](./rgcopy-docu.md)** 

## YouTube training
You can watch an introduction to RGCOPY on YouTube (22:35):

[![RGCOPY](https://i.ytimg.com/vi/8pCN10CRXtY/hqdefault.jpg)](https://www.youtube.com/watch?v=8pCN10CRXtY)


## Trademarks
This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
