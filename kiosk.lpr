program kiosk;

{$mode objfpc}{$H+}

{$IFDEF WIN32}
  {$SetPEFlags $20}
{$ENDIF}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  uCEFApplication,
  Interfaces, // this includes the LCL widgetset
  Forms, main
  { you can add units after this };

{$R *.res}

begin
 GlobalCEFApp := TCefApplication.Create;

 GlobalCEFApp.KioskPrinting:=True;
 GlobalCEFApp.IgnoreCertificateErrors:=true;

 GlobalCEFApp.FrameworkDirPath     :='bin';
 GlobalCEFApp.ResourcesDirPath     :='bin';
 GlobalCEFApp.LocalesDirPath       :='bin\locales';
 GlobalCEFApp.EnableGPU            :=True;      // Enable hardware acceleration
 GlobalCEFApp.cache                :='';
 GlobalCEFApp.UserDataPath         :='User';
 GlobalCEFApp.Locale               :='ru';

 RequireDerivedFormResource:=True;

 if GlobalCEFApp.StartMainProcess then
 begin
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
 end;

 GlobalCEFApp.Free;
 GlobalCEFApp := nil;
end.

