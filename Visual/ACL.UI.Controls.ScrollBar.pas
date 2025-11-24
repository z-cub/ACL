////////////////////////////////////////////////////////////////////////////////
//
//  Project:   Artem's Controls Library aka ACL
//             v7.0
//
//  Purpose:   ScrollBars
//
//  Author:    Artem Izmaylov
//             © 2006-2025
//             www.aimp.ru
//
//  FPC:       OK
//
unit ACL.UI.Controls.ScrollBar;

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
  {System.}Math,
  {System.}SysUtils,
  {System.}Types,
  // Vcl
  {Vcl.}Controls,
  {Vcl.}Graphics,
  {Vcl.}Forms,
  {Vcl.}StdCtrls,
  // ACL
  ACL.Classes,
  ACL.Geometry,
  ACL.Graphics,
  ACL.Graphics.SkinImage,
  ACL.Math,
  ACL.Timers,
  ACL.UI.Animation,
  ACL.UI.Controls.Base,
  ACL.UI.Controls.Buttons,
  ACL.UI.Resources,
  ACL.Utils.Common,
  ACL.Utils.Desktop,
  ACL.Utils.DPIAware;

const
  acScrollBarHitArea = 120;
  acScrollBarTimerInitialDelay = 400;
  acScrollBarTimerScrollInterval = 60;

type
  TACLScrollBar = class;
  TACLScrollBarSubClass = class;

  TACLScrollBarPart = (sbpNone, sbpLineUp, sbpLineDown, sbpThumbnail, sbpPageUp, sbpPageDown);

  { IACLScrollBarAppearance }

  IACLScrollBarAppearance = interface
  ['{2B8F4E80-397B-434C-82F6-F163FCA18CD7}']
    procedure Draw(ACanvas: TCanvas; const ABounds: TRect;
      AKind: TScrollBarKind; APart: TACLScrollBarPart; AState: TACLButtonState);
    function IsThumbResizable(AKind: TScrollBarKind): Boolean;
    function GetSkin(AKind: TScrollBarKind; APart: TACLScrollBarPart): TACLResourceTexture;
  end;

  { IACLScrollBar }

  IACLScrollBar = interface(IACLControl)
  ['{1C60D02A-9DA5-41B9-A616-C57075B728F9}']
    function AllowFading: Boolean;
    procedure Scroll(ACode: TScrollCode; var APosition: Integer);
  end;

  { TACLScrollInfo }

  TACLScrollInfo = packed record
    Max: Integer;
    Min: Integer;
    Page: Integer;
    Position: Integer;

    function CalculateProgressOffset(AValue: Integer): Integer;
  end;

  { TACLStyleScrollBox }

  TACLStyleScrollBox = class(TACLStyle, IACLScrollBarAppearance)
  protected
    procedure InitializeResources; override;
  public
    // IACLScrollBarAppearance
    procedure Draw(ACanvas: TCanvas; const ABounds: TRect;
      AKind: TScrollBarKind; APart: TACLScrollBarPart; AState: TACLButtonState);
    procedure DrawSizeGripArea(ACanvas: TCanvas; const R: TRect);
    function GetSkin(AKind: TScrollBarKind; APart: TACLScrollBarPart): TACLResourceTexture;
    function IsThumbResizable(AKind: TScrollBarKind): Boolean;
  published
    property TextureBackgroundHorz: TACLResourceTexture index 0 read GetTexture write SetTexture stored IsTextureStored;
    property TextureBackgroundVert: TACLResourceTexture index 1 read GetTexture write SetTexture stored IsTextureStored;
    property TextureButtonsHorz: TACLResourceTexture index 2 read GetTexture write SetTexture stored IsTextureStored;
    property TextureButtonsVert: TACLResourceTexture index 3 read GetTexture write SetTexture stored IsTextureStored;
    property TextureThumbHorz: TACLResourceTexture index 4 read GetTexture write SetTexture stored IsTextureStored;
    property TextureThumbVert: TACLResourceTexture index 5 read GetTexture write SetTexture stored IsTextureStored;
    property TextureSizeGripArea: TACLResourceTexture index 6 read GetTexture write SetTexture stored IsTextureStored;
  end;

  { TACLScrollBarViewItem }

  TACLScrollBarViewInfoItemClass = class of TACLScrollBarViewInfoItem;
  TACLScrollBarViewInfoItem = class(TACLUnknownObject, IACLAnimateControl)
  strict private
    FBounds: TRect;
    FOwner: TACLScrollBarSubClass;
    FPart: TACLScrollBarPart;
    FState: TACLButtonState;

    // IACLAnimateControl
    procedure IACLAnimateControl.Animate = Invalidate;
    procedure DrawCore(ACanvas: TCanvas; const R: TRect);
    function GetDisplayBounds: TRect;
    procedure SetState(AState: TACLButtonState);
  protected
    procedure AnimationInit1(out AAnimation: TACLAnimation); virtual;
    procedure AnimationInit2(AAnimation: TACLAnimation); virtual;
  public
    constructor Create(AOwner: TACLScrollBarSubClass; APart: TACLScrollBarPart);
    destructor Destroy; override;
    procedure Draw(ACanvas: TCanvas);
    procedure Invalidate;
    procedure UpdateState;
    //# Properties
    property Bounds: TRect read FBounds write FBounds;
    property DisplayBounds: TRect read GetDisplayBounds;
    property Owner: TACLScrollBarSubClass read FOwner;
    property Part: TACLScrollBarPart read FPart;
    property State: TACLButtonState read FState write SetState;
  end;

  { TACLScrollBarSubClass }

  TACLScrollBarSubClass = class(TACLControlSubClass)
  strict private
    FButtonDown: TACLScrollBarViewInfoItem;
    FButtonUp: TACLScrollBarViewInfoItem;
    FHotPart: TACLScrollBarPart;
    FKind: TScrollBarKind;
    FOwner: IACLScrollBar;
    FPressedMousePos: TPoint;
    FPressedPart: TACLScrollBarPart;
    FSaveThumbnailPos: TPoint;
    FScrollInfo: TACLScrollInfo;
    FSmallChange: Word;
    FStyle: IACLScrollBarAppearance;
    FThumbnail: TACLScrollBarViewInfoItem;
    FThumbnailSize: Integer;
    FTimer: TACLTimer;

    function CalculateButtonDownRect: TRect;
    function CalculateButtonUpRect: TRect;
    procedure CalculatePartStates;
    function CalculatePositionFromThumbnail(ATotal: Integer): Integer;
    procedure CalculateRects;
    function CalculateThumbnailRect: TRect;
    function GetPageDownRect: TRect;
    function GetPageUpRect: TRect;
    function GetPositionFromThumbnail: Integer;
    procedure MouseThumbTracking(const P: TPoint);
    procedure ScrollTimerHandler(ASender: TObject);
    procedure SetHotPart(APart: TACLScrollBarPart);
    procedure UpdateParts(AHotPart, APressedPart: TACLScrollBarPart);
    //# Messages
    procedure CMCancelMode(var Message: TCMCancelMode); message CM_CANCELMODE;
  public
    constructor Create(const AOwner: IACLScrollBar;
      const AStyle: IACLScrollBarAppearance;
      const AClass: TACLScrollBarViewInfoItemClass; AKind: TScrollBarKind);
    destructor Destroy; override;
    procedure Calculate(ABounds: TRect); override;
    procedure CheckScrollBarSizes(var AWidth, AHeight: Integer);
    procedure Draw(ACanvas: TCanvas); override;
    function HitTest(const P: TPoint): TACLScrollBarPart;
    //# Controller
    procedure CancelDrag;
    procedure MouseDown(AButton: TMouseButton; AShift: TShiftState; const P: TPoint); override;
    procedure MouseLeave; override;
    procedure MouseMove(AShift: TShiftState; const P: TPoint); override;
    procedure MouseUp(AButton: TMouseButton; AShift: TShiftState; const P: TPoint); override;
    procedure Scroll(AScrollCode: TScrollCode); overload;
    procedure Scroll(AScrollPart: TACLScrollBarPart); overload;
    function SetScrollParams(AMin, AMax, APosition, APageSize: Integer;
      ARedraw: Boolean = True): Boolean;
    //# Properties
    property ButtonDown: TACLScrollBarViewInfoItem read FButtonDown;
    property ButtonUp: TACLScrollBarViewInfoItem read FButtonUp;
    property HotPart: TACLScrollBarPart read FHotPart write SetHotPart;
    property Kind: TScrollBarKind read FKind write FKind;
    property Owner: IACLScrollBar read FOwner;
    property PageDownRect: TRect read GetPageDownRect;
    property PageUpRect: TRect read GetPageUpRect;
    property PressedPart: TACLScrollBarPart read FPressedPart;
    property ScrollInfo: TACLScrollInfo read FScrollInfo;
    property SmallChange: Word read FSmallChange write FSmallChange default 1;
    property Style: IACLScrollBarAppearance read FStyle;
    property Thumbnail: TACLScrollBarViewInfoItem read FThumbnail;
    property ThumbnailSize: Integer read FThumbnailSize;
  end;

  { TACLScrollBar }

  TACLScrollBar = class(TACLCustomControl, IACLScrollBar)
  strict private
    FStyle: TACLStyleScrollBox;
    FStyleOwnership: TStreamOwnership;
    FSubClass: TACLScrollBarSubClass;

    FOnScroll: TScrollEvent;

    function GetKind: TScrollBarKind;
    function GetPosition: Integer;
    function GetScrollInfo: TACLScrollInfo;
    function GetSmallChange: Word;
    procedure SetKind(Value: TScrollBarKind);
    procedure SetPosition(AValue: Integer);
    procedure SetSmallChange(AValue: Word);
    procedure SetStyle(AValue: TACLStyleScrollBox);
  protected
    // IACLScrollBar
    function AllowFading: Boolean;
    procedure Scroll(ScrollCode: TScrollCode; var ScrollPos: Integer); virtual;

    //# Mouse
    function MouseWheel(Direction: TACLMouseWheelDirection;
      Shift: TShiftState; const MousePos: TPoint): Boolean; override;
    //# Paint
    procedure Paint; override;
    procedure SetTargetDPI(AValue: Integer); override;
    procedure UpdateTransparency; override;

    //# Messages
    procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
    procedure CMVisibleChanged(var Message: TMessage); message CM_VISIBLECHANGED;
    procedure CNHScroll(var Message: TWMHScroll); message CN_HSCROLL;
    procedure CNVScroll(var Message: TWMVScroll); message CN_VSCROLL;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;

    //# Properties
    property SubClass: TACLScrollBarSubClass read FSubClass;
  public
    constructor Create(AOwner: TComponent); override;
    constructor CreateEx(AOwner: TComponent; AKind: TScrollBarKind;
      AStyle: TACLStyleScrollBox; AStyleOwnership: TStreamOwnership);
    destructor Destroy; override;
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: Integer); override;
    procedure SetScrollParams(AMin, AMax, APosition, APageSize: Integer; ARedraw: Boolean = True); overload;
    procedure SetScrollParams(const AInfo: TScrollInfo; ARedraw: Boolean = True); overload;
    //# Properties
    property Position: Integer read GetPosition write SetPosition;
    property ScrollInfo: TACLScrollInfo read GetScrollInfo;
  published
    property Align;
    property Anchors;
    property Constraints;
    property Enabled;
    property Kind: TScrollBarKind read GetKind write SetKind default sbHorizontal;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property SmallChange: Word read GetSmallChange write SetSmallChange default 1;
    property ResourceCollection;
    property Style: TACLStyleScrollBox read FStyle write SetStyle;
    property Visible;
    //# Events
    property OnScroll: TScrollEvent read FOnScroll write FOnScroll;
  end;

implementation

{$IFNDEF FPC}
uses
  ACL.Graphics.SkinImageSet;
{$ENDIF}

const
  SCROLL_BAR_TIMER_PARTS = [sbpLineUp, sbpLineDown, sbpPageUp, sbpPageDown];

{ TACLScrollInfo }

function TACLScrollInfo.CalculateProgressOffset(AValue: Integer): Integer;
begin
  if (AValue > 0) and (Max <> Min) then
    Result := MulDiv(AValue, Position - Min, Max - Min)
  else
    Result := 0;
end;

{ TACLStyleScrollBox }

procedure TACLStyleScrollBox.Draw(ACanvas: TCanvas; const ABounds: TRect;
  AKind: TScrollBarKind; APart: TACLScrollBarPart; AState: TACLButtonState);
var
  LFrame: Integer;
  LSkin: TACLResourceTexture;
begin
  LSkin := GetSkin(AKind, APart);
  if LSkin <> nil then
  begin
    LFrame := Ord(AState);
    if APart = sbpLineDown then
      Inc(LFrame, 4);
    LSkin.Draw(ACanvas, ABounds, LFrame);
  end;
end;

procedure TACLStyleScrollBox.DrawSizeGripArea(ACanvas: TCanvas; const R: TRect);
begin
  TextureSizeGripArea.Draw(ACanvas, R);
end;

procedure TACLStyleScrollBox.InitializeResources;
begin
  TextureBackgroundHorz.InitailizeDefaults('ScrollBox.Textures.Horz.Background');
  TextureBackgroundVert.InitailizeDefaults('ScrollBox.Textures.Vert.Background');
  TextureButtonsHorz.InitailizeDefaults('ScrollBox.Textures.Horz.Buttons');
  TextureButtonsVert.InitailizeDefaults('ScrollBox.Textures.Vert.Buttons');
  TextureSizeGripArea.InitailizeDefaults('ScrollBox.Textures.SizeGrip');
  TextureThumbHorz.InitailizeDefaults('ScrollBox.Textures.Horz.Thumb');
  TextureThumbVert.InitailizeDefaults('ScrollBox.Textures.Vert.Thumb');
end;

function TACLStyleScrollBox.GetSkin(
  AKind: TScrollBarKind; APart: TACLScrollBarPart): TACLResourceTexture;
begin
  case APart of
    sbpNone:
      if AKind = sbHorizontal then
        Result := TextureBackgroundHorz
      else
        Result := TextureBackgroundVert;

    sbpThumbnail:
      if AKind = sbVertical then
        Result := TextureThumbVert
      else
        Result := TextureThumbHorz;

    sbpLineDown, sbpLineUp:
      if AKind = sbHorizontal then
        Result := TextureButtonsHorz
      else
        Result := TextureButtonsVert;

  else
    Result := nil;
  end;
end;

function TACLStyleScrollBox.IsThumbResizable(AKind: TScrollBarKind): Boolean;
var
  LSkin: TACLResourceTexture;
begin
  LSkin := GetSkin(AKind, sbpThumbnail);
  Result := not ((LSkin.StretchMode = isCenter) and LSkin.Margins.IsZero);
end;

{ TACLScrollBarViewInfoItem }

constructor TACLScrollBarViewInfoItem.Create(
  AOwner: TACLScrollBarSubClass; APart: TACLScrollBarPart);
begin
  inherited Create;
  FOwner := AOwner;
  FPart := APart;
end;

destructor TACLScrollBarViewInfoItem.Destroy;
begin
  AnimationManager.RemoveOwner(Self);
  inherited Destroy;
end;

procedure TACLScrollBarViewInfoItem.AnimationInit1(out AAnimation: TACLAnimation);
var
  LAnimation: TACLBitmapAnimation absolute AAnimation;
begin
  LAnimation := TACLBitmapAnimation.Create(Self, DisplayBounds, TACLAnimatorFadeOut.Create);
  LAnimation.BuildFrame1(DrawCore);
end;

procedure TACLScrollBarViewInfoItem.AnimationInit2(AAnimation: TACLAnimation);
var
  LAnimation: TACLBitmapAnimation absolute AAnimation;
begin
  LAnimation.BuildFrame2(DrawCore);
  LAnimation.Run;
end;

procedure TACLScrollBarViewInfoItem.Draw(ACanvas: TCanvas);
begin
  if not AnimationManager.Draw(Self, ACanvas, DisplayBounds) then
    DrawCore(ACanvas, DisplayBounds);
end;

procedure TACLScrollBarViewInfoItem.DrawCore(ACanvas: TCanvas; const R: TRect);
begin
  Owner.Style.Draw(ACanvas, R, Owner.Kind, Part, State);
end;

function TACLScrollBarViewInfoItem.GetDisplayBounds: TRect;
begin
  Result := Bounds;
  if Part = sbpThumbnail then
    Result.Inflate(Owner.Style.GetSkin(Owner.Kind, sbpThumbnail).ContentOffsets);
end;

procedure TACLScrollBarViewInfoItem.Invalidate;
begin
  Owner.Owner.InvalidateRect(Bounds);
end;

procedure TACLScrollBarViewInfoItem.SetState(AState: TACLButtonState);
var
  LAnimation: TACLAnimation;
begin
  if AState <> FState then
  begin
    if (State = absHover) and (AState = absNormal) and Owner.Owner.AllowFading then
    begin
      AnimationInit1(LAnimation);
      FState := AState;
      AnimationInit2(LAnimation);
    end
    else
      FState := AState;

    Invalidate;
  end;
end;

procedure TACLScrollBarViewInfoItem.UpdateState;
begin
  if not Owner.Owner.GetEnabled then
    State := absDisabled
  else if Owner.PressedPart = Part then
    State := absPressed
  else if Owner.HotPart = Part then
    State := absHover
  else
    State := absNormal;
end;

{ TACLScrollBarSubClass }

constructor TACLScrollBarSubClass.Create(
  const AOwner: IACLScrollBar;
  const AStyle: IACLScrollBarAppearance;
  const AClass: TACLScrollBarViewInfoItemClass; AKind: TScrollBarKind);
begin
  inherited Create(AOwner);
  FKind := AKind;
  FOwner := AOwner;
  FStyle := AStyle;
  FSmallChange := 1;
  FScrollInfo.Max := 100;
  FButtonDown := AClass.Create(Self, sbpLineDown);
  FThumbnail := AClass.Create(Self, sbpThumbnail);
  FButtonUp := AClass.Create(Self, sbpLineUp);
  FTimer := TACLTimer.CreateEx(ScrollTimerHandler, acScrollBarTimerInitialDelay);
end;

destructor TACLScrollBarSubClass.Destroy;
begin
  FreeAndNil(FTimer);
  FreeAndNil(FButtonDown);
  FreeAndNil(FThumbnail);
  FreeAndNil(FButtonUp);
  inherited Destroy;
end;

procedure TACLScrollBarSubClass.Calculate(ABounds: TRect);
var
  LSkin: TACLResourceTexture;
begin
  inherited;
  LSkin := Style.GetSkin(Kind, sbpThumbnail);
  if Kind = sbVertical then
    FThumbnailSize := LSkin.FrameHeight - LSkin.ContentOffsets.MarginsHeight
  else
    FThumbnailSize := LSkin.FrameWidth - LSkin.ContentOffsets.MarginsWidth;

  CalculateRects;
  CalculatePartStates;
end;

function TACLScrollBarSubClass.CalculatePositionFromThumbnail(ATotal: Integer): Integer;
begin
  if Kind = sbHorizontal then
    Result := MulDiv(ATotal, Thumbnail.Bounds.Left - ButtonUp.Bounds.Right,
      ButtonDown.Bounds.Left - ButtonUp.Bounds.Right - Thumbnail.Bounds.Width)
  else
    Result := MulDiv(ATotal, Thumbnail.Bounds.Top - ButtonUp.Bounds.Bottom,
      ButtonDown.Bounds.Top - ButtonUp.Bounds.Bottom - Thumbnail.Bounds.Height);
end;

procedure TACLScrollBarSubClass.CalculatePartStates;
begin
  ButtonDown.UpdateState;
  Thumbnail.UpdateState;
  ButtonUp.UpdateState;
end;

procedure TACLScrollBarSubClass.CalculateRects;
begin
  ButtonDown.Bounds := CalculateButtonDownRect;
  ButtonUp.Bounds := CalculateButtonUpRect;
  Thumbnail.Bounds := CalculateThumbnailRect; // last
end;

function TACLScrollBarSubClass.CalculateButtonDownRect: TRect;
var
  LSkin: TACLResourceTexture;
begin
  LSkin := Style.GetSkin(Kind, sbpLineDown);
  if Kind = sbHorizontal then
  begin
    Result := Bounds;
    Result.Left := Result.Right - LSkin.FrameWidth;
  end
  else
  begin
    Result := Bounds;
    Result.Top := Result.Bottom - LSkin.FrameHeight;
  end;
end;

function TACLScrollBarSubClass.CalculateButtonUpRect: TRect;
var
  LSkin: TACLResourceTexture;
begin
  LSkin := Style.GetSkin(Kind, sbpLineUp);
  if Kind = sbHorizontal then
  begin
    Result := Bounds;
    Result.Width := LSkin.FrameWidth;
  end
  else
  begin
    Result := Bounds;
    Result.Height := LSkin.FrameHeight;
  end;
end;

function TACLScrollBarSubClass.CalculateThumbnailRect: TRect;
var
  ADelta, ASize, ATempValue: Integer;
begin
  Result := NullRect;
  if Owner.GetEnabled then
  begin
    if Kind = sbHorizontal then
    begin
      ADelta := ButtonDown.Bounds.Left - ButtonUp.Bounds.Right;
      if ScrollInfo.Page = 0 then
      begin
        ASize := ThumbnailSize;
        if ASize > ADelta then Exit;
        Dec(ADelta, ASize);
        ATempValue := ButtonUp.Bounds.Right + ScrollInfo.CalculateProgressOffset(ADelta);
        Result := Rect(ATempValue, Bounds.Top, ATempValue + ASize, Bounds.Bottom);
      end
      else
      begin
        ASize := Min(ADelta, MulDiv(ScrollInfo.Page, ADelta, ScrollInfo.Max - ScrollInfo.Min + 1));
        if (ADelta < ThumbnailSize) or (ScrollInfo.Max = ScrollInfo.Min) then Exit;
        ASize := Max(ThumbnailSize, ASize);
        Dec(ADelta, ASize);
        Result := {System.}Classes.Bounds(ButtonUp.Bounds.Right, Bounds.Top, ASize, Bounds.Height);
        ASize := (ScrollInfo.Max - ScrollInfo.Min) - (ScrollInfo.Page - 1);
        Result.Offset(MulDiv(ADelta, Min(ScrollInfo.Position - ScrollInfo.Min, ASize), ASize), 0);
      end;
    end
    else
    begin
      ADelta := ButtonDown.Bounds.Top - ButtonUp.Bounds.Bottom;
      if ScrollInfo.Page = 0 then
      begin
        ASize := ThumbnailSize;
        if ASize > ADelta then Exit;
        Dec(ADelta, ASize);
        ATempValue := ButtonUp.Bounds.Bottom + ScrollInfo.CalculateProgressOffset(ADelta);
        Result := Rect(Bounds.Left, ATempValue, Bounds.Right, ATempValue + ASize)
      end
      else
      begin
        ASize := Min(ADelta, MulDiv(ScrollInfo.Page, ADelta, ScrollInfo.Max - ScrollInfo.Min + 1));
        if (ADelta < ThumbnailSize) or (ScrollInfo.Max = ScrollInfo.Min) then Exit;
        ASize := Max(ASize, ThumbnailSize);
        Dec(ADelta, ASize);
        Result := {System.}Classes.Bounds(Bounds.Left, ButtonUp.Bounds.Bottom, Bounds.Width, ASize);
        ASize := (ScrollInfo.Max - ScrollInfo.Min) - (ScrollInfo.Page - 1);
        Result.Offset(0, MulDiv(ADelta, Min(ScrollInfo.Position - ScrollInfo.Min, ASize), ASize));
      end;
    end;
  end;
end;

procedure TACLScrollBarSubClass.CancelDrag;
begin
  if PressedPart <> sbpNone then
  begin
    FTimer.Enabled := False;
    if PressedPart = sbpThumbnail then
    begin
      FScrollInfo.Position := GetPositionFromThumbnail;
      Scroll(scPosition);
    end;
    UpdateParts(sbpNone, sbpNone);
    Scroll(scEndScroll);
    CalculateRects;
    Invalidate;
  end;
end;

procedure TACLScrollBarSubClass.CheckScrollBarSizes(var AWidth, AHeight: Integer);
var
  LSkin: TACLResourceTexture;
begin
  LSkin := Style.GetSkin(Kind, sbpNone);
  if Kind = sbHorizontal then
    AHeight := LSkin.FrameHeight
  else
    AWidth := LSkin.FrameWidth;
end;

procedure TACLScrollBarSubClass.CMCancelMode(var Message: TCMCancelMode);
begin
  CancelDrag;
  inherited;
end;

procedure TACLScrollBarSubClass.Draw(ACanvas: TCanvas);
begin
  Style.Draw(ACanvas, Bounds, Kind, sbpNone, absNormal);
  ButtonUp.Draw(ACanvas);
  ButtonDown.Draw(ACanvas);
  Thumbnail.Draw(ACanvas);
end;

function TACLScrollBarSubClass.GetPageDownRect: TRect;
begin
  if Thumbnail.Bounds.IsEmpty then
    Exit(NullRect);
  if Kind = sbHorizontal then
    Result := Rect(Thumbnail.Bounds.Right, Bounds.Top, ButtonDown.Bounds.Left, Bounds.Bottom)
  else
    Result := Rect(Bounds.Left, Thumbnail.Bounds.Bottom, Bounds.Right, ButtonDown.Bounds.Top);
end;

function TACLScrollBarSubClass.GetPageUpRect: TRect;
begin
  if Thumbnail.Bounds.IsEmpty then
    Exit(NullRect);
  if Kind = sbHorizontal then
    Result := Rect(ButtonUp.Bounds.Right, Bounds.Top, Thumbnail.Bounds.Left, Bounds.Bottom)
  else
    Result := Rect(Bounds.Left, ButtonUp.Bounds.Bottom, Bounds.Right, Thumbnail.Bounds.Top);
end;

function TACLScrollBarSubClass.GetPositionFromThumbnail: Integer;
begin
  Result := ScrollInfo.Min + CalculatePositionFromThumbnail(
    ScrollInfo.Max - ScrollInfo.Min + IfThen(ScrollInfo.Page > 0, - ScrollInfo.Page + 1));
end;

function TACLScrollBarSubClass.HitTest(const P: TPoint): TACLScrollBarPart;
begin
  if PtInRect(Thumbnail.DisplayBounds, P) then // first
    Result := sbpThumbnail
  else if PtInRect(ButtonUp.DisplayBounds, P) then
    Result := sbpLineUp
  else if PtInRect(ButtonDown.DisplayBounds, P) then
    Result := sbpLineDown
  else if PtInRect(PageUpRect, P) then
    Result := sbpPageUp
  else if PtInRect(PageDownRect, P) then
    Result := sbpPageDown
  else
    Result := sbpNone;
end;

procedure TACLScrollBarSubClass.MouseDown(
  AButton: TMouseButton; AShift: TShiftState; const P: TPoint);
var
  APart: TACLScrollBarPart;
begin
  if AButton = mbMiddle then
  begin
    Include(AShift, ssShift);
    AButton := mbLeft;
  end;

  if AButton = mbLeft then
  begin
    APart := HitTest(P);
    if APart <> sbpNone then
    begin
      if APart = sbpThumbnail then
      begin
        FPressedMousePos := P;
        FSaveThumbnailPos := Thumbnail.Bounds.TopLeft;
        Scroll(scTrack);
      end;
      if APart in SCROLL_BAR_TIMER_PARTS then
      begin
        if ssShift in AShift then
        begin
          FSaveThumbnailPos := Thumbnail.Bounds.TopLeft;
          FPressedMousePos := Thumbnail.Bounds.CenterPoint;
          Scroll(scTrack);
          MouseThumbTracking(P);
          APart := sbpThumbnail;
        end
        else
        begin
          Scroll(APart);
          FTimer.Interval := acScrollBarTimerInitialDelay;
          FTimer.Enabled := True;
        end;
      end;
      UpdateParts(APart, APart);
      Invalidate;
      Owner.Update;
    end;
  end;
end;

procedure TACLScrollBarSubClass.MouseLeave;
begin
  if PressedPart <> sbpThumbnail then
    HotPart := sbpNone;
end;

procedure TACLScrollBarSubClass.MouseMove(AShift: TShiftState; const P: TPoint);
var
  LPart: TACLScrollBarPart;
begin
  if PressedPart = sbpThumbnail then
    MouseThumbTracking(P)
  else
  begin
    LPart := HitTest(P);
    if PressedPart <> sbpNone then
      FTimer.Enabled := PressedPart = LPart;
    HotPart := LPart;
  end;
end;

procedure TACLScrollBarSubClass.MouseThumbTracking(const P: TPoint);
var
  ADelta, ASize: Integer;
  ANewPos: Integer;
begin
  if PtInRect(Bounds.InflateTo(acScrollBarHitArea), P) then
  begin
    if Kind = sbHorizontal then
    begin
      ADelta := P.X - FPressedMousePos.X;
      if ADelta <> 0 then
      begin
        ASize := Thumbnail.Bounds.Width;
        if (ADelta < 0) and (FSaveThumbnailPos.X + ADelta < ButtonUp.Bounds.Right) then
          ADelta := ButtonUp.Bounds.Right - FSaveThumbnailPos.X;
        if (ADelta > 0) and (FSaveThumbnailPos.X + ASize + ADelta > ButtonDown.Bounds.Left) then
          ADelta := ButtonDown.Bounds.Left - (FSaveThumbnailPos.X + ASize);
        Thumbnail.Bounds.Offset(-Thumbnail.Bounds.Left + FSaveThumbnailPos.X + ADelta, 0)
      end
    end
    else
    begin
      ADelta := P.Y - FPressedMousePos.Y;
      if ADelta <> 0 then
      begin
        ASize := Thumbnail.Bounds.Height;
        if (ADelta < 0) and (FSaveThumbnailPos.Y + ADelta < ButtonUp.Bounds.Bottom) then
          ADelta := ButtonUp.Bounds.Bottom - FSaveThumbnailPos.Y;
        if (ADelta > 0) and (FSaveThumbnailPos.Y + ASize + ADelta > ButtonDown.Bounds.Top) then
          ADelta := ButtonDown.Bounds.Top - (FSaveThumbnailPos.Y + ASize);
        Thumbnail.Bounds.Offset(0, -Thumbnail.Bounds.Top + FSaveThumbnailPos.Y + ADelta);
      end;
    end;
  end
  else
    Thumbnail.Bounds.Location := FSaveThumbnailPos;

  ANewPos := GetPositionFromThumbnail;
  if ANewPos <> ScrollInfo.Position then
  begin
    FScrollInfo.Position := ANewPos;
    Scroll(sbpThumbnail);
  end;
  Invalidate;
end;

procedure TACLScrollBarSubClass.MouseUp(
  AButton: TMouseButton; AShift: TShiftState; const P: TPoint);
begin
  CancelDrag;
  HotPart := HitTest(P);
end;

procedure TACLScrollBarSubClass.Scroll(AScrollCode: TScrollCode);
var
  ANewPos: Integer;
begin
  ANewPos := ScrollInfo.Position;
  case AScrollCode of
    scLineUp:
      Dec(ANewPos, SmallChange);
    scLineDown:
      Inc(ANewPos, SmallChange);
    scPageUp:
      Dec(ANewPos, {System.}Math.Max(SmallChange, ScrollInfo.Page));
    scPageDown:
      Inc(ANewPos, {System.}Math.Max(SmallChange, ScrollInfo.Page));
    scTop:
      ANewPos := ScrollInfo.Min;
    scBottom:
      ANewPos := ScrollInfo.Max;
  else;
  end;

  ANewPos := MinMax(ANewPos, ScrollInfo.Min, ScrollInfo.Max - ScrollInfo.Page + 1);
  Owner.Scroll(AScrollCode, ANewPos);
  ANewPos := MinMax(ANewPos, ScrollInfo.Min, ScrollInfo.Max - ScrollInfo.Page + 1);

  if ANewPos <> ScrollInfo.Position then
    SetScrollParams(ScrollInfo.Min, ScrollInfo.Max, ANewPos, ScrollInfo.Page);
end;

procedure TACLScrollBarSubClass.Scroll(AScrollPart: TACLScrollBarPart);
const
  ScrollCodeMap: array[TACLScrollBarPart] of TScrollCode = (
    scLineUp, scLineUp, scLineDown, scTrack, scPageUp, scPageDown
  );
begin
  if AScrollPart <> sbpNone then
    Scroll(ScrollCodeMap[AScrollPart]);
end;

function TACLScrollBarSubClass.SetScrollParams(
  AMin, AMax, APosition, APageSize: Integer;
  ARedraw: Boolean = True): Boolean;
var
  LBoundsChanged: Boolean;
begin
  if not Style.IsThumbResizable(Kind) then
  begin
    if APageSize > 1 then
      Dec(AMax, APageSize);
    APageSize := 0;
  end;
  AMax := Max(AMax, AMin);
  APageSize := Min(APageSize, AMax - AMin);
  APosition := MinMax(APosition, AMin, AMax - APageSize + 1);

  LBoundsChanged :=
    (ScrollInfo.Min <> AMin) or
    (ScrollInfo.Max <> AMax) or
    (ScrollInfo.Page = APageSize);
  Result := ScrollInfo.Position <> APosition;

  FScrollInfo.Position := APosition;
  FScrollInfo.Page := APageSize;
  FScrollInfo.Min := AMin;
  FScrollInfo.Max := AMax;

  if (PressedPart <> sbpThumbnail) or LBoundsChanged then
    Calculate(Bounds);
  if ARedraw and (LBoundsChanged or Result) then
  begin
    Invalidate;
    if PressedPart = sbpThumbnail then
      Owner.Update;
  end;
end;

procedure TACLScrollBarSubClass.UpdateParts(AHotPart, APressedPart: TACLScrollBarPart);
begin
  if (AHotPart <> FHotPart) or (APressedPart <> FPressedPart) then
  begin
    FPressedPart := APressedPart;
    FHotPart := AHotPart;
    CalculatePartStates;
  end;
end;

procedure TACLScrollBarSubClass.ScrollTimerHandler(ASender: TObject);
begin
  if PressedPart in SCROLL_BAR_TIMER_PARTS then
  begin
    FTimer.Interval := acScrollBarTimerScrollInterval;
    FTimer.Enabled := HitTest(Owner.ScreenToClient(MouseCursorPos)) = PressedPart;
    if FTimer.Enabled then
      Scroll(PressedPart);
  end
  else
    CancelDrag;
end;

procedure TACLScrollBarSubClass.SetHotPart(APart: TACLScrollBarPart);
begin
  UpdateParts(APart, PressedPart);
end;

{ TACLScrollBar }

constructor TACLScrollBar.Create(AOwner: TComponent);
begin
  CreateEx(AOwner, sbHorizontal, TACLStyleScrollBox.Create(Self), soOwned);
end;

constructor TACLScrollBar.CreateEx(AOwner: TComponent; AKind: TScrollBarKind;
  AStyle: TACLStyleScrollBox; AStyleOwnership: TStreamOwnership);
begin
  inherited Create(AOwner);
  ControlStyle := [csOpaque, csCaptureMouse];
  FStyle := AStyle;
  FStyleOwnership := AStyleOwnership;
  FDefaultSize := TSize.Create(200, 20);
  RegisterSubClass(FSubClass,
    TACLScrollBarSubClass.Create(Self, Style, TACLScrollBarViewInfoItem, AKind));
  DoubleBuffered := True;
  FocusOnClick := False;
end;

destructor TACLScrollBar.Destroy;
begin
  inherited Destroy;
  if FStyleOwnership = soOwned then
    FreeAndNil(FStyle);
end;

procedure TACLScrollBar.Paint;
begin
  SubClasses.Draw(Canvas);
end;

function TACLScrollBar.MouseWheel(Direction: TACLMouseWheelDirection;
  Shift: TShiftState; const MousePos: TPoint): Boolean;
begin
  Result := Enabled;
  if Result then
    SubClass.Scroll(TACLMouseWheel.DirectionToScrollCode[Direction]);
end;

procedure TACLScrollBar.Scroll(ScrollCode: TScrollCode; var ScrollPos: Integer);
begin
  if Assigned(OnScroll) then OnScroll(Self, ScrollCode, ScrollPos);
end;

procedure TACLScrollBar.CMEnabledChanged(var Message: TMessage);
begin
  inherited;
  SubClass.CancelDrag;
  SubClass.Calculate(ClientRect);
  Invalidate;
end;

procedure TACLScrollBar.CNHScroll(var Message: TWMHScroll);
begin
  SubClass.Scroll(TScrollCode(Message.ScrollCode));
end;

procedure TACLScrollBar.CMVisibleChanged(var Message: TMessage);
begin
  SubClass.CancelDrag;
  inherited;
end;

procedure TACLScrollBar.CNVScroll(var Message: TWMVScroll);
begin
  SubClass.Scroll(TScrollCode(Message.ScrollCode));
end;

procedure TACLScrollBar.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure TACLScrollBar.SetTargetDPI(AValue: Integer);
begin
  inherited SetTargetDPI(AValue);
  Style.TargetDPI := AValue;
end;

function TACLScrollBar.AllowFading: Boolean;
begin
  Result := acUIAnimations;
end;

function TACLScrollBar.GetKind: TScrollBarKind;
begin
  Result := SubClass.Kind;
end;

function TACLScrollBar.GetPosition: Integer;
begin
  Result := SubClass.ScrollInfo.Position;
end;

function TACLScrollBar.GetScrollInfo: TACLScrollInfo;
begin
  Result := SubClass.ScrollInfo;
end;

function TACLScrollBar.GetSmallChange: Word;
begin
  Result := SubClass.SmallChange;
end;

procedure TACLScrollBar.SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
begin
  if not (csLoading in ComponentState) then
    SubClass.CheckScrollBarSizes(AWidth, AHeight);
  inherited SetBounds(ALeft, ATop, AWidth, AHeight);
  SubClass.Calculate(ClientRect);
end;

procedure TACLScrollBar.SetScrollParams(
  AMin, AMax, APosition, APageSize: Integer; ARedraw: Boolean = True);
begin
  SubClass.SetScrollParams(AMin, AMax, APosition, APageSize, ARedraw);
end;

procedure TACLScrollBar.SetScrollParams(
  const AInfo: TScrollInfo; ARedraw: Boolean = True);
begin
  SetScrollParams(AInfo.nMin, AInfo.nMax, AInfo.nPos, AInfo.nPage, ARedraw);
end;

procedure TACLScrollBar.SetSmallChange(AValue: Word);
begin
  SubClass.SmallChange := Max(AValue, 1);
end;

procedure TACLScrollBar.SetKind(Value: TScrollBarKind);
begin
  if Kind <> Value then
  begin
    SubClass.Kind := Value;
    UpdateTransparency;
    AdjustSize;
    Invalidate;
  end;
end;

procedure TACLScrollBar.SetPosition(AValue: Integer);
var
  LInfo: TACLScrollInfo;
begin
  LInfo := GetScrollInfo;
  SetScrollParams(LInfo.Min, LInfo.Max, AValue, LInfo.Page);
end;

procedure TACLScrollBar.SetStyle(AValue: TACLStyleScrollBox);
begin
  FStyle.Assign(AValue);
end;

procedure TACLScrollBar.UpdateTransparency;
begin
  if Style.GetSkin(Kind, sbpNone).HasAlpha then
    ControlStyle := ControlStyle - [csOpaque]
  else
    ControlStyle := ControlStyle + [csOpaque]
end;

end.
