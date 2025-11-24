////////////////////////////////////////////////////////////////////////////////
//
//  Project:   Artem's Components Library aka ACL
//             v7.0
//
//  Purpose:   Timers
//
//  Author:    Artem Izmaylov
//             © 2006-2025
//             www.aimp.ru
//
//  FPC:       OK
//
unit ACL.Timers;

{$I ACL.Config.inc}

interface

uses
{$IFDEF FPC}
  LCLIntf,
  LCLType,
  LMessages,
  Messages,
{$ELSE}
  Winapi.Messages,
  Winapi.Windows,
{$ENDIF}
  // System
  {System.}Classes,
  {System.}Generics.Collections,
  {System.}Generics.Defaults,
  {System.}Math,
  {System.}SysUtils,
  {System.}Types,
  // ACL
  ACL.Classes,
  ACL.Classes.Collections,
  ACL.Threading,
  ACL.Utils.Common,
  ACL.Utils.Messaging;


{$IFDEF FPC}
const
  WM_TIMER = LM_TIMER;
type
  TWMTimer = TLMTimer;
{$ENDIF}

type

  { TACLTimer }

  TACLTimer = class(TComponent)
  public const
    DefaultInterval = 1000;
  private
    FHighResolutionCounter: Int64;
  strict private
    FEnabled: Boolean;
    FHighResolution: Boolean;
    FInterval: Cardinal;

    FOnTimer: TNotifyEvent;

    procedure SetEnabled(Value: Boolean);
    procedure SetInterval(Value: Cardinal);
    procedure SetHighResolution(Value: Boolean);
    procedure SetOnTimer(Value: TNotifyEvent);
    procedure UpdateTimer;
  protected
    function CanSetTimer: Boolean; virtual;
    procedure Timer; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    constructor CreateEx(AEvent: TNotifyEvent; AInterval: Cardinal = DefaultInterval);
    procedure BeforeDestruction; override;
    procedure Restart; overload;
    procedure Restart(AInterval: Cardinal); overload;
    function Start: TACLTimer;
    procedure Stop;
  published
    property Enabled: Boolean read FEnabled write SetEnabled default True;
    property Interval: Cardinal read FInterval write SetInterval default DefaultInterval;
    property HighResolution: Boolean read FHighResolution write SetHighResolution default False;
    // Events
    property OnTimer: TNotifyEvent read FOnTimer write SetOnTimer;
  end;

  { TACLTimerList }

  TACLTimerListOf<T> = class(TACLTimer)
  protected
    FList: TACLListOf<T>;
    function CanAdd(const AObject: T): Boolean; virtual;
    function CanSetTimer: Boolean; override;
    procedure Timer; override;
    procedure TimerObject(const AObject: T); virtual; abstract;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    procedure Add(const AObject: T);
    function Contains(const AObject: T): Boolean;
    procedure Remove(const AObject: T);
  end;

function GetExactTickCount: Int64;
function TickCountToTime(const ATicks: Int64): Cardinal;
function TimeToTickCount(const ATime: Cardinal): Int64;
implementation

type

  { TACLTimerManager }

  TACLTimerManager = class
  strict private
    class var FLock: TACLCriticalSection;

    class function AlignToSystemTimerResolution(AInterval: Cardinal): Cardinal;
    class procedure HandleMessage(var AMessage: TMessage);
    class procedure SafeCallTimerProc(ATimer: TACLTimer); inline;
    class procedure SafeUpdateHighResolutionThread;
  {$IFDEF FPC}
    class procedure TimerProc(hWnd: HWND; uMsg: UINT;
      idEvent: UINT_PTR; dwTime: DWORD); stdcall; static;
  {$ENDIF}
  protected
    class var FHandle: HWND;
    class var FHighResolutionThread: TACLPauseableThread;
    class var FHighResolutionTimers: TThreadList;
    class var FTimers: TList;

    class procedure SafeCallTimerProcs(AList: TList);
  public
    class constructor Create;
    class destructor Destroy;
    class procedure Register(ATimer: TACLTimer);
    class procedure Unregister(ATimer: TACLTimer);
  end;

  { TACLTimerManagerHighResolutionThread }

  TACLTimerManagerHighResolutionThread = class(TACLPauseableThread)
  protected
    procedure Execute; override;
  end;

var
  FTimerManager: TACLTimerManager;

{$IFDEF MSWINDOWS}
var
  FPerformanceCounterFrequency: Int64 = 0;
{$ENDIF}

function GetExactTickCount: Int64;
begin
{$IFDEF MSWINDOWS}
  //# https://docs.microsoft.com/ru-ru/windows/win32/api/profileapi/nf-profileapi-queryperformancecounter?redirectedfrom=MSDN
  //# On systems that run Windows XP or later, the function will always succeed and will thus never return zero.
  if not QueryPerformanceCounter(Result) then
    Result := GetTickCount;
{$ELSE}
  Result := GetTickCount64; // in milliseconds
{$ENDIF}
end;

function TickCountToTime(const ATicks: Int64): Cardinal;
begin
{$IFDEF MSWINDOWS}
  if FPerformanceCounterFrequency = 0 then
    QueryPerformanceFrequency(FPerformanceCounterFrequency);
  Result := (ATicks * 1000) div FPerformanceCounterFrequency;
{$ELSE}
  Result := ATicks;
{$ENDIF}
end;

function TimeToTickCount(const ATime: Cardinal): Int64;
begin
{$IFDEF MSWINDOWS}
  if FPerformanceCounterFrequency = 0 then
    QueryPerformanceFrequency(FPerformanceCounterFrequency);
  Result := (Int64(ATime) * FPerformanceCounterFrequency) div 1000;
{$ELSE}
  Result := ATime;
{$ENDIF}
end;

{ TACLTimer }

constructor TACLTimer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FInterval := DefaultInterval;
  FEnabled := True;
end;

constructor TACLTimer.CreateEx(AEvent: TNotifyEvent; AInterval: Cardinal);
begin
  Create(nil);
  FEnabled := False;
  FInterval := AInterval;
  FOnTimer := AEvent;
end;

procedure TACLTimer.BeforeDestruction;
begin
  inherited BeforeDestruction;
  Enabled := False;
end;

procedure TACLTimer.Restart;
begin
  Enabled := False;
  Enabled := True;
end;

procedure TACLTimer.Restart(AInterval: Cardinal);
begin
  Enabled := False;
  Interval := AInterval;
  Enabled := True;
end;

function TACLTimer.CanSetTimer: Boolean;
begin
  Result := (Interval > 0) and Enabled and Assigned(OnTimer);
end;

procedure TACLTimer.Timer;
begin
  CallNotifyEvent(Self, OnTimer);
end;

procedure TACLTimer.SetEnabled(Value: Boolean);
begin
  if Value <> FEnabled then
  begin
    FEnabled := Value;
    UpdateTimer;
  end;
end;

procedure TACLTimer.SetInterval(Value: Cardinal);
begin
  Value := Max(Value, 1);
  if Value <> FInterval then
  begin
    FInterval := Value;
    UpdateTimer;
  end;
end;

procedure TACLTimer.SetHighResolution(Value: Boolean);
begin
  if HighResolution <> Value then
  begin
    FHighResolution := Value;
    UpdateTimer;
  end;
end;

procedure TACLTimer.SetOnTimer(Value: TNotifyEvent);
begin
  FOnTimer := Value;
  UpdateTimer;
end;

function TACLTimer.Start: TACLTimer;
begin
  Enabled := True;
  Result := Self;
end;

procedure TACLTimer.Stop;
begin
  Enabled := False;
end;

procedure TACLTimer.UpdateTimer;
begin
  TACLTimerManager.Unregister(Self);
  if CanSetTimer then
    TACLTimerManager.Register(Self);
end;

{ TACLTimerList }

constructor TACLTimerListOf<T>.Create;
begin
  inherited Create(nil);
  FList := TACLListOf<T>.Create;
end;

destructor TACLTimerListOf<T>.Destroy;
begin
  FreeAndNil(FList);
  inherited Destroy;
end;

procedure TACLTimerListOf<T>.Add(const AObject: T);
begin
  if FList.IndexOf(AObject) < 0 then
  begin
    if CanAdd(AObject) then
    begin
      FList.Add(AObject);
      Start;
    end;
  end;
end;

function TACLTimerListOf<T>.CanAdd(const AObject: T): Boolean;
begin
  Result := True;
end;

function TACLTimerListOf<T>.CanSetTimer: Boolean;
begin
  Result := Enabled and (Interval > 0);
end;

function TACLTimerListOf<T>.Contains(const AObject: T): Boolean;
begin
  Result := FList.Contains(AObject);
end;

procedure TACLTimerListOf<T>.Remove(const AObject: T);
var
  LIndex: Integer;
begin
  LIndex := FList.IndexOf(AObject);
  if LIndex >= 0 then
  begin
    FList.Delete(LIndex);
    if FList.Count = 0 then Stop;
  end;
end;

procedure TACLTimerListOf<T>.Timer;
var
  I: Integer;
begin
  for I := FList.Count - 1 downto 0 do
    TimerObject(FList.List[I]);
end;

{ TACLTimerManager }

class constructor TACLTimerManager.Create;
begin
  FLock := TACLCriticalSection.Create;
  FTimers := TList.Create;
  FHandle := acWndAlloc(HandleMessage, ClassName, True);
  FHighResolutionTimers := TThreadList.Create;
end;

class destructor TACLTimerManager.Destroy;
begin
  acWndFree(FHandle);
  FHandle := 0;
  FreeAndNil(FHighResolutionThread);
  FreeAndNil(FHighResolutionTimers);
  FreeAndNil(FTimers);
  FreeAndNil(FLock);
end;

class function TACLTimerManager.AlignToSystemTimerResolution(AInterval: Cardinal): Cardinal;
begin
  ClearExceptions(False);
  // The resolution of the GetTickCount function is limited to the resolution of the system timer,
  // which is typically in the range of 10 milliseconds to 16 milliseconds
  Result := Max(1, Round(AInterval / 10)) * 10;
//#AI: Animation works too slow (in comparing with AIMP4)
//  Result := Max(1, Round(AInterval / SystemTimerResolution)) * SystemTimerResolution;
end;

class procedure TACLTimerManager.HandleMessage(var AMessage: TMessage);
begin
  try
    if AMessage.Msg = WM_TIMER then
      SafeCallTimerProc(TACLTimer(AMessage.WParam))
    else if AMessage.Msg = WM_USER then
      SafeCallTimerProcs(TList(AMessage.LParam))
    else
      acWndDefaultProc(FHandle, AMessage);
  except
    if Assigned(ApplicationHandleException) then
      ApplicationHandleException(nil);
  end;
end;

class procedure TACLTimerManager.Register(ATimer: TACLTimer);
begin
  if FHandle = 0 then Exit;
  FLock.Enter;
  try;
    FTimers.Add(ATimer);
    if ATimer.HighResolution and (ATimer.Interval < 1000) then
    begin
      FHighResolutionTimers.Add(ATimer);
      SafeUpdateHighResolutionThread;
    end
    else
      SetTimer(FHandle, NativeUInt(ATimer),
        AlignToSystemTimerResolution(ATimer.Interval),
        {$IFDEF FPC}@TimerProc{$ELSE}nil{$ENDIF}); // for .SO
  finally
    FLock.Leave;
  end;
end;

class procedure TACLTimerManager.Unregister(ATimer: TACLTimer);
begin
  if FHandle = 0 then Exit;  // app terminating

  FLock.Enter;
  try
    if FTimers.Remove(ATimer) >= 0 then
      KillTimer(FHandle, NativeUInt(ATimer));

    with FHighResolutionTimers.LockList do
    try
      if Remove(ATimer) >= 0 then
        SafeUpdateHighResolutionThread;
    finally
      FHighResolutionTimers.UnlockList;
    end;
  finally
    FLock.Leave;
  end;
end;

class procedure TACLTimerManager.SafeCallTimerProc(ATimer: TACLTimer);
begin
  if (FTimers <> nil) and FTimers.Contains(ATimer) then
    ATimer.Timer;
end;

class procedure TACLTimerManager.SafeCallTimerProcs(AList: TList);
var
  I: Integer;
begin
  for I := 0 to AList.Count - 1 do
    SafeCallTimerProc(AList.List[I]);
end;

class procedure TACLTimerManager.SafeUpdateHighResolutionThread;
var
  LList: TList;
begin
  if FHighResolutionTimers = nil then Exit;
  LList := FHighResolutionTimers.LockList;
  try
    if LList.Count = 0 then
    begin
      if FHighResolutionThread <> nil then
        FHighResolutionThread.SetPaused(True);
    end
    else
    begin
      if FHighResolutionThread = nil then
        FHighResolutionThread := TACLTimerManagerHighResolutionThread.Create(False);
      FHighResolutionThread.SetPaused(False);
    end;
  finally
    FHighResolutionTimers.UnlockList;
  end;
end;

{$IFDEF FPC}
class procedure TACLTimerManager.TimerProc(hWnd: HWND;
  uMsg: UINT; idEvent: UINT_PTR; dwTime: DWORD); stdcall;
begin
  SafeCallTimerProc(TACLTimer(idEvent));
//  PostMessage(hWnd, uMsg, idEvent, 0);
end;
{$ENDIF}

{ TACLTimerManagerHighResolutionThread }

procedure TACLTimerManagerHighResolutionThread.Execute;
var
  LList: TList;
  LNextTick: Int64;
  LSleepTime: Integer;
  LTicked: TList;
  LTicks: Int64;
  LTimer: TACLTimer;
  I: Integer;
begin
{$IFDEF ACL_THREADING_DEBUG}
  NameThreadForDebugging('HighResolutionTimer');
{$ENDIF}

  LTicked := TList.Create;
  try
    while not Terminated do
    begin
      LTicked.Count := 0;
      LTicks := GetExactTickCount;

      LList := TACLTimerManager.FHighResolutionTimers.LockList;
      try
        LNextTick := LTicks + TimeToTickCount(1000);
        for I := 0 to LList.Count - 1 do
        begin
          LTimer := LList.List[I];
          if LTimer.FHighResolutionCounter <= LTicks then
          begin
            LTimer.FHighResolutionCounter := LTicks + TimeToTickCount(LTimer.Interval);
            LTicked.Add(LTimer);
          end;
          LNextTick := Min(LNextTick, LTimer.FHighResolutionCounter);
        end;
      finally
        TACLTimerManager.FHighResolutionTimers.UnlockList;
      end;

      if LTicked.Count > 0 then
      begin
      {$IFDEF FPC}
        Synchronize(procedure begin TACLTimerManager.SafeCallTimerProcs(LTicked); end);
      {$ELSE}
        SendMessage(TACLTimerManager.FHandle, WM_USER, 0, LPARAM(LTicked));
      {$ENDIF}
        LTicks := GetExactTickCount;
      end;

      LSleepTime := TickCountToTime(Max(LNextTick - LTicks, 0));
      //#AI: always call sleep to take main thread some time to process message queue
      LSleepTime := EnsureRange(LSleepTime, 1, 1000);
      Sleep(LSleepTime);
      WaitForUnpause;
    end;
  finally
    LTicked.Free;
  end;
end;

initialization
  FTimerManager := TACLTimerManager.Create;

finalization
  FreeAndNil(FTimerManager);
end.
