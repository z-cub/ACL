﻿////////////////////////////////////////////////////////////////////////////////
//
//  Project:   Artem's Controls Library aka ACL
//             v6.0
//
//  Purpose:   Extended Library-based PaintBox
//             with hardware acceleration via Direct2D
//
//  Author:    Artem Izmaylov
//             © 2006-2024
//             www.aimp.ru
//
//  FPC:       OK
//
unit ACL.UI.Controls.Scene2D;

{$I ACL.Config.inc}

interface

uses
{$IFDEF FPC}
  LCLIntf,
  LCLType,
{$ELSE}
  {Winapi.}Windows,
{$ENDIF}
  {Winapi.}Messages,
  // System
  {System.}Classes,
  {System.}SysUtils,
  {System.}Types,
  System.UITypes,
  // ACL
  ACL.Graphics,
  ACL.Graphics.Ex,
  ACL.UI.Controls.Base,
  // VCL
  {Vcl.}Controls;

type
  TACLRenderEvent = procedure (Sender: TObject; Render: TACL2DRender) of object;

  { TACLRenderMode }

  {$SCOPEDENUMS ON}
  TACLRenderMode = (Default, Gdip, Direct2D, Cairo);
  {$SCOPEDENUMS OFF}

  TACLRenderModeHelper = record helper for TACLRenderMode
  public
    function IsAvailable: Boolean;
    function NextAvailable: TACLRenderMode;
  end;

  { TACLCustom2DScene }

  TACLCustom2DScene = class(TWinControl)
  strict private
    FRender: TACL2DRender;
    FRenderMode: TACLRenderMode;

    procedure CreateRender;
    procedure RecreateRenderRequested(Sender: TObject = nil);
    procedure SetRenderMode(AValue: TACLRenderMode);
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
  protected
    procedure CreateHandle; override;
    procedure DestroyHandle; override;
    procedure Paint(ARender: TACL2DRender); virtual;
    //# Events
    procedure DoCreate; virtual;
    procedure DoDestroy; virtual;
    //# Properties
    property Render: TACL2DRender read FRender;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property RenderMode: TACLRenderMode read FRenderMode
      write SetRenderMode default TACLRenderMode.Default;
  end;

  { TACLPaintBox2D }

  TACLPaintBox2D = class(TACLCustom2DScene)
  strict private
    FOnDestroy: TACLRenderEvent;
    FOnCreate: TACLRenderEvent;
    FOnPaint: TACLRenderEvent;
  protected
    procedure DoCreate; override;
    procedure DoDestroy; override;
    procedure Paint(ARender: TACL2DRender); override;
  published
    property OnCreate: TACLRenderEvent read FOnCreate write FOnCreate;
    property OnDestroy: TACLRenderEvent read FOnDestroy write FOnDestroy;
    property OnPaint: TACLRenderEvent read FOnPaint write FOnPaint;
  end;

implementation

uses
{$IFDEF ACL_CAIRO}
  ACL.Graphics.Ex.Cairo,
{$ENDIF}
{$IFDEF MSWINDOWS}
  ACL.Graphics.Ex.D2D,
  ACL.Graphics.Ex.Gdip,
{$ENDIF}
  ACL.Utils.Common;

{ TACLRenderModeHelper }

function TACLRenderModeHelper.IsAvailable: Boolean;
begin
{$IFDEF MSWINDOWS}
  if Self = TACLRenderMode.Direct2D then
    Exit(TACLDirect2D.Initialize);
  if Self = TACLRenderMode.Gdip then
    Exit(True);
{$ENDIF}
{$IFDEF ACL_CAIRO}
  if Self = TACLRenderMode.Cairo then
    Exit(True);
{$ENDIF}
  Result := False;
end;

function TACLRenderModeHelper.NextAvailable: TACLRenderMode;
begin
  Result := Self;
  repeat
    Result := TACLRenderMode((Ord(Result) + 1) mod (Ord(High(TACLRenderMode)) + 1));
    if Result = Self then Exit; // прошли круг, но ничего не выбрали
  until (Result <> TACLRenderMode.Default) and Result.IsAvailable;
end;

{ TACLCustom2DScene }

constructor TACLCustom2DScene.Create(AOwner: TComponent);
begin
  inherited;
  ControlStyle := ControlStyle + [csOpaque];
end;

destructor TACLCustom2DScene.Destroy;
begin
  DoDestroy;
  FreeAndNil(FRender);
  inherited;
end;

procedure TACLCustom2DScene.CreateRender;
begin
{$IFDEF MSWINDOWS}
  if (RenderMode = TACLRenderMode.Direct2D) and not (csDesigning in ComponentState) then
  begin
    if TACLDirect2D.TryCreateRender(RecreateRenderRequested, WindowHandle, FRender) then
      Exit;
  end;
  if RenderMode = TACLRenderMode.Gdip then
  begin
    FRender := TACLGdiplusRender.Create;
    Exit;
  end;
{$ENDIF}

{$IFDEF ACL_CAIRO}
  if RenderMode = TACLRenderMode.Cairo then
  begin
    FRender := TACLCairoRender.Create;
    Exit;
  end;
{$ENDIF}

  // Creating Default Render
{$IF DEFINED(MSWINDOWS)}
  FRender := TACLGdiplusRender.Create;
{$ELSEIF DEFINED(ACL_CAIRO)}
  FRender := TACLCairoRender.Create;
{$ELSE}
  raise ENotImplemented.Create('TACLScene2D - no one render is available');
{$ENDIF}
end;

procedure TACLCustom2DScene.CreateHandle;
var
  LIntf: IACL2DRenderWndBased;
begin
  inherited;
  if Render = nil then
    CreateRender;
  if Supports(Render, IACL2DRenderWndBased, LIntf) then
  begin
    LIntf.SetWndHandle(Handle);
    LIntf := nil;
  end;
  DoCreate;
end;

procedure TACLCustom2DScene.DestroyHandle;
var
  LIntf: IACL2DRenderWndBased;
begin
  DoDestroy;
  if Supports(Render, IACL2DRenderWndBased, LIntf) then
  begin
    LIntf.SetWndHandle(0);
    LIntf := nil;
  end;
  inherited;
end;

procedure TACLCustom2DScene.DoCreate;
begin
  // do nothing
end;

procedure TACLCustom2DScene.DoDestroy;
begin
  // do nothing
end;

procedure TACLCustom2DScene.Paint(ARender: TACL2DRender);
begin
  // do nothing
end;

procedure TACLCustom2DScene.RecreateRenderRequested(Sender: TObject);
begin
  DoDestroy;
  FreeAndNil(FRender);
  if HandleAllocated then
  begin
    CreateRender;
    DoCreate;
    Invalidate;
  end;
end;

procedure TACLCustom2DScene.SetRenderMode(AValue: TACLRenderMode);
begin
  if FRenderMode <> AValue then
  begin
    FRenderMode := AValue;
    if not (csDesigning in ComponentState) then
    begin
      RecreateRenderRequested;
    {$IFNDEF FPC}
      if HandleAllocated then
        RecreateWnd;
    {$ENDIF}
    end;
  end;
end;

procedure TACLCustom2DScene.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure TACLCustom2DScene.WMPaint(var Message: TWMPaint);
var
  LPaintStruct: TPaintStruct;
begin
  if Message.DC <> 0 then
  begin
    Render.BeginPaint(Message.DC, ClientRect);
    try
      Paint(Render);
    finally
      Render.EndPaint;
    end;
  end
  else
    if Supports(Render, IACL2DRenderWndBased) then
    begin
      BeginPaint(Handle, LPaintStruct{%H-});
      try
        // We not need to copy directX frame's content to DC (its already been
        // drawn over our hwnd). So, what why we set DC to zero.
        Render.BeginPaint(0, ClientRect, LPaintStruct.rcPaint);
        try
          Paint(Render);
        finally
          Render.EndPaint;
        end;
      finally
        EndPaint(Handle, LPaintStruct);
      end;
    end
    else
      TACLControls.BufferedPaint(Self);
end;

{ TACLPaintBox2D }

procedure TACLPaintBox2D.DoCreate;
begin
  if (Render <> nil) and Assigned(OnCreate) then
    OnCreate(Self, Render);
end;

procedure TACLPaintBox2D.DoDestroy;
begin
  if (Render <> nil) and Assigned(OnDestroy) then
    OnDestroy(Self, Render);
end;

procedure TACLPaintBox2D.Paint(ARender: TACL2DRender);
begin
  if csDesigning in ComponentState then
  begin
    ARender.FillRectangle(ClientRect, TAlphaColors.Black);
    ARender.DrawText('(' + Name + ')', ClientRect, TAlphaColors.White, Font, taCenter);
  end
  else
    if Assigned(OnPaint) then
      OnPaint(Self, ARender);
end;

end.
