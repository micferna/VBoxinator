Param(
    [string]$action,
    [string[]]$vmNameOrUUID = @(),
    [string[]]$cloneNames = @(),
    [int]$diskSizeMB = 0,
    [string]$diskPath = $null,
    [int]$cpuCores = -1, # Valeur par défaut pour le nombre de CPU (-1 pour ignorer la modification)
    [int]$ramSize = -1    # Valeur par défaut pour la taille de la RAM (-1 pour ignorer la modification)
)

$vboxManagePath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

# Cette fonction est appelée pour lister les VMs et leurs adresses IP
function ListVMsWithIP {
    Write-Host "Voici la liste des machines virtuelles disponibles avec leurs adresses IP :" -ForegroundColor Green
    
    # Récupération de la liste des VMs avec leurs IPs
    $vmsList = & $vboxManagePath list vms
    $vmInfoList = foreach ($vm in $vmsList) {
        $vmObj = $vm -replace '"', '' -split ' {'
        $vmName = $vmObj[0]
        $vmUUID = $vmObj[1].TrimEnd('}')
        $ipProperty = & $vboxManagePath guestproperty enumerate $vmUUID | Where-Object { $_ -like "*IP*" }
        $ipAddress = if ($ipProperty) { ($ipProperty -split ',')[1].Split(':')[1].Trim() } else { "N/A" }

        [PSCustomObject]@{
            VMName = $vmName
            UUID = $vmUUID
            IPAddress = if ($ipAddress -eq "N/A") { $ipAddress.PadLeft((15 + $ipAddress.Length) / 2).PadRight(15) } else { $ipAddress } # Centre "N/A"
        }
    }

    # Affichage de l'en-tête
    Write-Host "VMName                           UUID                                 IPAddress" -ForegroundColor Yellow

    $uuidColumnWidth = 36 # Largeur attribuée à la colonne UUID
    foreach ($vmInfo in $vmInfoList) {
        $centeredUUID = $vmInfo.UUID.PadLeft(($uuidColumnWidth + $vmInfo.UUID.Length) / 2).PadRight($uuidColumnWidth)
        Write-Host ("{0,-30} {1} {2,-15}" -f $vmInfo.VMName, $centeredUUID, $vmInfo.IPAddress) -ForegroundColor Cyan
    }
}

function ShowVMInfo {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$vmNameOrUUID
    )

    foreach ($vm in $vmNameOrUUID) {
        Write-Host "Affichage des informations pour la VM : $vm" -ForegroundColor Cyan
        
        # Vérifier si la machine virtuelle existe
        $vmInfo = & $vboxManagePath showvminfo $vm 2>$null
        if (-not $?) {
            Write-Host "Erreur : La machine virtuelle '$vm' n'existe pas." -ForegroundColor Red
            continue
        }

        $vmInfo
    }
}

function Get-VMMainDiskUUID {
    param(
        [string]$vmNameOrUUID
    )

    # Obtenir les informations de la VM en mode machine-readable
    $vmInfo = & $vboxManagePath showvminfo $vmNameOrUUID --machinereadable

    # Rechercher l'UUID du disque dur principal en utilisant l'identifiant correct
    $diskUUID = $vmInfo | Where-Object { $_ -match '^"SATA-ImageUUID-0-0"=' } | ForEach-Object {
        $_ -replace '^"SATA-ImageUUID-0-0"="', '' -replace '"$', ''
    }

    return $diskUUID
}

function StopVM {
    param (
        [Parameter(Mandatory=$true)]
        [string]$vmNameOrUUID
    )

    Write-Host "Arret de la machine virtuelle '$vmNameOrUUID'..." -ForegroundColor Cyan
    & $vboxManagePath controlvm $vmNameOrUUID poweroff
}

function StartVM {
    param (
        [Parameter(Mandatory=$true)]
        [string]$vmNameOrUUID
    )

    Write-Host "Demarrage de la machine virtuelle '$vmNameOrUUID'..." -ForegroundColor Cyan
    & $vboxManagePath startvm $vmNameOrUUID --type headless
}

switch ($action) {
    "list" {
        ListVMsWithIP
    }

    "showvminfo" {
        ShowVMInfo -vmNameOrUUID $vmNameOrUUID
    }
    
    "clone" {
        if ($vmNameOrUUID -and $cloneNames.Count -gt 0) {
            # Message de début groupé
            $cloneNamesJoined = $cloneNames -join ", "
            Write-Host "Tentative de clonage de la VM '$vmNameOrUUID' vers : $cloneNamesJoined..."
    
            foreach ($cloneName in $cloneNames) {
                $output = & $vboxManagePath clonevm $vmNameOrUUID --name $cloneName --register 2>&1
                if ($output -like "*already exists*") {
                    Write-Host "Erreur : Le clone '$cloneName' existe déjà." -ForegroundColor Red
                } elseif ($output -like "*Could not find a registered machine named*") {
                    Write-Host "Erreur : La machine virtuelle spécifiée '$vmNameOrUUID' n'existe pas." -ForegroundColor Red
                    # Afficher la liste des VMs disponibles
                    Write-Host "Voici la liste des machines virtuelles disponibles :"
                    & $vboxManagePath list vms | ForEach-Object { Write-Host $_ }
                    break # Sortir de la boucle pour éviter de répéter l'erreur pour chaque cloneName
                } elseif ($output -like "*error:*") {
                    Write-Host "Erreur lors du clonage vers '$cloneName'. Détails : $output" -ForegroundColor Red
                } else {
                    Write-Host "Le clone '$cloneName' a été créé avec succès." -ForegroundColor Green
                }
            }
    
            Write-Host "Les tentatives de clonage pour '$vmNameOrUUID' sont terminées."
        } else {
            Write-Host "Paramètres manquants ou incohérents pour l'action de clonage." -ForegroundColor Red
        }
    }
    
    
    "resize" {
        if ($vmNameOrUUID) {
            # S'assurer que diskSizeMB est spécifié et supérieur à 0 pour le redimensionnement du disque
            if ($diskSizeMB -gt 0) {
                $diskUUID = Get-VMMainDiskUUID -vmNameOrUUID $vmNameOrUUID
                if ($diskUUID) {
                    Write-Host "Redimensionnement du disque (UUID: $diskUUID) à $diskSizeMB MB..." -ForegroundColor Cyan
                    & $vboxManagePath modifymedium disk $diskUUID --resize $diskSizeMB > $null 2>&1
                    Write-Host "Disque redimensionné avec succès." -ForegroundColor Green
                } else {
                    Write-Host "UUID du disque introuvable." -ForegroundColor Red
                }
            } else {
                Write-Host "Redimensionnement du disque ignoré (taille de disque non spécifiée ou égale à 0)." -ForegroundColor Yellow
            }
    
            # Modification du nombre de CPU si spécifié
            if ($cpuCores -gt -1) {
                Write-Host "Modification du nombre de CPU pour la VM à $cpuCores..." -ForegroundColor Cyan
                & $vboxManagePath modifyvm $vmNameOrUUID --cpus $cpuCores
                Write-Host "Nombre de CPU modifié avec succès." -ForegroundColor Green
            }
    
            # Modification de la RAM si spécifiée
            if ($ramSize -gt -1) {
                Write-Host "Modification de la RAM pour la VM à $ramSize MB..." -ForegroundColor Cyan
                & $vboxManagePath modifyvm $vmNameOrUUID --memory $ramSize
                Write-Host "RAM modifiée avec succès." -ForegroundColor Green
            }
        } else {
            Write-Host "Paramètres manquants pour l'action de redimensionnement ou de modification." -ForegroundColor Red
        }
    }
    
    "delete" {
        $vmsToDelete = $vmNameOrUUID -join ", "
        Write-Host "Tentative de suppression des machines virtuelles : $vmsToDelete"
        
        $vmsStopped = @()
        $vmsDeleted = @()
        $errors = @()
        
        foreach ($vm in $vmNameOrUUID) {
            # Vérifier si la machine virtuelle existe
            $vmInfo = & $vboxManagePath showvminfo $vm --machinereadable 2>$null
            if (-not $?) {
                Write-Host "La machine virtuelle '$vm' n'existe pas." -ForegroundColor Yellow
                $errors += $vm
                continue
            }
            
            $vmState = $vmInfo | Where-Object { $_ -match "^VMState=" } | ForEach-Object { $_ -replace '.*="(.*)"', '$1' }
            
            if ($vmState -eq "running") {
                Write-Host "Arrêt de '$vm'..."
                & $vboxManagePath controlvm $vm poweroff > $null 2>&1
                Start-Sleep -Seconds 5
                $vmsStopped += $vm
            }
            
            $output = & $vboxManagePath unregistervm $vm --delete 2>$null
    
            if ($LASTEXITCODE -eq 0) {
                $vmsDeleted += $vm
            } else {
                $errors += $vm
            }
        }
        
        if ($vmsStopped) {
            Write-Host "Machines virtuelles arrêtées : $($vmsStopped -join ', ')" -ForegroundColor Cyan
        }
        if ($vmsDeleted) {
            Write-Host "Machines virtuelles supprimées avec succès : $($vmsDeleted -join ', ')" -ForegroundColor Green
        }
        if ($errors) {
            Write-Host "Erreurs lors de la suppression des machines virtuelles : $($errors -join ', ')" -ForegroundColor Red
        }
        
        Write-Host "Fin des tentatives de suppression des machines virtuelles."
    }
    
    

    "start" {
        # Concaténer les noms pour le message de début
        $vmNamesJoined = $vmNameOrUUID -join ", "
        Write-Host "Tentative de démarrage des machines virtuelles '$vmNamesJoined'..."
        
        $results = @()
        $allAlreadyStarted = $true
    
        foreach ($vm in $vmNameOrUUID) {
            # Vérifier si la machine virtuelle existe
            $stateInfo = & $vboxManagePath showvminfo $vm --machinereadable 2>$null
            if (-not $?) {
                Write-Host "La machine virtuelle '$vm' n'a pas été trouvée." -ForegroundColor Yellow
                $allAlreadyStarted = $false
                continue
            }
            
            $stateInfo = $stateInfo | Where-Object { $_ -match "^VMState=" }
            if ($stateInfo -match '"running"') {
                $results += "La machine virtuelle '$vm' est déjà démarrée."
            } else {
                $result = & $vboxManagePath startvm $vm --type headless
                if ($result -match "error") {
                    $results += "Erreur lors du démarrage de la machine virtuelle '$vm'."
                    $allAlreadyStarted = $false
                } else {
                    $results += "La machine virtuelle '$vm' a été démarrée avec succès."
                    $allAlreadyStarted = $false
                }
            }
        }
    
        # Afficher les résultats avec la couleur appropriée
        $results | ForEach-Object {
            if ($_ -match "est déjà démarrée") {
                Write-Host $_ -ForegroundColor Yellow
            } elseif ($_ -match "Erreur") {
                Write-Host $_ -ForegroundColor Red
            } else {
                Write-Host $_ -ForegroundColor Green
            }
        }
    
        if ($allAlreadyStarted) {
            Write-Host "Les machines virtuelles '$vmNamesJoined' étaient déjà toutes démarrées." -ForegroundColor Yellow
        } else {
            Write-Host "Les tentatives de démarrage des machines virtuelles '$vmNamesJoined' sont terminées." -ForegroundColor Cyan
        }
    }
    
    
    "stop" {
        # Concaténer les noms pour le message de début
        $vmNamesJoined = $vmNameOrUUID -join ", "
        Write-Host "Tentative d'arrêt des machines virtuelles '$vmNamesJoined' en arrière-plan..."
        
        $allAlreadyStopped = $true
        $results = @()
    
        foreach ($vm in $vmNameOrUUID) {
            # Vérifier si la machine virtuelle existe
            $stateInfo = & $vboxManagePath showvminfo $vm --machinereadable 2>$null
            if (-not $?) {
                $results += "Erreur : La machine virtuelle '$vm' n'existe pas."
                continue
            }
    
            $stateInfo = $stateInfo | Where-Object { $_ -match "^VMState=" }
            if ($stateInfo -match '"poweroff"') {
                $results += "La machine virtuelle '$vm' est déjà éteinte."
            } else {
                $result = & $vboxManagePath controlvm $vm poweroff 2>&1
                if ($result -match "error") {
                    $results += "Erreur lors de l'arrêt de la machine virtuelle '$vm'."
                    $allAlreadyStopped = $false
                } else {
                    $results += "La machine virtuelle '$vm' a été éteinte avec succès."
                    $allAlreadyStopped = $false
                }
            }
        }
    
        # Afficher les résultats avec la couleur appropriée
        $results | ForEach-Object {
            if ($_ -match "est déjà éteinte") {
                Write-Host $_ -ForegroundColor Yellow
            } elseif ($_ -match "Erreur") {
                Write-Host $_ -ForegroundColor Red
            } else {
                Write-Host $_ -ForegroundColor Green
            }
        }
    
        if ($allAlreadyStopped) {
            Write-Host "Les machines virtuelles '$vmNamesJoined' sont déjà éteintes." -ForegroundColor Yellow
        } else {
            Write-Host "Les tentatives d'arrêt des machines virtuelles '$vmNamesJoined' sont terminées." -ForegroundColor Cyan
        }
    }
    
    
    "reboot" {
        # Concaténer les noms pour le message de début
        $vmNamesJoined = $vmNameOrUUID -join ", "
        Write-Host "Tentative de redémarrage des machines virtuelles '$vmNamesJoined' en arrière-plan..."
    
        $results = @()
    
        foreach ($vm in $vmNameOrUUID) {
            # Vérifier si la machine virtuelle existe
            $stateInfo = & $vboxManagePath showvminfo $vm --machinereadable 2>$null
            if (-not $?) {
                $results += "Erreur : La machine virtuelle '$vm' n'existe pas."
                continue
            }
    
            $stateInfo = $stateInfo | Where-Object { $_ -match "^VMState=" }
            if ($stateInfo -match '"poweroff"') {
                $results += "Erreur : La machine virtuelle '$vm' n'est pas en cours d'exécution et ne peut pas être redémarrée."
            } else {
                $result = & $vboxManagePath controlvm $vm reset
                if ($result -match "error") {
                    $results += "Erreur lors du redémarrage de la machine virtuelle '$vm'. Détails : $result"
                } else {
                    $results += "La machine virtuelle '$vm' a été redémarrée avec succès."
                }
            }
        }
    
        # Afficher les résultats avec la couleur appropriée
        $results | ForEach-Object {
            if ($_ -match "Erreur") {
                Write-Host $_ -ForegroundColor Red
            } else {
                Write-Host $_ -ForegroundColor Green
            }
        }
    
        Write-Host "Les tentatives de redémarrage des machines virtuelles '$vmNamesJoined' sont terminées." -ForegroundColor Cyan
    }
    
    default {
        Write-Host "Invalid action: $action"
    }
}
