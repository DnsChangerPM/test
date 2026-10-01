#define MyAppName "Advanced Timer"
#define MyAppExeName "advanced_timer.exe"

#ifndef MyAppVersion
#define MyAppVersion "1.0.0"
#endif

[Setup]
AppId={{8C1F1C6B-5A6A-4D0F-9F0C-7C5F9B3A2D1E}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Your Company
AppPublisherURL=https://example.com
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=AdvancedTimer-Setup-{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
SetupLogging=yes

[Languages]

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
procedure RemoveDirectoryIfExists(const Path: String);
begin
  if DirExists(Path) then
    DelTree(Path, True, True, True);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    RemoveDirectoryIfExists(ExpandConstant('{userappdata}\AdvancedTimer'));
    RemoveDirectoryIfExists(ExpandConstant('{userappdata}\advanced_timer'));
    RemoveDirectoryIfExists(ExpandConstant('{localappdata}\AdvancedTimer'));
    RemoveDirectoryIfExists(ExpandConstant('{localappdata}\advanced_timer'));
  end;
end;
