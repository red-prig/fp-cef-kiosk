unit main;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes,
  SysUtils,
  Forms,
  Controls,
  Graphics,
  Dialogs,
  ExtCtrls,
  INIFiles,

  uCEFConstants,
  uCEFChromiumWindow,
  uCEFTypes,
  uCEFInterfaces,
  uCEFWinControl;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    TimerClear: TTimer;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ClearCache;
    procedure UpdateTime;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    //
    procedure FOnBeforePopup(Sender                   : TObject;
                             const browser            : ICefBrowser;
                             const frame              : ICefFrame;
                             const targetUrl          : ustring;
                             const targetFrameName    : ustring;
                                   targetDisposition  : TCefWindowOpenDisposition;
                                   userGesture        : Boolean;
                             const popupFeatures      : TCefPopupFeatures;
                             var   windowInfo         : TCefWindowInfo;
                             var   client             : ICefClient;
                             var   settings           : TCefBrowserSettings;
                             var   extra_info         : ICefDictionaryValue;
                             var   noJavascriptAccess : Boolean;
                             var   Result             : Boolean);
    procedure FOnLoadingStateChange(Sender:TObject;const browser:ICefBrowser;isLoading,canGoBack,canGoForward:Boolean);
    procedure FOnLoadError(Sender:TObject;const browser:ICefBrowser;const frame:ICefFrame;errorCode:TCefErrorCode;const errorText,failedUrl:ustring);
    procedure FOnKeyEvent(Sender:TObject;const browser:ICefBrowser;const event:PCefKeyEvent;osEvent:TCefEventHandle;out Result:Boolean);
    procedure TimerClearTimer(Sender: TObject);
  private

  public
   ChromiumWindow:TChromiumWindow;
  end;

var
  frmMain: TfrmMain;

const
 BlankURL:UnicodeString='about:blank';

var
 main_url :RawByteString='';
 inject_js:RawByteString='';
 error_page:RawByteString='<html><body bgcolor="white"><br><br><center><h2>Error loading URL %s : %s.</h2></center></body></html>';

 up_time_default:DWORD=120000;
 up_time_long   :DWORD=480000;
 up_time_error  :DWORD= 60000;

implementation

{$R *.lfm}

procedure TfrmMain.FOnBeforePopup(Sender                   : TObject;
                                  const browser            : ICefBrowser;
                                  const frame              : ICefFrame;
                                  const targetUrl          : ustring;
                                  const targetFrameName    : ustring;
                                        targetDisposition  : TCefWindowOpenDisposition;
                                        userGesture        : Boolean;
                                  const popupFeatures      : TCefPopupFeatures;
                                  var   windowInfo         : TCefWindowInfo;
                                  var   client             : ICefClient;
                                  var   settings           : TCefBrowserSettings;
                                  var   extra_info         : ICefDictionaryValue;
                                  var   noJavascriptAccess : Boolean;
                                  var   Result             : Boolean);
begin
 Result := (targetDisposition in [WOD_NEW_FOREGROUND_TAB, WOD_NEW_BACKGROUND_TAB, WOD_NEW_POPUP, WOD_NEW_WINDOW]);
end;

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
 CanClose:=True;
 halt;
end;

procedure TfrmMain.ClearCache;
begin
 ChromiumWindow.ChromiumBrowser.FlushCookieStore(True);
 ChromiumWindow.ChromiumBrowser.ClearCache;
end;

procedure TFrmMain.UpdateTime;
begin
 TimerClear.Enabled :=False;
 TimerClear.Interval:=up_time_default;
 TimerClear.Enabled :=True;
end;

var
 first:boolean=true;

procedure TfrmMain.FOnLoadingStateChange(Sender:TObject;const browser:ICefBrowser;isLoading,canGoBack,canGoForward:Boolean);
begin
 if not isLoading then //load is complite
 begin
  if first then
  begin
   first:=false;
   if (BlankURL=browser.MainFrame.Url) then
   begin
    ChromiumWindow.LoadURL(UTF8Decode(main_url));
    Exit;
   end;
  end;
  UpdateTime;
  browser.MainFrame.ExecuteJavaScript(UTF8Decode(inject_js),BlankURL,0);
 end;
end;

procedure TfrmMain.FOnLoadError(Sender:TObject;const browser:ICefBrowser;const frame:ICefFrame;errorCode:TCefErrorCode;const errorText,failedUrl:ustring);
begin
 if (errorCode<>-3) then
 begin
  ChromiumWindow.ChromiumBrowser.LoadString(
   UTF8Decode(Format(error_page,[failedUrl,errorText]))
  ,frame);
 end;
 TimerClear.Interval:=up_time_error;
end;

procedure TfrmMain.FOnKeyEvent(Sender:TObject;const browser:ICefBrowser;const event:PCefKeyEvent;osEvent:TCefEventHandle;out Result:Boolean);
begin
 Result:=True;

 if (event^.modifiers and (EVENTFLAG_ALT_DOWN or EVENTFLAG_ALTGR_DOWN))<>0 then //alt
 if (event^.windows_key_code=115) then //f4
 begin
  halt;
 end;

 UpdateTime;
end;

procedure TfrmMain.TimerClearTimer(Sender: TObject);
begin
 ClearCache;

 TimerClear.Interval:=up_time_long;

 ChromiumWindow.LoadURL(UTF8Decode(main_url));
end;

function ReadIntDWORD(ini:TINIFile;const Section,Ident:RawByteString;Default:DWORD):DWORD;
begin
 Result:=StrToDWordDef(ini.ReadString(Section,Ident,''),Default);
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
 M:TMemoryStream;
 inject_js_file:RawByteString;
 error_page_file:RawByteString;
 config:TINIFile;
begin

 if FileExists('config.ini') then
 begin
  config:=TINIFile.Create('config.ini');

  main_url       :=config.ReadString('Main','main_url','');
  inject_js_file :=config.ReadString('Main','inject_js_file','');
  error_page_file:=config.ReadString('Main','error_page_file','');

  up_time_default:=ReadIntDWORD(config,'Main','up_time_default',up_time_default);
  up_time_long   :=ReadIntDWORD(config,'Main','up_time_long'   ,up_time_long);
  up_time_error  :=ReadIntDWORD(config,'Main','up_time_error'  ,up_time_error);

  //
  if FileExists(inject_js_file) then
  begin
   M:=TMemoryStream.Create;
   M.LoadFromFile(inject_js_file);

   SetLength(inject_js,M.Size);
   M.Position:=0;
   M.Read(PChar(inject_js)^,M.Size);

   M.Free;
  end;

  //
  if FileExists(error_page_file) then
  begin
   M:=TMemoryStream.Create;
   M.LoadFromFile(error_page_file);

   SetLength(error_page,M.Size);
   M.Position:=0;
   M.Read(PChar(error_page)^,M.Size);

   M.Free;
  end;

 end else
 begin
  main_url:=ParamStr(1);
 end;

 {$IFOPT D-}
 BorderStyle:=bsNone;
 WindowState:=wsMaximized;
 FormStyle:=fsStayOnTop;
 {$ENDIF}

 ChromiumWindow:=TChromiumWindow.Create(Self);
 ChromiumWindow.Parent:=Self;

 ChromiumWindow.ChromiumBrowser.OnBeforePopup:=@FOnBeforePopup;
 ChromiumWindow.ChromiumBrowser.OnLoadingStateChange:=@FOnLoadingStateChange;
 ChromiumWindow.ChromiumBrowser.OnLoadError:=@FOnLoadError;
 ChromiumWindow.ChromiumBrowser.OnKeyEvent:=@FOnKeyEvent;

 ChromiumWindow.Cursor:=Cursor;

 ChromiumWindow.AnchorAsAlign(alClient, 0);
 ChromiumWindow.Left  :=0;
 ChromiumWindow.Top   :=0;
 ChromiumWindow.Width :=Width;
 ChromiumWindow.Height:=Height;

 ChromiumWindow.TabStop:=True;
 ChromiumWindow.TabOrder:=1;
 ChromiumWindow.ChromiumBrowser.DefaultUrl:=BlankURL;

 ChromiumWindow.ChromiumBrowser.Options.Webgl:=STATE_DISABLED;

 ChromiumWindow.Visible:=True;
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
 While not(ChromiumWindow.CreateBrowser) and not(ChromiumWindow.Initialized) do
 begin
  Sleep(200);
 end;

 UpdateTime;
end;

end.

