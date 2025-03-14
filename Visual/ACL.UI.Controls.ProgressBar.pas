////////////////////////////////////////////////////////////////////////////////
//
//  Project:   Artem's Controls Library aka ACL
//             v6.0
//
//  Purpose:   ProgressBar
//
//  Author:    Artem Izmaylov
//             © 2006-2024
//             www.aimp.ru
//
//  FPC:       OK
//
unit ACL.UI.Controls.ProgressBar;

{$I ACL.Config.inc}

interface

uses
{$IFDEF FPC}
  LCLType,
{$ELSE}
  {Winapi.}Messages,
  {Winapi.}Windows,
{$ENDIF}
  // System
  {System.}Classes,
  {System.}Math,
  {System.}SysUtils,
  {System.}Types,
  // Vcl
  {Vcl.}Controls,
  {Vcl.}Graphics,
  // ACL
  ACL.Classes,
  ACL.Timers,
  ACL.Graphics.SkinImage,
  ACL.UI.Controls.Base,
  ACL.UI.Resources,
  ACL.Utils.DPIAware;

type

  { TACLStyleProgress }

  TACLStyleProgress = class(TACLStyle)
  protected
    procedure InitializeResources; override;
  public
    procedure DrawBackground(ACanvas: TCanvas; const R: TRect; AEnabled: Boolean);
    procedure DrawProgress(ACanvas: TCanvas; const R: TRect);
  published
    property Texture: TACLResourceTexture index 0 read GetTexture write SetTexture stored IsTextureStored;
  end;

  { TACLProgressBar }

  TACLProgressBar = class(TACLGraphicControl)
  strict private
    FAnimPosition: Integer;
    FMax: Single;
    FMin: Single;
    FProgress: Single;
    FStyle: TACLStyleProgress;
    FTimer: TACLTimer;
    FWaitingMode: Boolean;

    function GetProgressAnimSize: Integer;
    function GetProgressRange: Single;
    function IsIndexStored(Index: Integer): Boolean;
    procedure SetIndex(AIndex: Integer; AValue: Single);
    procedure SetStyle(const Value: TACLStyleProgress);
    procedure SetWaitingMode(AValue: Boolean);
  protected
    procedure CalculateProgressRect(const ABounds: TRect; out R1, R2, R1Clip, R2Clip: TRect);
    function CanAutoSize(var NewWidth, NewHeight: Integer): Boolean; override;
    procedure SetTargetDPI(AValue: Integer); override;
    procedure DoTimer(Sender: TObject);
    procedure Paint; override;
    procedure UpdateTransparency; override;
    //# Properties
    property AnimPosition: Integer read FAnimPosition;
    property ProgressAnimSize: Integer read GetProgressAnimSize;
    property ProgressRange: Single read GetProgressRange;
    property Timer: TACLTimer read FTimer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  {$IFDEF FPC}
    procedure ShouldAutoAdjust(var AWidth, AHeight: Boolean); override;
  {$ENDIF}
  published
    property Align;
    property Anchors;
    property AutoSize default True;
    property Enabled;
    property Max: Single index 0 read FMax write SetIndex stored IsIndexStored;
    property Min: Single index 1 read FMin write SetIndex stored IsIndexStored;
    property ResourceCollection;
    property Style: TACLStyleProgress read FStyle write SetStyle;
    property Progress: Single index 2 read FProgress write SetIndex stored IsIndexStored;
    property Visible;
    property WaitingMode: Boolean read FWaitingMode write SetWaitingMode default False;
	  //# Events
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
  end;

implementation

uses
  ACL.Geometry,
  ACL.Graphics,
{$IFNDEF FPC}
  ACL.Graphics.SkinImageSet, // inlining
{$ENDIF}
  ACL.Utils.Common;

{ TACLStyleProgress }

procedure TACLStyleProgress.DrawBackground(
  ACanvas: TCanvas; const R: TRect; AEnabled: Boolean);
begin
  Texture.Draw(ACanvas, R, 2 * Ord(not AEnabled));
end;

procedure TACLStyleProgress.DrawProgress(ACanvas: TCanvas; const R: TRect);
begin
  Texture.Draw(ACanvas, R, 1);
end;

procedure TACLStyleProgress.InitializeResources;
begin
  Texture.InitailizeDefaults('ProgressBar.Texture');
end;

{ TACLProgressBar }

constructor TACLProgressBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTimer := TACLTimer.CreateEx(DoTimer, 30);
  FStyle := TACLStyleProgress.Create(Self);
  AutoSize := True;
end;

destructor TACLProgressBar.Destroy;
begin
  FreeAndNil(FStyle);
  FreeAndNil(FTimer);
  inherited Destroy;
end;

procedure TACLProgressBar.CalculateProgressRect(
  const ABounds: TRect; out R1, R2, R1Clip, R2Clip: TRect);

  function CalculateClipRect(var R: TRect): TRect;
  begin
    Result := R;
    if R.Left > ABounds.Left then
      Dec(R.Left, Style.Texture.ContentOffsets.Left);
    if R.Right < ABounds.Right then
      Inc(R.Right, Style.Texture.ContentOffsets.Right);
  end;

var
  LHalf: Integer;
begin
  R1 := NullRect;
  R1Clip := NullRect;
  R2 := NullRect;
  R2Clip := NullRect;

  if WaitingMode then
  begin
    R1 := ABounds;
    LHalf := ProgressAnimSize div 2;
    if AnimPosition < LHalf then
    begin
      R2 := R1;
      R2.Left := Width + AnimPosition - LHalf;
      R2.Width := LHalf * 2;
      R2.Intersect(ABounds);
      R2Clip := CalculateClipRect(R2);
    end;
    if AnimPosition > Width - LHalf then
    begin
      R2 := R1;
      R2.Left := AnimPosition - Width - LHalf;
      R2.Width := 2 * LHalf;
      R2.Intersect(ABounds);
      R2Clip := CalculateClipRect(R2);
    end;
    R1.Left := AnimPosition - LHalf;
    R1.Right := AnimPosition + LHalf;
    R1.Intersect(ABounds);
    R1Clip := CalculateClipRect(R1);
  end
  else
    if ProgressRange > 0 then
    begin
      R1 := ABounds;
      R1.Right := R1.Left + Trunc(R1.Width * EnsureRange((Progress - Min) / ProgressRange, 0, 1));
      R1Clip := CalculateClipRect(R1);
    end;
end;

function TACLProgressBar.CanAutoSize(var NewWidth, NewHeight: Integer): Boolean;
begin
  if AutoSize then
    NewHeight := dpiApply(16, FCurrentPPI);
  Result := True;
end;

{$IFDEF FPC}
procedure TACLProgressBar.ShouldAutoAdjust(var AWidth, AHeight: Boolean);
begin
  AWidth := True;
  AHeight := not AutoSize;
end;
{$ENDIF}

procedure TACLProgressBar.SetTargetDPI(AValue: Integer);
begin
  inherited SetTargetDPI(AValue);
  Style.SetTargetDPI(AValue);
  AdjustSize;
end;

procedure TACLProgressBar.DoTimer(Sender: TObject);
begin
  Inc(FAnimPosition, 5);
  if FAnimPosition > Width then
    FAnimPosition := 0;
  Invalidate;
end;

procedure TACLProgressBar.Paint;
var
  LClipRgn: TRegionHandle;
  LPart1: TRect;
  LPart1Clip: TRect;
  LPart2: TRect;
  LPart2Clip: TRect;
begin
  if Enabled then
  begin
    LClipRgn := acSaveClipRegion(Canvas.Handle);
    try
      CalculateProgressRect(ClientRect, LPart1, LPart2, LPart1Clip, LPart2Clip);
      Style.DrawProgress(Canvas, LPart1);
      Style.DrawProgress(Canvas, LPart2);
      acExcludeFromClipRegion(Canvas.Handle, LPart1Clip);
      acExcludeFromClipRegion(Canvas.Handle, LPart2Clip);
      Style.DrawBackground(Canvas, ClientRect, Enabled);
    finally
      acRestoreClipRegion(Canvas.Handle, LClipRgn);
    end;
  end
  else
    Style.DrawBackground(Canvas, ClientRect, Enabled);
end;

function TACLProgressBar.GetProgressAnimSize: Integer;
begin
  Result := Trunc(Width * 0.3);
end;

function TACLProgressBar.GetProgressRange: Single;
begin
  if (Max = 0) and (Min = 0) then
    Result := 100
  else
    Result := Max - Min;
end;

function TACLProgressBar.IsIndexStored(Index: Integer): Boolean;
begin
  Result := False;
  case Index of
    0: Result := not IsZero(FMax);
    1: Result := not IsZero(FMin);
    2: Result := not IsZero(FProgress);
  end;
end;

procedure TACLProgressBar.SetIndex(AIndex: Integer; AValue: Single);
var
  ANeedRedraw: Boolean;
begin
  ANeedRedraw := False;
  if Enabled then
  begin
    case AIndex of
      0: begin
           ANeedRedraw := not SameValue(FMax, AValue);
           FMax := AValue;
           FMin := {System.}Math.Min(FMin, FMax);
         end;
      1: begin
           ANeedRedraw := not SameValue(FMin, AValue);
           FMin := AValue;
           FMax := {System.}Math.Max(FMin, FMax);
         end;
      2: begin
           ANeedRedraw := not SameValue(FProgress, AValue);
           FProgress := AValue;
           if Progress > 0 then
             WaitingMode := False;
         end;
    end;
  end;
  if ANeedRedraw then
    Invalidate;
end;

procedure TACLProgressBar.SetStyle(const Value: TACLStyleProgress);
begin
  FStyle.Assign(Value);
end;

procedure TACLProgressBar.SetWaitingMode(AValue: Boolean);
begin
  if FWaitingMode <> AValue then
  begin
    FWaitingMode := AValue;
    FTimer.Enabled := WaitingMode;
    Invalidate;
    Update;
  end;
end;

procedure TACLProgressBar.UpdateTransparency;
begin
  if Style.Texture.HasAlpha then
    ControlStyle := ControlStyle - [csOpaque]
  else
    ControlStyle := ControlStyle + [csOpaque];
end;

end.
