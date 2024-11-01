////////////////////////////////////////////////////////////////////////////////
//
//  Project:   Artem's Components Library aka ACL
//             Extended Graphics Library
//             v6.0
//
//  Purpose:   Cairo Wrappers
//
//  Author:    Artem Izmaylov
//             © 2006-2024
//             www.aimp.ru
//
//  FPC:       OK
//
unit ACL.Graphics.Ex.Cairo;

{$I ACL.Config.inc}

{$RANGECHECKS OFF}
{$POINTERMATH ON}

interface

uses
  Cairo,
{$IFDEF MSWINDOWS}
  CairoWin32,
  Windows,
{$ENDIF}
{$IFDEF LCLGtk2}
  glib2,
  gdk2,
  gtk2Def,
{$ENDIF}
{$IFDEF FPC}
  LazUtf8,
  LCLIntf,
  LCLType,
{$ENDIF}
  // System
  Classes,
  Math,
  SysUtils,
  System.UITypes,
  Types,
  // Vcl
  Graphics,
  // ACL
  ACL.Classes.Collections,
  ACL.Geometry,
  ACL.Geometry.Utils,
  ACL.Graphics,
  ACL.Graphics.Ex,
  ACL.Graphics.TextLayout,
  ACL.Utils.Common,
  ACL.Utils.Strings;

type
  PCairoGlyphArray = ^TCairoGlyphArray;
  TCairoGlyphArray = array[0..0] of cairo_glyph_t;

  { EGSCairoError }

  EGSCairoError = class(Exception);

  { TCairoColor }

  TCairoColor = record
    R, G, B, A: Double;
    class function From(A, R, G, B: Byte): TCairoColor; overload; static;
    class function From(Color: TAlphaColor): TCairoColor; overload; static;
    class function From(Color: TColor): TCairoColor; overload; static;
    class function From(Font: TFont): TCairoColor; overload; static;
  end;

  { TCairoContext }

  PCairoContext = ^TCairoContext;
  TCairoContext = record
  {$IFDEF MSWINDOWS}
    DC: HDC;
    Index: Integer;
  {$ENDIF}
  end;

  { TCairoFontMetrics }

  TCairoFontMetrics = record
    // same to cairo_font_extents_t
    ascent: Double;
    descent: Double;
    height: Double;
    max_x_advance: Double;
    max_y_advance: Double;
    // our extensions:
    baseline: Double;
    line_thickness: Double;
  end;

  { TACLTextLayoutCairoRender }

  TACLTextLayoutCairoRender = class(TACLTextLayoutCanvasRender)
  strict private
    FContext: PCairoContext;
    FFillColor: TCairoColor;
    FFillColorAssigned: Boolean;
    FFont: Pcairo_scaled_font_t;
    FFontColor: TCairoColor;
    FFontHasLines: Boolean;
    FFontMetrics: TCairoFontMetrics;
    FHandle: Pcairo_t;
    FHandleOwnership: TStreamOwnership;
    FLineHeight: Integer;
    FOrigin: TPoint;
    FSurface: Pcairo_surface_t;
  public
    constructor Create(ACanvas: TCanvas); override;
    constructor CreateEx(ACairo: Pcairo_t); overload;
    constructor CreateEx(ADib: TACLDib); overload;
    destructor Destroy; override;
    function CreateCompatibleRender(ADib: TACLDib): TACLTextLayoutRender; override;
    // Drawing
    procedure DrawImage(ADib: TACLDib; const R: TRect); override;
    procedure DrawText(ABlock: TACLTextLayoutBlockText; X, Y: Integer); override;
    procedure DrawUnderline(const R: TRect); override;
    procedure FillBackground(const R: TRect); override;
    function GetClipBox(out R: TRect): Boolean; override;
    // Measuring
    procedure GetMetrics(out ABaseline, ALineHeight, ASpaceWidth: Integer); override;
    procedure Measure(ABlock: TACLTextLayoutBlockText); override;
    procedure Shrink(ABlock: TACLTextLayoutBlockText; AMaxSize: Integer); override;
    // Setup
    procedure SetFill(AValue: TColor); override;
    procedure SetFont(AFont: TFont); override;
    // Properties
    property Origin: TPoint read FOrigin write FOrigin;
  end;

{$REGION ' Render2D '}

  { TACLCairoRender }

  TACLCairoRender = class(TACL2DRender)
  strict private
    FContext: PCairoContext;
    FHandle: Pcairo_t;
    FHandleOwnership: TStreamOwnership;
    FImageSmoothStretching: TACLBoolean;
    FTargetSurface: Pcairo_surface_t;

    procedure CheckRecursivePaint;
    procedure PathEllipseArc(X1, Y1, X2, Y2: Double);
    procedure PathPolyline(Points: PPoint; Count: Integer; ClosePath: Boolean);
  public
    procedure BeginPaint(ACairo: Pcairo_t); overload;
    procedure BeginPaint(ACanvas: TCanvas); override;
    procedure BeginPaint(AColors: PACLPixel32Array; AWidth, AHeight: Integer); overload;
    procedure BeginPaint(ADib: TACLDib); overload;
    procedure BeginPaint(ASurface: Pcairo_surface_t); overload;
    procedure BeginPaint(DC: HDC; const BoxRect, UpdateRect: TRect); overload; override;
    procedure EndPaint; override;

    // General
    function FriendlyName: string; override;
    function Name: string; override;

    // Clipping
    function Clip(const R: TRect; out Data: TACL2DRenderRawData): Boolean; overload; override;
    function Clip(const R: TACLRegionData; out Data: TACL2DRenderRawData): Boolean; reintroduce; overload;
    procedure ClipRestore(Data: TACL2DRenderRawData); override;
    function IsVisible(const R: TRect): Boolean; override;

    // Ellipse
    procedure DrawEllipse(X1, Y1, X2, Y2: Single; Color: TAlphaColor;
      Width: Single; Style: TACL2DRenderStrokeStyle); override;
    procedure FillEllipse(X1, Y1, X2, Y2: Single; Color: TAlphaColor); override;

    // Line
    procedure Line(X1, Y1, X2, Y2: Single; Color: TAlphaColor;
      Width: Single = 1; Style: TACL2DRenderStrokeStyle = ssSolid); override;
    procedure Line(const Points: PPoint; Count: Integer; Color: TAlphaColor;
      Width: Single = 1; Style: TACL2DRenderStrokeStyle = ssSolid); override;

    // Images
    function CreateImage(Colors: PACLPixel32; Width, Height: Integer;
      AlphaFormat: TAlphaFormat = afDefined): TACL2DRenderImage; override;
    procedure DrawImage(Image: TACL2DRenderImage;
      const TargetRect, SourceRect: TRect; Alpha: Byte = MaxByte); override;
    procedure DrawImage(Image: TACL2DRenderImage;
      const TargetRect, SourceRect: TRect; Attributes: TACL2DRenderImageAttributes); override;

    // Rectangles
    procedure DrawRectangle(X1, Y1, X2, Y2: Single; Color: TAlphaColor;
      Width: Single = 1; Style: TACL2DRenderStrokeStyle = ssSolid); override;
    procedure FillHatchRectangle(const R: TRect; Color1, Color2: TAlphaColor; Size: Integer); override;
    procedure FillRectangle(X1, Y1, X2, Y2: Single; Color: TAlphaColor); override;
    procedure FillRectangleByGradient(const ARect: TRect;
      AFrom, ATo: TAlphaColor; AVertical: Boolean); override;
    procedure FillSurface(const ATargetRect, ASourceRect: TRect;
      ASurface: Pcairo_surface_t; AAlpha: Double; ATileMode: Boolean;
      AOperator: cairo_operator_t = CAIRO_OPERATOR_OVER);

    // Text
    procedure MeasureText(const Text: string;
      Font: TFont; var Rect: TRect; WordWrap: Boolean); override;
    procedure DrawText(const Text: string; const R: TRect;
      Color: TAlphaColor; Font: TFont; HorzAlign: TAlignment = taLeftJustify;
      VertAlign: TVerticalAlignment = taVerticalCenter; WordWrap: Boolean = False); override;

    // Paths
    function CreatePath: TACL2DRenderPath; override;
    procedure DrawPath(Path: TACL2DRenderPath; Color: TAlphaColor;
      Width: Single = 1; Style: TACL2DRenderStrokeStyle = ssSolid); override;
    procedure FillPath(Path: TACL2DRenderPath; Color: TAlphaColor); override;

    // Polygons
    procedure DrawPolygon(const Points: array of TPoint; Color: TAlphaColor;
      Width: Single = 1; Style: TACL2DRenderStrokeStyle = ssSolid); override;
    procedure FillPolygon(const Points: array of TPoint; Color: TAlphaColor); override;

    // World Transform
    procedure ModifyWorldTransform(const XForm: TXForm); override;
    procedure RestoreWorldTransform(State: TACL2DRenderRawData); override;
    procedure SaveWorldTransform(out State: TACL2DRenderRawData); override;
    procedure ScaleWorldTransform(ScaleX, ScaleY: Single); overload; override;
    procedure SetWorldTransform(const XForm: TXForm); override;
    procedure TransformPoints(Points: PPointF; Count: Integer); override;
    procedure TranslateWorldTransform(OffsetX, OffsetY: Single); override;

    //# Options
    procedure SetImageSmoothing(AValue: TACLBoolean); override;

    //# Properties
    property Handle: Pcairo_t read FHandle;
    property Origin;
    property TargetSurface: Pcairo_surface_t read FTargetSurface; // nullable
  end;

{$ENDREGION}

{$REGION ' Blend Mode '}

  TCairoBlendFunctions = class
  public const
    ModeMap: array[TACLBlendMode] of cairo_operator_t = (
      CAIRO_OPERATOR_OVER,
      CAIRO_OPERATOR_MULTIPLY,
      CAIRO_OPERATOR_SCREEN,
      CAIRO_OPERATOR_OVERLAY,
      CAIRO_OPERATOR_ADD,
      CAIRO_OPERATOR_OVER, // bmSubstract, unsupported
      CAIRO_OPERATOR_DIFFERENCE,
      CAIRO_OPERATOR_OVER, // bmDivide, unsupported
      CAIRO_OPERATOR_LIGHTEN,
      CAIRO_OPERATOR_DARKEN,
      CAIRO_OPERATOR_OVER  // bmGrayscale, unsupported
    );
    Supported = [Low(TACLBlendMode)..High(TACLBlendMode)] - [bmSubstract, bmDivide, bmGrayscale];
  strict private
    class procedure DoBlend(ABackground, AForeground: TACLDib;
      AAlpha: Byte; AOperator: cairo_operator_t); overload;
//    class procedure DoBlend(Canvas: TCanvas; Foreground: TACLDib;
//      const Origin: TPoint; Mode: TACLBlendMode; Alpha: Byte); overload; static;
    // BlendFunctions
    class procedure DoAddition(ABackground, AForeground: TACLDib; AAlpha: Byte);
    class procedure DoDarken(ABackground, AForeground: TACLDib; AAlpha: Byte);
    class procedure DoDifference(ABackground, AForeground: TACLDib; AAlpha: Byte);
    class procedure DoLighten(ABackground, AForeground: TACLDib; AAlpha: Byte);
    class procedure DoMultiply(ABackground, AForeground: TACLDib; AAlpha: Byte);
    class procedure DoOverlay(ABackground, AForeground: TACLDib; AAlpha: Byte);
    class procedure DoScreen(ABackground, AForeground: TACLDib; AAlpha: Byte);
  public
    class procedure Register;
  end;

{$ENDREGION}

var
  CairoPainter: TACLCairoRender;

(*
  Флаги, поддерживаемые имплементацей на чистом cairo:
    DT_LEFT, DT_CENTER, DT_RIGHT, DT_CALCRECT, DT_TOP, DT_VCENTER, DT_BOTTOM,
    DT_SINGLELINE, DT_HIDEPREFIX, DT_NOPREFIX, DT_NOCLIP, DT_EDITCONTROL,
    DT_WORDBREAK, DT_END_ELLIPSIS
*)
procedure CairoDrawText(ACanvas: TCanvas; const S: string; var R: TRect; AFlags: Cardinal);

// GetTextExtPoint & TextOut
function CairoTextGetLastVisible(ACanvas: TCanvas; const S: string; AMaxWidth: Integer): Integer;
procedure CairoTextOut(ACanvas: TCanvas; X, Y: Integer; AText: PChar; ALength: Integer; AClipRect: PRect = nil);
procedure CairoTextSize(ACanvas: TCanvas; const S: string; AWidth, AHeight: PInteger);

// Context
function cairo_create_context(DC: HDC): pcairo_t; overload;
function cairo_create_context(DC: HDC; out Origin: TPoint;
  out SavedContext: PCairoContext): pcairo_t; overload;
procedure cairo_destroy_context(ACairo: pcairo_t; ASavedContext: PCairoContext);

// Surface
function cairo_create_surface(AWidth, AHeight: LongInt): Pcairo_surface_t; overload;
function cairo_create_surface(AData: PACLPixel32Array; AWidth, AHeight: LongInt): Pcairo_surface_t; overload;

// Utilities
procedure cairo_set_source_color(ACairo: pcairo_t; const AColor: TAlphaColor); overload;
procedure cairo_set_source_color(ACairo: pcairo_t; const AColor: TACLPixel32); overload;
procedure cairo_set_source_color(ACairo: pcairo_t; const AColor: TCairoColor); overload;

procedure cairo_fill_surface(ACairo: pcairo_t; ASurface: Pcairo_surface_t;
  const ATargetRect, ASourceRect: TRect; const AOrigin: TPoint;
  AAlpha: Double; ATileMode: Boolean;
  AOperator: cairo_operator_t = CAIRO_OPERATOR_OVER;
  AFilter: cairo_filter_t = CAIRO_FILTER_NEAREST);
implementation

uses
  ACL.Graphics.FontCache;

{$REGION ' DrawText '}
const
  CairoTextStyleLines = [fsUnderline, fsStrikeOut];

type
  TTextBlock = class(TACLTextLayoutBlockText);

  { TCairoTextLayoutMetrics }

  PCairoTextLayoutMetrics = ^TCairoTextLayoutMetrics;
  TCairoTextLayoutMetrics = packed record
    Capacity: Integer;
    Count: Integer;
    Glyphs: TCairoGlyphArray;
    class function Allocate(AGlyphCount: Integer): PCairoTextLayoutMetrics; static;
    procedure Assign(AGlyphs: pcairo_glyph_t; ACount: Integer);
  end;

  { TCairoTextLine }

  PCairoTextLine = ^TCairoTextLine;
  TCairoTextLine = record
    Glyphs: PCairoGlyphArray;
    GlyphCount: Integer;
    Width: Double;
    NextLine: PCairoTextLine;
    procedure Align(ARightBound: Integer; AAlignment: THorzRectAlign);
    procedure CalcMetrics(AFont: pcairo_scaled_font_t);
    function GetCount: Integer;
    function GetMaxWidth: Double;
    procedure Init(AGlyphs: PCairoGlyphArray; AIndex, ACount: Integer);
    function Push(AGlyphs: PCairoGlyphArray; AIndex, ACount: Integer): PCairoTextLine;
    procedure Free;
  end;

  { TCairoHelper }

  TCairoHelper = class
  strict private
    class var FBitmap: TACLDib;
    class var FContext: Pcairo_t;
    class var FDefaultFontData: TFontData;
    class var FUtf8Buffer: PAnsiChar;
    class var FUtf8BufferSize: Integer;
    class procedure InitDefaultFont;
  public
    class destructor Destroy;
    class function DefaultFontName: TFontDataName;
    class function DefaultFontSize: Integer;
    class function Measurer(ACanvas: TCanvas): Pcairo_t;
    class function ToUtf8(AText: PWideChar; ATextLen: Integer; out Utf8Len: Integer): PAnsiChar;
  end;

{$ENDREGION}

{$REGION ' Render2D '}

  { TACLCairoRenderImage }

  TACLCairoRenderImage = class(TACL2DRenderImage)
  strict private
    FColors: Pointer;
    FHandle: Pcairo_surface_t;
  public
    constructor Create(ARender: TACL2DRender; AColors: PACLPixel32;
      AWidth, AHeight: Integer; AAlphaFormat: TAlphaFormat);
    destructor Destroy; override;
    property Handle: Pcairo_surface_t read FHandle;
  end;

  { TACLCairoRenderPath }

  TACLCairoRenderPath = class(TACL2DRenderPath)
  strict private type
  {$REGION ' Items '}
    TItem = class
    public
      X, Y: Single;
      constructor Create(X, Y: Single);
      procedure Write(Handle: Pcairo_t; dX, dY: Single); virtual; abstract;
    end;

    TArc = class(TItem)
    public
      CX, CY, RX, RY, Angle1, Angle2: Single;
      procedure Write(Handle: Pcairo_t; dX, dY: Single); override;
    end;

    TMoveTo = class(TItem)
    public
      procedure Write(Handle: Pcairo_t; dX, dY: Single); override;
    end;

    TLineTo = class(TItem)
    public
      procedure Write(Handle: Pcairo_t; dX, dY: Single); override;
    end;

    TFigure = TACLObjectListOf<TItem>;
  {$ENDREGION}
  strict private
    FFigure: TFigure;
    FFigures: TACLObjectListOf<TFigure>;

    function StartFigureIfNecessary(X, Y: Single): TFigure;
  protected
    procedure Write(Handle: Pcairo_t; dX, dY: Single);
  public
    destructor Destroy; override;
    procedure AddArc(CenterX, CenterY, RadiusX, RadiusY, StartAngle, SweepAngle: Single); override;
    procedure AddLine(X1, Y1, X2, Y2: Single); override;
    procedure FigureClose; override;
    procedure FigureStart; override;
  end;

{$ENDREGION}

{$REGION ' Generic '}

function cairo_create_context(DC: HDC): pcairo_t;
begin
{$IF DEFINED(LCLGtk2)}
  Result := gdk_cairo_create(TGtkDeviceContext(DC).Drawable);
{$ELSEIF DEFINED(MSWINDOWS)}
  var LSurface := cairo_win32_surface_create(DC);
  Result := cairo_create(LSurface);
  cairo_surface_destroy(LSurface);
{$ELSE}
  Result := nil;
{$ENDIF}
  if Result = nil then
    raise EGSCairoError.Create('Cannot create cairo context');
end;

function cairo_create_context(DC: HDC;
  out Origin: TPoint; out SavedContext: PCairoContext): pcairo_t;
begin
{$IFDEF MSWINDOWS}
  //#AI, 28.10.2024:
  // Текст рендерится на PaintBox-е обрезанным. Эксперименты говорят,
  // что клиппинг для текста учитывает Origin с противоположным знаком.
  // Посему врубаем нашу реализацию Origin + ClipBox и для Windows.
  New(SavedContext);
  SavedContext^.DC := DC;
  SavedContext^.Index := SaveDC(DC);
  SetWindowOrgEx(DC, 0, 0, @Origin);
{$ELSE}
  SavedContext := nil;
  Origin := NullPoint;
  GetWindowOrgEx(DC, Origin);
{$ENDIF}
  try
    Result := cairo_create_context(DC);
  except
    cairo_destroy_context(nil, SavedContext);
    raise;
  end;
end;

procedure cairo_destroy_context(ACairo: pcairo_t; ASavedContext: PCairoContext);
begin
  if ACairo <> nil then
    cairo_destroy(ACairo);
  if ASavedContext <> nil then
  try
  {$IFDEF MSWINDOWS}
    RestoreDC(ASavedContext^.DC, ASavedContext^.Index);
  {$ENDIF}
  finally
    Dispose(ASavedContext);
  end;
end;

function cairo_create_surface(AWidth, AHeight: LongInt): Pcairo_surface_t;
begin
  Result := cairo_image_surface_create(CAIRO_FORMAT_ARGB32, AWidth, AHeight);
end;

function cairo_create_surface(AData: PACLPixel32Array; AWidth, AHeight: LongInt): Pcairo_surface_t;
begin
  Result := cairo_image_surface_create_for_data(
    PByte(AData), CAIRO_FORMAT_ARGB32, AWidth, AHeight, AWidth * 4);
end;

procedure cairo_font_metrics(AFont: Pcairo_scaled_font_t; out AMetrics: TCairoFontMetrics);
begin
  cairo_scaled_font_extents(AFont, @AMetrics);
  AMetrics.baseline := AMetrics.height - AMetrics.descent;
  AMetrics.line_thickness := Max(1.0, AMetrics.height / 16.0);
end;

procedure cairo_matrix_init(out matrix: cairo_matrix_t; const form: TXForm);
begin
  matrix.xx := form.eM11;
  matrix.yx := form.eM12;
  matrix.xy := form.eM21;
  matrix.yy := form.eM22;
  matrix.x0 := form.eDx;
  matrix.y0 := form.eDy;
end;

function cairo_set_clipping(ACairo: pcairo_t; DC: HDC): Boolean;
var
  I: Integer;
  LData: TACLRegionData;
  LOrigin: TPoint;
  LRect: TRect;
begin
  Result := True;
  case GetClipBox(DC, {$IFDEF FPC}@{$ENDIF}LRect) of
    SimpleRegion:
      begin
        LOrigin := NullPoint;
        GetWindowOrgEx(DC, LOrigin);
        LRect.Offset(-LOrigin.X, -LOrigin.Y);
        cairo_rectangle(ACairo, LRect.Left, LRect.Top, LRect.Width, LRect.Height);
        cairo_clip(ACairo);
      end;

    ComplexRegion:
      begin
        LData := TACLRegionData.CreateFromDC(DC);
        try
          for I := 0 to LData.Count - 1 do
          begin
            with LData.Rects^[I] do
              cairo_rectangle(ACairo, Left, Top, Width, Height);
          end;
          cairo_clip(ACairo);
        finally
          LData.Free;
        end;
      end;
  else
    Result := False;
  end;
end;

procedure cairo_set_dash(ACairo: pcairo_t; const ADashes: array of Double); overload;
begin
  Cairo.cairo_set_dash(ACairo, @ADashes[0], Length(ADashes), 0);
end;

procedure cairo_set_line(ACairo: pcairo_t; AWidth: Single; AStyle: TACL2DRenderStrokeStyle);
begin
  case AStyle of
    ssDashDotDot:
      cairo_set_dash(ACairo, [4 * AWidth, AWidth, AWidth, AWidth, AWidth, AWidth]);
    ssDashDot:
      cairo_set_dash(ACairo, [4 * AWidth, AWidth, AWidth, AWidth]);
    ssDash:
      cairo_set_dash(ACairo, [4 * AWidth, AWidth]);
    ssDot:
      cairo_set_dash(ACairo, [AWidth]);
  else
    Cairo.cairo_set_dash(ACairo, nil, 0, 0);
  end;
  cairo_set_line_width(ACairo, AWidth);
end;

procedure cairo_set_font(ACairo: pcairo_t; AFont: TFont);
var
  LName: AnsiString;
  LSlant: cairo_font_slant_t;
  LWeight: cairo_font_weight_t;
begin
  if fsItalic in AFont.Style then
    LSlant := CAIRO_FONT_SLANT_ITALIC
  else
    LSlant := CAIRO_FONT_SLANT_NORMAL;

  if fsBold in AFont.Style then
    LWeight := CAIRO_FONT_WEIGHT_BOLD
  else
    LWeight := CAIRO_FONT_WEIGHT_NORMAL;

  if AFont.Name = 'default' then
    LName := TCairoHelper.DefaultFontName
  else
    LName := acAString(AFont.Name);

  cairo_select_font_face(ACairo, PAnsiChar(LName), LSlant, LWeight);
  if AFont.Height = 0 then
    cairo_set_font_size(ACairo, TCairoHelper.DefaultFontSize)
  else
    cairo_set_font_size(ACairo, Abs(acResolveFontHeight(AFont, AFont.Height)));
end;

procedure cairo_set_source_color(ACairo: pcairo_t; const AColor: TAlphaColor);
begin
  cairo_set_source_rgba(ACairo, AColor.R / 255, AColor.G / 255, AColor.B / 255, AColor.A / 255);
end;

procedure cairo_set_source_color(ACairo: pcairo_t; const AColor: TACLPixel32);
begin
  cairo_set_source_rgba(ACairo, AColor.R / 255, AColor.G / 255, AColor.B / 255, AColor.A / 255);
end;

procedure cairo_set_source_color(ACairo: pcairo_t; const AColor: TCairoColor);
begin
  cairo_set_source_rgba(ACairo, AColor.R, AColor.G, AColor.B, AColor.A);
end;

procedure cairo_fill_surface(ACairo: pcairo_t; ASurface: Pcairo_surface_t;
  const ATargetRect, ASourceRect: TRect;
  const AOrigin: TPoint; AAlpha: Double; ATileMode: Boolean;
  AOperator: cairo_operator_t; AFilter: cairo_filter_t);
var
  LCairo: Pcairo_t;
  LMatrix: cairo_matrix_t;
  LPrevOperator: cairo_operator_t;
  LSurface: Pcairo_surface_t;
  LSourceW, LSourceH: LongInt;
  LTargetW, LTargetH: Double;
  X, Y: Double;
begin
  LSourceH := ASourceRect.Height;
  LSourceW := ASourceRect.Width;
  LTargetH := ATargetRect.Height;
  LTargetW := ATargetRect.Width;
  X := ATargetRect.Left - AOrigin.X;
  Y := ATargetRect.Top - AOrigin.Y;
  if (LSourceW <= 0) or (LSourceH <= 0) or (LTargetH <= 0) or (LTargetW <= 0) then
    Exit;

  LPrevOperator := cairo_get_operator(ACairo);
  cairo_set_operator(ACairo, AOperator);
  if ATileMode then
  begin
    LSurface := cairo_create_surface(LSourceW, LSourceH);

    LCairo := cairo_create(LSurface);
    cairo_set_source_surface(LCairo, ASurface, -ASourceRect.Left, -ASourceRect.Top);
    cairo_rectangle(LCairo, 0, 0, LSourceW, LSourceH);
    cairo_paint_with_alpha(LCairo, AAlpha);
    cairo_destroy(LCairo);

    cairo_set_source_surface(ACairo, LSurface, X, Y);
    cairo_pattern_set_extend(cairo_get_source(ACairo), CAIRO_EXTEND_REPEAT);
    cairo_rectangle(ACairo, X, Y, LTargetW, LTargetH);
    cairo_fill(ACairo);
    cairo_surface_destroy(LSurface);
  end
  else
  begin
    cairo_set_source_surface(ACairo, ASurface, 0, 0);
    cairo_matrix_init_identity(@LMatrix);
    cairo_matrix_translate(@LMatrix, ASourceRect.Left, ASourceRect.Top);
    cairo_matrix_scale(@LMatrix, LSourceW / LTargetW, LSourceH / LTargetH);
    cairo_matrix_translate(@LMatrix, -X, -Y);
    cairo_pattern_set_matrix(cairo_get_source(ACairo), @LMatrix);
    cairo_pattern_set_filter(cairo_get_source(ACairo), AFilter);
    cairo_rectangle(ACairo, X, Y, LTargetW, LTargetH);
    if AAlpha < 1.0 then
    begin
      cairo_save(ACairo);
      cairo_clip(ACairo);
      cairo_paint_with_alpha(ACairo, AAlpha);
      cairo_restore(ACairo);
    end
    else
      cairo_fill(ACairo);
  end;
  cairo_set_operator(ACairo, LPrevOperator);
end;

function cairo_scaled_font_text_to_glyphs(scaled_font: Pcairo_scaled_font_t; x, y: Double;
  const text: PWideChar; text_len: LongInt; glyphs: PPcairo_glyph_t; num_glyphs: PLongInt;
  clusters: PPcairo_text_cluster_t; num_clusters: PLongInt;
  cluster_flags: Pcairo_text_cluster_flags_t): cairo_status_t; overload;
var
  LUtf8: PAnsiChar;
  LUtf8Len: Integer;
begin
  LUtf8 := TCairoHelper.ToUtf8(text, text_len, LUtf8Len);
  Result := Cairo.cairo_scaled_font_text_to_glyphs(scaled_font, x, y,
    LUtf8, LUtf8Len, glyphs, num_glyphs, clusters, num_clusters, cluster_flags);
end;

procedure cairo_text_extents(cr: Pcairo_t; text: PWideChar; extents: Pcairo_text_extents_t); overload;
var
  x: Integer;
begin
  Cairo.cairo_text_extents(cr, TCairoHelper.ToUtf8(text, StrLen(text), x), extents);
end;

function cairo_text_to_glyphs(AFont: Pcairo_scaled_font_t;
  AText: PChar; ATextLen: Integer; out AGlyphs: Pcairo_glyph_t;
  out AGlyphCount: Integer; X, Y: Double): Boolean; overload;
begin
  AGlyphs := nil;
  AGlyphCount := 0;
  cairo_scaled_font_text_to_glyphs(AFont, X, Y,
    AText, ATextLen, @AGlyphs, @AGlyphCount, nil, nil, nil);
  Result := AGlyphs <> nil;
end;

function cairo_text_to_glyphs(AFont: Pcairo_scaled_font_t; const AText: string;
  out AGlyphs: PCairoGlyphArray; out AGlyphCount: Integer): Boolean; overload;
begin
  Result := cairo_text_to_glyphs(AFont, PChar(AText), Length(AText),
    Pcairo_glyph_t(AGlyphs), AGlyphCount, 0, 0);
end;

{ TCairoColor }

class function TCairoColor.From(A, R, G, B: Byte): TCairoColor;
begin
  Result.R := R / 255;
  Result.G := G / 255;
  Result.B := B / 255;
  Result.A := A / 255;
end;

class function TCairoColor.From(Color: TAlphaColor): TCairoColor;
begin
  Result := From(Color.A, Color.R, Color.G, Color.B);
end;

class function TCairoColor.From(Color: TColor): TCairoColor;
begin
  Color := ColorToRGB(Color);
  Result := From(255, GetRValue(Color), GetGValue(Color), GetBValue(Color));
end;

class function TCairoColor.From(Font: TFont): TCairoColor;
begin
  Result := From(acGetActualColor(Font));
end;
{$ENDREGION}

{$REGION ' DrawText '}

function Contains(const D: TLongWordDynArray; Index: LongWord): Boolean;
var
  I: Integer;
begin
  for I := Low(D) to High(D) do
  begin
    if D[I] = Index then
      Exit(True);
  end;
  Result := False;
end;

procedure OffsetGlyphs(AGlyphs: PCairoGlyphArray; ACount: Integer; ADeltaX, ADeltaY: Double);
var
  I: Integer;
begin
  for I := 0 to ACount - 1 do
    with AGlyphs^[I] do
    begin
      X := X + ADeltaX;
      Y := Y + ADeltaY;
    end;
end;

procedure CairoCalculateTextLayout(AFont: Pcairo_scaled_font_t;
  ALines: PCairoTextLine; const ARect: TRect; AFlags: Cardinal);
const
  WordBreaks = #13#10#9' ';
var
  LGlyphCount: Integer;
  LGlyphs: PCairoGlyphArray;
  LGlyphCR, LGlyphLF: LongWord;

  procedure InitDelimiters(out D: TLongWordDynArray;
    const S: string; AExtents: Pcairo_text_extents_t = nil);
  var
    I: Integer;
    LGlyphCount: Integer;
    LGlyphs: PCairoGlyphArray;
  begin
    D := nil;
    LGlyphs := nil;
    LGlyphCount := 0;
    cairo_scaled_font_text_to_glyphs(AFont, 0, 0,
      PChar(S), Length(S), @LGlyphs, @LGlyphCount, nil, nil, nil);
    if LGlyphs <> nil then
    try
      SetLength(D{%H-}, LGlyphCount);
      for I := 0 to LGlyphCount - 1 do
        D[I] := LGlyphs^[I].index;
      if AExtents <> nil then
        cairo_scaled_font_glyph_extents(AFont, @LGlyphs^[0], LGlyphCount, AExtents);
    finally
      cairo_glyph_free(@LGlyphs^[0]);
    end;
  end;

  procedure ProcessLineBreak(var Index: Integer);
  var
    LSize: Integer;
  begin
    if (LGlyphs^[Index].Index = LGlyphCR) and
       (Index + 1 < LGlyphCount) and (LGlyphs^[Index + 1].Index = LGlyphLF)
    then //#13#10
      LSize := 2
    else
      LSize := 1; // #13 or #10

    Inc(Index, LSize);
    Dec(ALines.Push(LGlyphs, Index, LGlyphCount)^.GlyphCount, LSize);
  end;

var
  I, J: Integer;
  LDeltaY: Double;
  LGlyphWidth: Double;
  LGlyphWidths: TDoubleDynArray;
  LEndEllipsis: TLongWordDynArray;
  LFontMetrics: TCairoFontMetrics;
  LTextExtents: cairo_text_extents_t;
  LLineScan: PCairoTextLine;
  LLineStart: Integer;
  LWordBreaks: TLongWordDynArray;
  LOffsetX, LOffsetY: Double;
  LHeight: Double;
  LWidth: Double;
begin
  LGlyphs := ALines^.Glyphs;
  LGlyphCount := ALines^.GlyphCount;
  cairo_font_metrics(AFont, LFontMetrics);

  // Считаем лейаут
  if AFlags and DT_SINGLELINE = 0 then
  begin
    LOffsetX := 0;
    LOffsetY := 0;
    LGlyphCR := 0;
    LGlyphLF := 0;
    LGlyphWidth := 0;

    InitDelimiters(LWordBreaks, #13#10);
    if Length(LWordBreaks) > 0 then
      LGlyphCR := LWordBreaks[0];
    if Length(LWordBreaks) > 1 then
      LGlyphLF := LWordBreaks[1];

    // В этом режиме мы переносим строки только по CR/LF
    if AFlags and DT_WORDBREAK = 0 then
    begin
      I := 0;
      while I < LGlyphCount do
      begin
        if I + 1 < LGlyphCount then
          LGlyphWidth := LGlyphs^[I + 1].X - LGlyphs^[I].X;
        LGlyphs^[I].X := LOffsetX;
        LGlyphs^[I].Y := LOffsetY;
        LOffsetX := LOffsetX + LGlyphWidth;
        if (LGlyphs^[I].Index = LGlyphCR) or (LGlyphs^[I].Index = LGlyphLF) then
        begin
          ProcessLineBreak(I);
          LOffsetY := LOffsetY + LFontMetrics.height;
          LOffsetX := 0;
          Continue;
        end;
        Inc(I);
      end;
    end
    else // Wordbreak
    begin
      SetLength(LGlyphWidths{%H-}, LGlyphCount);
      for I := 0 to LGlyphCount - 2 do
        LGlyphWidths[I] := LGlyphs^[I + 1].X - LGlyphs^[I].X;
      cairo_scaled_font_glyph_extents(AFont, @LGlyphs^[LGlyphCount - 1], 1, @LTextExtents);
      LGlyphWidths[LGlyphCount - 1] := LTextExtents.x_advance;

      I := 0;
      LLineStart := 0;
      LWidth := ARect.Width;
      InitDelimiters(LWordBreaks, WordBreaks);
      while I < LGlyphCount do
      begin
        // слово не влезает - откатываемся к ближайшему разделителю
        if LOffsetX + LGlyphWidths[I] > LWidth then
        begin
          J := I;
          while (J > LLineStart) and not Contains(LWordBreaks, LGlyphs^[J].Index) do
            Dec(J);
          // Если в текущей строке не нашлось ни одного разделителя -
          // оставляем "как есть". В противном случае - переносим строку.
          if J > LLineStart then
          begin
            LLineStart := J + 1;
            ALines.Push(LGlyphs, LLineStart, LGlyphCount);
            LOffsetY := LOffsetY + LFontMetrics.height;
            LOffsetX := 0;
            I := LLineStart;
            Continue;
          end;
        end;

        LGlyphs^[I].X := LOffsetX;
        LGlyphs^[I].Y := LOffsetY;
        LOffsetX := LOffsetX + LGlyphWidths[I];
        LOffsetX := LOffsetX + LGlyphWidth;
        if (LGlyphs^[I].Index = LGlyphCR) or (LGlyphs^[I].Index = LGlyphLF) then
        begin
          ProcessLineBreak(I);
          LOffsetY := LOffsetY + LFontMetrics.height;
          LOffsetX := 0;
          LLineStart := I;
          Continue;
        end;
        Inc(I);
      end;
    end;
  end;

  // EndEllipsis
  if AFlags and (DT_CALCRECT or DT_END_ELLIPSIS) = DT_END_ELLIPSIS then
  begin
    // Считаем метрики
    ALines.CalcMetrics(AFont);
    // Ищем последнюю видимую строку
    LLineScan := ALines;
    LHeight := ARect.Height;
    // В случае DT_EDITCONTROL - нам нужна последняя полностью видимая строка!
    LOffsetY := IfThen(AFlags and DT_EDITCONTROL <> 0, LFontMetrics.height, 0);
    while LHeight > LOffsetY do
    begin
      LHeight := LHeight - LFontMetrics.height;
      if (LHeight > LOffsetY) and (LLineScan.NextLine <> nil) then
        LLineScan := LLineScan.NextLine
      else
        Break;
    end;
    // Текст-то обрезан у нас?
    if (LLineScan^.NextLine <> nil) or // не все строки влезли
       (LLineScan^.Width > ARect.Width) then
    begin
      // Инициализируем '...'
      InitDelimiters(LEndEllipsis, '.', @LTextExtents);
      LWidth := ARect.Width - 3 * LTextExtents.x_advance;
      // Теперь ищем позицию по x, куда можно вставить '...'
      I := LLineScan^.GlyphCount - 1;
      // Вот тут интересно: если мы не в самом конце строки - не смещаем индекс,
      // чтобы заюзать неиспользуемые глифы из следующей строки.
      if LLineScan^.NextLine = nil then
        Dec(I, 2);
      while I >= 0 do
      begin
        if (LLineScan^.Glyphs^[I].X <= LWidth) or (I = 0) then
        begin
          // Подменяем имеющиеся глифы на глиф точки
          LLineScan^.Glyphs^[I + 0].index := LEndEllipsis[0];
          LLineScan^.Glyphs^[I + 1].index := LEndEllipsis[0];
          LLineScan^.Glyphs^[I + 2].index := LEndEllipsis[0];
          LLineScan^.Glyphs^[I + 1].x := LLineScan^.Glyphs^[I + 0].x + LTextExtents.x_advance;
          LLineScan^.Glyphs^[I + 2].x := LLineScan^.Glyphs^[I + 1].x + LTextExtents.x_advance;
          LLineScan^.Glyphs^[I + 1].y := LLineScan^.Glyphs^[I].y;
          LLineScan^.Glyphs^[I + 2].y := LLineScan^.Glyphs^[I].y;
          LLineScan^.GlyphCount := I + 3;
          // Усекаем лейаут по текущей строке (последующие строки будут освобождены)
          LLineScan^.Free;
          // Мы уже учли DT_EDITCONTROL - нет смысла делать работу еще раз
          AFlags := AFlags and not DT_EDITCONTROL;
          Break;
        end;
        Dec(I);
      end;
    end;
  end;

  // Считаем метрики
  ALines.CalcMetrics(AFont);

  // Позиционирование
  if AFlags and DT_CALCRECT = 0 then
  begin
    // DT_EDITCONTROL - скрываем частично видимые строки
    if AFlags and DT_EDITCONTROL <> 0 then
    begin
      LHeight := 0;
      LLineScan := ALines;
      while (LLineScan <> nil) and (LHeight + LFontMetrics.height <= ARect.Height) do
      begin
        LHeight := LHeight + LFontMetrics.height;
        LLineScan := LLineScan.NextLine;
      end;
      // Усекаем лейаут по последней видимой строке (последующие строки будут освобождены)
      // Себя оставляем, ведь мы можем быть строкой-инициализатором
      if LLineScan <> nil then
      begin
        LLineScan^.GlyphCount := 0;
        LLineScan^.Free;
      end;
    end
    else
      LHeight := ALines.GetCount * LFontMetrics.height;

    // Выравнивание по горизонтали
    if AFlags and DT_CENTER <> 0 then
      ALines.Align(ARect.Width, THorzRectAlign.Center)
    else if AFlags and DT_RIGHT <> 0 then
      ALines.Align(ARect.Width, THorzRectAlign.Right);

    // Выравнивание по вертикали
    if AFlags and DT_VCENTER <> 0 then
      LDeltaY := (ARect.Top + ARect.Bottom - LHeight) / 2
    else if AFlags and DT_BOTTOM <> 0 then
      LDeltaY := ARect.Bottom - LHeight
    else
      LDeltaY := ARect.Top;

    OffsetGlyphs(LGlyphs, LGlyphCount, ARect.Left, LDeltaY + LFontMetrics.baseline);
  end;
end;

procedure CairoDrawTextStyleLines(ACairo: Pcairo_t; AFontStyle: TFontStyles;
  X, Y, AWidth: Double; const AMetrics: TCairoFontMetrics); overload;
begin
  if CairoTextStyleLines * AFontStyle <> [] then
  begin
    if fsUnderline in AFontStyle then
      cairo_rectangle(ACairo, X, Y + AMetrics.baseline + AMetrics.line_thickness, AWidth, AMetrics.line_thickness);
    if fsStrikeOut in AFontStyle then
      cairo_rectangle(ACairo, X, Y + AMetrics.height / 2, AWidth, AMetrics.line_thickness);
    cairo_fill(ACairo);
  end;
end;

procedure CairoDrawTextLines(ACairo: Pcairo_t; ALines: PCairoTextLine;
  AFontStyle: TFontStyles; const AFontMetrics: TCairoFontMetrics);
begin
  while ALines <> nil do
  begin
    if ALines^.GlyphCount > 0 then
    begin
      cairo_show_glyphs(ACairo, @ALines^.Glyphs^[0], ALines^.GlyphCount);
      CairoDrawTextStyleLines(ACairo, AFontStyle,
        ALines^.Glyphs^[0].X, ALines^.Glyphs^[0].Y - AFontMetrics.baseline,
        ALines^.Width, AFontMetrics);
    end;
    ALines := ALines^.NextLine;
  end;
end;

procedure CairoDrawTextCore(ACanvas: TCanvas;
  const S: string; var R: TRect; AFlags: Cardinal);
var
  LCairo: Pcairo_t;
  LContext: PCairoContext;
  LFont: Pcairo_scaled_font_t;
  LFontMetrics: TCairoFontMetrics;
  LGlyphCount: Integer;
  LGlyphs: PCairoGlyphArray;
  LLines: TCairoTextLine;
  LOrigin: TPoint;
  LRect: TRect;
begin
  LCairo := cairo_create_context(ACanvas.Handle, LOrigin, LContext);
  try
    cairo_set_font(LCairo, ACanvas.Font);
    LFont := cairo_get_scaled_font(LCairo);
    if cairo_text_to_glyphs(LFont, S, LGlyphs, LGlyphCount) then
    try
      cairo_font_metrics(LFont, LFontMetrics);
      if AFlags and DT_CALCRECT <> 0 then
      begin
        LLines.Init(LGlyphs, 0, LGlyphCount);
        try
          CairoCalculateTextLayout(LFont, @LLines, R, AFlags);
          R.Height := Ceil(LLines.GetCount * LFontMetrics.height);
          R.Width := Ceil(LLines.GetMaxWidth);
        finally
          LLines.Free;
        end;
      end
      else
        if cairo_set_clipping(LCairo, ACanvas.Handle) then
        begin
          LRect := R;
          LRect.Offset(-LOrigin.X, -LOrigin.Y);
          LLines.Init(LGlyphs, 0, LGlyphCount);
          try
            CairoCalculateTextLayout(LFont, @LLines, LRect, AFlags);
            cairo_set_source_color(LCairo, TCairoColor.From(ACanvas.Font));
            if AFlags and DT_NOCLIP = 0 then
            begin
              cairo_rectangle(LCairo, LRect.Left, LRect.Top, LRect.Width, LRect.Height);
              cairo_clip(LCairo);
            end;
            CairoDrawTextLines(LCairo, @LLines, ACanvas.Font.Style, LFontMetrics);
          finally
            LLines.Free;
          end;
        end;
    finally
      cairo_glyph_free(@LGlyphs^[0]);
    end;
  finally
    cairo_destroy_context(LCairo, LContext);
  end;
end;

procedure CairoDrawText(ACanvas: TCanvas; const S: string; var R: TRect; AFlags: Cardinal);
var
  LText: string;
begin
  if S = '' then
  begin
    if AFlags and DT_CALCRECT <> 0 then
    begin
      CairoTextSize(ACanvas, S, @R.Right, @R.Bottom);
      Inc(R.Bottom, R.Top);
      Inc(R.Right, R.Left);
    end;
    Exit;
  end;

  LText := S;
  if AFlags and DT_NOPREFIX = 0 then
  begin
    if AFlags and DT_HIDEPREFIX <> 0 then
      acExpandPrefixes(LText, True)
    else
      // Может просто DT_NOPREFIX забыли?
      if LText.Contains('&') then
      begin
        acAdvDrawText(ACanvas, S, R, AFlags);
        Exit;
      end;
  end;

  CairoDrawTextCore(ACanvas, LText, R, AFlags);
end;

function CairoTextGetLastVisible(ACanvas: TCanvas; const S: string; AMaxWidth: Integer): Integer;
var
  LCairo: pcairo_t;
  LFont: pcairo_scaled_font_t;
  LGlyphCount: Integer;
  LGlyphs: PCairoGlyphArray;
  LTextExtents: cairo_text_extents_t;
begin
  Result := 0;
  LCairo := TCairoHelper.Measurer(ACanvas);
  LFont := cairo_get_scaled_font(LCairo);
  if cairo_text_to_glyphs(LFont, S, LGlyphs, LGlyphCount) then
  try
    cairo_scaled_font_glyph_extents(LFont, @LGlyphs^[0], LGlyphCount, @LTextExtents);
    while (LGlyphCount > 0) and (LTextExtents.x_advance > AMaxWidth) do
    begin
      LTextExtents.x_advance := LGlyphs^[LGlyphCount - 1].x;
      Dec(LGlyphCount);
    end;
  {$IFDEF UNICODE}
    Result := LGlyphCount;
  {$ELSE}
    Result := UTF8CodepointToByteIndex(PChar(S), Length(S), LGlyphCount);
  {$ENDIF}
  finally
    cairo_glyph_free(@LGlyphs^[0]);
  end;
end;

procedure CairoTextOut(ACanvas: TCanvas; X, Y: Integer;
  AText: PChar; ALength: Integer; AClipRect: PRect = nil);
var
  LCairo: pcairo_t;
  LContext: PCairoContext;
  LOrigin: TPoint;
  LFont: pcairo_scaled_font_t;
  LFontMetrics: TCairoFontMetrics;
  LTextExtents: cairo_text_extents_t;
  LGlyphCount: Integer;
  LGlyphs: Pcairo_glyph_t;
begin
  LCairo := cairo_create_context(ACanvas.Handle, LOrigin, LContext);
  try
    if cairo_set_clipping(LCairo, ACanvas.Handle) then
    begin
      if AClipRect <> nil then
      begin
        cairo_rectangle(LCairo, AClipRect.Left - LOrigin.X,
          AClipRect.Top - LOrigin.Y, AClipRect.Width, AClipRect.Height);
        cairo_clip(LCairo);
      end;

      Dec(X, LOrigin.X);
      Dec(Y, LOrigin.Y);

      cairo_set_font(LCairo, ACanvas.Font);
      cairo_set_source_color(LCairo, TCairoColor.From(ACanvas.Font));

      LFont := cairo_get_scaled_font(LCairo);
      cairo_font_metrics(LFont, LFontMetrics);
      if cairo_text_to_glyphs(LFont, AText, ALength, LGlyphs, LGlyphCount, X, Y + LFontMetrics.baseline) then
      try
        cairo_scaled_font_glyph_extents(LFont, LGlyphs, LGlyphCount, @LTextExtents);
        cairo_show_glyphs(LCairo, LGlyphs, LGlyphCount);
        if CairoTextStyleLines * ACanvas.Font.Style <> [] then
          CairoDrawTextStyleLines(LCairo, ACanvas.Font.Style, X, Y, LTextExtents.x_advance, LFontMetrics);
      finally
        cairo_glyph_free(LGlyphs);
      end;
    end;
  finally
    cairo_destroy_context(LCairo, LContext);
  end;
end;

procedure CairoTextSize(ACanvas: TCanvas; const S: string; AWidth, AHeight: PInteger);
var
  LCairo: pcairo_t;
  LFontExtents: cairo_font_extents_t;
  LTextExtents: cairo_text_extents_t;
begin
  LCairo := TCairoHelper.Measurer(ACanvas);
  if AHeight <> nil then
  begin
    cairo_font_extents(LCairo, @LFontExtents);
    AHeight^ := Round(LFontExtents.height);
  end;
  if AWidth <> nil then
  begin
    cairo_text_extents(LCairo, PChar(S), @LTextExtents);
    AWidth^ := Round(LTextExtents.x_advance);
  end;
end;

{ TCairoHelper }

class destructor TCairoHelper.Destroy;
begin
  if FContext <> nil then
  begin
    cairo_destroy(FContext);
    FContext := nil;
  end;
  FreeAndNil(FBitmap);
  FreeMem(FUtf8Buffer);
end;

class function TCairoHelper.DefaultFontName: TFontDataName;
begin
  if FDefaultFontData.Name = '' then
    InitDefaultFont;
  Result := FDefaultFontData.Name;
end;

class function TCairoHelper.DefaultFontSize: Integer;
begin
  if FDefaultFontData.Height = 0 then
    InitDefaultFont;
  Result := FDefaultFontData.Height;
end;

class procedure TCairoHelper.InitDefaultFont;
begin
{$IFDEF FPC}
  FDefaultFontData := GetFontData(GetStockObject(DEFAULT_GUI_FONT));
{$ELSE}
  FDefaultFontData := DefFontData;
{$ENDIF}
end;

class function TCairoHelper.Measurer(ACanvas: TCanvas): Pcairo_t;
begin
  if FBitmap = nil then
  begin
    FBitmap := TACLDib.Create(1, 1);
    FBitmap.Canvas.Font := ACanvas.Font;
    FContext := cairo_create_context(FBitmap.Canvas.Handle);
    cairo_set_font(FContext, ACanvas.Font);
  end
  else
    if FBitmap.Canvas.Font.Handle <> ACanvas.Font.Handle then
    //if not ACanvas.Font.IsEqual(FBitmap.Canvas.Font) then
    begin
      FBitmap.Canvas.Font := ACanvas.Font;
      cairo_set_font(FContext, ACanvas.Font);
    end;

  Result := FContext;
end;

class function TCairoHelper.ToUtf8(AText: PWideChar;
  ATextLen: Integer; out Utf8Len: Integer): PAnsiChar;
begin
  if FUtf8BufferSize < 3 * ATextLen + 1 then
  begin
    FUtf8BufferSize := 3 * ATextLen + 1;
    ReallocMem(FUtf8Buffer, FUtf8BufferSize);
  end;
  Result := FUtf8Buffer;
  Utf8Len := acUnicodeToUtf8(Result, FUtf8BufferSize - 1, AText, ATextLen);
  Result[Utf8Len] := #0;
end;

{ TCairoTextLine }

procedure TCairoTextLine.Align(ARightBound: Integer; AAlignment: THorzRectAlign);
var
  LDeltaX: Double;
begin
  if GlyphCount > 0 then
  begin
    if AAlignment = THorzRectAlign.Center then
      LDeltaX := (ARightBound - (Glyphs^[0].x * 2 + Width)) / 2
    else if AAlignment = THorzRectAlign.Right then
      LDeltaX := (ARightBound - (Glyphs^[0].x + Width))
    else
      LDeltaX := -Glyphs^[0].x;

    OffsetGlyphs(Glyphs, GlyphCount, LDeltaX, 0);
  end;
  if NextLine <> nil then
    NextLine^.Align(ARightBound, AAlignment);
end;

procedure TCairoTextLine.CalcMetrics(AFont: pcairo_scaled_font_t);
var
  LExtents: cairo_text_extents_t;
begin
  if GlyphCount > 0 then
  begin
    cairo_scaled_font_glyph_extents(AFont, @Glyphs^[GlyphCount - 1], 1, @LExtents);
    Width := LExtents.x_advance + Glyphs^[GlyphCount - 1].x - Glyphs^[0].x;
  end
  else
    Width := 0;

  if NextLine <> nil then
    NextLine^.CalcMetrics(AFont);
end;

function TCairoTextLine.GetCount: Integer;
begin
  Result := 1;
  if NextLine <> nil then
    Inc(Result, NextLine^.GetCount);
end;

procedure TCairoTextLine.Free;
begin
  if NextLine <> nil then
  begin
    NextLine^.Free;
    Dispose(NextLine);
    NextLine := nil;
  end;
end;

function TCairoTextLine.GetMaxWidth: Double;
begin
  Result := Width;
  if NextLine <> nil then
    Result := Max(Result, NextLine^.GetMaxWidth);
end;

procedure TCairoTextLine.Init(AGlyphs: PCairoGlyphArray; AIndex, ACount: Integer);
begin
  Glyphs := @AGlyphs[AIndex];
  GlyphCount := ACount - AIndex;
  NextLine := nil;
  Width := -1;
end;

function TCairoTextLine.Push(AGlyphs: PCairoGlyphArray; AIndex, ACount: Integer): PCairoTextLine;
var
  LCurr: PCairoTextLine;
begin
  LCurr := @Self;
  while LCurr^.NextLine <> nil do
    LCurr := LCurr^.NextLine;
  New(LCurr^.NextLine);
  LCurr^.NextLine^.Init(AGlyphs, AIndex, ACount);
  LCurr^.GlyphCount := LCurr^.NextLine^.Glyphs - LCurr^.Glyphs;
  Result := LCurr;
end;

{ TCairoTextLayoutMetrics }

class function TCairoTextLayoutMetrics.Allocate(AGlyphCount: Integer): PCairoTextLayoutMetrics;
begin
  Result := AllocMem(SizeOf(TCairoTextLayoutMetrics) + AGlyphCount * SizeOf(cairo_glyph_t));
  Result^.Capacity := AGlyphCount;
  Result^.Count := 0;
end;

procedure TCairoTextLayoutMetrics.Assign(AGlyphs: pcairo_glyph_t; ACount: Integer);
begin
  if ACount > Capacity then
    raise EInvalidArgument.CreateFmt('TCairoTextLayoutMetrics.Assign capacity exceeded (%d -> %d)', [ACount, Capacity]);
  Count := ACount;
  Move(AGlyphs^, Glyphs[0], ACount * SizeOf(cairo_glyph_t));
end;

{ TACLTextLayoutCairoRender }

constructor TACLTextLayoutCairoRender.Create(ACanvas: TCanvas);
begin
  inherited Create(ACanvas);
  FHandle := cairo_create_context(ACanvas.Handle, FOrigin, FContext);
  FHandleOwnership := soOwned;
  cairo_set_clipping(FHandle, Canvas.Handle);
end;

constructor TACLTextLayoutCairoRender.CreateEx(ACairo: Pcairo_t);
begin
  inherited Create(MeasureCanvas);
  FHandle := ACairo;
  FHandleOwnership := soReference;
end;

constructor TACLTextLayoutCairoRender.CreateEx(ADib: TACLDib);
begin
  inherited Create(MeasureCanvas);
  FSurface := cairo_create_surface(ADib.Colors, ADib.Width, ADib.Height);
  FHandle := cairo_create(FSurface);
  FHandleOwnership := soOwned;
end;

destructor TACLTextLayoutCairoRender.Destroy;
begin
  if FHandleOwnership = soOwned then
    cairo_destroy_context(FHandle, FContext);
  if FSurface <> nil then
    cairo_surface_destroy(FSurface);
  inherited Destroy;
end;

function TACLTextLayoutCairoRender.CreateCompatibleRender(ADib: TACLDib): TACLTextLayoutRender;
begin
  Result := TACLTextLayoutCairoRender.CreateEx(ADib);
end;

procedure TACLTextLayoutCairoRender.DrawImage(ADib: TACLDib; const R: TRect);
var
  LSurface: Pcairo_surface_t;
begin
  LSurface := cairo_create_surface(ADib.Colors, ADib.Width, ADib.Height);
  if LSurface <> nil then
  try
    cairo_fill_surface(FHandle, LSurface, R, ADib.ClientRect, FOrigin, 1.0, False);
  finally
    cairo_surface_destroy(LSurface);
  end;
end;

procedure TACLTextLayoutCairoRender.DrawUnderline(const R: TRect);
begin
  if FFontHasLines then
    CairoDrawTextStyleLines(FHandle, Canvas.Font.Style, R.Left, R.Top, R.Width, FFontMetrics);
end;

procedure TACLTextLayoutCairoRender.FillBackground(const R: TRect);
begin
  if FFillColorAssigned then
  begin
    cairo_set_source_color(FHandle, FFillColor);
    cairo_rectangle(FHandle, R.Left - FOrigin.X, R.Top - FOrigin.Y, R.Width, R.Height);
    cairo_fill(FHandle);
    cairo_set_source_color(FHandle, FFontColor);
  end;
end;

function TACLTextLayoutCairoRender.GetClipBox(out R: TRect): Boolean;
begin
  Result := False;
end;

procedure TACLTextLayoutCairoRender.DrawText(ABlock: TACLTextLayoutBlockText; X, Y: Integer);
var
  LBlock: TTextBlock absolute ABlock;
  LMetrics: PCairoTextLayoutMetrics;
begin
  LMetrics := PCairoTextLayoutMetrics(LBlock.FMetrics);
  if (LMetrics <> nil) and (LMetrics^.Count > 0) and (ABlock.TextLengthVisible > 0) then
  begin
    Dec(X, FOrigin.X);
    Dec(Y, FOrigin.Y);

    if FFillColorAssigned then
    begin
      cairo_set_source_color(FHandle, FFillColor);
      cairo_rectangle(FHandle, X, Y, LBlock.TextWidth, LBlock.TextHeight);
      cairo_fill(FHandle);
      cairo_set_source_color(FHandle, FFontColor);
    end;

    OffsetGlyphs(@LMetrics^.Glyphs[0], LMetrics^.Count,  X,  Y + FFontMetrics.baseline);
    cairo_show_glyphs(FHandle, @LMetrics^.Glyphs[0], LMetrics^.Count);
    OffsetGlyphs(@LMetrics^.Glyphs[0], LMetrics^.Count, -X, -Y - FFontMetrics.baseline);

    if FFontHasLines then
      CairoDrawTextStyleLines(FHandle, Canvas.Font.Style, X, Y, ABlock.TextWidth, FFontMetrics);
  end;
end;

procedure TACLTextLayoutCairoRender.GetMetrics(out ABaseline, ALineHeight, ASpaceWidth: Integer);
var
  LTextExtents: cairo_text_extents_t;
begin
  cairo_text_extents(FHandle, ' ', @LTextExtents);
  ASpaceWidth := Round(LTextExtents.x_advance);
  ALineHeight := Round(FFontMetrics.height);
  ABaseLine := Round(FFontMetrics.baseline);
  FLineHeight := ALineHeight;
end;

procedure TACLTextLayoutCairoRender.Measure(ABlock: TACLTextLayoutBlockText);
var
  LBlock: TTextBlock absolute ABlock;
  LExtents: cairo_text_extents_t;
  LGlyphCount: Integer;
  LGlyphs: Pcairo_glyph_t;
begin
  LBlock.FLengthVisible := 0;
  if cairo_text_to_glyphs(FFont, LBlock.Text, LBlock.TextLength, LGlyphs, LGlyphCount, 0, 0) then
  try
    if LBlock.FMetrics = nil then
      LBlock.FMetrics := TCairoTextLayoutMetrics.Allocate(LGlyphCount);
    PCairoTextLayoutMetrics(LBlock.FMetrics).Assign(LGlyphs, LGlyphCount);
    cairo_scaled_font_glyph_extents(FFont, LGlyphs, LGlyphCount, @LExtents);
    LBlock.FLengthVisible := LBlock.TextLength;
    LBlock.FWidth := Round(LExtents.x_advance);
    LBlock.FHeight := FLineHeight;
  finally
    cairo_glyph_free(LGlyphs);
  end;
end;

procedure TACLTextLayoutCairoRender.SetFill(AValue: TColor);
begin
  FFillColor := TCairoColor.From(AValue);
  FFillColorAssigned := AValue <> clNone;
end;

procedure TACLTextLayoutCairoRender.SetFont(AFont: TFont);
begin
  Canvas.Font := AFont; // иначе TFont.GetColor не сработает
  cairo_set_font(FHandle, AFont);
  FFontColor := TCairoColor.From(Canvas.Font);
  cairo_set_source_color(FHandle, FFontColor);
  FFont := cairo_get_scaled_font(FHandle);
  cairo_font_metrics(FFont, FFontMetrics);
  FFontHasLines := CairoTextStyleLines * AFont.Style <> [];
  FLineHeight := Round(FFontMetrics.height);
end;

procedure TACLTextLayoutCairoRender.Shrink(
  ABlock: TACLTextLayoutBlockText; AMaxSize: Integer);
var
  LBlock: TTextBlock absolute ABlock;
  LGlyph: Pcairo_glyph_t;
  LMetrics: PCairoTextLayoutMetrics;
  LWidth: Double;
begin
  LMetrics := PCairoTextLayoutMetrics(LBlock.FMetrics);
  LGlyph := @LMetrics^.Glyphs[LMetrics^.Count - 1];
  LWidth := LBlock.FWidth;
  while LMetrics^.Count > 0 do
  begin
    LWidth := LGlyph^.x;
    Dec(LMetrics^.Count);
    if LWidth <= AMaxSize then Break;
    Dec(LGlyph);
  end;
  LBlock.FWidth := Round(LWidth);
{$IFDEF UNICODE}
  LBlock.FLengthVisible := LMetrics^.Count;
{$ELSE}
  LBlock.FLengthVisible := UTF8CodepointToByteIndex(LBlock.Text, LBlock.TextLength, LMetrics^.Count);
{$ENDIF}
end;
{$ENDREGION}

{$REGION ' Render2D '}

{ TACLCairoRender }

procedure TACLCairoRender.BeginPaint(ACairo: Pcairo_t);
begin
  CheckRecursivePaint;
  FTargetSurface := nil;
  FHandle := ACairo;
  FHandleOwnership := soReference;
  FImageSmoothStretching := TACLBoolean.Default;
  FOrigin := NullPoint;
end;

procedure TACLCairoRender.BeginPaint(ACanvas: TCanvas);
begin
  CheckRecursivePaint;
  // Если DC у DIB-а уже захвачен - рисуем на нем, не переключаемся.
  // Иначе запрос Bits спровоцирует отключение канваса и следующий за нами
  // вызов уже получит канвас без Handle-а и не сможет получить валидный WindowOrg
  if not ACanvas.HandleAllocated and (ACanvas is TACLDibCanvas) then
    BeginPaint(TACLDibCanvas(ACanvas).Owner)
  else
  begin
    FTargetSurface := nil;
    FHandleOwnership := soOwned;
    FHandle := cairo_create_context(ACanvas.Handle, FOrigin, FContext);
    FImageSmoothStretching := TACLBoolean.Default;
    cairo_set_clipping(Handle, ACanvas.Handle);
  end;
end;

procedure TACLCairoRender.BeginPaint(AColors: PACLPixel32Array; AWidth, AHeight: Integer);
begin
  CheckRecursivePaint;
  FOrigin := NullPoint;
  FTargetSurface := cairo_create_surface(AColors, AWidth, AHeight);
  FHandleOwnership := soOwned;
  FHandle := cairo_create(FTargetSurface);
  FImageSmoothStretching := TACLBoolean.Default;
end;

procedure TACLCairoRender.BeginPaint(ADib: TACLDib);
begin
  BeginPaint(ADib.Colors, ADib.Width, ADib.Height);
end;

procedure TACLCairoRender.BeginPaint(ASurface: Pcairo_surface_t);
begin
  FTargetSurface := nil;
  FHandleOwnership := soOwned;
  FHandle := cairo_create(ASurface);
  FImageSmoothStretching := TACLBoolean.Default;
  FOrigin := NullPoint;
end;

procedure TACLCairoRender.BeginPaint(DC: HDC; const BoxRect, UpdateRect: TRect);
begin
  FTargetSurface := nil;
  FHandleOwnership := soOwned;
  FHandle := cairo_create_context(DC, FOrigin, FContext);
  FImageSmoothStretching := TACLBoolean.Default;
  cairo_rectangle(FHandle,
    UpdateRect.Left - FOrigin.X,
    UpdateRect.Top - FOrigin.Y,
    UpdateRect.Width, UpdateRect.Height);
  cairo_clip(FHandle);
end;

procedure TACLCairoRender.EndPaint;
begin
  if FHandle <> nil then
  try
    if FHandleOwnership = soOwned then
      cairo_destroy_context(FHandle, FContext);
    if FTargetSurface <> nil then
      cairo_surface_destroy(FTargetSurface);
  finally
    FTargetSurface := nil;
    FContext := nil;
    FHandle := nil;
  end;
end;

function TACLCairoRender.CreateImage(Colors: PACLPixel32;
  Width, Height: Integer; AlphaFormat: TAlphaFormat): TACL2DRenderImage;
begin
  Result := TACLCairoRenderImage.Create(Self, Colors, Width, Height, AlphaFormat);
end;

function TACLCairoRender.CreatePath: TACL2DRenderPath;
begin
  Result := TACLCairoRenderPath.Create(Self);
end;

function TACLCairoRender.Clip(const R: TRect; out Data: TACL2DRenderRawData): Boolean;
begin
  Result := IsVisible(R);
  if Result then
  begin
    Data := nil;
    cairo_save(Handle);
    cairo_rectangle(Handle, R.Left - Origin.X, R.Top - Origin.Y, R.Width, R.Height);
    cairo_clip(Handle);
  end;
end;

function TACLCairoRender.Clip(const R: TACLRegionData; out Data: TACL2DRenderRawData): Boolean;
var
  LRect: PRect;
  I: Integer;
begin
  Result := R.Count > 0;
  if Result then
  begin
    Data := nil;
    cairo_save(Handle);
    LRect := @R.Rects^[0];
    for I := 0 to R.Count - 1 do
    begin
      cairo_rectangle(Handle,
        LRect^.Left - Origin.X, LRect^.Top - Origin.Y,
        LRect^.Width, LRect^.Height);
      Inc(LRect);
    end;
    cairo_clip(Handle);
  end;
end;

procedure TACLCairoRender.ClipRestore(Data: TACL2DRenderRawData);
var
  LMatrix: cairo_matrix_t;
begin
  cairo_get_matrix(Handle, @LMatrix);
  cairo_restore(Handle);
  cairo_set_matrix(Handle, @LMatrix);
end;

function TACLCairoRender.IsVisible(const R: TRect): Boolean;
begin
  Result := True;
end;

procedure TACLCairoRender.DrawEllipse(X1, Y1, X2, Y2: Single;
  Color: TAlphaColor; Width: Single; Style: TACL2DRenderStrokeStyle);
begin
  if (X2 > X1) and (Y2 > Y1) and Color.IsValid then
  begin
    PathEllipseArc(X1, Y1, X2, Y2);
    cairo_set_line(Handle, Width, Style);
    cairo_set_source_color(Handle, Color);
    cairo_stroke(Handle);
  end;
end;

procedure TACLCairoRender.FillEllipse(X1, Y1, X2, Y2: Single; Color: TAlphaColor);
begin
  if (X2 > X1) and (Y2 > Y1) and Color.IsValid then
  begin
    PathEllipseArc(X1, Y1, X2, Y2);
    cairo_set_source_color(Handle, Color);
    cairo_fill(Handle);
  end;
end;

procedure TACLCairoRender.Line(X1, Y1, X2, Y2: Single;
  Color: TAlphaColor; Width: Single; Style: TACL2DRenderStrokeStyle);
begin
  cairo_move_to(Handle, X1 - Origin.X, Y1 - Origin.Y);
  cairo_line_to(Handle, X2 - Origin.X, Y2 - Origin.Y);
  cairo_set_source_color(Handle, Color);
  cairo_set_line(Handle, Width, Style);
  cairo_stroke(Handle);
end;

procedure TACLCairoRender.Line(const Points: PPoint; Count: Integer;
  Color: TAlphaColor; Width: Single; Style: TACL2DRenderStrokeStyle);
begin
  if (Count > 1) and Color.IsValid and (Width > 0) then
  begin
    PathPolyline(Points, Count, False);
    cairo_set_source_color(Handle, Color);
    cairo_set_line(Handle, Width, Style);
    cairo_stroke(Handle);
  end;
end;

procedure TACLCairoRender.DrawImage(Image: TACL2DRenderImage;
  const TargetRect, SourceRect: TRect; Alpha: Byte);
begin
  if IsValid(Image) then
    FillSurface(TargetRect, SourceRect, TACLCairoRenderImage(Image).Handle, Alpha / 255, False);
end;

procedure TACLCairoRender.DrawImage(Image: TACL2DRenderImage;
  const TargetRect, SourceRect: TRect; Attributes: TACL2DRenderImageAttributes);
var
  LColor: TCairoColor;
  LTemp: TACLCairoRender;
  LTempRect: TRect;
  LTempSurface: Pcairo_surface_t;
begin
  if TargetRect.IsEmpty then
    Exit;
  if SourceRect.IsEmpty then
    Exit;
  if not IsValid(Image) then
    Exit;
  if not IsValid(Attributes) then
  begin
    DrawImage(Image, TargetRect, SourceRect);
    Exit;
  end;

  if Attributes.TintColor.IsValid then
  begin
    LColor := TCairoColor.From(Attributes.TintColor);
    LColor.A := LColor.A * Attributes.Alpha / MaxByte;
    cairo_set_source_color(Handle, LColor);

    if (SourceRect.Top = 0) and (SourceRect.Left = 0) and TargetRect.EqualSizes(SourceRect) then
    begin
      cairo_mask_surface(Handle, TACLCairoRenderImage(Image).Handle,
        TargetRect.Left - Origin.X, TargetRect.Top - Origin.Y);
    end
    else
    begin
      LTempRect := TargetRect - TargetRect.TopLeft;
      LTempSurface := cairo_create_surface(LTempRect.Right, LTempRect.Bottom);
      try
        LTemp := TACLCairoRender.Create;
        try
          LTemp.BeginPaint(LTempSurface);
          LTemp.FillSurface(LTempRect, SourceRect,
            TACLCairoRenderImage(Image).Handle, 1.0, False);
          LTemp.EndPaint;
        finally
          LTemp.Free;
        end;
        cairo_mask_surface(Handle, LTempSurface,
          TargetRect.Left - Origin.X, TargetRect.Top - Origin.Y);
      finally
        cairo_surface_destroy(LTempSurface);
      end;
    end;
  end
  else
    DrawImage(Image, TargetRect, SourceRect, Attributes.Alpha);
end;

procedure TACLCairoRender.DrawRectangle(X1, Y1, X2, Y2: Single;
  Color: TAlphaColor; Width: Single; Style: TACL2DRenderStrokeStyle);
begin
  if (X2 > X1) and (Y2 > Y1) then
  begin
    cairo_rectangle(Handle, X1 - Origin.X, Y1 - Origin.Y, X2 - X1, Y2 - Y1);
    cairo_set_source_color(Handle, Color);
    cairo_set_line(Handle, Width, Style);
    cairo_stroke(Handle);
  end;
end;

procedure TACLCairoRender.FillHatchRectangle(
  const R: TRect; Color1, Color2: TAlphaColor; Size: Integer);
var
  LTemp: Pcairo_t;
  LTempSurface: Pcairo_surface_t;
  X, Y: Double;
begin
  LTempSurface := cairo_create_surface(2 * Size, 2 * Size);
  try
    LTemp := cairo_create(LTempSurface);
    try
      // Color1
      cairo_set_source_color(LTemp, Color1);
      cairo_rectangle(LTemp,    0,    0, Size, Size);
      cairo_rectangle(LTemp, Size, Size, Size, Size);
      cairo_fill(LTemp);
      // Color2
      cairo_set_source_color(LTemp, Color2);
      cairo_rectangle(LTemp,    0, Size, Size, Size);
      cairo_rectangle(LTemp, Size,    0, Size, Size);
      cairo_fill(LTemp);
    finally
      cairo_destroy(LTemp);
    end;

    X := R.Left - Origin.X;
    Y := R.Top - Origin.Y;
    cairo_set_source_surface(Handle, LTempSurface, X, Y);
    cairo_pattern_set_extend(cairo_get_source(Handle), CAIRO_EXTEND_REPEAT);
    cairo_rectangle(Handle, X, Y, R.Width, R.Height);
    cairo_fill(Handle);
  finally
    cairo_surface_destroy(LTempSurface);
  end;
end;

procedure TACLCairoRender.FillRectangle(X1, Y1, X2, Y2: Single; Color: TAlphaColor);
begin
  if (X2 > X1) and (Y2 > Y1) then
  begin
    cairo_set_source_color(Handle, Color);
    cairo_rectangle(Handle, X1 - Origin.X, Y1 - Origin.Y, X2 - X1, Y2 - Y1);
    cairo_fill(Handle);
  end;
end;

procedure TACLCairoRender.FillRectangleByGradient(
  const ARect: TRect; AFrom, ATo: TAlphaColor; AVertical: Boolean);
var
  LPattern: Pcairo_pattern_t;
begin
  if AVertical then
    LPattern := cairo_pattern_create_linear(0, ARect.Top - Origin.Y, 0, ARect.Bottom - Origin.Y)
  else
    LPattern := cairo_pattern_create_linear(ARect.Left - Origin.X, 0, ARect.Right - Origin.X, 0);

  with TCairoColor.From(AFrom) do
    cairo_pattern_add_color_stop_rgba(LPattern, 0.0, R, G, B, A);
  with TCairoColor.From(ATo) do
    cairo_pattern_add_color_stop_rgba(LPattern, 1.0, R, G, B, A);

  cairo_rectangle(Handle, ARect.Left - Origin.X,
    ARect.Top - Origin.Y, ARect.Width, ARect.Height);
  cairo_set_source(Handle, LPattern);
  cairo_fill(Handle);

  cairo_pattern_destroy(LPattern);
end;

procedure TACLCairoRender.FillSurface(const ATargetRect, ASourceRect: TRect;
  ASurface: Pcairo_surface_t; AAlpha: Double; ATileMode: Boolean;
  AOperator: cairo_operator_t = CAIRO_OPERATOR_OVER);
const
  Map: array[TACLBoolean] of cairo_filter_t = (
    CAIRO_FILTER_NEAREST, // default
    CAIRO_FILTER_NEAREST, // false
    CAIRO_FILTER_BEST     // true
  );
begin
  cairo_fill_surface(Handle, ASurface, ATargetRect, ASourceRect,
    FOrigin, AAlpha, ATileMode, AOperator, Map[FImageSmoothStretching]);
end;

function TACLCairoRender.FriendlyName: string;
begin
  Result := 'Cairo Graphics';
end;

function TACLCairoRender.Name: string;
begin
  Result := 'Cairo';
end;

procedure TACLCairoRender.MeasureText(
  const Text: string; Font: TFont; var Rect: TRect; WordWrap: Boolean);
var
  LFont: Pcairo_scaled_font_t;
  LFontMetrics: TCairoFontMetrics;
  LGlyphCount: Integer;
  LGlyphs: PCairoGlyphArray;
  LLines: TCairoTextLine;
  LFlags: Cardinal;
begin
  cairo_set_font(Handle, Font);
  LFont := cairo_get_scaled_font(Handle);
  if cairo_text_to_glyphs(LFont, Text, LGlyphs, LGlyphCount) then
  try
    LFlags := DT_CALCRECT;
    if WordWrap then
      LFlags := LFlags or DT_WORDBREAK;

    LLines.Init(LGlyphs, 0, LGlyphCount);
    try
      CairoCalculateTextLayout(LFont, @LLines, Rect, LFlags);
      cairo_font_metrics(LFont, LFontMetrics);
      Rect.Height := Ceil(LLines.GetCount * LFontMetrics.height);
      Rect.Width := Ceil(LLines.GetMaxWidth);
    finally
      LLines.Free;
    end;
  finally
    cairo_glyph_free(@LGlyphs^[0]);
  end;
end;

procedure TACLCairoRender.DrawText(const Text: string; const R: TRect;
  Color: TAlphaColor; Font: TFont; HorzAlign: TAlignment;
  VertAlign: TVerticalAlignment; WordWrap: Boolean);
var
  LFont: Pcairo_scaled_font_t;
  LFontMetrics: TCairoFontMetrics;
  LGlyphCount: Integer;
  LGlyphs: PCairoGlyphArray;
  LLines: TCairoTextLine;
  LFlags: Cardinal;
begin
  if R.IsEmpty or not Color.IsValid or (Text = '') then
    Exit;

  cairo_set_font(Handle, Font);
  LFont := cairo_get_scaled_font(Handle);
  if cairo_text_to_glyphs(LFont, Text, LGlyphs, LGlyphCount) then
  try
    LFlags := acTextAlignHorz[HorzAlign] or acTextAlignVert[VertAlign];
    if WordWrap then
      LFlags := LFlags or DT_WORDBREAK;

    LLines.Init(LGlyphs, 0, LGlyphCount);
    try
      CairoCalculateTextLayout(LFont, @LLines, R - Origin, LFlags);
      cairo_font_metrics(LFont, LFontMetrics);
      cairo_set_source_color(Handle, Color);
      CairoDrawTextLines(Handle, @LLines, Font.Style, LFontMetrics);
    finally
      LLines.Free;
    end;
  finally
    cairo_glyph_free(@LGlyphs^[0]);
  end;
end;

procedure TACLCairoRender.DrawPath(Path: TACL2DRenderPath;
  Color: TAlphaColor; Width: Single; Style: TACL2DRenderStrokeStyle);
begin
  if IsValid(Path) then
  begin
    TACLCairoRenderPath(Path).Write(Handle, -Origin.X, -Origin.Y);
    cairo_set_source_color(Handle, Color);
    cairo_set_line(Handle, Width, Style);
    cairo_stroke(Handle);
  end;
end;

procedure TACLCairoRender.FillPath(Path: TACL2DRenderPath; Color: TAlphaColor);
begin
  if IsValid(Path) then
  begin
    TACLCairoRenderPath(Path).Write(Handle, -Origin.X, -Origin.Y);
    cairo_set_source_color(Handle, Color);
    cairo_fill(Handle);
  end;
end;

procedure TACLCairoRender.DrawPolygon(const Points: array of TPoint;
  Color: TAlphaColor; Width: Single; Style: TACL2DRenderStrokeStyle);
begin
  if (Length(Points) > 1) and Color.IsValid and (Width > 0) then
  begin
    PathPolyline(@Points[0], Length(Points), True);
    cairo_set_source_color(Handle, Color);
    cairo_set_line(Handle, Width, Style);
    cairo_stroke(Handle);
  end;
end;

procedure TACLCairoRender.FillPolygon(const Points: array of TPoint; Color: TAlphaColor);
begin
  if (Length(Points) > 1) and Color.IsValid then
  begin
    PathPolyline(@Points[0], Length(Points), True);
    cairo_set_source_color(Handle, Color);
    cairo_fill(Handle);
  end;
end;

procedure TACLCairoRender.ModifyWorldTransform(const XForm: TXForm);
var
  LMatrix: cairo_matrix_t;
begin
  cairo_matrix_init(LMatrix, XForm);
  cairo_transform(Handle, @LMatrix);
end;

procedure TACLCairoRender.RestoreWorldTransform(State: TACL2DRenderRawData);
var
  LMatrix: pcairo_matrix_t absolute State;
begin
  cairo_set_matrix(Handle, LMatrix);
  Dispose(LMatrix);
end;

procedure TACLCairoRender.SaveWorldTransform(out State: TACL2DRenderRawData);
var
  LMatrix: pcairo_matrix_t absolute State;
begin
  New(LMatrix);
  cairo_get_matrix(Handle, LMatrix);
end;

procedure TACLCairoRender.ScaleWorldTransform(ScaleX, ScaleY: Single);
begin
  cairo_scale(Handle, ScaleX, ScaleY);
end;

procedure TACLCairoRender.SetImageSmoothing(AValue: TACLBoolean);
begin
  FImageSmoothStretching := AValue;
end;

procedure TACLCairoRender.SetWorldTransform(const XForm: TXForm);
var
  LMatrix: cairo_matrix_t;
begin
  cairo_matrix_init(LMatrix, XForm);
  cairo_set_matrix(Handle, @LMatrix);
end;

procedure TACLCairoRender.TranslateWorldTransform(OffsetX, OffsetY: Single);
begin
  cairo_translate(Handle, OffsetX, OffsetY);
end;

procedure TACLCairoRender.TransformPoints(Points: PPointF; Count: Integer);
var
  LMatrix: cairo_matrix_t;
  LPoint: TPointF;
begin
  cairo_get_matrix(Handle, @LMatrix);
  while Count > 0 do
  begin
    LPoint := Points^;
    Points^.X := LPoint.X * LMatrix.xx + LPoint.Y * LMatrix.yx + LMatrix.x0;
    Points^.Y := LPoint.X * LMatrix.xy + LPoint.Y * LMatrix.yy + LMatrix.y0;
    Inc(Points);
    Dec(Count);
  end;
end;

procedure TACLCairoRender.CheckRecursivePaint;
begin
  if Handle <> nil then
    raise EInvalidGraphicOperation.Create(ClassName + ' recursive calls not yet supported');
end;

procedure TACLCairoRender.PathEllipseArc(X1, Y1, X2, Y2: Double);
begin
  if (X2 > X1) and (Y2 > Y1) then
  begin
    cairo_save(Handle);
    try
      cairo_translate(Handle, (X1 + X2) * 0.5 - Origin.X, (Y1 + Y2) * 0.5 - Origin.Y);
      cairo_scale(Handle, (X2 - X1) * 0.5, (Y2 - Y1) * 0.5);
      cairo_move_to(Handle, 1, 0);
      cairo_arc(Handle, 0, 0, 1, 0, 2 * PI);
    finally
      cairo_restore(Handle);
    end;
  end;
end;

procedure TACLCairoRender.PathPolyline(Points: PPoint; Count: Integer; ClosePath: Boolean);
var
  LFirstPoint: PPoint;
begin
  if Count > 1 then
  begin
    LFirstPoint := Points;
    cairo_move_to(Handle, Points^.X - Origin.X, Points^.Y - Origin.X);
    while Count > 1 do
    begin
      Inc(Points);
      Dec(Count);
      cairo_line_to(Handle, Points^.X - Origin.X, Points^.Y - Origin.X);
    end;
    if ClosePath then
      cairo_line_to(Handle, LFirstPoint^.X - Origin.X, LFirstPoint^.Y - Origin.X);
  end;
end;

{ TACLCairoRenderImage }

constructor TACLCairoRenderImage.Create(ARender: TACL2DRender;
  AColors: PACLPixel32; AWidth, AHeight: Integer; AAlphaFormat: TAlphaFormat);
var
  LNumBytes: Integer;
begin
  inherited Create(ARender);
  if AAlphaFormat <> afPremultiplied then
  begin
    LNumBytes := AWidth * AHeight * SizeOf(TACLPixel32);
    FColors := AllocMem(LNumBytes);
    Move(AColors^, FColors^, LNumBytes);
    if AAlphaFormat = afDefined then
      TACLColors.Premultiply(FColors, AWidth * AHeight);
    if AAlphaFormat = afIgnored then
      TACLColors.MakeOpaque(FColors, AWidth * AHeight);
    AColors := PACLPixel32(FColors);
  end;
  FHandle := cairo_create_surface(PACLPixel32Array(AColors), AWidth, AHeight);
  FHeight := AHeight;
  FWidth := AWidth;
end;

destructor TACLCairoRenderImage.Destroy;
begin
  cairo_surface_destroy(FHandle);
  FreeMemAndNil(FColors);
  inherited;
end;

{ TACLCairoRenderPath }

destructor TACLCairoRenderPath.Destroy;
begin
  FreeAndNil(FFigures);
  inherited Destroy;
end;

procedure TACLCairoRenderPath.AddArc(
  CenterX, CenterY, RadiusX, RadiusY, StartAngle, SweepAngle: Single);
var
  LItem: TArc;
  LAngle1: Single;
  LAngle2: Single;
  P1, P2: TPointF;
begin
  LAngle1 := DegToRad(StartAngle);
  LAngle2 := DegToRad(StartAngle + SweepAngle);
  acCalcArcSegment(CenterX, CenterY, RadiusX, RadiusY, 2 * PI - LAngle1, 2 * PI - LAngle2, P1, P2);
  LItem := TArc.Create(P2.X, P2.Y);
  LItem.CX := CenterX;
  LItem.CY := CenterY;
  LItem.RX := RadiusX;
  LItem.RY := RadiusY;
  LItem.Angle1 := LAngle1;
  LItem.Angle2 := LAngle2;
  StartFigureIfNecessary(P1.X, P1.Y).Add(LItem);
end;

procedure TACLCairoRenderPath.AddLine(X1, Y1, X2, Y2: Single);
begin
  StartFigureIfNecessary(X1, Y1).Add(TLineTo.Create(X2, Y2));
end;

procedure TACLCairoRenderPath.FigureClose;
var
  LLast, LFirst: TItem;
begin
  if FFigure <> nil then
  begin
    if FFigure.Count > 0 then
    begin
      LLast := FFigure.Last;
      LFirst := FFigure.First;
      if not (SameValue(LLast.X, LFirst.X) and SameValue(LLast.Y, LFirst.Y)) then
        FFigure.Add(TLineTo.Create(LFirst.X, LFirst.Y));
    end;
    FFigure := nil;
  end;
end;

procedure TACLCairoRenderPath.FigureStart;
begin
  FigureClose;
end;

function TACLCairoRenderPath.StartFigureIfNecessary(X, Y: Single): TFigure;
begin
  if FFigure = nil then
  begin
    if FFigures = nil then
      FFigures := TACLObjectListOf<TFigure>.Create(True);
    FFigure := TFigure.Create;
    FFigures.Add(FFigure);
  end;

  if (FFigure.Count = 0) or
    not SameValue(X, FFigure.Last.X) or
    not SameValue(Y, FFigure.Last.Y)
  then
    FFigure.Add(TMoveTo.Create(X, Y));

  Result := FFigure;
end;

procedure TACLCairoRenderPath.Write(Handle: Pcairo_t; dX, dY: Single);
var
  LFigure: TFigure;
  I, J: Integer;
begin
  if FFigures = nil then
    Exit;
  for I := 0 to FFigures.Count - 1 do
  begin
    LFigure := FFigures.List[I];
    for J := 0 to LFigure.Count - 1 do
      LFigure.List[J].Write(Handle, dX, dY);
  end;
end;

{ TACLCairoRenderPath.TArc }

procedure TACLCairoRenderPath.TArc.Write(Handle: Pcairo_t; dX, dY: Single);
begin
  cairo_save(Handle);
  try
    cairo_translate(Handle, CX + dX, CY + dY);
    cairo_scale(Handle, RX, RY);
    if Angle2 > Angle1 then
      cairo_arc(Handle, 0, 0, 1, Angle1, Angle2)
    else
      cairo_arc_negative(Handle, 0, 0, 1, Angle1, Angle2);
  finally
    cairo_restore(Handle);
  end;
end;

{ TACLCairoRenderPath.TItem }

constructor TACLCairoRenderPath.TItem.Create(X, Y: Single);
begin
  Self.X := X;
  Self.Y := Y;
end;

{ TACLCairoRenderPath.TMoveTo }

procedure TACLCairoRenderPath.TMoveTo.Write(Handle: Pcairo_t; dX, dY: Single);
begin
  cairo_move_to(Handle, X + dX, Y + dY);
end;

{ TACLCairoRenderPath.TLineTo }

procedure TACLCairoRenderPath.TLineTo.Write(Handle: Pcairo_t; dX, dY: Single);
begin
  cairo_line_to(Handle, X + dX, Y + dY);
end;
{$ENDREGION}

{$REGION ' Blend Mode '}

{ TCairoBlendFunctions }

class procedure TCairoBlendFunctions.DoAddition(
  ABackground, AForeground: TACLDib; AAlpha: Byte);
begin
  DoBlend(ABackground, AForeground, AAlpha, CAIRO_OPERATOR_ADD);
end;

class procedure TCairoBlendFunctions.DoBlend(
  ABackground, AForeground: TACLDib; AAlpha: Byte; AOperator: cairo_operator_t);
var
  LCairo: Pcairo_t;
  LBackground: Pcairo_surface_t;
  LForeground: Pcairo_surface_t;
begin
  LBackground := cairo_create_surface(ABackground.Colors, ABackground.Width, ABackground.Height);
  LForeground := cairo_create_surface(AForeground.Colors, AForeground.Width, AForeground.Height);
  try
    LCairo := cairo_create(LBackground);
    try
      cairo_fill_surface(LCairo, LForeground, ABackground.ClientRect,
        AForeground.ClientRect, NullPoint, AAlpha / 255, False, AOperator);
    finally
      cairo_destroy(LCairo);
    end;
  finally
    cairo_surface_destroy(LBackground);
    cairo_surface_destroy(LForeground);
  end;
end;

//class procedure TCairoBlendFunctions.DoBlend(Canvas: TCanvas;
//  Foreground: TACLDib; const Origin: TPoint; Mode: TACLBlendMode; Alpha: Byte);
//var
//  LCairo: Pcairo_t;
//  LContext: PCairoContext;
//  LForeground: Pcairo_surface_t;
//  LOrigin: TPoint;
//begin
//  if Mode in Supported then
//  begin
//    LForeground := cairo_create_surface(Foreground.Colors, Foreground.Width, Foreground.Height);
//    try
//      LCairo := cairo_create_context(Canvas.Handle, LOrigin, LContext);
//      try
//        cairo_fill_surface(LCairo, LForeground,
//          Foreground.ClientRect, Foreground.ClientRect,
//          LOrigin + Origin, Alpha / 255, False, ModeMap[Mode]);
//      finally
//        cairo_destroy_context(LCairo, LContext);
//      end;
//    finally
//      cairo_surface_destroy(LForeground);
//    end;
//  end
//  else
//    acDrawBlendFunc(Canvas, Foreground, Origin, Mode, Alpha);
//end;

class procedure TCairoBlendFunctions.DoDarken(
  ABackground, AForeground: TACLDib; AAlpha: Byte);
begin
  DoBlend(ABackground, AForeground, AAlpha, CAIRO_OPERATOR_DARKEN);
end;

class procedure TCairoBlendFunctions.DoDifference(
  ABackground, AForeground: TACLDib; AAlpha: Byte);
begin
  DoBlend(ABackground, AForeground, AAlpha, CAIRO_OPERATOR_DIFFERENCE);
end;

class procedure TCairoBlendFunctions.DoLighten(
  ABackground, AForeground: TACLDib; AAlpha: Byte);
begin
  DoBlend(ABackground, AForeground, AAlpha, CAIRO_OPERATOR_LIGHTEN);
end;

class procedure TCairoBlendFunctions.DoMultiply(
  ABackground, AForeground: TACLDib; AAlpha: Byte);
begin
  DoBlend(ABackground, AForeground, AAlpha, CAIRO_OPERATOR_MULTIPLY);
end;

class procedure TCairoBlendFunctions.DoOverlay(
  ABackground, AForeground: TACLDib; AAlpha: Byte);
begin
  DoBlend(ABackground, AForeground, AAlpha, CAIRO_OPERATOR_OVERLAY);
end;

class procedure TCairoBlendFunctions.DoScreen(
  ABackground, AForeground: TACLDib; AAlpha: Byte);
begin
  DoBlend(ABackground, AForeground, AAlpha, CAIRO_OPERATOR_SCREEN);
end;

class procedure TCairoBlendFunctions.Register;
begin
//  BlendModeDraw := DoBlend;
  BlendFunctions[bmAddition] := DoAddition;
  BlendFunctions[bmAddition] := DoAddition;
  BlendFunctions[bmDarken] := DoDarken;
  BlendFunctions[bmDifference] := DoDifference;
  BlendFunctions[bmLighten] := DoLighten;
  BlendFunctions[bmMultiply] := DoMultiply;
  BlendFunctions[bmOverlay] := DoOverlay;
  BlendFunctions[bmScreen] := DoScreen;
end;

{$ENDREGION}

initialization
  CairoPainter := TACLCairoRender.Create;

finalization
  FreeAndNil(CairoPainter);
end.
