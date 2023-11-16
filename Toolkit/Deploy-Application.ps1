<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2023 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType

The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode

Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru

Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode

Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging

Disables logging to file for the script. Default is: $false.

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
- 70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    }
    Catch {
    }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## TODO Variables: Application
    [String]$appVendor = ''
    [String]$appName = ''
    [String]$appVersion = ''
    [String]$appArch = ''
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = 'XX/XX/20XX'
    [String]$appScriptAuthor = '<author name>'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = ''
    [String]$installTitle = ''

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.9.3'
    [String]$deployAppScriptDate = '02/05/2023'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'

        ## TODO Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
        Show-InstallationWelcome -CloseApps 'iexplore' -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt
        ## EXAMPLES ##
        ## $CheckAGENTFile1 = "$envProgramFiles\iManage\AgentServices\iManageStayExec.exe"
        ## $CheckAGENTFileVer1 = ""
        ## $AgentVersion_we_require = [version]"10.9.0.23"		

        ## if(test-path $CheckAGENTFile1) { 
            ##Show-InstallationProgress -StatusMessage "Removing Previous Version(s) of iManage Agent Services..."
            ##$CheckAGENTFileVer1 = GET-FILEVERSION -File $CheckAGENTFile1
            ##$AGENTVersion_we_require = [version]"10.8.0.4"
            ##if(($CheckAGENTFileVer1) -eq $AGENTVersion_we_require) {
            ##    Execute-MSI -Action Uninstall -Path '{DBF323BA-D23F-4994-A43A-88F4C65F4369}'
            ##}
            ##$AGENTVersion_we_require = [version]"10.9.0.23"
            ##if(($CheckAGENTFileVer1) -eq $AGENTVersion_we_require) {
            ##    Execute-Process -Path "$dirFiles\Work10Files\iManageAgentServices.exe" -Parameters "/uninstall /quiet" -WindowStyle Hidden -continueonerror $true -IgnoreExitCodes *
            ##}
        ##}
        ##$install_params = "/uninstall /passive /norestart"
        ##$install_params = "/uninstall /quiet /norestart"
        ##$file1 = 'iManageWorkDesktopForWindows.exe'
        ##Get-ChildItem –Path 'C:\ProgramData\Package Cache' -Recurse -Filter $file1 |

        ##Foreach-Object {
        ##    #Do something with $_.FullName
        ##    Write-Host $_.FullName
        ##    Start-Process -Wait -FilePath $_.FullName -ArgumentList $install_params -RedirectStandardError "c:\temp\example-output.txt" 
        ##}

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Installation tasks here>


        ##*===============================================
        ##* TODO INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## EXAMPLE COPY PRE-INSTALL FILES FOR CONFIG PRIOR TO MAIN INSTALL
        ##$ProfilePaths = Get-UserProfiles | Select-Object -ExpandProperty 'ProfilePath'
        ##ForEach ($Profile in $ProfilePaths) {
        ##    Copy-File -Path "$dirfiles\Work10Files\Customs\iManWork.config" -Destination "$Profile\APPDATA\Roaming\IMANAGE\WORK\CONFIGS\USER\"
        ##    Copy-File -Path "$dirfiles\Work10Files\Customs\iManWork.config" -Destination "$Profile\APPDATA\Roaming\IMANAGE\WORK\CONFIGS\"
        ##    Copy-File -Path "$dirfiles\Work10Files\Customs\imEMM.config" -Destination "$Profile\APPDATA\Roaming\IMANAGE\WORK\CONFIGS\"
        ##    Copy-File -Path "$dirfiles\Work10Files\Customs\imWorkOptions.xml" -Destination "$Profile\APPDATA\Roaming\IMANAGE\WORK\CONFIGS\USER\"
        ##}

        ## EXAMPLE MESSAGE USER 
        ##Show-InstallationProgress -StatusMessage "Installing iManage Agent Services $Agent_Ver..."
        ## TODO  Show-InstallationWelcome -CloseApps 'WESCLIENT=iManage Search,THINCLIENT=iManage Desksite,OUTLOOK=MS Outlook,WINWORD=MS Word,EXCEL=MS Excel,POWERPNT=MS PowerPoint,ADOBERD32=Adobe Reader,ACRORD32=Adobe Reader,ACROBAT=Adobe Acrobat' -FORCECLOSEAPPSCOUNTDOWN 3600 -PersistPrompt -MinimizeWindows $false
        ## EXAMPLE RUN INSTALL .EXE
        ##Execute-Process -Path "$dirFiles\Work10Files\iManageAgentServices.exe" -Parameters "/silent /AUTO_UPDATE=0" -WindowStyle Hidden -continueonerror $true -IgnoreExitCodes *
        ##Start-Process -Wait -filepath "$envSystem32Directory\taskkill.exe" -ArgumentList "/F /IM iManageStayExec.exe"  -WindowStyle Hidden
        ##Stop-ServiceAndDependencies -Name 'iwAgentWebService'
        ##Stop-ServiceAndDependencies -Name 'imUpdateManagerService'




        ## Handle Zero-Config MSI Installations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) {
                $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ }
            }
        }

        ## <Perform Installation tasks here>


        ##*===============================================
        ## TODO POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>
        ## EXAMPLE POST CONFIG FILES
		# COPY CONFIG FILES
		#--------------------------------------------------------------------------------------------
		#        
		# C:\ProgramData\iManage\AgentServices\CentralizedConfigs
		## ***To copy and overwrite a file***
		#$CheckDIR1 = "$envProgramData\iManage\AgentServices\CentralizedConfigs"
		#$CheckFile1 = "$CheckDir1\UpdateManagerConfiguration.xml"
		#if(!(test-path $CheckDIR1))
		#{ 
		#	Write-Host "Creating $CheckDir1"
		#	new-item $CheckDir1 -itemtype directory
		#}
		#Copy-File -Path "$dirfiles\Work10Files\Customs\UpdateManagerConfiguration.xml" -Destination "$checkFile1" 
		## %DESTFOLDER%\UpdateManagerConfiguration.xml
		##C:\ProgramData\iManage\AgentServices\Configs
		#$CheckDIR1 = "$envProgramData\iManage\AgentServices\Configs"
		#$CheckFile1 = "$CheckDir1\UpdateManagerConfiguration.xml"
		#if(!(test-path $CheckDIR1))
		#{ 
		#	Write-Host "Creating $CheckDir1"
		#	new-item $CheckDir1 -itemtype directory
		#}
		#Copy-File -Path "$dirfiles\Work10Files\Customs\UpdateManagerConfiguration.xml" -Destination "$checkFile1" 
		#
        ## EXAMPLE POST CONFIG REG FILES
		# APPLY MACHINE REGISTRY FILES HKCR / HKLM 
		## HKCR_NRL_SHELL_OPEN_EDIT.reg
		#$installDir1 = "$dirfiles\Work10Files\Customs"
		#Execute-Process -FilePath "reg.exe" -Parameters "IMPORT `"$installDir1\HKCR_NRL_SHELL_OPEN_EDIT.reg`"" -PassThru -ContinueOnError $true

        ## EXAMPLE POST CONFIG REG FILES
        # APPLY USER REGISTRY FILES HKCU AND ALL USER HIVES IN HKEY_USERS
		## REGISTRY - USER MODIFICATIONS
		## ***To set an HKCU key for all users including default profile***
    	#Show-InstallationProgress -StatusMessage "Applying User Customisations..."
		#[scriptblock]$HKCURegistrySettings = {
			#Set-RegistryKey -Key 'HKCU\SOFTWARE\iManage\Work\10.0\ADFS' -Name 'TokenCaching' -Value 1 -Type DWord -SID $UserProfile.SID -ContinueOnError:$True
			#Remove-RegistryKey -Key 'HKCU:SOFTWARE\iManage\Work\10.0\EMM\Preferences' -Name 'PreviewPlace'
			#Set-RegistryKey -Key 'HKCU\SOFTWARE\Legal Tech\DMS Footer' -Name 'DatabaseText' 'Comcast'-Type String -SID $UserProfile.SID
			#Remove-RegistryKey -Key 'HKCU:SOFTWARE\iManage\Work\10.0\Client\Login' -Name 'EnableChromiumBrowser'
		#}
		#Invoke-HKCURegistrySettingsForAllUsers -RegistrySettings $HKCURegistrySettings

		## EXAMPLE COPY A POST CONFIG FILE
		## Copy a file to the correct relative location for all user accounts
		#$ProfilePaths = Get-UserProfiles | Select-Object -ExpandProperty 'ProfilePath'
		#ForEach ($Profile in $ProfilePaths) {
			#Copy-File -Path "$dirfiles\Work10Files\Customs\iManWork.config" -Destination "$Profile\APPDATA\Roaming\IMANAGE\WORK\CONFIGS\USER\"
		#}
        ## EXAMPLE KILL A PROCESS
		#Start-Process -Wait -filepath "$envSystem32Directory\taskkill.exe" -ArgumentList "/F /IM iwagent.exe"  -WindowStyle Hidden


        ## Display a message at the end of the install
        ## EXAMPLE VERIFY PRODUCT HAS INSTALLED
		#$CheckCLIENTFile1 = "$envProgramFiles\iManage\Work10\109.1.14\iwlnrl.exe"
		#$CheckCLIENTFileVer1 = ""
		#$ClientVersion_we_require = [version]"10.9.1.14"
		#$CheckClientResult = ""
		##*===============================================
		## TODO CHECK FOR WORK 10 DESKTOP
		##*===============================================
		#if(test-path $CheckCLIENTFile1) { 
		#	$CheckCLIENTFileVer1 = GET-FILEVERSION -File $CheckCLIENTFile1
        #   $CLIENTInstall = $TRUE
        #}
		#ELSE {
		#	$CLIENTInstall = $FALSE
		#}
		#Write-Log -Source $deployAppScriptFriendlyName -Message "CLIENT= $CHECKInstall"

        #If ($AGENTINSTALL -And $CLIENTINSTALL) {
        #    $APPCHECKER = "VERIFIED"
        #}

        ##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## TODO EXAMPLE WRITE INSTALLATION TATTOO IN REGISTRY
        
		#If ($APPCHECK = "VERIFIED") { 
		#    $CheckForReg = 'HKLM:SOFTWARE\Comcast Legal\DMS'
		#    if (test-path $CheckForReg) { 
		#	    Write-Host "Found $CheckForReg"
		#	    Remove-RegistryKey -Key 'HKLM:SOFTWARE\Comcast Legal\DMS' -recurse -ErrorAction SilentlyContinue
    	#	}
    	#	$CheckForReg = 'HKLM:SOFTWARE\Comcast Legal\LegalTechOpsDMSRemoval'
		 #   if (test-path $CheckForReg) { 
		#	    Write-Host "Found $CheckForReg"
		#	    Remove-RegistryKey -Key 'HKLM:SOFTWARE\Comcast Legal\LegalTechOpsDMSRemoval' -recurse -ErrorAction SilentlyContinue
    	#	}
        #   [datetime]$InstallDateTime = Get-Date
        #  Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Comcast Legal\DMS' -Name 'APP_NAME' -Value $appname -Type String
        #   Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Comcast Legal\DMS' -Name 'INSTALL_TYPE' -Value $installTitle -Type String
        #   Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Comcast Legal\DMS' -Name 'AGENT_VER' -Value $checkAgentFileVer1 -Type String
        #   Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Comcast Legal\DMS' -Name 'APP_VER' -Value $checkClientFileVer1 -Type String
        #    Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Comcast Legal\DMS' -Name 'INSTALLDATE' -Value $InstallDateTime -Type String
        #    Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Comcast Legal\DMS' -Name 'LOCATION' -Value "CLOUD" -Type String
        #    Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Comcast Legal\DMS' -Name 'PACKAGE_VERSION' -Value $appRevision -Type String
        #    Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Comcast Legal\DMS' -Name 'WORK_VER' -Value $WORK_VER -Type String
        #    Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Comcast Legal\DMS' -Name 'INSTALL_MODE' -Value $DeployMode -Type String
		#	Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Comcast Legal\DMS' -Name 'WORKSHARE_DETECTED' -Value $WorkshareVersionCheck -Type String
        #    
		#	#Show-InstallationPrompt -Message 'Installation has been verified...' -ButtonRightText 'OK' -Icon Information -NoWait 
		#	Show-InstallationProgress -StatusMessage "Installation has completed Successfully ..."
		#	Start-Sleep -Seconds 2
		#	[int32]$mainExitCode = 0
		#}
		#ELSE { 
		#	Show-InstallationPrompt -Message 'Some items failed to install - please report to Legal Tech Operations.' -ButtonRightText 'OK' -Icon Information -NoWait 
		#	[int32]$mainExitCode = 60001
		#}        
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## TODO Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Uninstallation tasks here>
		##*===============================================
		## TODO REMOVE / UNINSTALL FOR IMANAGE WORK AGENT
		##*===============================================
        ## EXAMPLES ##
        ## $CheckAGENTFile1 = "$envProgramFiles\iManage\AgentServices\iManageStayExec.exe"
        ## $CheckAGENTFileVer1 = ""
        ## $AgentVersion_we_require = [version]"10.9.0.23"		

        ## if(test-path $CheckAGENTFile1) { 
            ##Show-InstallationProgress -StatusMessage "Removing Previous Version(s) of iManage Agent Services..."
            ##$CheckAGENTFileVer1 = GET-FILEVERSION -File $CheckAGENTFile1
            ##$AGENTVersion_we_require = [version]"10.8.0.4"
            ##if(($CheckAGENTFileVer1) -eq $AGENTVersion_we_require) {
            ##    Execute-MSI -Action Uninstall -Path '{DBF323BA-D23F-4994-A43A-88F4C65F4369}'
            ##}
            ##$AGENTVersion_we_require = [version]"10.9.0.23"
            ##if(($CheckAGENTFileVer1) -eq $AGENTVersion_we_require) {
            ##    Execute-Process -Path "$dirFiles\Work10Files\iManageAgentServices.exe" -Parameters "/uninstall /quiet" -WindowStyle Hidden -continueonerror $true -IgnoreExitCodes *
            ##}
        ##}
        ##$install_params = "/uninstall /passive /norestart"
        ##$install_params = "/uninstall /quiet /norestart"
        ##$file1 = 'iManageWorkDesktopForWindows.exe'
        ##Get-ChildItem –Path 'C:\ProgramData\Package Cache' -Recurse -Filter $file1 |

        ##Foreach-Object {
        ##    #Do something with $_.FullName
        ##    Write-Host $_.FullName
        ##    Start-Process -Wait -FilePath $_.FullName -ArgumentList $install_params -RedirectStandardError "c:\temp\example-output.txt" 
        ##}

        #Show-InstallationProgress -StatusMessage "Verifying uninstallation..."

   		$APPCHECKER = "NULL"
		$CheckCLIENTFile1 = "$envProgramFiles\iManage\Work10\109.1.14\iwlnrl.exe"
		$CheckCLIENTFileVer1 = ""
		$ClientVersion_we_require = [version]"10.9.1.14"
		$ClientInstall = $TRUE
		$CheckClientResult = ""

		##*===============================================
		##* CHECK FOR WORK 10 DESKTOP
		##*===============================================
		#if(test-path $CheckCLIENTFile1) { 
		#	$CheckCLIENTFileVer1 = GET-FILEVERSION -File $CheckCLIENTFile1
        #    $CLIENTInstall = $TRUE
        #}
		#ELSE {
		#	$CLIENTInstall = $FALSE
		#}	
		#Write-Log -Source $deployAppScriptFriendlyName -Message "CLIENT= $CHECKInstall"

        #If (-not(test-path $CheckCLIENTFile1)) {
        #    $APPCHECKER = "UNINSTALLED"
        #}



        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        ## Handle Zero-Config MSI Uninstallations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }

        ## <Perform Uninstallation tasks here>


        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'
        ## TODO REMOVE APP TATTOO #If ($APPCHECK = "UNINSTALLED") { 
		#$CheckForReg = 'HKLM:SOFTWARE\Comcast Legal\DMS'
		#if (test-path $CheckForReg) { 
		#	Write-Host "Found $CheckForReg"
		#	Remove-RegistryKey -Key 'HKLM:SOFTWARE\Comcast Legal\DMS' -recurse -ErrorAction SilentlyContinue
        #    Show-InstallationProgress -StatusMessage "Uninstall Successful..."
        #    Start-Sleep -Seconds 1
    	#}
        ## <Perform Post-Uninstallation tasks here>


    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Repair tasks here>

        ##*===============================================
        ## TODO REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        ## Handle Zero-Config MSI Repairs
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }
        ## <Perform Repair tasks here>

        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'

        ## <Perform Post-Repair tasks here>


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
