## CODEBYGPT
[![Rejoignez le Discord !](https://img.shields.io/discord/347412941630341121?style=flat-square&logo=discord&colorB=7289DA)](https://discord.gg/rSfTxaW)

## Script PowerShell pour la gestion en CLI de VirtualBox

Ce script permet de gérer les machines virtuelles VirtualBox à partir de la ligne de commande PowerShell. Il s'appuie sur l'utilitaire `VBoxManage.exe` fourni avec VirtualBox. 

### Fonctionnalités

* Clonage de machines virtuelles
* Démarrage, arrêt et redémarrage de machines virtuelles
* Liste des machines virtuelles avec leurs adresses IP
* Affichage d'informations détaillées sur une machine virtuelle
* Redimensionnement du disque dur d'une machine virtuelle
* Modification du nombre de CPU et de la RAM d'une machine virtuelle
* Suppression de machines virtuelles

### Installation

Copiez le script `VBoxManager.ps1` sur votre ordinateur et placez-le dans un dossier accessible depuis votre profil PowerShell.

Par exemple sur `C:\script`


### Si souci de droit sur powershell 
```powershell
# De façon temporraire :
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# De façon permanante :
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
```

### Clone,Start,Stop,Reboot,Liste,Delete les VM (multiple)
```powershell
# Optionnel au clone : -diskSizeMB 50480 -cpuCores 4 -ramSize 4096
.\VBoxManager.ps1 -action clone  -vmNameOrUUID "debian"       -cloneNames "NOM_DU_CLONE","NOM_DU_CLONE1" 
.\VBoxManager.ps1 -action resize -vmNameOrUUID "NOM_DU_CLONE" -diskSizeMB 50480 -cpuCores 4 -ramSize 4096

.\VBoxManager.ps1 -action start  -vmNameOrUUID "NOM_DU_CLONE","NOM_DU_CLONE1"
.\VBoxManager.ps1 -action stop   -vmNameOrUUID "NOM_DU_CLONE","NOM_DU_CLONE1"
.\VBoxManager.ps1 -action reboot -vmNameOrUUID "NOM_DU_CLONE","NOM_DU_CLONE1"
.\VBoxManager.ps1 -action delete -vmNameOrUUID "NOM_DU_CLONE","NOM_DU_CLONE1"
.\VBoxManager.ps1 -action list
```

### Liste les info détailler sur une ou plusieurs VM 
```powershell
.\VBoxManager.ps1 -action showvminfo -vmNameOrUUID "debian", "NOM_DU_CLONE"
```
