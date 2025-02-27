////////////////////////////////////////////////////////////////////////////////
//
//  Project:   Artem's Components Library aka ACL
//             v6.0
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
  {System.}Math,
  {System.}SysUtils,
  {System.}Types,
  // ACL
  ACL.Classes.Collections;

{$IFDEF FPC}
const
  WM_TIMER = LM_TIMER;
type
  TWMTimer = TLMTimer;
{$ENDIF}

type

  { TACLTimer }

  TACLTimerMode = (tmDefault, tmHighResolution, tmTickOnce);
  TACLTimer = class(TComponent)
  public const
    DefaultInterval = 1000;
  strict private
    FEnabled: Boolean;
    FInterval: Cardinal;
    FMode: TACLTimerMode;

    FOnTimer: TNotifyEvent;

    procedure SetEnabled(Value: Boolean);
    procedure SetInterval(Value: Cardinal);
    procedure SetMode(Value: TACLTimerMode);
    procedure SetOnTimer(Value: TNotifyEvent);
    procedure UpdateTimer;
  private
    FHighResolutionCounter: Int64;
  protected
    function CanSetTimer: Boolean; virtual;
    procedure Timer; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    constructor CreateEx(AEvent: TNotifyEvent;
      AInterval: Cardinal = DefaultInterval;
      AMode: TACLTimerMode = tmDefault);
    procedure BeforeDestruction; override;
    procedure Restart; overload;
    procedure Restart(AInterval: Cardinal); overload;
    function Start: TACLTimer;
  published
    property Enabled: Boolean read FEnabled write SetEnabled default True;
    property Interval: Cardinal read FInterval write SetInterval default DefaultInterval;
    property Mode: TACLTimerMode read FMode write SetMode default tmDefault;
    // Events
    property OnTimer: TNotifyEvent read FOnTimer write SetOnTimer;
  end;

  { TACLTimerList }

  TACLTimerListOf<T> = class(TACLTimer)
  strict private
    procedure CheckState;
  protected
    FList: TACLListOf<T>;

    procedure DoAdding(const AObject: T); virtual;
    procedure DoRemoving(const AObject: T); virtual;

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

uses
  ACL.Classes,
  ACL.Threading,
  ACL.Utils.Common,
  ACL.Utils.Messaging;

type

  { TACLTimerManager }

  TACLTimerManager = class
  strict private
    FLock: TACLCriticalSection;
  {$IFDEF MSWINDOWS}
    FSystemTimerResolution: Integer;
  {$ENDIF}

    function AlignToSystemTimerResolution(AInterval: Cardinal): Cardinal;
    function GetSystemTimerResolution: Integer;
    procedure HandleMessage(var AMessage: TMessage);
    procedure SafeCallTimerProc(ATimer: TACLTimer); inline;
    procedure SafeUpdateHighResolutionThread;
  protected
    class procedure TimerProc(hWnd: HWND; uMsg: UINT; idEvent: UINT_PTR; dwTime: DWORD); stdcall; static;
  protected
    FHandle: HWND;
    FHighResolutionThread: TACLPauseableThread;
    FHighResolutionTimers: TThreadList;
    FTimers: TList;

    procedure SafeCallTimerProcs(AList: TList);
    property SystemTimerResolution: Integer read GetSystemTimerResolution;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterTimer(ATimer: TACLTimer);
    procedure UnregisterTimer(ATimer: TACLTimer);
  end;

  { TACLTimerManagerHighResolutionThread }

  TACLTimerManagerHighResolutionThread = class(TACLPauseableThread)
  strict private
    FOwner: TACLTimerManager;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TACLTimerManager);
  end;

var
  FTimerManager: TACLTimerManager;

{$IFDEF MSWINDOWS}
var
  FPerformanceCounterFrequency: Int64 = 0;

function NtQueryTimerResolution(out Maximum, Minimum, Actual: ULONG): ULONG32; stdcall; external 'ntdll.dll';
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

constructor TACLTimer.CreateEx(AEvent: TNotifyEvent; AInterval: Cardinal; AMode: TACLTimerMode);
begin
  Create(nil);
  FMode := AMode;
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

procedure TACLTimer.SetMode(Value: TACLTimerMode);
begin
  if FMode <> Value then
  begin
    FMode := Value;
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

procedure TACLTimer.UpdateTimer;
begin
  if FTimerManager <> nil then
  begin
    FTimerManager.UnregisterTimer(Self);
    if CanSetTimer then
      FTimerManager.RegisterTimer(Self);
  end;
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
    DoAdding(AObject);
    FList.Add(AObject);
    CheckState;
  end;
end;

function TACLTimerListOf<T>.Contains(const AObject: T): Boolean;
begin
  Result := FList.Contains(AObject);
end;

procedure TACLTimerListOf<T>.Remove(const AObject: T);
var
  AIndex: Integer;
begin
  AIndex := FList.IndexOf(AObject);
  if AIndex >= 0 then
  begin
    DoRemoving(AObject);
    FList.Delete(AIndex);
    CheckState;
  end;
end;

procedure TACLTimerListOf<T>.DoAdding(const AObject: T);
begin
  // do nothing
end;

procedure TACLTimerListOf<T>.DoRemoving(const AObject: T);
begin
  // do nothing
end;

function TACLTimerListOf<T>.CanSetTimer: Boolean;
begin
  Result := Enabled and (Interval > 0);
end;

procedure TACLTimerListOf<T>.Timer;
var
  I: Integer;
begin
  for I := FList.Count - 1 downto 0 do
    TimerObject(FList.List[I]);
end;

procedure TACLTimerListOf<T>.CheckState;
begin
  Enabled := FList.Count > 0;
end;

{ TACLTimerManager }

constructor TACLTimerManager.Create;
begin
  FLock := TACLCriticalSection.Create;
  FTimers := TList.Create;
  FHandle := WndCreate(HandleMessage, ClassName, True);
  FHighResolutionTimers := TThreadList.Create;
end;

destructor TACLTimerManager.Destroy;
begin
  WndFree(FHandle);
  FreeAndNil(FHighResolutionThread);
  FreeAndNil(FHighResolutionTimers);
  FreeAndNil(FTimers);
  FreeAndNil(FLock);
  inherited Destroy;
end;

procedure TACLTimerManager.RegisterTimer(ATimer: TACLTimer);
begin
  FLock.Enter;
  try;
    FTimers.Add(ATimer);
    if (ATimer.Mode = tmHighResolution) and (ATimer.Interval < 1000) then
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

procedure TACLTimerManager.UnregisterTimer(ATimer: TACLTimer);
begin
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

procedure TACLTimerManager.HandleMessage(var AMessage: TMessage);
begin
  if AMessage.Msg = WM_TIMER then
    SafeCallTimerProc(TACLTimer(AMessage.WParam))
  else if AMessage.Msg = WM_USER then
    SafeCallTimerProcs(TList(AMessage.LParam))
  else
    WndDefaultProc(FHandle, AMessage);
end;

function TACLTimerManager.AlignToSystemTimerResolution(AInterval: Cardinal): Cardinal;
begin
  // The resolution of the GetTickCount function is limited to the resolution of the system timer,
  // which is typically in the range of 10 milliseconds to 16 milliseconds
  Result := Max(1, Round(AInterval / 10)) * 10;

//#AI: Animation works too slow (in comparing with AIMP4)
//  Result := Max(1, Round(AInterval / SystemTimerResolution)) * SystemTimerResolution;
end;

function TACLTimerManager.GetSystemTimerResolution: Integer;
{$IFDEF MSWINDOWS}
var
  LActual, LMax, LMin: ULONG;
begin
  if FSystemTimerResolution = 0 then
  begin
    if NtQueryTimerResolution(LMax, LMin, LActual) = 0 then
      FSystemTimerResolution := Round(LActual / 1000);
    FSystemTimerResolution := Max(FSystemTimerResolution, 1);
  end;
  Result := FSystemTimerResolution;
end;
{$ELSE}
begin
  Result := 1; // todo - check it
end;
{$ENDIF}

procedure TACLTimerManager.SafeCallTimerProc(ATimer: TACLTimer);
begin
  if FTimers.Contains(ATimer) then
  begin
    if ATimer.Mode = tmTickOnce then
      ATimer.Enabled := False;
    ATimer.Timer;
  end;
end;

procedure TACLTimerManager.SafeCallTimerProcs(AList: TList);
var
  I: Integer;
begin
  for I := 0 to AList.Count - 1 do
    SafeCallTimerProc(AList.List[I]);
end;

procedure TACLTimerManager.SafeUpdateHighResolutionThread;
var
  LList: TList;
begin
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
        FHighResolutionThread := TACLTimerManagerHighResolutionThread.Create(Self);
      FHighResolutionThread.SetPaused(False);
    end;
  finally
    FHighResolutionTimers.UnlockList;
  end;
end;

class procedure TACLTimerManager.TimerProc(
  hWnd: HWND; uMsg: UINT; idEvent: UINT_PTR; dwTime: DWORD); stdcall;
begin
  SendMessage(hWnd, uMsg, idEvent, 0);
end;

{ TACLTimerManagerHighResolutionThread }

constructor TACLTimerManagerHighResolutionThread.Create(AOwner: TACLTimerManager);
begin
  inherited Create(False);
  FOwner := AOwner;
end;

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

      LList := FOwner.FHighResolutionTimers.LockList;
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
        FOwner.FHighResolutionTimers.UnlockList;
      end;

      if LTicked.Count > 0 then
      begin
      {$IFDEF FPC}
        Synchronize(procedure begin FOwner.SafeCallTimerProcs(LTicked); end);
      {$ELSE}
        SendMessage(FOwner.FHandle, WM_USER, 0, LPARAM(LTicked));
      {$ENDIF}
        LTicks := GetExactTickCount;
      end;

      LSleepTime := TickCountToTime(LNextTick - LTicks);
      LSleepTime := Max(LSleepTime, 1); //#AI: always call sleep to take main thread some time to process message queue
      if LSleepTime > 0 then
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
