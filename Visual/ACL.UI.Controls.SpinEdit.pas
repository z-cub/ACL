////////////////////////////////////////////////////////////////////////////////
//
//  Project:   Artem's Controls Library aka ACL
//             v7.0
//
//  Purpose:   SpinEdit
//
//  Author:    Artem Izmaylov
//             © 2006-2025
//             www.aimp.ru
//
//  FPC:       OK
//
unit ACL.UI.Controls.SpinEdit;

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
  {System.}Variants,
  {System.}Types,
  System.UITypes,
  // Vcl
  {Vcl.}Controls,
  {Vcl.}Forms,
  {Vcl.}Graphics,
  {Vcl.}Dialogs,
  // ACL
  ACL.Classes,
  ACL.Graphics.SkinImage,
  ACL.MUI,
  ACL.Timers,
  ACL.UI.Controls.Base,
  ACL.UI.Controls.BaseEditors,
  ACL.UI.Controls.Buttons,
  ACL.UI.Resources,
  ACL.Utils.DPIAware;

type
{$REGION ' Custom '}

  TACLSpinEditValueType = (evtInteger, evtFloat);

  { TACLStyleSpinButton }

  TACLStyleSpinButton = class(TACLStyleEditButton)
  protected
    procedure InitializeTextures; override;
  end;

  { TACLSpinButtonSubClass }

  TACLSpinButtonSubClass = class(TACLSimpleButtonSubClass)
  protected
    procedure DrawBackground(ACanvas: TCanvas; const R: TRect); override;
  end;

  { TACLCustomSpinEdit }

  TACLCustomSpinEdit = class(TACLCustomEdit)
  strict private
    FAutoClick: TACLSimpleButtonSubClass;
    FAutoClickWaitCount: Integer;
    FButtonLeft: TACLSimpleButtonSubClass;
    FButtonRight: TACLSimpleButtonSubClass;

    procedure SetAutoClick(AButton: TACLSimpleButtonSubClass);
    //# Messages
    procedure CMCancelMode(var Message: TCMCancelMode); message CM_CANCELMODE;
    procedure WMTimer(var Message: TWMTimer); message WM_TIMER;
  protected
    procedure Calculate(ABounds: TRect); override;
    function CanAutoSize(var AWidth, AHeight: Integer): Boolean; override;
    procedure CheckInput(var AText, APart1, APart2: string; var AAccept: Boolean); virtual;
    function CreateStyleButton: TACLStyleButton; override;
    //# Keyboard
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    //# Mouse
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function MouseWheel(Direction: TACLMouseWheelDirection;
      Shift: TShiftState; const MousePos: TPoint): Boolean; override;
    //# Paint
    procedure PaintCore; override;
    //# Properties
    property ButtonLeft: TACLSimpleButtonSubClass read FButtonLeft;
    property ButtonRight: TACLSimpleButtonSubClass read FButtonRight;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Increase(AStep: Integer); virtual;
  published
    property AutoSize;
    property Anchors;
    property Enabled;
    property ResourceCollection;
    property Style;
    property StyleButton;
    property TabOrder;
    //# Events
    property OnChange;
  end;

{$ENDREGION}

{$REGION ' SpinEdit '}

  { TACLSpinEditOptionsValue }

  TACLSpinEdit = class;
  TACLSpinEditAssignedValue = (seavIncCount, seavMaxValue, seavMinValue);
  TACLSpinEditAssignedValues = set of TACLSpinEditAssignedValue;

  TACLSpinEditOptionsValue = class(TACLLockablePersistent)
  strict private const
    DefaultDisplayFormat = '%s';
    DefaultFloatPrecision = 2;
  strict private
    FAssignedValues: TACLSpinEditAssignedValues;
    FDisplayFormat: string;
    FFloatPrecision: Integer;
    FOwner: TACLSpinEdit;
    FValues: array[0..2] of Variant;
    FValueType: TACLSpinEditValueType;

    function GetValue(const Index: Integer): Variant;
    function IsDisplayFormatStored: Boolean;
    function IsValueStored(const Index: Integer): Boolean;
    procedure SetAssignedValues(const Value: TACLSpinEditAssignedValues);
    procedure SetDisplayFormat(const Value: string);
    procedure SetFloatPrecision(AValue: Integer);
    procedure SetValue(const Index: Integer; const AValue: Variant);
    procedure SetValueType(const Value: TACLSpinEditValueType);
  protected
    procedure DoAssign(Source: TPersistent); override;
    procedure DoChanged(AChanges: TACLPersistentChanges); override;
    procedure ValidateValue(var V: Variant);
    procedure ValidateValueType(var V: Variant);
  public
    constructor Create(AOwner: TACLSpinEdit); virtual;
    function ValueToText(const AValue: Variant): string;
  published
    property ValueType: TACLSpinEditValueType read FValueType write SetValueType default evtInteger; // first!
    property AssignedValues: TACLSpinEditAssignedValues read FAssignedValues write SetAssignedValues stored False;
    property DisplayFormat: string read FDisplayFormat write SetDisplayFormat stored IsDisplayFormatStored;
    property FloatPrecision: Integer read FFloatPrecision write SetFloatPrecision default DefaultFloatPrecision;
    property IncCount: Variant index 0 read GetValue write SetValue stored IsValueStored;
    property MaxValue: Variant index 1 read GetValue write SetValue stored IsValueStored;
    property MinValue: Variant index 2 read GetValue write SetValue stored IsValueStored;
  end;

  { TACLSpinEdit }

  TACLSpinEdit = class(TACLCustomSpinEdit)
  strict private
    FChanging: Boolean;
    FOptionsValue: TACLSpinEditOptionsValue;
    FValue: Variant;

    FOnGetDisplayText: TACLEditGetDisplayTextEvent;

    function IsValueStored: Boolean;
    procedure SetOnGetDisplayText(AValue: TACLEditGetDisplayTextEvent);
    procedure SetOptionsValue(AValue: TACLSpinEditOptionsValue);
    procedure SetValue(AValue: Variant);
    //# Messages
    procedure CMExit(var Message: TCMEnter); message CM_EXIT;
  protected
    procedure CheckInput(var AText, APart1, APart2: string; var AAccept: Boolean); override;
    function GetDisplayText: string; virtual;
    procedure TextChanged; override;
    procedure UpdateDisplayValue;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AfterConstruction; override;
    procedure Increase(AStep: Integer); override;
  published
    property Align;
    property AutoSelect default True;
    property OptionsValue: TACLSpinEditOptionsValue read FOptionsValue write SetOptionsValue;
    property Value: Variant read FValue write SetValue stored IsValueStored;
    property OnGetDisplayText: TACLEditGetDisplayTextEvent read FOnGetDisplayText write SetOnGetDisplayText;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
  end;

{$ENDREGION}

implementation

uses
{$IFNDEF FPC}
  ACL.Graphics.SkinImageSet, // inlinging
{$ENDIF}
  ACL.Geometry,
  ACL.Graphics,
  ACL.Math,
  ACL.Utils.Common,
  ACL.Utils.Strings;

{$REGION ' Custom '}

{ TACLStyleSpinButton }

procedure TACLStyleSpinButton.InitializeTextures;
begin
  Texture.InitailizeDefaults('EditBox.Textures.SpinButton');
end;

{ TACLSpinButtonSubClass }

procedure TACLSpinButtonSubClass.DrawBackground(ACanvas: TCanvas; const R: TRect);
begin
  Style.Texture.Draw(ACanvas, R, Ord(State) + 5 * Ord(Tag > 0));
end;

{ TACLCustomSpinEdit }

constructor TACLCustomSpinEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDefaultSize := TSize.Create(100, 20);
  RegisterSubClass(FButtonLeft, TACLSpinButtonSubClass.Create(Self, StyleButton));
  RegisterSubClass(FButtonRight, TACLSpinButtonSubClass.Create(Self, StyleButton));
  FEditBox.OnInput := CheckInput;
  FEditBox.TextAlign := taCenter;
  FButtonRight.Tag := 1;
  FButtonLeft.Tag := -1;
end;

procedure TACLCustomSpinEdit.Calculate(ABounds: TRect);
var
  LButtonWidth: Integer;
begin
  LButtonWidth := StyleButton.Texture.FrameWidth;
  FButtonLeft.Calculate(ABounds.Split(srLeft, LButtonWidth));
  FButtonRight.Calculate(ABounds.Split(srRight, LButtonWidth));
  ABounds.Right := FButtonRight.Bounds.Left;
  ABounds.Left := FButtonLeft.Bounds.Right;
  CalculateContent(ABounds);
end;

function TACLCustomSpinEdit.CanAutoSize(var AWidth, AHeight: Integer): Boolean;
begin
  if AutoSize then
  begin
    AHeight := FEditBox.AutoHeight + 2 * OuterBorderSize;
    AHeight := Max(AHeight, StyleButton.Texture.FrameHeight);
  end;
  Result := True;
end;

procedure TACLCustomSpinEdit.CheckInput(
  var AText, APart1, APart2: string; var AAccept: Boolean);
begin
  // do nothing
end;

procedure TACLCustomSpinEdit.CMCancelMode(var Message: TCMCancelMode);
begin
  if Message.Sender <> Self then
    SetAutoClick(nil);
  inherited;
end;

function TACLCustomSpinEdit.CreateStyleButton: TACLStyleButton;
begin
  Result := TACLStyleSpinButton.Create(Self);
end;

procedure TACLCustomSpinEdit.Increase(AStep: Integer);
begin
  // do nothing
end;

procedure TACLCustomSpinEdit.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  case Key of
    vkDown:
      Increase(-1);
    vkUp:
      Increase(1);
  else
    Exit;
  end;
  Key := 0;
end;

procedure TACLCustomSpinEdit.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
    SetAutoClick(Safe.CastOrNil<TACLSpinButtonSubClass>(SubClasses.HitTest(Point(X, Y))));
end;

procedure TACLCustomSpinEdit.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (FAutoClick <> nil) and (SubClasses.HitTest(Point(X, Y)) = FAutoClick) then
  begin
    if FAutoClickWaitCount > 0 then
      Increase(Signs[FAutoClick = ButtonRight]);
  end;
  SetAutoClick(nil);
  inherited MouseUp(Button, Shift, X, Y);
end;

function TACLCustomSpinEdit.MouseWheel(Direction: TACLMouseWheelDirection;
  Shift: TShiftState; const MousePos: TPoint): Boolean;
begin
  if not inherited then
    Increase(TACLMouseWheel.DirectionToInteger[Direction]);
  Result := True;
end;

procedure TACLCustomSpinEdit.PaintCore;
var
  LPrevClip: TRegionHandle;
begin
  if Borders then
  begin
    if acStartClippedDraw(Canvas, ClientRect.InflateTo(-OuterBorderSize), LPrevClip) then
    try
      inherited;
    finally
      acEndClippedDraw(Canvas, LPrevClip);
    end;
  end
  else
    inherited;
end;

procedure TACLCustomSpinEdit.SetAutoClick(AButton: TACLSimpleButtonSubClass);
begin
  if FAutoClick <> AButton then
  begin
    if HandleAllocated then
      KillTimer(Handle, NativeUInt(Self));
    FAutoClick := AButton;
    FAutoClickWaitCount := 5;
    if FAutoClick <> nil then
      SetTimer(Handle, NativeUInt(Self), 100, nil);
  end;
end;

procedure TACLCustomSpinEdit.WMTimer(var Message: TWMTimer);
begin
  inherited;
  if Message.TimerID = NativeUInt(Self) then
  begin
    if FAutoClickWaitCount > 0 then
      Dec(FAutoClickWaitCount)
    else
      if FAutoClick <> nil then
        Increase(10 * Signs[FAutoClick = ButtonRight])
      else
        SetAutoClick(nil);
  end;
end;

{$ENDREGION}

{$REGION ' SpinEdit '}

{ TACLSpinEditOptionsValue }

constructor TACLSpinEditOptionsValue.Create(AOwner: TACLSpinEdit);
begin
  inherited Create;
  FOwner := AOwner;
  FDisplayFormat := DefaultDisplayFormat;
  FFloatPrecision := DefaultFloatPrecision;
  FValues[0] := 1;
  FValues[1] := 0;
  FValues[2] := 0;
end;

procedure TACLSpinEditOptionsValue.DoAssign(Source: TPersistent);
begin
  if Source is TACLSpinEditOptionsValue then
  begin
    ValueType := TACLSpinEditOptionsValue(Source).ValueType; // first
    MaxValue := TACLSpinEditOptionsValue(Source).MaxValue;
    MinValue := TACLSpinEditOptionsValue(Source).MinValue;
    IncCount := TACLSpinEditOptionsValue(Source).IncCount;
    DisplayFormat := TACLSpinEditOptionsValue(Source).DisplayFormat;
    FloatPrecision := TACLSpinEditOptionsValue(Source).FloatPrecision;
    AssignedValues := TACLSpinEditOptionsValue(Source).AssignedValues; // last
  end;
end;

procedure TACLSpinEditOptionsValue.DoChanged(AChanges: TACLPersistentChanges);
begin
  FOwner.Value := FOwner.Value;
  FOwner.UpdateDisplayValue;
end;

procedure TACLSpinEditOptionsValue.ValidateValue(var V: Variant);
begin
  ValidateValueType(V);
  if seavMaxValue in AssignedValues then
    V := Min(Double(V), Double(MaxValue));
  if seavMinValue in AssignedValues then
    V := Max(Double(V), Double(MinValue));
  if ValueType = evtFloat then
    V := RoundTo(Double(V), -FloatPrecision);
  ValidateValueType(V);
end;

procedure TACLSpinEditOptionsValue.ValidateValueType(var V: Variant);
const
  MaxValue: Double =  MaxInt / 1.0;
  MinValue: Double = -MaxInt / 1.0;
begin
  V := EnsureRange(V, MinValue, MaxValue);
  if ValueType = evtInteger then
    V := VarAsType(V, varInteger)
  else
    V := VarAsType(V, varDouble);
end;

function TACLSpinEditOptionsValue.ValueToText(const AValue: Variant): string;
begin
  if ValueType = evtInteger then
    Result := IntToStr(AValue)
  else
    Result := FormatFloat('0.' + acDupeString('#', FloatPrecision), AValue);
end;

function TACLSpinEditOptionsValue.GetValue(const Index: Integer): Variant;
begin
  Result := FValues[Index];
end;

function TACLSpinEditOptionsValue.IsDisplayFormatStored: Boolean;
begin
  Result := FDisplayFormat <> DefaultDisplayFormat;
end;

function TACLSpinEditOptionsValue.IsValueStored(const Index: Integer): Boolean;
begin
  Result := TACLSpinEditAssignedValue(Index) in AssignedValues;
end;

procedure TACLSpinEditOptionsValue.SetAssignedValues(const Value: TACLSpinEditAssignedValues);
begin
  if FAssignedValues <> Value then
  begin
    FAssignedValues := Value;
    Changed([apcLayout]);
  end;
end;

procedure TACLSpinEditOptionsValue.SetDisplayFormat(const Value: string);
begin
  if FDisplayFormat <> Value then
  begin
    FDisplayFormat := IfThenW(Value, DefaultDisplayFormat);
    Changed([apcLayout]);
  end;
end;

procedure TACLSpinEditOptionsValue.SetFloatPrecision(AValue: Integer);
begin
  FFloatPrecision := EnsureRange(AValue, 1, 8);
end;

procedure TACLSpinEditOptionsValue.SetValue(const Index: Integer; const AValue: Variant);
begin
  BeginUpdate;
  try
    AssignedValues := AssignedValues + [TACLSpinEditAssignedValue(Index)];
    if not VarSameValue(GetValue(Index), AValue) then
    begin
      FValues[Index] := AValue;
      ValidateValueType(FValues[Index]);
      case TACLSpinEditAssignedValue(Index) of
        seavMaxValue:
          if seavMinValue in AssignedValues then
            MinValue := Min(Double(MinValue), Double(MaxValue));
        seavMinValue:
          if seavMaxValue in AssignedValues then
            MaxValue := Max(Double(MaxValue), Double(MinValue));
      else;
      end;
      Changed([apcLayout]);
    end;
  finally
    EndUpdate;
  end;
end;

procedure TACLSpinEditOptionsValue.SetValueType(const Value: TACLSpinEditValueType);
var
  I: Integer;
begin
  if FValueType <> Value then
  begin
    FValueType := Value;
    for I := Low(FValues) to High(FValues) do
      ValidateValueType(FValues[I]);
    Changed([apcLayout]);
  end;
end;

{ TACLSpinEdit }

constructor TACLSpinEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  AutoSelect := True;
  FValue := 0;
  FOptionsValue := TACLSpinEditOptionsValue.Create(Self);
  FEditBox.OnDisplayFormat := GetDisplayText;
  FEditBox.OnReturn := UpdateDisplayValue;
end;

destructor TACLSpinEdit.Destroy;
begin
  FreeAndNil(FOptionsValue);
  inherited Destroy;
end;

procedure TACLSpinEdit.AfterConstruction;
begin
  inherited;
  UpdateDisplayValue;
end;

procedure TACLSpinEdit.CheckInput(
  var AText, APart1, APart2: string; var AAccept: Boolean);

  function CanEnterMinus: Boolean;
  begin
    if seavMinValue in OptionsValue.AssignedValues then
      Result := OptionsValue.MinValue < 0
    else
      Result := true;
  end;

  procedure ValidateValue(AValue: Double);
  var
    LValue: Variant;
  begin
    LValue := AValue;
    OptionsValue.ValidateValue(LValue);
    // Вот тут интересно, если вводимое значение меньше минималки -
    // не блокируем (возможно, пользователь еще не доконца ввел нужное)
    // А вот бОльшее значение отсекаем сразу
    if (AValue > LValue) or (AValue < 0) and (LValue >= 0) then
    begin
      //AAccept := False;
      APart1 := '';
      APart2 := '';
      AText := OptionsValue.ValueToText(LValue);
      acMessageBeep(mtWarning);
    end;
    AAccept := True;
  end;

var
  LText: string;
  LValueFloat: Double;
  LValueInt32: Integer;
begin
  AText := acReplaceChar(AText, '.', FormatSettings.DecimalSeparator);
  LText := APart1 + AText + APart2;
  if (LText = '') then
    Exit; // разрешаем полность удалять значение
  if (LText = '-') and CanEnterMinus then
    Exit; // пока тоже норм

  AAccept := False;
  case OptionsValue.ValueType of
    evtInteger:
      if TryStrToInt(LText, LValueInt32) then
        ValidateValue(LValueInt32);
    evtFloat:
      if TryStrToFloat(LText, LValueFloat) then
        ValidateValue(LValueFloat);
  end;
end;

procedure TACLSpinEdit.CMExit(var Message: TCMEnter);
begin
  inherited;
  UpdateDisplayValue;
end;

procedure TACLSpinEdit.Increase(AStep: Integer);
begin
  Value := Value + AStep * OptionsValue.IncCount;
end;

function TACLSpinEdit.IsValueStored: Boolean;
begin
  Result := not VarSameValue(Value, 0);
end;

function TACLSpinEdit.GetDisplayText: string;
begin
  Result := Format(OptionsValue.DisplayFormat, [FEditBox.Text]);
  if Assigned(OnGetDisplayText) then
    OnGetDisplayText(Self, Value, Result);
end;

procedure TACLSpinEdit.SetOnGetDisplayText(AValue: TACLEditGetDisplayTextEvent);
begin
  FOnGetDisplayText := AValue;
  FEditBox.Changed;
end;

procedure TACLSpinEdit.SetOptionsValue(AValue: TACLSpinEditOptionsValue);
begin
  OptionsValue.Assign(AValue);
end;

procedure TACLSpinEdit.SetValue(AValue: Variant);
begin
  OptionsValue.ValidateValue(AValue);
  if not VarSameValue(AValue, FValue) then
  begin
    FValue := AValue;
    if not FChanging then
      UpdateDisplayValue;
    if not (csLoading in ComponentState) then
      Changed;
  end;
end;

procedure TACLSpinEdit.TextChanged;
var
  LValue: Double;
begin
  if TryStrToFloat(FEditBox.Text, LValue) then
  begin
    FChanging := Focused;
    try
      Value := LValue;
    finally
      FChanging := False;
    end;
  end;
  inherited;
end;

procedure TACLSpinEdit.UpdateDisplayValue;
begin
  FEditBox.Text := OptionsValue.ValueToText(Value);
end;
{$ENDREGION}

end.
