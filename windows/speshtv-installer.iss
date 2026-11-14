#ifndef ReleaseDir
  #error ReleaseDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef OutputName
  #define OutputName "SpeshTV-Windows-x64-Setup"
#endif
#ifndef NumericVersion
  #define NumericVersion AppVersion
#endif

[Setup]
AppId={{F0D080B5-D412-4C78-AB46-6F30929FD154}
AppName=SpeshTV
AppVersion={#AppVersion}
VersionInfoVersion={#NumericVersion}
DefaultDirName={localappdata}\Programs\SpeshTV
DefaultGroupName=SpeshTV
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=runner\resources\speshtv.ico
UninstallDisplayIcon={app}\SpeshTV.exe
LicenseFile={#ReleaseDir}\LICENSE
CloseApplications=yes
RestartApplications=no

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\SpeshTV"; Filename: "{app}\SpeshTV.exe"
Name: "{userdesktop}\SpeshTV"; Filename: "{app}\SpeshTV.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Run]
Filename: "{app}\SpeshTV.exe"; Description: "Open SpeshTV"; Flags: nowait postinstall skipifsilent
