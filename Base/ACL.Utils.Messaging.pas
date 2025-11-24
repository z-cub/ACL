////////////////////////////////////////////////////////////////////////////////
//
//  Project:   Artem's Components Library aka ACL
//             v7.0
//
//  Purpose:   Messaging routines
//
//  Author:    Artem Izmaylov
//             © 2006-2024
//             www.aimp.ru
//
//  FPC:       OK
//
unit ACL.Utils.Messaging;

{$I ACL.Config.inc}

interface

uses
{$IFDEF FPC}
  InterfaceBase,
  LCLIntf,
  LCLType,
  LMessages,
{$ELSE}
  {Winapi.}Windows,
{$ENDIF}
  {Winapi.}Messages,
  // System
  {System.}Classes,
  Generics.Collections,
  Generics.Defaults,
  // ACL
  ACL.Utils.Common;

const
{$IFDEF FPC}
  WM_USER = LMessages.LM_USER;
{$ELSE}
  WM_USER = Messages.WM_USER;
{$ENDIF}

type
{$IFDEF FPC}
  TWndMethod = TLCLWndMethod;

  LPARAM = LCLType.LPARAM;
  WPARAM = LCLType.WPARAM;
{$ELSE}
  LPARAM = Windows.LPARAM;
  WPARAM = Windows.WPARAM;
{$ENDIF}

function acWndAlloc(AMethod: TWndMethod; const AClassName: string;
  AIsMessageOnly: Boolean = False; const AName: string = ''): TWndHandle;
procedure acWndDefaultProc(AWnd: TWndHandle; var Message: TMessage);
procedure acWndFree(AWnd: TWndHandle);

function acSendMessage(AWnd: TWndHandle; AMsg: Cardinal; WParam: WPARAM; LParam: LPARAM): LRESULT;
function acPostMessage(AWnd: TWndHandle; AMsg: Cardinal; WParam: WPARAM; LParam: LPARAM): Boolean;
procedure acRemoveMessage(AMessage: Cardinal; ATargetWnd: TWndHandle = 0);
{$IFDEF MSWINDOWS}
procedure acProcessMessage(AMessage: Cardinal; ATargetWnd: TWndHandle = 0);
{$ENDIF}
implementation

uses
  {System.}Math,
  {System.}SysUtils,
  {System.}Types;

function acSendMessage(AWnd: TWndHandle; AMsg: Cardinal; WParam: WPARAM; LParam: LPARAM): LRESULT;
{$IFDEF FPC}
var
  LInnerResult: LRESULT;
{$ENDIF}
begin
{$IFDEF FPC}
  if MainThreadID <> GetCurrentThreadId then
  begin
    LInnerResult := 0;
    TThread.Synchronize(nil, procedure begin
      LInnerResult := LCLIntf.SendMessage(AWnd, AMsg, WParam, LParam);
    end);
    Exit(LInnerResult);
  end;
{$ENDIF}
  Result := SendMessage(AWnd, AMsg, WParam, LParam);
end;

function acPostMessage(AWnd: TWndHandle; AMsg: Cardinal; WParam: WPARAM; LParam: LPARAM): Boolean;
begin
  Result := PostMessage(AWnd, AMsg, WParam, LParam);
end;

procedure acRemoveMessage(AMessage: Cardinal; ATargetWnd: TWndHandle = 0);
var
  LMsg: TMsg;
begin
  while PeekMessage(LMsg{%H-}, ATargetWnd, AMessage, AMessage, PM_REMOVE) do ;
end;

{$IFDEF MSWINDOWS}
procedure acProcessMessage(AMessage: Cardinal; ATargetWnd: TWndHandle = 0);
var
  LMsg: TMsg;
begin
  while PeekMessage(LMsg{%H-}, ATargetWnd, AMessage, AMessage, PM_REMOVE) do
  begin
    TranslateMessage(LMsg);
    DispatchMessage(LMsg);
  end;
end;
{$ENDIF}

{$IFDEF FPC}
function acWndAlloc(AMethod: TWndMethod; const AClassName: string;
  AIsMessageOnly: Boolean = False; const AName: string = ''): TWndHandle;
begin
  if MainThreadID <> GetCurrentThreadId then
    raise EInvalidOperation.Create('Cannot create window in non-main thread');
  Result := AllocateHWnd(AMethod);
  if Result = 0 then
    raise ENotImplemented.Create('AllocateHWnd is not implemented for this platform');
end;

procedure acWndDefaultProc(AWnd: TWndHandle; var Message: TMessage);
begin
  // do nothing
end;

procedure acWndFree(AWnd: TWndHandle);
begin
  DeallocateHWnd(AWnd);
end;

{$ELSE}
var
  UtilWindowClass: TWndClass = (Style: 0; lpfnWndProc: @DefWindowProc;
    cbClsExtra: 0; cbWndExtra: 0; hInstance: 0; hIcon: 0; hCursor: 0;
    hbrBackground: 0; lpszMenuName: nil; lpszClassName: 'TPUtilWindow');
  UtilWindowClassName: string;

function acWndAlloc(AMethod: TWndMethod; const AClassName: string;
  AIsMessageOnly: Boolean = False; const AName: string = ''): TWndHandle;
var
  ClassRegistered: Boolean;
  TempClass: TWndClass;
begin
  if MainThreadID <> GetCurrentThreadId then
    raise EInvalidOperation.Create('Cannot create window in non-main thread');
  UtilWindowClassName := AClassName;
  UtilWindowClass.hInstance := HInstance;
  UtilWindowClass.lpszClassName := PChar(UtilWindowClassName);
  ClassRegistered := GetClassInfo(HInstance, UtilWindowClass.lpszClassName, TempClass);
  if not ClassRegistered or (TempClass.lpfnWndProc <> @DefWindowProc) then
  begin
    if ClassRegistered then
      {Winapi.}Windows.UnregisterClass(UtilWindowClass.lpszClassName, HInstance);
    {Winapi.}Windows.RegisterClass(UtilWindowClass);
  end;
  Result := CreateWindowEx(WS_EX_TOOLWINDOW, UtilWindowClass.lpszClassName, PChar(AName),
    WS_POPUP {!0}, 0, 0, 0, 0, IfThen(AIsMessageOnly, HWND_MESSAGE), 0, HInstance, nil);
  if Assigned(AMethod) then
    SetWindowLong(Result, GWL_WNDPROC, NativeUInt(System.Classes.MakeObjectInstance(AMethod)));
end;

procedure acWndDefaultProc(AWnd: TWndHandle; var Message: TMessage);
begin
  Message.Result := DefWindowProc(AWnd, Message.Msg, Message.WParam, Message.LParam);
end;

procedure acWndFree(AWnd: TWndHandle);
var
  LInstance: Pointer;
begin
  if AWnd <> 0 then
  begin
    LInstance := Pointer(GetWindowLong(AWnd, GWL_WNDPROC));
    DestroyWindow(AWnd);
    if LInstance <> @DefWindowProc then
      System.Classes.FreeObjectInstance(LInstance);
  end;
end;
{$ENDIF}

end.
