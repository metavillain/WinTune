# WinTune tweak catalog.
# Fields: Id, Name, Category, Risk (low|med|high), Desc, plus any of:
#   Reg   = @( @{ P='HKLM:\path'; T='DWord'; V=@{ ValueName = data } } )   (name '(default)' = key default value)
#   Svc   = @( @{ N='ServiceName'; Set='disabled|manual'; Default='auto|delayed|manual|disabled' } )
#   Tasks = @( '\Task\Path\TaskName' )
#   Appx  = @( 'Package.Name*' )   Store = @( 'StoreProductId' )  (used to reinstall)
#   Apply / Revert / Test = PowerShell command strings (Revert missing = not reversible)
#   MinBuild / MaxBuild = Windows build range this tweak applies to
# Restoring a tweak uses the value recorded when WinTune applied it; if none was recorded
# (tweak was already in place) it falls back to the Windows default (value deleted / Default).
@{
Tweaks = @(

# ---------------- Privacy ----------------
@{ Id='privacy.telemetry'; Name='Minimise telemetry'; Category='Privacy'; Risk='low'
   Desc='Sets diagnostic data to the minimum your edition allows (fully off on Enterprise/Education) and disables the DiagTrack / dmwappushservice telemetry services.'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; T='DWord'; V=@{ AllowTelemetry=0; DoNotShowFeedbackNotifications=1 } } )
   Svc=@( @{ N='DiagTrack'; Set='disabled'; Default='auto' }, @{ N='dmwappushservice'; Set='disabled'; Default='manual' } ) },

@{ Id='privacy.tasks'; Name='Disable telemetry scheduled tasks'; Category='Privacy'; Risk='low'
   Desc='Disables Compatibility Appraiser, CEIP, Windows Error Reporting queue and feedback (Siuf) scheduled tasks.'
   Tasks=@( '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
            '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
            '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
            '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
            '\Microsoft\Windows\Feedback\Siuf\DmClient',
            '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
            '\Microsoft\Windows\Windows Error Reporting\QueueReporting' ) },

@{ Id='privacy.adid'; Name='Disable advertising ID & tailored experiences'; Category='Privacy'; Risk='low'
   Desc='Stops apps using your advertising ID, diagnostic-data-based tailored suggestions, and websites reading your language list.'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; T='DWord'; V=@{ Enabled=0 } },
          @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; T='DWord'; V=@{ TailoredExperiencesWithDiagnosticDataEnabled=0 } },
          @{ P='HKCU:\Control Panel\International\User Profile'; T='DWord'; V=@{ HttpAcceptLanguageOptOut=1 } } ) },

@{ Id='privacy.activity'; Name='Disable activity history'; Category='Privacy'; Risk='low'
   Desc='Turns off Timeline-style activity feed collection and upload.'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; T='DWord'; V=@{ EnableActivityFeed=0; PublishUserActivities=0; UploadUserActivities=0 } } ) },

@{ Id='privacy.feedback'; Name='Stop feedback prompts'; Category='Privacy'; Risk='low'
   Desc='Windows will no longer ask for feedback.'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Siuf\Rules'; T='DWord'; V=@{ NumberOfSIUFInPeriod=0 } } ) },

@{ Id='privacy.typing'; Name='Disable typing/inking data collection'; Category='Privacy'; Risk='low'
   Desc='Stops Windows collecting typing and handwriting samples for personalisation.'
   Reg=@( @{ P='HKCU:\Software\Microsoft\InputPersonalization'; T='DWord'; V=@{ RestrictImplicitTextCollection=1; RestrictImplicitInkCollection=1 } },
          @{ P='HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore'; T='DWord'; V=@{ HarvestContacts=0 } },
          @{ P='HKCU:\Software\Microsoft\Personalization\Settings'; T='DWord'; V=@{ AcceptedPrivacyPolicy=0 } } ) },

@{ Id='privacy.location'; Name='Disable location services (system-wide)'; Category='Privacy'; Risk='med'
   Desc='Turns location off for all users. Breaks maps, weather auto-location and Find My Device.'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'; T='DWord'; V=@{ DisableLocation=1 } } ) },

@{ Id='privacy.wer'; Name='Disable Windows Error Reporting'; Category='Privacy'; Risk='low'
   Desc='Crash reports are no longer sent to Microsoft.'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'; T='DWord'; V=@{ Disabled=1 } } ) },

@{ Id='privacy.clipboardsync'; Name='Disable cloud clipboard sync'; Category='Privacy'; Risk='low'
   Desc='Stops clipboard contents syncing to the cloud and your other devices. Local clipboard history (Win+V) still works.'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; T='DWord'; V=@{ AllowCrossDeviceClipboard=0 } } ) },

@{ Id='privacy.speech'; Name='Disable online speech recognition'; Category='Privacy'; Risk='low'
   Desc='Turns off cloud speech recognition so your voice is not sent to Microsoft. On-device typing still works.'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy'; T='DWord'; V=@{ HasAccepted=0 } },
          @{ P='HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization'; T='DWord'; V=@{ AllowInputPersonalization=0 } } ) },

@{ Id='privacy.finddevice'; Name='Disable Find My Device'; Category='Privacy'; Risk='low'
   Desc='Stops Windows periodically recording this device''s location for Find My Device.'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice'; T='DWord'; V=@{ AllowFindMyDevice=0 } } ) },

@{ Id='privacy.settingssync'; Name='Disable settings sync'; Category='Privacy'; Risk='low'
   Desc='Stops Windows syncing your settings and preferences across devices through your Microsoft account.'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'; T='DWord'; V=@{ DisableSettingSync=2; DisableSettingSyncUserOverride=1 } } ) },

# ---------------- Ads & suggestions ----------------
@{ Id='ads.suggestions'; Name='Remove ads & suggestions in Start, lock screen and Settings'; Category='Ads & Suggestions'; Risk='low'
   Desc='Disables sponsored tiles, Start recommendations, lock-screen tips/spotlight ads, Settings suggestions and silent auto-install of promoted apps.'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; T='DWord'; V=@{
            ContentDeliveryAllowed=0; FeatureManagementEnabled=0; OemPreInstalledAppsEnabled=0; PreInstalledAppsEnabled=0
            PreInstalledAppsEverEnabled=0; SilentInstalledAppsEnabled=0; SoftLandingEnabled=0; SystemPaneSuggestionsEnabled=0
            RotatingLockScreenOverlayEnabled=0; 'SubscribedContent-310093Enabled'=0; 'SubscribedContent-338387Enabled'=0
            'SubscribedContent-338388Enabled'=0; 'SubscribedContent-338389Enabled'=0; 'SubscribedContent-338393Enabled'=0
            'SubscribedContent-353694Enabled'=0; 'SubscribedContent-353696Enabled'=0; 'SubscribedContent-353698Enabled'=0
            'SubscribedContent-88000326Enabled'=0 } },
          @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; T='DWord'; V=@{ Start_IrisRecommendations=0; Start_AccountNotifications=0; ShowSyncProviderNotifications=0 } },
          @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; T='DWord'; V=@{ ScoobeSystemSettingEnabled=0 } } ) },

@{ Id='ads.consumer'; Name='Disable Windows consumer features'; Category='Ads & Suggestions'; Risk='low'
   Desc='Policy that stops Windows installing promoted third-party apps on sign-in (fully enforced on Enterprise/Education; harmless elsewhere).'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; T='DWord'; V=@{ DisableWindowsConsumerFeatures=1; DisableConsumerAccountStateContent=1; DisableCloudOptimizedContent=1 } } ) },

@{ Id='ads.bingsearch'; Name='Disable Bing / web results in Start search'; Category='Ads & Suggestions'; Risk='low'
   Desc='Start search only searches your PC and apps.'
   Reg=@( @{ P='HKCU:\Software\Policies\Microsoft\Windows\Explorer'; T='DWord'; V=@{ DisableSearchBoxSuggestions=1 } } ) },

# ---------------- AI ----------------
@{ Id='ai.copilot'; Name='Disable Windows Copilot'; Category='AI'; Risk='low'
   Desc='Turns off the Copilot integration via policy.'
   Reg=@( @{ P='HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'; T='DWord'; V=@{ TurnOffWindowsCopilot=1 } },
          @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; T='DWord'; V=@{ TurnOffWindowsCopilot=1 } } ) },

@{ Id='ai.recall'; Name='Disable Recall / AI data analysis'; Category='AI'; Risk='low'; MinBuild=26100
   Desc='Stops Recall from saving snapshots of your screen (24H2 and later).'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; T='DWord'; V=@{ DisableAIDataAnalysis=1 } },
          @{ P='HKCU:\Software\Policies\Microsoft\Windows\WindowsAI'; T='DWord'; V=@{ DisableAIDataAnalysis=1 } } ) },

# ---------------- Notifications ---------------- (toggles - not in any template; apply to silence, restore to re-enable)
@{ Id='notif.defender'; Name='Silence non-critical Windows Security (Defender) notifications'; Category='Notifications'; Risk='low'
   Desc='Stops the periodic "no action needed" summaries, scan results and recommendation nags from Windows Security. Real threat alerts still come through. Restore brings the summaries back.'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications'; T='DWord'; V=@{ DisableEnhancedNotifications=1 } } ) },

@{ Id='notif.defenderall'; Name='Silence ALL Windows Security (Defender) notifications'; Category='Notifications'; Risk='med'
   Desc='Turns off every Windows Security notification, including actual threat and firewall alerts. Only use this if you watch security another way. Restore turns them back on.'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications'; T='DWord'; V=@{ DisableNotifications=1; DisableEnhancedNotifications=1 } } ) },

@{ Id='notif.updates'; Name='Silence Windows Update restart nags'; Category='Notifications'; Risk='low'
   Desc='Stops the "restart to finish updating" auto-restart reminder notifications. Updates still install; you just are not nagged. Restore re-enables the reminders.'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; T='DWord'; V=@{ SetAutoRestartNotificationDisable=1; AutoRestartNotificationSchedule=0 } } ) },

@{ Id='notif.lockscreen'; Name='No notifications on the lock screen'; Category='Notifications'; Risk='low'
   Desc='Stops app notifications (messages, mail, etc.) from showing on the lock screen. They still appear once you sign in. Restore re-enables them.'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; T='DWord'; V=@{ DisableLockScreenAppNotifications=1 } } ) },

@{ Id='notif.tips'; Name='No tips, tricks and suggestion notifications'; Category='Notifications'; Risk='low'
   Desc='Turns off the "get tips, tricks and suggestions as you use Windows" notifications and the Settings-app suggestions.'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; T='DWord'; V=@{ 'SubscribedContent-338389Enabled'=0 } },
          @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; T='DWord'; V=@{ ScoobeSystemSettingEnabled=0 } } ) },

@{ Id='notif.alltoasts'; Name='Turn off ALL notification banners (toasts)'; Category='Notifications'; Risk='med'
   Desc='Master off switch: no app shows pop-up notification banners for your account (Teams, mail, calendar and everything else go silent). They still collect in the notification centre. Restore turns banners back on.'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications'; T='DWord'; V=@{ ToastEnabled=0 } } ) },

# ---------------- Taskbar & shell ----------------
@{ Id='ui.widgets'; Name='Hide Widgets button'; Category='Taskbar & Shell'; Risk='low'
   Desc='Removes the Widgets (news/weather) button from the taskbar. This is the per-user taskbar toggle, which Windows reliably honours; the machine-wide Dsh policy is ignored on recent builds. To also remove the Widgets engine itself, use "Remove Widgets app".'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; T='DWord'; V=@{ TaskbarDa=0 } } ) },

@{ Id='apps.widgets'; Name='Remove Widgets app'; Category='Remove Apps'; Risk='med'
   Desc='Uninstalls the Widgets engine (Windows Web Experience Pack), which removes Widgets entirely rather than just hiding the button. Restore reinstalls it from the Microsoft Store.'
   Appx=@('MicrosoftWindows.Client.WebExperience'); Store=@('9MSSGKG348SP') },

@{ Id='ui.chat'; Name='Remove Teams Chat icon from taskbar'; Category='Taskbar & Shell'; Risk='low'; After='explorer'
   Desc='Hides the consumer Chat/Teams taskbar button.'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat'; T='DWord'; V=@{ ChatIcon=3 } } ) },

@{ Id='ui.searchbox'; Name='Hide taskbar search box'; Category='Taskbar & Shell'; Risk='low'; After='explorer'
   Desc='Removes the search box/button from the taskbar (Win+S still works).'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; T='DWord'; V=@{ SearchboxTaskbarMode=0 } } ) },

@{ Id='ui.taskview'; Name='Hide Task View button'; Category='Taskbar & Shell'; Risk='low'; After='explorer'
   Desc='Removes the Task View button from the taskbar (Win+Tab still works).'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; T='DWord'; V=@{ ShowTaskViewButton=0 } } ) },

@{ Id='ui.classicmenu'; Name='Classic right-click menu'; Category='Taskbar & Shell'; Risk='low'
   Desc='Brings back the full Windows 10 context menu without "Show more options". Restart Explorer or sign out to see it.'
   Reg=@( @{ P='HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'; T='String'; V=@{ '(default)'='' } } ) },

# ---------------- Explorer ----------------
@{ Id='explorer.ext'; Name='Show file extensions'; Category='Explorer'; Risk='low'; After='explorer'
   Desc='Always show file extensions (helps spot disguised files).'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; T='DWord'; V=@{ HideFileExt=0 } } ) },

@{ Id='explorer.hidden'; Name='Show hidden files'; Category='Explorer'; Risk='low'; After='explorer'
   Desc='Shows hidden files and folders.'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; T='DWord'; V=@{ Hidden=1 } } ) },

@{ Id='explorer.thispc'; Name='Open Explorer to This PC'; Category='Explorer'; Risk='low'; After='explorer'
   Desc='File Explorer opens to This PC instead of Home/Quick access.'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; T='DWord'; V=@{ LaunchTo=1 } } ) },

@{ Id='explorer.gallery'; Name='Remove Gallery from navigation pane'; Category='Explorer'; Risk='low'; After='explorer'
   Desc='Removes the Gallery entry from the File Explorer left-hand pane.'
   Reg=@( @{ P='HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'; T='DWord'; V=@{ 'System.IsPinnedToNameSpaceTree'=0 } } ) },

@{ Id='explorer.onedrivenav'; Name='Remove OneDrive from navigation pane'; Category='Explorer'; Risk='low'; After='explorer'
   Desc='Removes the OneDrive entry from the File Explorer left-hand pane. Does not uninstall OneDrive.'
   Reg=@( @{ P='HKCU:\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}'; T='DWord'; V=@{ 'System.IsPinnedToNameSpaceTree'=0 } } ) },

@{ Id='explorer.endtask'; Name='Add "End Task" to taskbar right-click'; Category='Explorer'; Risk='low'
   Desc='Adds an End Task item to the right-click menu of taskbar apps, to force-close a hung program.'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'; T='DWord'; V=@{ TaskbarEndTask=1 } } ) },

@{ Id='explorer.trayicons'; Name='Show all system tray icons'; Category='Explorer'; Risk='low'; After='explorer'
   Desc='Shows every notification-area icon instead of tucking them into the overflow flyout.'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'; T='DWord'; V=@{ EnableAutoTray=0 } } ) },

# ---------------- Performance ----------------
@{ Id='perf.gamedvr'; Name='Disable Game DVR / background recording'; Category='Performance'; Risk='low'
   Desc='Turns off Xbox Game Bar background capture, which costs FPS and CPU.'
   Reg=@( @{ P='HKCU:\System\GameConfigStore'; T='DWord'; V=@{ GameDVR_Enabled=0 } },
          @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; T='DWord'; V=@{ AllowGameDVR=0 } } ) },

@{ Id='perf.startupdelay'; Name='Remove startup app delay'; Category='Performance'; Risk='low'
   Desc='Desktop startup apps launch immediately instead of after a built-in delay.'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'; T='DWord'; V=@{ StartupDelayInMSec=0 } } ) },

@{ Id='perf.dodownload'; Name='Disable peer-to-peer update sharing'; Category='Performance'; Risk='low'
   Desc='Delivery Optimization downloads from Microsoft only; your PC does not upload updates to others.'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; T='DWord'; V=@{ DODownloadMode=0 } } ) },

@{ Id='perf.hibernate'; Name='Disable hibernation & Fast Startup'; Category='Performance'; Risk='med'
   Desc='Deletes hiberfil.sys (frees several GB). You lose hibernate and Fast Startup.'
   Apply='powercfg /h off'; Revert='powercfg /h on'
   Test='(Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Power -ErrorAction Stop).HibernateEnabled -eq 0' },

@{ Id='perf.services'; Name='Disable rarely used services'; Category='Performance'; Risk='med'
   Desc='Sets Fax, Retail Demo, Downloaded Maps Manager and Windows Media Player Network Sharing to Disabled.'
   Svc=@( @{ N='Fax'; Set='disabled'; Default='manual' }, @{ N='RetailDemo'; Set='disabled'; Default='manual' },
          @{ N='MapsBroker'; Set='disabled'; Default='delayed' }, @{ N='WMPNetworkSvc'; Set='disabled'; Default='manual' } ) },

@{ Id='perf.visualfx'; Name='Optimise visual effects for performance'; Category='Performance'; Risk='low'; After='signout'
   Desc='Switches Windows to the "adjust for best performance" style: turns off most window and taskbar animations. Font smoothing is kept. Full effect after sign-out.'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; T='DWord'; V=@{ VisualFXSetting=2 } },
          @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; T='DWord'; V=@{ TaskbarAnimations=0 } },
          @{ P='HKCU:\Control Panel\Desktop\WindowMetrics'; T='String'; V=@{ MinAnimate='0' } } ) },

@{ Id='perf.transparency'; Name='Disable transparency effects'; Category='Performance'; Risk='low'
   Desc='Turns off the acrylic/blur transparency on the taskbar, Start and window borders, saving a little GPU work.'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; T='DWord'; V=@{ EnableTransparency=0 } } ) },

@{ Id='perf.powerplan'; Name='Use the High Performance power plan'; Category='Performance'; Risk='low'
   Desc='Sets the active power plan to High Performance. On a laptop this increases battery drain. Restore returns it to Balanced.'
   Apply='powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
   Revert='powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e'
   Test='[bool](& powercfg /getactivescheme | Select-String ''8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'')' },

@{ Id='perf.pointeraccel'; Name='Disable mouse pointer acceleration'; Category='Performance'; Risk='low'; After='signout'
   Desc='Turns off "enhance pointer precision" so the mouse moves 1:1 - preferred for gaming and precise work.'
   Reg=@( @{ P='HKCU:\Control Panel\Mouse'; T='String'; V=@{ MouseSpeed='0'; MouseThreshold1='0'; MouseThreshold2='0' } } ) },

@{ Id='perf.bgapps'; Name='Disable background apps'; Category='Performance'; Risk='low'
   Desc='Stops Store/UWP apps running in the background. Normal desktop programs are unaffected.'
   Reg=@( @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'; T='DWord'; V=@{ GlobalUserDisabled=1 } },
          @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; T='DWord'; V=@{ LetAppsRunInBackground=2 } } ) },

@{ Id='perf.sysmain'; Name='Disable SysMain (Superfetch)'; Category='Performance'; Risk='med'
   Desc='Stops the SysMain prefetch service. Frees RAM and reduces disk churn on SSDs; on an old hard disk it can slow app launches. Restore turns it back on.'
   Svc=@( @{ N='SysMain'; Set='disabled'; Default='auto' } ) },

@{ Id='perf.indexing'; Name='Disable Windows Search indexing'; Category='Performance'; Risk='med'
   Desc='Stops the search indexer service. Saves CPU and disk, but Start and Explorer searches become slower. Restore turns it back on.'
   Svc=@( @{ N='WSearch'; Set='disabled'; Default='delayed' } ) },

@{ Id='perf.reservedstorage'; Name='Turn off Reserved Storage'; Category='Performance'; Risk='med'
   Desc='Frees roughly 7 GB that Windows reserves for updates. Windows may refuse while an update is pending. Restore turns it back on.'
   Apply='DISM /Online /Set-ReservedStorageState /State:Disabled'
   Revert='DISM /Online /Set-ReservedStorageState /State:Enabled'
   Test='[bool](& DISM /Online /Get-ReservedStorageState | Select-String ''Disabled'')' },

# ---------------- Edge ----------------
@{ Id='edge.nag'; Name='Quiet Microsoft Edge'; Category='Edge'; Risk='low'
   Desc='Disables first-run, startup boost, background mode, shopping assistant, recommendations and sidebar via policy (Edge will say "managed by your organisation").'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Edge'; T='DWord'; V=@{
            HideFirstRunExperience=1; StartupBoostEnabled=0; BackgroundModeEnabled=0; EdgeShoppingAssistantEnabled=0
            ShowRecommendationsEnabled=0; PersonalizationReportingEnabled=0; SpotlightExperiencesAndRecommendationsEnabled=0
            HubsSidebarEnabled=0 } } ) },

# ---------------- Remove apps ----------------
@{ Id='apps.bing'; Name='Bing News, Weather, Finance, Sports'; Category='Remove Apps'; Risk='low'
   Desc='Microsoft news/weather apps.'
   Appx=@('Microsoft.BingNews','Microsoft.BingWeather','Microsoft.BingFinance','Microsoft.BingSports'); Store=@('9WZDNCRFHVFW','9WZDNCRFJ3Q2') },
@{ Id='apps.tips'; Name='Tips and Get Help'; Category='Remove Apps'; Risk='low'
   Desc='Microsoft Tips / Get Started and Get Help.'
   Appx=@('Microsoft.Getstarted','Microsoft.GetHelp'); Store=@('9WZDNCRDTBJJ','9PKDZBMV1H3T') },
@{ Id='apps.officehub'; Name='Microsoft 365 (Office) hub'; Category='Remove Apps'; Risk='low'
   Desc='The Microsoft 365 ad/launcher app (does not remove installed Office).'
   Appx=@('Microsoft.MicrosoftOfficeHub'); Store=@('9WZDNCRD29V9') },
@{ Id='apps.solitaire'; Name='Solitaire Collection'; Category='Remove Apps'; Risk='low'
   Desc='Microsoft Solitaire Collection.'
   Appx=@('Microsoft.MicrosoftSolitaireCollection'); Store=@('9WZDNCRFHWD2') },
@{ Id='apps.feedbackhub'; Name='Feedback Hub'; Category='Remove Apps'; Risk='low'
   Desc='Windows Feedback Hub.'
   Appx=@('Microsoft.WindowsFeedbackHub'); Store=@('9NBLGGH4R32N') },
@{ Id='apps.clipchamp'; Name='Clipchamp'; Category='Remove Apps'; Risk='low'
   Desc='Clipchamp video editor.'
   Appx=@('Clipchamp.Clipchamp'); Store=@('9P1J8S7CCWWT') },
@{ Id='apps.people'; Name='People'; Category='Remove Apps'; Risk='low'
   Desc='Microsoft People app.'
   Appx=@('Microsoft.People'); Store=@('9NBLGGH10PG8') },
@{ Id='apps.powerautomate'; Name='Power Automate Desktop'; Category='Remove Apps'; Risk='low'
   Desc='Power Automate Desktop.'
   Appx=@('Microsoft.PowerAutomateDesktop'); Store=@('9NFTCH6J7FHV') },
@{ Id='apps.mixedreality'; Name='Mixed Reality Portal'; Category='Remove Apps'; Risk='low'
   Desc='Windows Mixed Reality Portal.'
   Appx=@('Microsoft.MixedReality.Portal') },
@{ Id='apps.cortana'; Name='Cortana'; Category='Remove Apps'; Risk='low'
   Desc='Legacy Cortana app.'
   Appx=@('Microsoft.549981C3F5F10') },
@{ Id='apps.teams'; Name='Microsoft Teams (consumer)'; Category='Remove Apps'; Risk='low'
   Desc='Consumer Teams/Chat app preinstalled on Windows 11. Work/school Teams (desktop install) is unaffected.'
   Appx=@('MicrosoftTeams','MSTeams') },
@{ Id='apps.devhome'; Name='Dev Home'; Category='Remove Apps'; Risk='low'
   Desc='Dev Home dashboard.'
   Appx=@('Microsoft.Windows.DevHome') },
@{ Id='apps.sponsored'; Name='Sponsored / promo apps'; Category='Remove Apps'; Risk='med'
   Desc='Candy Crush, Disney+, Spotify, TikTok, Facebook, Instagram, Netflix, Twitter, Prime Video. Also removes them if YOU installed them from the Store - uncheck if so.'
   Appx=@('*CandyCrush*','Disney.37853FC22B2CE','SpotifyAB.SpotifyMusic','BytedancePte.Ltd.TikTok','Facebook.Facebook','Facebook.InstagramBeta','4DF9E0F8.Netflix','9E2F88E3.Twitter','AmazonVideo.PrimeVideo') },
@{ Id='apps.xbox'; Name='Xbox apps'; Category='Remove Apps'; Risk='med'
   Desc='Xbox app, Game Bar overlay and Xbox identity/TCUI helpers. Remove only if you do not use Xbox / Game Pass / Game Bar.'
   Appx=@('Microsoft.GamingApp','Microsoft.XboxGamingOverlay','Microsoft.XboxGameOverlay','Microsoft.XboxSpeechToTextOverlay','Microsoft.Xbox.TCUI','Microsoft.XboxIdentityProvider'); Store=@('9MV0B5HZVK9Z') },
@{ Id='apps.phonelink'; Name='Phone Link'; Category='Remove Apps'; Risk='med'
   Desc='Phone Link / Your Phone.'
   Appx=@('Microsoft.YourPhone'); Store=@('9NMPJ99VJBWV') },
@{ Id='apps.mailcal'; Name='Mail and Calendar'; Category='Remove Apps'; Risk='med'
   Desc='Legacy Mail & Calendar app.'
   Appx=@('microsoft.windowscommunicationsapps'); Store=@('9WZDNCRFHVQM') },
@{ Id='apps.newoutlook'; Name='New Outlook'; Category='Remove Apps'; Risk='med'
   Desc='The new Outlook for Windows app.'
   Appx=@('Microsoft.OutlookForWindows'); Store=@('9NRX63209R7B') },
@{ Id='apps.todo'; Name='Microsoft To Do'; Category='Remove Apps'; Risk='low'
   Desc='Microsoft To Do.'
   Appx=@('Microsoft.Todos'); Store=@('9NBLGGH5R558') },
@{ Id='apps.media'; Name='Groove Music and Movies & TV'; Category='Remove Apps'; Risk='med'
   Desc='Legacy Zune Music / Video apps.'
   Appx=@('Microsoft.ZuneMusic','Microsoft.ZuneVideo'); Store=@('9WZDNCRFJ3PT','9WZDNCRFJ3P2') },
@{ Id='apps.onedrive'; Name='Uninstall OneDrive'; Category='Remove Apps'; Risk='high'
   Desc='Uninstalls OneDrive. Files already synced stay in your OneDrive folder. Restore reinstalls it.'
   Apply='Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue; $p = if(Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"){"$env:SystemRoot\SysWOW64\OneDriveSetup.exe"}else{"$env:SystemRoot\System32\OneDriveSetup.exe"}; Start-Process $p -ArgumentList "/uninstall" -Wait'
   Revert='$p = if(Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"){"$env:SystemRoot\SysWOW64\OneDriveSetup.exe"}else{"$env:SystemRoot\System32\OneDriveSetup.exe"}; Start-Process $p -Wait'
   Test='-not ((Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe") -or (Test-Path "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe") -or (Test-Path "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe"))' },

@{ Id='apps.quickassist'; Name='Quick Assist'; Category='Remove Apps'; Risk='low'
   Desc='Microsoft Quick Assist remote-help tool.'
   Appx=@('MicrosoftCorporationII.QuickAssist'); Store=@('9P7BP5VNWKX5') },
@{ Id='apps.maps'; Name='Windows Maps'; Category='Remove Apps'; Risk='low'
   Desc='Windows Maps app.'
   Appx=@('Microsoft.WindowsMaps'); Store=@('9WZDNCRDTBVB') },
@{ Id='apps.soundrec'; Name='Sound Recorder'; Category='Remove Apps'; Risk='low'
   Desc='Windows Sound Recorder / Voice Recorder.'
   Appx=@('Microsoft.WindowsSoundRecorder'); Store=@('9WZDNCRFHWKN') },
@{ Id='apps.clock'; Name='Clock (Alarms & Clock)'; Category='Remove Apps'; Risk='low'
   Desc='Windows Clock app - alarms, timers and focus sessions.'
   Appx=@('Microsoft.WindowsAlarms'); Store=@('9WZDNCRFJ3PR') },
@{ Id='apps.copilot'; Name='Copilot app'; Category='Remove Apps'; Risk='low'
   Desc='The standalone Copilot app and its provider. (See also the AI category to disable Copilot by policy.)'
   Appx=@('Microsoft.Copilot','Microsoft.Windows.Ai.Copilot.Provider') },
@{ Id='apps.family'; Name='Family Safety'; Category='Remove Apps'; Risk='low'
   Desc='Microsoft Family Safety app.'
   Appx=@('MicrosoftCorporationII.MicrosoftFamily') },

# ---------------- Security (advanced) - OFF by default, not in any built-in template ----------------
# These lower your PC's defences. WinTune records the originals so Restore turns them back on,
# but do not apply them unless you understand the trade-off and have another plan for protection.
@{ Id='sec.smartscreen'; Name='Disable SmartScreen (all surfaces)'; Category='Security (advanced)'; Risk='high'
   Desc='Turns SmartScreen fully off: the "check apps and files" reputation filter (policy + live toggle), Microsoft Edge SmartScreen and its PUA / potentially-unwanted-app blocking, and the Store-app web content filter. SmartScreen is a built-in Windows component, so it can be switched off but not uninstalled. It warns you before running unrecognised or malicious downloads, so turning it off removes a real layer of protection - only do this if you run other protection. Restore turns every part back on.'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; T='DWord'; V=@{ EnableSmartScreen=0 } },
          @{ P='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'; T='String'; V=@{ SmartScreenEnabled='Off' } },
          @{ P='HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter'; T='DWord'; V=@{ EnabledV9=0 } },
          @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Edge'; T='DWord'; V=@{ SmartScreenEnabled=0; SmartScreenPuaEnabled=0 } },
          @{ P='HKCU:\Software\Microsoft\Windows\CurrentVersion\AppHost'; T='DWord'; V=@{ EnableWebContentEvaluation=0; PreventOverride=0 } } ) },

@{ Id='sec.defender'; Name='Disable Microsoft Defender Antivirus'; Category='Security (advanced)'; Risk='high'
   Desc='Disables Defender real-time protection and its scheduled scans. BEFORE applying, turn OFF Tamper Protection (Windows Security > Virus & threat protection > Manage settings) or Windows will immediately undo it. Defender cannot be uninstalled on Windows 11; this only switches it off. Your PC has no antivirus afterwards unless you install another. Restore turns Defender back on - then turn Tamper Protection back on yourself.'
   Reg=@( @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'; T='DWord'; V=@{ DisableAntiSpyware=1; DisableAntiVirus=1 } },
          @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; T='DWord'; V=@{ DisableRealtimeMonitoring=1; DisableBehaviorMonitoring=1; DisableOnAccessProtection=1; DisableScanOnRealtimeEnable=1 } } )
   Tasks=@( '\Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance',
            '\Microsoft\Windows\Windows Defender\Windows Defender Cleanup',
            '\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan',
            '\Microsoft\Windows\Windows Defender\Windows Defender Verification' )
   Apply='try { Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop; Write-Log "  real-time monitoring off" } catch { Write-Log "  Could not turn off real-time monitoring - Tamper Protection is still on. Disable it in Windows Security, then apply this again." "WARN" }'
   Revert='try { Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue } catch {}'
   Test='try { -not (Get-MpComputerStatus -ErrorAction Stop).RealTimeProtectionEnabled } catch { $false }' },

# ---------------- Cleanup ----------------
@{ Id='cleanup.temp'; Name='Clean temporary files'; Category='Cleanup'; Risk='low'
   Desc='Deletes files in your temp folder and C:\Windows\Temp. One-way: cannot be restored.'
   Apply='Get-ChildItem -Path $env:TEMP,"$env:WINDIR\Temp" -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue' }

)
}
