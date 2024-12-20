﻿////////////////////////////////////////////////////////////////////////////////
//
//  Project:   Artem's Components Library aka ACL
//             v6.0
//
//  Purpose:   Graphics Library
//
//  Author:    Artem Izmaylov
//             © 2006-2024
//             www.aimp.ru
//
//  FPC:       OK
//
unit ACL.Graphics;

{$I ACL.Config.inc}

{$POINTERMATH ON}

interface

uses
{$IFDEF ACL_CAIRO}
  Cairo,
{$ENDIF}
{$IFDEF LCLGtk2}
  Gdk2pixbuf,
{$ENDIF}
{$IFDEF FPC}
  GraphType,
  IntfGraphics,
  LCLIntf,
  LCLType,
{$ELSE}
  Winapi.GDIPAPI,
  Winapi.Windows,
{$ENDIF}
  // System
  {System.}Classes,
  {System.}Math,
  {System.}StrUtils,
  {System.}SysUtils,
  {System.}Types,
  System.UIConsts,
  System.UITypes,
  // Vcl
  {Vcl.}Graphics,
  // ACL
  ACL.Classes.Collections,
  ACL.FastCode,
  ACL.Geometry,
  ACL.Utils.Common;

type
  TRGBColors = array of TRGBQuad;
  TACLArrowKind = (makLeft, makRight, makTop, makBottom);
{$IFDEF FPC}
  TAlphaFormat = (afIgnored, afDefined, afPremultiplied);
{$ENDIF}

const
  acDropArrowSize: TSize = (cx: 7; cy: 3);
  acMeasureTextPattern = 'Qq';
  acEndEllipsis: string = '…';
  acFocusRectIndent = 1;
  acTextIndent = 2;

  acDragImageAlpha = 150;
  acDragImageColor = $8F2929;
  acHatchDefaultColor1 = clWhite;
  acHatchDefaultColor2 = $BFBFBF;
  acHatchDefaultSize = 8;

  acTextAlignHorz: array[TAlignment] of Integer = (DT_LEFT, DT_RIGHT, DT_CENTER);
  acTextAlignVert: array [TVerticalAlignment] of Integer = (DT_TOP, DT_BOTTOM, DT_VCENTER);

type
{$IFDEF FPC}
  TAlphaColor = type Cardinal;
{$ELSE}
  TAlphaColor = System.UITypes.TAlphaColor;
{$ENDIF}
  PAlphaColor = ^TAlphaColor;
  PAlphaColorArray = ^TAlphaColorArray;
  TAlphaColorArray = array[0..0] of TAlphaColor;

type
  TRegionHandle = HRGN;

  { TACLColorSchema }

  TACLColorSchema = record
    Hue: Byte;
    HueIntensity: Byte;

    constructor Create(AHue: Byte; AHueIntensity: Byte = 100);
    class function CreateFromColor(AColor: TAlphaColor): TACLColorSchema; static;
    class function Default: TACLColorSchema; static;
    function IsAssigned: Boolean;

    class operator Equal(const C1, C2: TACLColorSchema): Boolean;
    class operator NotEqual(const C1, C2: TACLColorSchema): Boolean;
  end;

  { IACLColorSchema }

  IACLColorSchema = interface
  ['{19F1214B-9BE2-4E0A-B70C-28771671ABAF}']
    procedure ApplyColorSchema(const ASchema: TACLColorSchema);
  end;

  { TACLPixel32 }

  /// <summary>
  ///  TACLPixel32 - platform-depended version of TRGBQuad.
  ///  Used for more optimal operations with pixels
  /// </summary>
  PACLPixel32 = ^TACLPixel32;
  TACLPixel32 = packed record
  public const
    EssenceMask = $00FFFFFF;
  public
    B, G, R, A: Byte; // TRGBQuad's order
    class function Create(A, R, G, B: Byte): TACLPixel32; overload; static; inline;
    class function Create(AColor: TAlphaColor): TACLPixel32; overload; static;
    class function Create(AColor: TColor; AAlpha: Byte = MaxByte): TACLPixel32; overload; static;
    class operator Implicit(const Value: TRGBQuad): TACLPixel32; overload;
    class operator Implicit(const Value: TACLPixel32): TRGBQuad; overload;
    function ToColor: TColor;
  end;

  PACLPixel32Array = ^TACLPixel32Array;
  TACLPixel32Array = array [0..0] of TACLPixel32;
  TACLPixel32DynArray = array of TACLPixel32;

  PACLPixelMap = ^TACLPixelMap;
  TACLPixelMap = array[Byte, Byte] of Byte;

  { TAlphaColorHelper }

  TAlphaColorHelper = record helper for TAlphaColor
  strict private type
    PARGB = ^TARGB;
    TARGB = array[0..3] of Byte;
  strict private
    function GetAlpha(const Index: Integer): Byte;
    function GetComponent(const Index: Integer): Byte;
    procedure SetComponent(const Index: Integer; const Value: Byte);
  public const
    None = TAlphaColor(0);
    Default = TAlphaColor($00010203);
    Black = TAlphaColor($FF000000);
    White = TAlphaColor($FFFFFFFF);
  public
    class function ApplyColorSchema(AColor: TAlphaColor; const ASchema: TACLColorSchema): TAlphaColor; static;
    class function FromARGB(const A, R, G, B: Byte): TAlphaColor; static;
    class function FromColor(const AColor: TColor; AAlpha: Byte = MaxByte): TAlphaColor; overload; static;
    class function FromColor(const AColor: TACLPixel32): TAlphaColor; overload; static;
    class function FromString(AColor: string): TAlphaColor; static;
    function IsDefault: Boolean; inline;
    function IsValid: Boolean; inline;
    function ToColor: TColor;
    function ToPixel: TACLPixel32;
    function ToString: string;

    property A: Byte index 3 read GetAlpha write SetComponent;
    property R: Byte index 2 read GetComponent write SetComponent;
    property G: Byte index 1 read GetComponent write SetComponent;
    property B: Byte index 0 read GetComponent write SetComponent;
  end;

  { TFontHelper }

  TFontHelper = class helper for TFont
  public
    procedure Assign(Source: TFont; SourceDpi, TargetDpi: Integer); overload;
    function Clone: TFont;
    procedure ResolveHeight;
    procedure SetSize(ASize: Integer; ATargetDpi: Integer); overload;
  end;

  { TCanvasHelper }

  TCanvasHelper = class helper for TCanvas
  public
    procedure SetScaledFont(AFont: TFont);
  end;

  // Refer to following articles for more information:
  //  https://en.wikipedia.org/wiki/Blend_modes
  //  https://en.wikipedia.org/wiki/Alpha_compositing
  TACLBlendMode = (bmNormal, bmMultiply, bmScreen, bmOverlay, bmAddition,
    bmSubstract, bmDifference, bmDivide, bmLighten, bmDarken, bmGrayscale);
  TACLBlendModes = set of TACLBlendMode;

  { TACLDib }

  TACLDib = class
  strict private
    FBitmap: HBITMAP;
    FCanvas: TCanvas;
    FColorCount: Integer;
    FColors: PACLPixel32Array;
    FHandle: HDC;
    FHeight: Integer;
    FWidth: Integer;

    function GetCanvas: TCanvas;
    function GetClientRect: TRect; inline;
    function GetEmpty: Boolean; inline;
    function GetSize: TSize; inline;
  {$IFDEF FPC}
  strict private
    FCanvasChanged: Boolean;
    FColorsChanged: Boolean;
    function GetColors: PACLPixel32Array;
    function GetDC: HDC;
  protected
    procedure CopyCanvasToColors; virtual;
    procedure CopyColorsToCanvas; virtual;
  {$ENDIF}
  protected
    procedure CreateHandles(W, H: Integer); virtual;
    procedure FreeHandles; virtual;
  public
    constructor Create; overload;
    constructor Create(const R: TRect); overload;
    constructor Create(const S: TSize); overload;
    constructor Create(const W, H: Integer); overload; virtual;
    destructor Destroy; override;
    procedure Assign(AColors: PACLPixel32; AWidth, AHeight: Integer); overload;
    procedure Assign(ASource: TACLDib); overload;
    procedure Assign(ASource: TGraphic); overload;
  {$IFDEF LCLGtk2}
    procedure Assign(ASource: PGdkPixbuf); overload;
  {$ENDIF}
  {$IFDEF FPC}
    procedure Assign(ASource: TRawImage); overload;
    procedure Assign(ASource: TLazIntfImage); overload;
    procedure AssignTo(ATarget: TRasterImage);
  {$ELSE}
    procedure AssignTo(ATarget: TBitmap);
  {$ENDIF}
    function Clone(out AData: PACLPixel32Array): Boolean;
    function CoordToFlatIndex(X, Y: Integer): Integer; inline;
    function Equals(Obj: TObject): Boolean; override;
    function IsPremultiplied: Boolean;

    //# Processing
    procedure ApplyTint(const AColor: TColor); overload;
    procedure ApplyTint(const AColor: TACLPixel32); overload;
    procedure CopyRect(ACanvas: TCanvas; const R: TRect; X: Integer = 0; Y: Integer = 0);
    procedure Flip(AHorizontally, AVertically: Boolean);
    procedure MakeDisabled(AIgnoreMask: Boolean = False);
    procedure MakeMirror(ASize: Integer);
    procedure MakeOpaque;
    procedure MakeTransparent(const AColor: TACLPixel32); overload;
    procedure MakeTransparent(const AColor: TColor); overload;
    procedure Premultiply; overload;
    procedure Premultiply(R: TRect); overload;
    procedure Unpremultiply;
    procedure Reset; overload;
    procedure Reset(const ARect: TRect); overload;
    function Resize(const ANewBounds: TRect): Boolean; overload;
    function Resize(const ANewWidth, ANewHeight: Integer): Boolean; overload;

    //# Draw
  {$IFDEF ACL_CAIRO}
    procedure DrawBlend(ACairo: Pcairo_t; const ATargetRect, ASourceRect: TRect; AAlpha: Byte = MaxByte); overload;
  {$ENDIF}
    procedure DrawBlend(ACanvas: HDC; const ATargetRect, ASourceRect: TRect; AAlpha: Byte = MaxByte); overload;
    procedure DrawBlend(ACanvas: TCanvas; const P: TPoint; AAlpha: Byte = MaxByte); overload;
    procedure DrawBlend(ACanvas: TCanvas; const P: TPoint;
      AMode: TACLBlendMode; AAlpha: Byte = MaxByte); overload;
    procedure DrawBlend(ACanvas: TCanvas; const ATargetRect, ASourceRect: TRect;
      AAlpha: Byte; ASmoothStretch: Boolean = False); overload;
    procedure DrawBlend(ACanvas: TCanvas; const R: TRect;
      AAlpha: Byte = MaxByte; ASmoothStretch: Boolean = False); overload;
    procedure DrawCopy(ACanvas: TCanvas; const P: TPoint); overload;
    procedure DrawCopy(ACanvas: TCanvas; const R: TRect; ASmoothStretch: Boolean = False); overload;

    //# Properties
    property Canvas: TCanvas read GetCanvas;
    property ColorCount: Integer read FColorCount;
    property Colors: PACLPixel32Array read {$IFDEF FPC}GetColors{$ELSE}FColors{$ENDIF};
    property Empty: Boolean read GetEmpty;
    property Handle: HDC read {$IFDEF FPC}GetDC{$ELSE}FHandle{$ENDIF};
    //# Dimensions
    property ClientRect: TRect read GetClientRect;
    property Height: Integer read FHeight;
    property Size: TSize read GetSize;
    property Width: Integer read FWidth;
  end;

  { TACLDibCanvas }

  TACLDibCanvas = class(TCanvas)
  strict private
    FOwner: TACLDib;
  protected
    {%H-}constructor Create(AOwner: TACLDib);
    procedure CreateHandle; override;
  public
    property Owner: TACLDib read FOwner;
  end; // for internal use only

  { TACLColorList }

  TACLColorList = class(TACLListOf<TColor>);

  { TACLBitmap }

  TACLBitmap = class(TBitmap, IACLColorSchema)
  strict private
    function GetClientRect: TRect;
  {$IFDEF FPC}
    // IUnknown
    function _AddRef: Integer; {$IFDEF MSWINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
    function _Release: Integer; {$IFDEF MSWINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
    function QueryInterface({$IFDEF FPC}constref{$ELSE}const{$ENDIF}
      IID: TGUID; out Obj): HRESULT; virtual; {$IFDEF MSWINDOWS}stdcall{$ELSE}cdecl{$ENDIF};
  {$ENDIF}
  public
    constructor CreateEx(const S: TSize;
      APixelFormat: TPixelFormat = pf32bit; AResetContent: Boolean = False); overload;
    constructor CreateEx(const R: TRect;
      APixelFormat: TPixelFormat = pf32bit; AResetContent: Boolean = False); overload;
    constructor CreateEx(W, H: Integer;
      APixelFormat: TPixelFormat = pf32bit; AResetContent: Boolean = False); overload;
    procedure LoadFromResource(Inst: HINST; const AName, AType: string);
    procedure LoadFromStream(Stream: TStream); override;
    procedure SetSize(const R: TRect); reintroduce; overload;
    // Effects
    procedure ApplyColorSchema(const AValue: TACLColorSchema);
    procedure MakeOpaque;
    procedure MakeTransparent(AColor: TColor);
    procedure Reset;
    // Properties
    property ClientRect: TRect read GetClientRect;
  end;

  { TACLRegion }

  TACLRegionCombineFunc = (rcmOr, rcmAnd, rcmXor, rcmDiff, rcmCopy);

  TACLRegion = class
  strict private const
    CombineFuncMap: array[TACLRegionCombineFunc] of Integer = (
      RGN_OR, RGN_AND, RGN_XOR, RGN_DIFF, RGN_COPY
    );
    MaxRegionSize = 30000;
  strict private
    FHandle: TRegionHandle;

    function GetBounds: TRect;
    function GetIsEmpty: Boolean;
    procedure FreeHandle;
    procedure SetHandle(AValue: TRegionHandle);
  public
    constructor Create; virtual;
    constructor CreateRect(const R: TRect);
    constructor CreateFromDC(DC: HDC);
    constructor CreateFromHandle(AHandle: TRegionHandle);
    destructor Destroy; override;
    //# Methods
    function Clone: TRegionHandle;
    function Contains(const P: TPoint): Boolean; overload; inline;
    function Contains(const R: TRect): Boolean; overload; inline;
    procedure Combine(ARegion: TACLRegion;
      ACombineFunc: TACLRegionCombineFunc; AFreeRegion: Boolean = False); overload;
    procedure Combine(const R: TRect;
      ACombineFunc: TACLRegionCombineFunc); overload;
    procedure Offset(X, Y: Integer);
    procedure Reset;
    procedure SetToWindow(AHandle: HWND; ARedraw: Boolean = True);
    //# Properties
    property Bounds: TRect read GetBounds;
    property Empty: Boolean read GetIsEmpty;
    property Handle: TRegionHandle read FHandle write SetHandle;
  end;

  { TACLRegionData }

  TACLRegionData = class
  strict private
    FCount: Integer;
    FData: Pointer;
    FDataSize: Integer;
    FRects: PRectArray;
    procedure SetCount(AValue: Integer);
  strict protected
    procedure DataAllocate(ACount: Integer);
    procedure DataAllocateFromNativeHandle(APtr: Pointer);
    procedure DataFree;
  public
    constructor Create(ACount: Integer);
    constructor CreateFromDC(DC: HDC);
    constructor CreateFromHandle(ARgn: TRegionHandle);
    destructor Destroy; override;
    function BoundingBox: TRect;
    function CreateHandle(const ABoundingBox: TRect): TRegionHandle;
    //# Properties
    property Rects: PRectArray read FRects;
    property Count: Integer read FCount write SetCount;
  end;

  { TACLScreenCanvas }

  TACLScreenCanvas = class(TCanvas)
  strict private
    FDeviceContext: HDC;
  protected
    procedure CreateHandle; override;
    procedure FreeHandle; {$IFDEF FPC}override;{$ENDIF}
  public
    destructor Destroy; override;
    procedure Release;
  end;

  { TACLMeasureCanvas }

  TACLMeasureCanvas = class(TCanvas)
  strict private
    FBitmap: TBitmap;
  {$IFDEF FPC}
    function GetFont: TFont;
    procedure SetFont(AValue: TFont); reintroduce;
  {$ENDIF}
  protected
    procedure CreateHandle; override;
    procedure FreeHandle; {$IFDEF FPC}override;{$ENDIF}
  public
    destructor Destroy; override;
  {$IFDEF FPC}
    property Font: TFont read GetFont write SetFont;
  {$ENDIF}
  end;

  { TACLColors }

  TACLColors = class
  public const
    MaskPixel: TACLPixel32 = (B: 255; G: 0; R: 255; A: 0); // clFuchsia
    NullPixel: TACLPixel32 = (B:   0; G: 0; R:   0; A: 0);
  public class var
    PremultiplyTable: TACLPixelMap;
    UnpremultiplyTable: TACLPixelMap;
  public
    class constructor Create;
    class function CompareRGB(const Q1, Q2: TACLPixel32): Boolean; inline; static;
    class function IsDark(Color: TColor): Boolean;
    class function IsMask(const P: TACLPixel32): Boolean; inline; static;

    class procedure AlphaBlend(var D: TColor; S: TColor; AAlpha: Byte = 255); overload; inline; static;
    class procedure AlphaBlend(var D: TACLPixel32; const S: TACLPixel32; AAlpha: Byte = 255); overload; inline; static;
    class procedure Flip(AColors: PACLPixel32Array; AWidth, AHeight: Integer; AHorizontally, AVertically: Boolean);
    class procedure Flush(var P: TACLPixel32); inline; static;
    class procedure Grayscale(P: PACLPixel32; Count: Integer); overload; static;
    class procedure Grayscale(var P: TACLPixel32); overload; inline; static;
    class function Hue(Color: TColor): Single; overload; static;
    class function Lightness(Color: TColor): Single; overload; static;
    class procedure MakeDisabled(P: PACLPixel32; Count: Integer; IgnoreMask: Boolean = False); overload; static;
    class procedure MakeDisabled(var P: TACLPixel32; IgnoreMask: Boolean = False); overload; inline; static;
    class procedure MakeOpaque(P: PACLPixel32; Count: Integer); overload; static;
    class procedure MakeTransparent(P: PACLPixel32; ACount: Integer; const AColor: TACLPixel32); overload;
    class procedure Mix(var D: TACLPixel32; const S: TACLPixel32; AAlpha: Byte = 255); overload; inline; static;

    // ApplyColorSchema
    class procedure ApplyColorSchema(AColors: PACLPixel32;
      ACount: Integer; const AValue: TACLColorSchema); overload; inline; static;
    class procedure ApplyColorSchema(const AFont: TFont; const AValue: TACLColorSchema); overload;
    class procedure ApplyColorSchema(var AColor: TAlphaColor; const AValue: TACLColorSchema); overload;
    class procedure ApplyColorSchema(var AColor: TColor; const AValue: TACLColorSchema); overload;
    class procedure ApplyColorSchema(var AColor: TACLPixel32; const AValue: TACLColorSchema); overload;

    // Premultiply
    class function ArePremultiplied(AColors: PACLPixel32; ACount: Integer): Boolean;
    class procedure Premultiply(P: PACLPixel32; ACount: Integer); overload; static;
    class procedure Premultiply(var P: TACLPixel32); overload; inline; static;
    class procedure Unpremultiply(P: PACLPixel32; ACount: Integer); overload; static;
    class procedure Unpremultiply(var P: TACLPixel32); overload; inline; static;

    // Coloration
    // Pixels must be unpremultiplied
    class procedure ChangeColor(P: PACLPixel32; ACount: Integer; const AColor: TACLPixel32); static;
    class procedure ChangeHue(P: PACLPixel32; ACount: Integer; AHue: Byte; AIntensity: Byte = 100); overload; static;
    class procedure ChangeHue(var P: TACLPixel32; AHue: Byte; AIntensity: Byte = 100); overload; inline; static;
    class procedure Tint(P: PACLPixel32; ACount: Integer; const ATintColor: TACLPixel32); overload; static;

    // BGRA <-> RGBA
    class procedure BGRAtoRGBA(P: PACLPixel32; ACount: Integer); static;

    // RGB <-> HSL
    class function HSLtoRGB(H, S, L: Single): TColor; overload;
    class procedure HSLtoRGB(H, S, L: Single; out AColor: TColor); overload;
    class procedure HSLtoRGB(H, S, L: Single; out R, G, B: Byte); overload;
    class procedure HSLtoRGBi(H, S, L: Byte; out AColor: TColor); overload;
    class procedure HSLtoRGBi(H, S, L: Byte; out R, G, B: Byte); overload;
    class procedure RGBtoHSL(AColor: TColor; out H, S, L: Single); overload;
    class procedure RGBtoHSL(R, G, B: Byte; out H, S, L: Single); overload;
    class procedure RGBtoHSLi(AColor: TColor; out H, S, L: Byte); overload;
    class procedure RGBtoHSLi(R, G, B: Byte; out H, S, L: Byte); overload;

    // RGB <-> HSV
    class function HSVtoRGB(H, S, V: Single): TColor; overload;
    class procedure HSVtoRGB(H, S, V: Single; out AColor: TColor); overload;
    class procedure HSVtoRGB(H, S, V: Single; out R, G, B: Byte); overload;
    class procedure RGBtoHSV(AColor: TColor; out H, S, V: Single); overload;
    class procedure RGBtoHSV(R, G, B: Byte; out H, S, V: Single); overload;
  end;

  { TACLRegionManager }

  TACLRegionManager = class
  strict private const
    CacheSize = 8;
  strict private
    class var Cache: array[0..Pred(CacheSize)] of TRegionHandle;
  public
    class destructor Finalize;
    class function Get: TRegionHandle; inline;
    class procedure Release(var ARegion: TRegionHandle); inline;
  end;

{$IFDEF MSWINDOWS}
// AlphaBlend
procedure acUpdateLayeredWindow(Wnd: TWndHandle; SrcDC: HDC; const R: TRect; AAlpha: Integer = 255); overload;
{$ENDIF}

// GDI
procedure acBitBlt(DC, SourceDC: HDC; const R: TRect; const APoint: TPoint); overload; inline;
procedure acBitBlt(DC: HDC; ABitmap: TBitmap; const ADestPoint: TPoint); overload; inline;
procedure acBitBlt(DC: HDC; ABitmap: TBitmap; const R: TRect; const APoint: TPoint); overload; inline;
procedure acDrawArrow(ACanvas: TCanvas; R: TRect;
  AColor: TColor; AArrowKind: TACLArrowKind; ATargetDPI: Integer);
function acGetArrowSize(AArrowKind: TACLArrowKind; ATargetDPI: Integer): TSize;
procedure acDrawComplexFrame(ACanvas: TCanvas; const R: TRect;
  AColor1, AColor2: TColor; ABorders: TACLBorders = acAllBorders); overload;
procedure acDrawComplexFrame(ACanvas: TCanvas; const R: TRect;
  AColor1, AColor2: TAlphaColor; ABorders: TACLBorders = acAllBorders); overload;
procedure acDrawColorPreview(ACanvas: TCanvas; R: TRect; AColor: TAlphaColor); overload;
procedure acDrawColorPreview(ACanvas: TCanvas; R: TRect; AColor: TAlphaColor;
  ABorderColor, AHatchColor1, AHatchColor2: TColor); overload;
procedure acDrawDotsLineH(DC: HDC; X1, X2, Y: Integer; AColor: TColor);
procedure acDrawDotsLineV(DC: HDC; X, Y1, Y2: Integer; AColor: TColor);
procedure acDrawDropArrow(DC: HDC; const R: TRect; AColor: TColor); overload;
procedure acDrawDropArrow(DC: HDC; const R: TRect; AColor: TColor; const AArrowSize: TSize); overload;
procedure acDrawExpandButton(ACanvas: TCanvas; const R: TRect; ABorderColor, AColor: TColor; AExpanded: Boolean);
procedure acDrawFocusRect(ACanvas: TCanvas; const R: TRect; AColor: TColor = clDefault);
procedure acDrawFrame(ACanvas: TCanvas; const ARect: TRect;
  AColor: TColor; AThickness: Integer = 1); overload;
procedure acDrawFrame(ACanvas: TCanvas; const ARect: TRect;
  AColor: TAlphaColor; AThickness: Integer = 1); overload;
procedure acDrawFrameEx(ACanvas: TCanvas; const ARect: TRect;
  AColor: TColor; ABorders: TACLBorders; AThickness: Integer = 1); overload;
procedure acDrawFrameEx(ACanvas: TCanvas; const ARect: TRect;
  AColor: TAlphaColor; ABorders: TACLBorders; AThickness: Integer = 1); overload;
procedure acDrawGradient(ACanvas: TCanvas; const ARect: TRect;
  AFrom, ATo: TColor; AVertical: Boolean = True); overload;
procedure acDrawGradient(ACanvas: TCanvas; const ARect: TRect;
  AFrom, ATo: TAlphaColor; AVertical: Boolean = True); overload;
procedure acDrawHatch(DC: HDC; const R: TRect); overload;
procedure acDrawHatch(DC: HDC; const R: TRect; AColor1, AColor2: TColor; ASize: Integer); overload;
procedure acDrawHueColorBar(ACanvas: TCanvas; const R: TRect);
procedure acDrawHueIntensityBar(ACanvas: TCanvas; const R: TRect; AHue: Byte = 0);
procedure acDrawSelectionRect(ACanvas: TCanvas; const R: TRect; AColor: TAlphaColor);
procedure acDrawShadow(ACanvas: TCanvas; const ARect: TRect; ABKColor: TColor; AShadowSize: Integer = 5);
procedure acFillRect(ACanvas: TCanvas; const ARect: TRect; AColor: TAlphaColor); overload;
procedure acFillRect(ACanvas: TCanvas; const ARect: TRect; AColor: TAlphaColor; ARadius: Integer); overload;
procedure acFillRect(ACanvas: TCanvas; const ARect: TRect; AColor: TColor); overload;
procedure acFitFileName(ACanvas: TCanvas; ATargetWidth: Integer; var S: string);
procedure acResetFont(AFont: TFont);
procedure acResetRect(DC: HDC; const R: TRect);
procedure acStretchBlt(DC, SourceDC: HDC; const ADest, ASource: TRect); inline;
procedure acStretchDraw(DC, SourceDC: HDC; const ADest, ASource: TRect; AMode: TACLStretchMode);
procedure acTileBlt(DC, SourceDC: HDC; const ADest, ASource: TRect);
function acHatchCreatePattern(ASize: Integer; AColor1, AColor2: TColor): TBitmap;

// Clippping
function acCombineWithClipRegion(DC: HDC; ARegion: TRegionHandle;
  AOperation: Integer; AConsiderWindowOrg: Boolean = True): Boolean;
procedure acExcludeFromClipRegion(DC: HDC; const R: TRect); overload;
procedure acExcludeFromClipRegion(DC: HDC; ARegion: TRegionHandle; AConsiderWindowOrg: Boolean = True); overload;
function acIntersectClipRegion(DC: HDC; const R: TRect): Boolean; overload;
function acIntersectClipRegion(DC: HDC; ARegion: TRegionHandle; AConsiderWindowOrg: Boolean = True): Boolean; overload;
function acRectVisible(ACanvas: TCanvas; const R: TRect): Boolean;
procedure acRestoreClipRegion(DC: HDC; ARegion: TRegionHandle);
function acSaveClipRegion(DC: HDC): TRegionHandle;
function acStartClippedDraw(DC: HDC; const R: TRect; out PrevRegion: TRegionHandle): Boolean;

// Regions
function acRegionClone(ARegion: TRegionHandle): TRegionHandle;
function acRegionCombine(ATarget, ASource: TRegionHandle; AOperation: Integer): Integer; overload;
function acRegionCombine(ATarget: TRegionHandle; const ASource: TRect; AOperation: Integer): Integer; overload;
procedure acRegionFree(var ARegion: TRegionHandle); inline;
function acRegionFromBitmap(ABitmap: TACLDib): TRegionHandle; overload;
function acRegionFromBitmap(AColors: PACLPixel32;
  AWidth, AHeight: Integer; ATransparentColor: TColor): TRegionHandle; overload;
procedure acRegionSetToWindow(AWnd: TWndHandle; ARegion: TRegionHandle; ARedraw: Boolean);

// WindowOrg
function acMoveWindowOrg(DC: HDC; const P: TPoint): TPoint; overload;
function acMoveWindowOrg(DC: HDC; DX, DY: Integer): TPoint; overload;
procedure acRegionMoveToWindowOrg(DC: HDC; ARegion: TRegionHandle);
procedure acRestoreWindowOrg(DC: HDC; const P: TPoint);

// Bitmaps
procedure acInitBitmap32Info(out AInfo: TBitmapInfo; AWidth, AHeight: Integer);
function acGetBitmapBits(ABitmap: TBitmap): TACLPixel32DynArray;
procedure acSetBitmapBits(ABitmap: TBitmap; const AColors: TACLPixel32DynArray); overload;
procedure acSetBitmapBits(ABitmap: TBitmap; AColors: PACLPixel32; ACount: Integer); overload;

// Colors
procedure acApplyColorSchema(AObject: TObject; const AColorSchema: TACLColorSchema); inline;
procedure acBuildColorPalette(ATargetList: TACLColorList; ABaseColor: TColor);
function acGetActualColor(AColor, ADefaultColor: TAlphaColor): TAlphaColor; overload;
function acGetActualColor(AColor, ADefaultColor: TColor): TColor; overload;
function acGetActualColor(AFont: TFont; ADefaultColor: TColor = clBlack): TColor; overload;
function ColorToString(AColor: TColor): string;
function StringToColor(AColor: string): TColor;

// Unicode Text
function acFontHeight(Canvas: TCanvas): Integer; overload;
function acFontHeight(Font: TFont): Integer; overload;

function acTextAlign(const R: TRect; const ATextSize: TSize; AHorzAlignment: TAlignment;
  AVertAlignment: TVerticalAlignment; APreventTopLeftExceed: Boolean = False): TPoint;
function acTextEllipsize(ACanvas: TCanvas;
  var AText: string; var ATextSize: TSize; AMaxWidth: Integer): Integer;
procedure acTextDraw(ACanvas: TCanvas; const S: string; const R: TRect;
  AHorzAlignment: TAlignment = taLeftJustify; AVertAlignment: TVerticalAlignment = taAlignTop;
  AEndEllipsis: Boolean = False; APreventTopLeftExceed: Boolean = False;
  AWordWrap: Boolean = False);
procedure acTextDrawHighlight(ACanvas: TCanvas; const S: string; const R: TRect;
  AHorzAlignment: TAlignment; AVertAlignment: TVerticalAlignment; AEndEllipsis: Boolean;
  AHighlightStart, AHighlightFinish: Integer; AHighlightColor, AHighlightTextColor: TColor);
procedure acTextDrawVertical(ACanvas: TCanvas; const S: string; const R: TRect;
  AHorzAlignment: TAlignment; AVertAlignment: TVerticalAlignment;
  AEndEllipsis: Boolean = False); overload;
procedure acTextOut(ACanvas: TCanvas; X, Y: Integer;
  const S: string; AClipRect: PRect = nil); overload; inline;
procedure acTextOut(ACanvas: TCanvas; X, Y: Integer;
  AText: PChar; ALength: Integer; AClipRect: PRect = nil); overload;

function acTextSize(ACanvas: TCanvas; const AText: string): TSize; overload;
function acTextSize(ACanvas: TCanvas; const AText: PChar; ALength: Integer): TSize; overload;
function acTextSize(AFont: TFont; const AText: string): TSize; overload;
function acTextSize(AFont: TFont; const AText: PChar; ALength: Integer): TSize; overload;
function acTextSizeMultiline(ACanvas: TCanvas;
  const AText: string; AMaxWidth: Integer = 0): TSize;

procedure acSysDrawText(ACanvas: TCanvas; var R: TRect; const AText: string; AFlags: Cardinal);

// Screen
function MeasureCanvas: TACLMeasureCanvas;
function ScreenCanvas: TACLScreenCanvas;
implementation

uses
{$IFDEF LCLGtk2}
  Gdk2,
  Glib2,
  Gtk2Def,
  Gtk2Int,
{$ENDIF}
  ACL.Math,
  ACL.Graphics.Ex,
{$IFDEF MSWINDOWS}
  ACL.Graphics.Ex.Gdip,
{$ENDIF}
{$IFDEF ACL_CAIRO}
  ACL.Graphics.Ex.Cairo,
{$ENDIF}
  ACL.Graphics.TextLayout,
  ACL.Utils.DPIAware,
  ACL.Utils.Strings;

type
{$IFDEF FPC}
  TFontAccess = class(TFont);
{$ELSE}
  TBitmapAccess = class(TBitmap);
  TBitmapImageAccess = class(TBitmapImage);
{$ENDIF}

var
  FMeasureCanvas: TACLMeasureCanvas = nil;
  FScreenCanvas: TACLScreenCanvas = nil;

procedure acApplyColorSchema(AObject: TObject; const AColorSchema: TACLColorSchema);
var
  ASchema: IACLColorSchema;
begin
  if Supports(AObject, IACLColorSchema, ASchema) then
    ASchema.ApplyColorSchema(AColorSchema)
end;

procedure acBuildColorPalette(ATargetList: TACLColorList; ABaseColor: TColor);
const
  BasePalette: array [0..6] of Single = (0.61, 0.99, 0.74, 0.35, 0.9, 0.08, 0.55);

  procedure DoBuild(ATargetList: TACLColorList; ALightnessDelta: Single);
  var
    H, S, L: Single;
    I: Integer;
  begin
    TACLColors.RGBtoHSL(ABaseColor, H, S, L);
    L := EnsureRange(L, 0.4, 0.8);
    S := Max(S, 0.4);
    L := EnsureRange(L + ALightnessDelta, 0.2, 0.9);
    for I := 0 to Length(BasePalette) - 1 do
      ATargetList.Add(TACLColors.HSLtoRGB(BasePalette[I], S, L));
  end;

begin
  ATargetList.Count := 0;
  ATargetList.Capacity := Length(BasePalette) * 3;
  DoBuild(ATargetList, 0);
  DoBuild(ATargetList, -0.15);
  DoBuild(ATargetList, 0.15);
end;

function acGetActualColor(AColor, ADefaultColor: TAlphaColor): TAlphaColor;
begin
  if AColor.IsDefault then
    Result := ADefaultColor
  else
    Result := AColor;
end;

function acGetActualColor(AColor, ADefaultColor: TColor): TColor;
begin
  if AColor = clDefault then
    Result := ADefaultColor
  else
    Result := AColor;
end;

function acGetActualColor(AFont: TFont; ADefaultColor: TColor): TColor;
begin
{$IFDEF FPC}
  Result := TFontAccess(AFont).GetColor;
{$ELSE}
  Result := AFont.Color;
{$ENDIF}
  if Result = clDefault then
    Result := ADefaultColor;
end;

function ColorToString(AColor: TColor): string;
begin
  if AColor = clNone then
    Result := 'None'
  else
    if AColor = clDefault then
      Result := 'Default'
    else
      Result :=
        IntToHex(GetRValue(AColor), 2) +
        IntToHex(GetGValue(AColor), 2) +
        IntToHex(GetBValue(AColor), 2);
end;

function StringToColor(AColor: string): TColor;

  function RemoveInvalidChars(const AColor: string): string;
  var
    I: Integer;
  begin
    Result := acLowerCase(AColor);
    for I := Length(Result) downto 1 do
    begin
      if not CharInSet(Result[I], ['0'..'9', 'a'..'f']) then
        Delete(Result, I, 1);
    end;
  end;

begin
  Result := clNone;
  if not (IdentToColor(AColor, LongInt(Result)) or (IdentToColor('cl' + AColor, LongInt(Result)))) then
  begin
    AColor := RemoveInvalidChars(AColor);
    AColor := acDupeString('0', Length(AColor) mod 2) + AColor;
    AColor := AColor + acDupeString('0', 6 - Length(AColor));
    Result := RGB(
      TACLHexCode.Decode(AColor[1], AColor[2]),
      TACLHexCode.Decode(AColor[3], AColor[4]),
      TACLHexCode.Decode(AColor[5], AColor[6]));
  end;
end;

procedure acFitFileName(ACanvas: TCanvas; ATargetWidth: Integer; var S: string);
const
  CollapsedPath = '...';
var
  APos: Integer;
  APosNext: Integer;
  APosPrev: Integer;
begin
  APosPrev := acPos(PathDelim, S);
  APosNext := APosPrev;
  while ACanvas.TextWidth(S) > ATargetWidth do
  begin
    APos := Pos(PathDelim, S, APosNext + 1);
    if APos = 0 then Break;
    S := Copy(S, 1, APosPrev) + CollapsedPath + Copy(S, APos, MaxInt);
    APosNext := APosPrev + Length(CollapsedPath) + 1;
  end;
end;

procedure acResetFont(AFont: TFont);
var
  ATempFont: TFont;
begin
  ATempFont := TFont.Create;
  try
    AFont.Assign(ATempFont);
  finally
    ATempFont.Free;
  end;
end;

procedure acResetRect(DC: HDC; const R: TRect);
begin
  FillRect(DC, R, GetStockObject(BLACK_BRUSH));
end;

//----------------------------------------------------------------------------------------------------------------------
// Clipping
//----------------------------------------------------------------------------------------------------------------------

function acCombineWithClipRegion(DC: HDC; ARegion: TRegionHandle;
  AOperation: Integer; AConsiderWindowOrg: Boolean = True): Boolean;
var
  AClipRegion: TRegionHandle;
  AOrigin: TPoint;
begin
  AClipRegion := CreateRectRgnIndirect(NullRect);
  try
    GetClipRgn(DC, AClipRegion);

    if AConsiderWindowOrg then
    begin
      GetWindowOrgEx(DC, AOrigin{%H-});
      OffsetRgn(ARegion, -AOrigin.X, -AOrigin.Y);
      CombineRgn(AClipRegion, AClipRegion, ARegion, AOperation);
      OffsetRgn(ARegion, AOrigin.X, AOrigin.Y);
    end
    else
      CombineRgn(AClipRegion, AClipRegion, ARegion, AOperation);

    Result := SelectClipRgn(DC, AClipRegion) <> NULLREGION;
  finally
    DeleteObject(AClipRegion);
  end;
end;

procedure acExcludeFromClipRegion(DC: HDC; const R: TRect);
begin
  ExcludeClipRect(DC, R.Left, R.Top, R.Right, R.Bottom);
end;

procedure acExcludeFromClipRegion(DC: HDC; ARegion: TRegionHandle; AConsiderWindowOrg: Boolean = True);
begin
  acCombineWithClipRegion(DC, ARegion, RGN_DIFF, AConsiderWindowOrg);
end;

function acIntersectClipRegion(DC: HDC; const R: TRect): Boolean;
begin
  Result := IntersectClipRect(DC, R.Left, R.Top, R.Right, R.Bottom) <> NULLREGION;
end;

function acIntersectClipRegion(DC: HDC; ARegion: TRegionHandle; AConsiderWindowOrg: Boolean = True): Boolean;
begin
  Result := acCombineWithClipRegion(DC, ARegion, RGN_AND, AConsiderWindowOrg);
end;

function acRectVisible(ACanvas: TCanvas; const R: TRect): Boolean;
begin
  if R.IsEmpty then
    Exit(False);
{$IFDEF FPC}
  if not ACanvas.HandleAllocated and (ACanvas is TACLDibCanvas) then
    Exit(R.IntersectsWith(TACLDibCanvas(ACanvas).Owner.ClientRect));
{$ENDIF}
  Result := RectVisible(ACanvas.Handle, R);
end;

procedure acRestoreClipRegion(DC: HDC; ARegion: TRegionHandle);
begin
  SelectClipRgn(DC, ARegion);
  TACLRegionManager.Release(ARegion);
end;

function acSaveClipRegion(DC: HDC): TRegionHandle;
begin
  Result := TACLRegionManager.Get;
  if GetClipRgn(DC, Result) = 0 then
  begin
    TACLRegionManager.Release(Result);
    Result := 0;
  end;
end;

function acStartClippedDraw(DC: HDC; const R: TRect; out PrevRegion: TRegionHandle): Boolean;
begin
{$IFDEF MSWINDOWS} // под Linux это не имеет смысла, т.к. там идет такая же работа с регионом, как ниже
  if not RectVisible(DC, R) then Exit(False);
{$ENDIF}
  PrevRegion := acSaveClipRegion(DC);
  Result := IntersectClipRect(DC, R.Left, R.Top, R.Right, R.Bottom) <> NULLREGION;
  if not Result then
    acRestoreClipRegion(DC, PrevRegion);
end;

//----------------------------------------------------------------------------------------------------------------------
// Regions
//----------------------------------------------------------------------------------------------------------------------

function acRegionClone(ARegion: TRegionHandle): TRegionHandle;
begin
  Result := CreateRectRgn(0, 0, 0, 0);
  CombineRgn(Result, ARegion, {$IFDEF FPC}ARegion{$ELSE}0{$ENDIF}, RGN_COPY);
end;

function acRegionCombine(ATarget, ASource: TRegionHandle; AOperation: Integer): Integer;
begin
  Result := CombineRgn(ATarget, ATarget, ASource, AOperation);
end;

function acRegionCombine(ATarget: TRegionHandle; const ASource: TRect; AOperation: Integer): Integer;
var
  ASourceRgn: TRegionHandle;
begin
  ASourceRgn := CreateRectRgnIndirect(ASource);
  try
    Result := acRegionCombine(ATarget, ASourceRgn, AOperation);
  finally
    DeleteObject(ASourceRgn);
  end;
end;

procedure acRegionFree(var ARegion: TRegionHandle);
begin
  if ARegion <> 0 then
  begin
    DeleteObject(ARegion);
    ARegion := 0;
  end;
end;

function acRegionFromBitmap(ABitmap: TACLDib): TRegionHandle;
begin
  Result := acRegionFromBitmap(@ABitmap.Colors[0], ABitmap.Width, ABitmap.Height, clFuchsia);
end;

function acRegionFromBitmap(AColors: PACLPixel32; AWidth, AHeight: Integer; ATransparentColor: TColor): TRegionHandle;

  procedure FlushRegion(X, Y: Integer; var ACount: Integer; var ACombined: TRegionHandle);
  var
    ARgn: TRegionHandle;
  begin
    if ACount > 0 then
    begin
      ARgn := CreateRectRgn(X - ACount, Y, X, Y + 1);
      if ACombined = 0 then
        ACombined := ARgn
      else
      begin
        CombineRgn(ACombined, ACombined, ARGN, RGN_OR);
        DeleteObject(ARgn);
      end;
      ACount := 0;
    end;
  end;

var
  ACount: Integer;
  ATransparent: TACLPixel32;
  X, Y: Integer;
begin
  Result := 0;
  ATransparent.B := GetBValue(ATransparentColor);
  ATransparent.G := GetGValue(ATransparentColor);
  ATransparent.R := GetRValue(ATransparentColor);
  for Y := 0 to AHeight - 1 do
  begin
    ACount := 0;
    for X := 0 to AWidth - 1 do
    begin
      if TACLColors.CompareRGB(AColors^, ATransparent) then
        FlushRegion(X, Y, ACount, Result)
      else
        Inc(ACount);

      Inc(AColors);
    end;
    FlushRegion(AWidth, Y, ACount, Result);
  end;
end;

procedure acRegionSetToWindow(AWnd: TWndHandle; ARegion: TRegionHandle; ARedraw: Boolean);
begin
{$IFDEF LCLGtk2}
  // LCLGtk2 не умеет делать Redraw для окна, если регион = 0:
  //    gdk_region_empty: assertion 'region != NULL' failed
  if ARedraw and (ARegion = 0) then
  begin
    SetWindowRgn(AWnd, ARegion, False);
    InvalidateRect(AWnd, nil, True);
    Exit;
  end;
{$ENDIF}
  SetWindowRgn(AWnd, ARegion, ARedraw);
{$IFDEF LCLGtk2}
  DeleteObject(ARegion);
{$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------
// Window Org
//----------------------------------------------------------------------------------------------------------------------

function acMoveWindowOrg(DC: HDC; const P: TPoint): TPoint;
begin
  Result := acMoveWindowOrg(DC, P.X, P.Y);
end;

function acMoveWindowOrg(DC: HDC; DX, DY: Integer): TPoint;
begin
  GetWindowOrgEx(DC, Result{%H-});
  SetWindowOrgEx(DC, Result.X - DX, Result.Y - DY, nil);
end;

procedure acRegionMoveToWindowOrg(DC: HDC; ARegion: TRegionHandle);
var
  P: TPoint;
begin
  if GetWindowOrgEx(DC, P{%H-}){$IFDEF FPC}<> 0{$ENDIF} then
    OffsetRgn(ARegion, -P.X, -P.Y);
end;

procedure acRestoreWindowOrg(DC: HDC; const P: TPoint);
begin
  SetWindowOrgEx(DC, P.X, P.Y, nil);
end;

//----------------------------------------------------------------------------------------------------------------------
// TextDraw Utilities
//----------------------------------------------------------------------------------------------------------------------

function acTextAlign(const R: TRect; const ATextSize: TSize; AHorzAlignment: TAlignment;
  AVertAlignment: TVerticalAlignment; APreventTopLeftExceed: Boolean = False): TPoint;
begin
  case AVertAlignment of
    taAlignTop:
      Result.Y := R.Top;
    taAlignBottom:
      Result.Y := (R.Bottom - ATextSize.cy);
  else
    Result.Y := (R.Bottom + R.Top - ATextSize.cy) div 2;
  end;
  if APreventTopLeftExceed then
    Result.Y := Max(Result.Y, R.Top);

  case AHorzAlignment of
    taRightJustify:
      Result.X := (R.Right - ATextSize.cx);
    taCenter:
      Result.X := (R.Right + R.Left - ATextSize.cx) div 2;
  else
    Result.X := R.Left;
  end;
  if APreventTopLeftExceed then
    Result.X := Max(Result.X, R.Left);
end;

function acFontHeight(Canvas: TCanvas): Integer;
begin
  Result := acTextSize(Canvas, acMeasureTextPattern).cy;
end;

function acFontHeight(Font: TFont): Integer;
begin
  Result := acTextSize(Font, acMeasureTextPattern).cy;
end;

function acTextSize(AFont: TFont; const AText: string): TSize;
begin
  MeasureCanvas.SetScaledFont(AFont);
  Result := acTextSize(MeasureCanvas, AText);
end;

function acTextSize(AFont: TFont; const AText: PChar; ALength: Integer): TSize;
begin
  MeasureCanvas.SetScaledFont(AFont);
  Result := acTextSize(MeasureCanvas, AText, ALength);
end;

function acTextSize(ACanvas: TCanvas; const AText: PChar; ALength: Integer): TSize; overload;
{$IFNDEF ACL_CAIRO_TEXTOUT}
var
  AMetrics: TTextMetric;
{$ENDIF}
begin
  if ALength <= 0 then
    Exit(NullSize);
{$IFDEF ACL_CAIRO_TEXTOUT}
  CairoTextSize(ACanvas, acMakeString(AText, ALength), @Result.cx, @Result.cy);
{$ELSE}
  GetTextExtentPoint32(ACanvas.Handle, AText, ALength, Result);
  //# https://forums.embarcadero.com/thread.jspa?messageID=667590&tstart=0
  //# https://github.com/virtual-treeview/virtual-treeview/issues/465
  GetTextMetrics(ACanvas.Handle, AMetrics{%H-});
  if IsWine or (AMetrics.tmItalic <> 0) then
    Inc(Result.cx, AMetrics.tmAveCharWidth div 2);
{$ENDIF}
end;

function acTextSize(ACanvas: TCanvas; const AText: string): TSize;
begin
{$IFDEF ACL_CAIRO_TEXTOUT}
  CairoTextSize(ACanvas, AText, @Result.cx, @Result.cy);
{$ELSE}
  Result := acTextSize(ACanvas, PChar(AText), Length(AText));
{$ENDIF}
end;

function acTextSizeMultiline(ACanvas: TCanvas; const AText: string; AMaxWidth: Integer = 0): TSize;
var
  LTextRect: TRect;
begin
  if AMaxWidth <= 0 then
    AMaxWidth := MaxWord;
  LTextRect := Rect(0, 0, AMaxWidth, 2);
  acSysDrawText(ACanvas, LTextRect, AText, DT_CALCRECT or DT_WORDBREAK);
  Result := LTextRect.Size;
end;

procedure acTextDraw(ACanvas: TCanvas; const S: string; const R: TRect;
  AHorzAlignment: TAlignment; AVertAlignment: TVerticalAlignment;
  AEndEllipsis, APreventTopLeftExceed, AWordWrap: Boolean);
var
  LMultiLine: Boolean;
  LText: string;
  LTextFlags: Integer;
  LTextOffset: TPoint;
  LTextRect: TRect;
  LTextSize: TSize;
begin
  if (S <> '') and acRectVisible(ACanvas, R) then
  begin
    LMultiLine := acContains(#13, S);
    if AWordWrap or LMultiLine then
    begin
      LTextRect := R;
      LTextFlags := acTextAlignHorz[AHorzAlignment] or acTextAlignVert[AVertAlignment];
      if AEndEllipsis then
        LTextFlags := LTextFlags or DT_END_ELLIPSIS;
      if AWordWrap then
        LTextFlags := LTextFlags or DT_WORDBREAK
      else if not LMultiLine then
        LTextFlags := LTextFlags or DT_SINGLELINE;
      acSysDrawText(ACanvas, LTextRect, S, LTextFlags);
    end
    else
      if (AHorzAlignment <> taLeftJustify) or (AVertAlignment <> taAlignTop) or AEndEllipsis then
      begin
        LText := S;
        LTextSize := acTextSize(ACanvas, LText);
        if AEndEllipsis then
          acTextEllipsize(ACanvas, LText, LTextSize, R.Width);
        LTextOffset := acTextAlign(R, LTextSize, AHorzAlignment, AVertAlignment, APreventTopLeftExceed);
        acTextOut(ACanvas, LTextOffset.X, LTextOffset.Y, LText, @R);
      end
      else
        acTextOut(ACanvas, R.Left, R.Top, S, @R);
  end;
end;

procedure acTextDrawHighlight(ACanvas: TCanvas; const S: string; const R: TRect;
  AHorzAlignment: TAlignment; AVertAlignment: TVerticalAlignment; AEndEllipsis: Boolean;
  AHighlightStart, AHighlightFinish: Integer; AHighlightColor, AHighlightTextColor: TColor);
var
  LHighlightRect: TRect;
  LHighlightTextSize: TSize;
  LPrevTextColor: TColor;
  LSaveRgn: TRegionHandle;
  LText: string;
  LTextOffset: TPoint;
  LTextPart: string;
  LTextPartSize: TSize;
  LTextSize: TSize;
begin
  if AHighlightFinish > AHighlightStart then
  begin
    LText := S;
    LTextSize := acTextSize(ACanvas, LText);
    if AEndEllipsis then
      AHighlightFinish := Min(AHighlightFinish, acTextEllipsize(ACanvas, LText, LTextSize, R.Width));
    LTextOffset := acTextAlign(R, LTextSize, AHorzAlignment, AVertAlignment, True);
    LTextPart := Copy(LText, 1, AHighlightStart);
    LTextPartSize := acTextSize(ACanvas, LTextPart);
    LTextPart := Copy(LText, 1, AHighlightFinish);
    LHighlightTextSize := acTextSize(ACanvas, LTextPart);
    Dec(LHighlightTextSize.cx, LTextPartSize.cx);

    LHighlightRect := R;
    LHighlightRect.Left := LTextOffset.X + LTextPartSize.cx;
    LHighlightRect.Right := LHighlightRect.Left + LHighlightTextSize.cx;

    LSaveRgn := acSaveClipRegion(ACanvas.Handle);
    try
      acExcludeFromClipRegion(ACanvas.Handle, LHighlightRect);
      acTextOut(ACanvas, LTextOffset.X, LTextOffset.Y, LText, @R);
    finally
      acRestoreClipRegion(ACanvas.Handle, LSaveRgn);
    end;

    if acStartClippedDraw(ACanvas.Handle, LHighlightRect, LSaveRgn) then
    try
      acFillRect(ACanvas, LHighlightRect, AHighlightColor);
      LPrevTextColor := ACanvas.Font.Color;
      ACanvas.Font.Color := AHighlightTextColor;
      acTextOut(ACanvas, LTextOffset.X, LTextOffset.Y, LText, @R);
      ACanvas.Font.Color := LPrevTextColor;
    finally
      acRestoreClipRegion(ACanvas.Handle, LSaveRgn);
    end;
  end
  else
    acTextDraw(ACanvas, S, R, AHorzAlignment, AVertAlignment, AEndEllipsis);
end;

procedure acTextDrawVertical(ACanvas: TCanvas; const S: string; const R: TRect;
  AHorzAlignment: TAlignment; AVertAlignment: TVerticalAlignment;
  AEndEllipsis: Boolean = False);
const
  MapVert: array[TAlignment] of TVerticalAlignment = (taAlignBottom, taAlignTop, taVerticalCenter);
var
  LText: string;
  LTextOffset: TPoint;
  LTextSize: TSize;
begin
  ACanvas.Font.Orientation := 900;
  try
    LText := S;
    LTextSize := acTextSize(ACanvas, LText);
    if AEndEllipsis then
      acTextEllipsize(ACanvas, LText, LTextSize, R.Height);
    TACLMath.Exchange<Integer>(LTextSize.cx, LTextSize.cy);
    LTextOffset := acTextAlign(R, LTextSize, TAlignment(AVertAlignment), MapVert[AHorzAlignment]);
    acTextOut(ACanvas, LTextOffset.X, LTextOffset.Y + LTextSize.cy, LText);
  finally
    ACanvas.Font.Orientation := 0;
  end;
end;

function acTextEllipsize(ACanvas: TCanvas;
  var AText: string; var ATextSize: TSize; AMaxWidth: Integer): Integer;
begin
  if ATextSize.cx > AMaxWidth then
  begin
    AMaxWidth := Max(AMaxWidth - acTextSize(ACanvas, acEndEllipsis).cx, 0);
  {$IFDEF ACL_CAIRO_TEXTOUT}
    Result := CairoTextGetLastVisible(ACanvas, AText, AMaxWidth);
  {$ELSE}
    GetTextExtentExPoint(ACanvas.Handle, PChar(AText), Length(AText), AMaxWidth, @Result, nil, ATextSize);
  {$ENDIF}
    AText := Copy(AText, 1, Result) + acEndEllipsis;
    ATextSize := acTextSize(ACanvas, AText);
  end
  else
    Result := Length(AText);
end;

procedure acTextOut(ACanvas: TCanvas; X, Y: Integer; const S: string; AClipRect: PRect = nil);
begin
  acTextOut(ACanvas, X, Y, PChar(S), Length(S), AClipRect);
end;

procedure acTextOut(ACanvas: TCanvas; X, Y: Integer;
  AText: PChar; ALength: Integer; AClipRect: PRect = nil);
begin
{$IFDEF ACL_CAIRO_TEXTOUT}
  CairoTextOut(ACanvas, X, Y, AText, ALength, AClipRect);
{$ELSE}
  ExtTextOut(ACanvas.Handle, X, Y,
    IfThen(AClipRect <> nil, ETO_CLIPPED, 0),
    AClipRect, AText, ALength, nil);
{$ENDIF}
end;

procedure acSysDrawText(ACanvas: TCanvas; var R: TRect; const AText: string; AFlags: Cardinal);
{$IF DEFINED(ACL_CAIRO_TEXTOUT)}
begin
  CairoDrawText(ACanvas, AText, R, AFlags);
{$ELSEIF DEFINED(FPC)}
begin
  acAdvDrawText(ACanvas, AText, R, AFlags);
{$ELSE}
var
  LMetrics: TTextMetric;
begin
  DrawText(ACanvas.Handle, PChar(AText), Length(AText), R, AFlags);
  if AFlags and DT_CALCRECT <> 0 then
  begin
    GetTextMetrics(ACanvas.Handle, LMetrics{%H-});
    if IsWine or (LMetrics.tmItalic <> 0) then
      Inc(R.Right, LMetrics.tmAveCharWidth div 2);
  end;
{$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------
// ScreenCanvas
//----------------------------------------------------------------------------------------------------------------------

function ScreenCanvas: TACLScreenCanvas;
begin
  if FScreenCanvas = nil then
    FScreenCanvas := TACLScreenCanvas.Create;
  Result := FScreenCanvas;
end;

{ TACLScreenCanvas }

destructor TACLScreenCanvas.Destroy;
begin
  FreeHandle;
  inherited Destroy;
end;

procedure TACLScreenCanvas.CreateHandle;
begin
{$IFDEF FPC}
  FDeviceContext := GetDC(0);
{$ELSE}
  FDeviceContext := GetDCEx(0, 0, DCX_CACHE or DCX_LOCKWINDOWUPDATE);
{$ENDIF}
  Handle := FDeviceContext;
end;

procedure TACLScreenCanvas.Release;
begin
  if LockCount = 0 then
    FreeHandle;
end;

procedure TACLScreenCanvas.FreeHandle;
begin
  if FDeviceContext <> 0 then
  begin
    Handle := 0;
    ReleaseDC(0, FDeviceContext);
    FDeviceContext := 0;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------
// MeasureCanvas
//----------------------------------------------------------------------------------------------------------------------

function MeasureCanvas: TACLMeasureCanvas;
begin
  if FMeasureCanvas = nil then
    FMeasureCanvas := TACLMeasureCanvas.Create;
  Result := FMeasureCanvas;
end;

{ TACLMeasureCanvas }

destructor TACLMeasureCanvas.Destroy;
begin
  FreeHandle;
  inherited Destroy;
end;

procedure TACLMeasureCanvas.CreateHandle;
begin
  FBitmap := TACLBitmap.CreateEx(1, 1, pf32bit);
  FBitmap.Canvas.Lock;
  Handle := FBitmap.Canvas.Handle;
end;

procedure TACLMeasureCanvas.FreeHandle;
begin
  if HandleAllocated then
  begin
    Handle := 0;
    FBitmap.Canvas.Unlock;
    FreeAndNil(FBitmap);
  end;
end;

{$IFDEF FPC}
function TACLMeasureCanvas.GetFont: TFont;
begin
  Result := inherited Font;
end;

procedure TACLMeasureCanvas.SetFont(AValue: TFont);
begin
  SetScaledFont(AValue);
end;
{$ENDIF}

//----------------------------------------------------------------------------------------------------------------------
// Bitmaps
//----------------------------------------------------------------------------------------------------------------------

{$IFDEF FPC}
procedure acRawImageToBits(ABits: PACLPixel32; const AImage: TLazIntfImage); overload;
var
  X, Y: Integer;
begin
  for Y := 0 to AImage.Height - 1 do
    for X := 0 to AImage.Width - 1 do
      with AImage.Colors[x, y] do
      begin
        ABits^.A := Alpha shr 8;
        ABits^.R := Red shr 8;
        ABits^.G := Green shr 8;
        ABits^.B := Blue shr 8;
        Inc(ABits);
      end;
end;

procedure acRawImageToBits(ABits: PACLPixel32; const ARawImage: TRawImage); overload;
var
  LImage: TLazIntfImage;
begin
  LImage := TLazIntfImage.Create(ARawImage, False);
  try
    acRawImageToBits(ABits, LImage);
  finally
    LImage.Free;
  end;
end;
{$ENDIF}

procedure acInitBitmap32Info(out AInfo: TBitmapInfo; AWidth, AHeight: Integer);
begin
  FillChar(AInfo{%H-}, SizeOf(AInfo), 0);
  AInfo.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
  AInfo.bmiHeader.biWidth := AWidth;
  AInfo.bmiHeader.biHeight := -AHeight;
  AInfo.bmiHeader.biPlanes := 1;
  AInfo.bmiHeader.biBitCount := 32;
  AInfo.bmiHeader.biSizeImage := AWidth * AHeight * 4;
//  AInfo.bmiHeader.biSizeImage := ((AWidth shl 5 + 31) and -32) shr 3 * AHeight;
  AInfo.bmiHeader.biCompression := BI_RGB;
end;

function acGetBitmapBits(ABitmap: TBitmap): TACLPixel32DynArray;
{$IFDEF FPC}
begin
  SetLength(Result{%H-}, ABitmap.Width * ABitmap.Height);
  if Length(Result) > 0 then
    acRawImageToBits(@Result[0], ABitmap.RawImage);
{$ELSE}
var
  LInfo: TBitmapInfo;
begin
  SetLength(Result{%H-}, ABitmap.Width * ABitmap.Height);
  acInitBitmap32Info(LInfo, ABitmap.Width, ABitmap.Height);
  GetDIBits(MeasureCanvas.Handle, ABitmap.Handle, 0, ABitmap.Height, Result, LInfo, DIB_RGB_COLORS);
{$ENDIF}
end;

procedure acSetBitmapBits(ABitmap: TBitmap; const AColors: TACLPixel32DynArray);
begin
  acSetBitmapBits(ABitmap, @AColors[0], Length(AColors));
end;

procedure acSetBitmapBits(ABitmap: TBitmap; AColors: PACLPixel32; ACount: Integer);
{$IFDEF FPC}
var
  LRawImage: TRawImage;
begin
  LRawImage.Init;
  LRawImage.Data := PByte(AColors);
  LRawImage.DataSize := ACount * SizeOf(TACLPixel32);
  LRawImage.Description.Init_BPP32_B8G8R8A8_BIO_TTB(ABitmap.Width, ABitmap.Height);
  ABitmap.LoadFromRawImage(LRawImage, False);
{$ELSE}
var
  AInfo: TBitmapInfo;
begin
  acInitBitmap32Info(AInfo, ABitmap.Width, ABitmap.Height);
  SetDIBits(MeasureCanvas.Handle, ABitmap.Handle, 0, ABitmap.Height, AColors, AInfo, DIB_RGB_COLORS);
  TBitmapAccess(ABitmap).Changed(ABitmap);
{$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------
// Alpha Blend Functions
//----------------------------------------------------------------------------------------------------------------------

{$IFDEF MSWINDOWS}
procedure acUpdateLayeredWindow(Wnd: TWndHandle; SrcDC: HDC; const R: TRect; AAlpha: Integer = 255);
var
  ABlendFunc: TBlendFunction;
  ASize: TSize;
  AStyle: Cardinal;
  ATopLeft, N: TPoint;
begin
  AStyle := GetWindowLong(Wnd, GWL_EXSTYLE);
  if AStyle and WS_EX_LAYERED = 0 then
    SetWindowLong(Wnd, GWL_EXSTYLE, AStyle or WS_EX_LAYERED);

  ZeroMemory(@ABlendFunc, SizeOf(ABlendFunc));
  ABlendFunc.BlendOp := AC_SRC_OVER;
  ABlendFunc.AlphaFormat := AC_SRC_ALPHA;
  ABlendFunc.SourceConstantAlpha := AAlpha;

  N := NullPoint;
  ASize := R.Size;
  ATopLeft := R.TopLeft;
  UpdateLayeredWindow(Wnd, 0, @ATopLeft, @ASize, SrcDC, @N, 0, @ABlendFunc, ULW_ALPHA);
end;
{$ENDIF}

//----------------------------------------------------------------------------------------------------------------------
// GDI
//----------------------------------------------------------------------------------------------------------------------

procedure acBitBlt(DC, SourceDC: HDC; const R: TRect; const APoint: TPoint);
begin
  BitBlt(DC, R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top, SourceDC, APoint.X, APoint.Y, SRCCOPY);
end;

procedure acBitBlt(DC: HDC; ABitmap: TBitmap; const ADestPoint: TPoint);
begin
  BitBlt(DC, ADestPoint.X, ADestPoint.Y, ABitmap.Width, ABitmap.Height, ABitmap.Canvas.Handle, 0, 0, SRCCOPY);
end;

procedure acBitBlt(DC: HDC; ABitmap: TBitmap; const R: TRect; const APoint: TPoint);
begin
  acBitBlt(DC, ABitmap.Canvas.Handle, R, APoint);
end;

procedure acDrawArrow(ACanvas: TCanvas; R: TRect;
  AColor: TColor; AArrowKind: TACLArrowKind; ATargetDPI: Integer);

  procedure Draw(R: TRect; const Extends: TRect; Count: Integer);
  begin
    R.CenterHorz(1);
    R.CenterVert(1);
    while Count > 0 do
    begin
      ACanvas.FillRect(R);
      R.Content(Extends);
      Dec(Count);
    end;
  end;

var
  ASize: Integer;
begin
  ASize := MulDiv(2, ATargetDPI, acDefaultDPI);
  if AArrowKind in [makLeft, makRight] then
  begin
    R.CenterHorz(ASize + 1);
    R.CenterVert(ASize * 2 + 1);
  end
  else
  begin
    R.CenterHorz(ASize * 2 + 1);
    R.CenterVert(ASize + 1);
  end;

  ACanvas.Brush.Color := AColor;
  case AArrowKind of
    makLeft:
      Draw(R.Split(srLeft, 1), Rect(1, -1, -1, -1), ASize + 1);
    makRight:
      Draw(R.Split(srLeft, R.Right, 1), Rect(-1, -1, 1, -1), ASize + 1);
    makTop:
      Draw(R.Split(srTop, 1), Rect(-1, 1, -1, -1), ASize + 1);
    makBottom:
      Draw(R.Split(srTop, R.Bottom, 1), Rect(-1, -1, -1, 1), ASize + 1);
  end;
end;

function acGetArrowSize(AArrowKind: TACLArrowKind; ATargetDPI: Integer): TSize;
var
  ASize: Integer;
begin
  ASize := MulDiv(2, ATargetDPI, acDefaultDPI);
  if AArrowKind in [makLeft, makRight] then
    Result := TSize.Create(ASize + 1, ASize * 2 + 1)
  else
    Result := TSize.Create(ASize * 2 + 1, ASize + 1);
end;

procedure acDrawDotsLineV(DC: HDC; X, Y1, Y2: Integer; AColor: TColor);
var
  ABrush: HBRUSH;
  I: Integer;
  R: TRect;
begin
{$IFDEF MSWINDOWS}
  BeginPath(DC);
{$ENDIF}
  ABrush := CreateSolidBrush(ColorToRGB(AColor));
  R := Rect(X, Y1, X + 1, Y1 + 1);
  for I := 0 to (Y2 - Y1) div 3 do
  begin
    FillRect(DC, R, ABrush);
    Inc(R.Bottom, 3);
    Inc(R.Top, 3);
  end;
  DeleteObject(ABrush);
{$IFDEF MSWINDOWS}
  EndPath(DC);
{$ENDIF}
end;

procedure acDrawDotsLineH(DC: HDC; X1, X2, Y: Integer; AColor: TColor);
var
  ABrush: HBRUSH;
  I: Integer;
  R: TRect;
begin
{$IFDEF MSWINDOWS}
  BeginPath(DC);
{$ENDIF}
  ABrush := CreateSolidBrush(ColorToRGB(AColor));
  R := Rect(X1, Y, X1 + 1, Y + 1);
  for I := 0 to (X2 - X1) div 3 do
  begin
    FillRect(DC, R, ABrush);
    Inc(R.Left, 3);
    Inc(R.Right, 3);
  end;
  DeleteObject(ABrush);
{$IFDEF MSWINDOWS}
  EndPath(DC);
{$ENDIF}
end;

procedure acDrawColorPreview(ACanvas: TCanvas; R: TRect; AColor: TAlphaColor);
begin
  acDrawColorPreview(ACanvas, R, AColor, clGray, acHatchDefaultColor1, acHatchDefaultColor2);
end;

procedure acDrawColorPreview(ACanvas: TCanvas; R: TRect;
  AColor: TAlphaColor; ABorderColor, AHatchColor1, AHatchColor2: TColor);
var
  APrevFontColor: TColor;
begin
  acDrawFrame(ACanvas, R, ABorderColor);
  R.Inflate(-1);
  acDrawFrame(ACanvas, R, AHatchColor1);
  R.Inflate(-1);
  if AColor.IsDefault then
  begin
    APrevFontColor := ACanvas.Font.Color;
    ACanvas.Brush.Style := bsClear;
    ACanvas.Font.Color := ABorderColor;
    acFillRect(ACanvas, R, AHatchColor1);
    acTextDraw(ACanvas, '?', R, taCenter, taVerticalCenter);
    ACanvas.Font.Color := APrevFontColor;
  end
  else
  begin
    acDrawHatch(ACanvas.Handle, R, AHatchColor1, AHatchColor2, 4);
    acFillRect(ACanvas, R, AColor);
  end;
  acExcludeFromClipRegion(ACanvas.Handle, R.InflateTo(2));
end;

procedure acDrawFocusRect(ACanvas: TCanvas; const R: TRect; AColor: TColor);
{$IFDEF MSWINDOWS}
var
  AOrg, APrevOrg: TPoint;
{$ENDIF}
begin
  if AColor = clDefault then
    AColor := ACanvas.Font.Color;
  if AColor = clDefault then
    AColor := clWindowText;
  if AColor <> clNone then
  begin
  {$IFDEF MSWINDOWS}
    GetWindowOrgEx(ACanvas.Handle, AOrg);
    SetBrushOrgEx(ACanvas.Handle, AOrg.X, AOrg.Y, @APrevOrg);
    try
      ExPainter.BeginPaint(ACanvas);
      ExPainter.DrawRectangle(R, TAlphaColor.FromColor(AColor), 1, ssDot);
      ExPainter.EndPaint;
    finally
      SetBrushOrgEx(ACanvas.Handle, APrevOrg.X, APrevOrg.Y, nil);
    end;
  {$ELSE}
    ACanvas.Pen.Color := AColor;
    ACanvas.Pen.Style := psDot;
    ACanvas.Pen.Width := 1;
    ACanvas.Rectangle(R);
  {$ENDIF}
  end;
end;

procedure acDrawHatch(DC: HDC; const R: TRect);
begin
  acDrawHatch(DC, R, acHatchDefaultColor1, acHatchDefaultColor2, acHatchDefaultSize);
end;

procedure acDrawHatch(DC: HDC; const R: TRect; AColor1, AColor2: TColor; ASize: Integer);
var
  LBrush: HBRUSH;
  LBrushBitmap: TBitmap;
{$IFDEF MSWINDOWS}
  LOrigin: TPoint;
{$ENDIF}
begin
  LBrushBitmap := acHatchCreatePattern(ASize, AColor1, AColor2);
  try
  {$IFDEF MSWINDOWS}
    GetWindowOrgEx(DC, LOrigin);
    SetBrushOrgEx(DC, R.Left - LOrigin.X, R.Top - LOrigin.Y, @LOrigin);
  {$ENDIF}

    LBrush := CreatePatternBrush(LBrushBitmap.Handle);
    FillRect(DC, R, LBrush);
    DeleteObject(LBrush);

  {$IFDEF MSWINDOWS}
    SetBrushOrgEx(DC, LOrigin.X, LOrigin.Y, nil);
  {$ENDIF}
  finally
    LBrushBitmap.Free;
  end;
end;

function acHatchCreatePattern(ASize: Integer; AColor1, AColor2: TColor): TBitmap;
begin
  Result := TACLBitmap.CreateEx(2 * ASize, 2 * ASize, pf24bit);
  acFillRect(Result.Canvas, Bounds(0,         0, ASize, ASize), AColor2);
  acFillRect(Result.Canvas, Bounds(0,     ASize, ASize, ASize), AColor1);
  acFillRect(Result.Canvas, Bounds(ASize,     0, ASize, ASize), AColor1);
  acFillRect(Result.Canvas, Bounds(ASize, ASize, ASize, ASize), AColor2);
end;

procedure acDrawSelectionRect(ACanvas: TCanvas; const R: TRect; AColor: TAlphaColor);
begin
  if not R.IsEmpty then
  begin
    acFillRect(ACanvas, R, TAlphaColor.FromColor(AColor.ToColor, 100));
    acDrawFrame(ACanvas, R, AColor.ToColor);
  end;
end;

procedure acDrawShadow(ACanvas: TCanvas; const ARect: TRect; ABKColor: TColor; AShadowSize: Integer = 5);

  procedure DrawShadow(const R: TRect);
  var
    AShadowColor: TColor;
  begin
    ABKColor := ColorToRGB(ABKColor);
    AShadowColor := RGB(
      MulDiv(GetRValue(ABKColor), 200, 255),
      MulDiv(GetGValue(ABKColor), 200, 255),
      MulDiv(GetBValue(ABKColor), 200, 255));
    acFillRect(ACanvas, R, AShadowColor);
  end;

var
  R1: TRect;
begin
  R1 := ARect;
  R1.Top := R1.Bottom - AShadowSize;
  Inc(R1.Left, AShadowSize);
  DrawShadow(R1);

  R1 := ARect;
  R1.Left := R1.Right - AShadowSize;
  Inc(R1.Top, AShadowSize);
  DrawShadow(R1);
end;

procedure acStretchBlt(DC, SourceDC: HDC; const ADest, ASource: TRect);
begin
  StretchBlt(DC, ADest.Left, ADest.Top, ADest.Right - ADest.Left,
    ADest.Bottom - ADest.Top, SourceDC, ASource.Left, ASource.Top,
    ASource.Right - ASource.Left, ASource.Bottom - ASource.Top, SRCCOPY);
end;

procedure acDrawExpandButton(ACanvas: TCanvas;
  const R: TRect; ABorderColor, AColor: TColor; AExpanded: Boolean);
var
  R1: TRect;
begin
  R1 := R;
  R1.Inflate(-1);
  acDrawFrame(ACanvas, R1, ABorderColor);
  R1.Inflate(-2);
  acFillRect(ACanvas, R1.CenterTo(R1.Right - R1.Left, 1), AColor);
  if not AExpanded then
    acFillRect(ACanvas, R1.CenterTo(1, R1.Bottom - R1.Top), AColor);
end;

procedure acTileBlt(DC, SourceDC: HDC; const ADest, ASource: TRect);
var
  AClipRgn: TRegionHandle;
  R: TRect;
  W, H: Integer;
  X, Y, XCount, YCount: Integer;
begin
  if not (ADest.IsEmpty or ASource.IsEmpty) and RectVisible(DC, ADest) then
  begin
    W := ASource.Right - ASource.Left;
    H := ASource.Bottom - ASource.Top;
    R := ADest;
    R.Height := H;
    XCount := acCalcPatternCount(ADest.Right - ADest.Left, W);
    YCount := acCalcPatternCount(ADest.Bottom - ADest.Top, H);

    if acStartClippedDraw(DC, ADest, AClipRgn) then
    try
      for Y := 1 to YCount do
      begin
        R.Left := ADest.Left;
        R.Right := ADest.Left + W;
        for X := 1 to XCount do
        begin
          acBitBlt(DC, SourceDC, R, ASource.TopLeft);
          Inc(R.Left, W);
          Inc(R.Right, W);
        end;
        Inc(R.Top, H);
        Inc(R.Bottom, H);
      end;
    finally
      acRestoreClipRegion(DC, AClipRgn);
    end;
  end;
end;

procedure acStretchDraw(DC, SourceDC: HDC; const ADest, ASource: TRect; AMode: TACLStretchMode);
begin
  case AMode of
    isTile:
      acTileBlt(DC, SourceDC, ADest, ASource);
    isStretch, isCenter:
      acStretchBlt(DC, SourceDC, ADest, ASource);
  end;
end;

procedure acDrawDropArrow(DC: HDC; const R: TRect; AColor: TColor);
begin
  acDrawDropArrow(DC, R, AColor, acDropArrowSize);
end;

procedure acDrawDropArrow(DC: HDC; const R: TRect; AColor: TColor; const AArrowSize: TSize);
var
  ABrush: HBRUSH;
  APoints: array[0..2] of TPoint;
  ARegion: TRegionHandle;
  X, Y: Integer;
begin
  if not R.IsEmpty then
  begin
    X := (R.Right + R.Left - AArrowSize.cx) div 2;
    Y := (R.Bottom + R.Top - AArrowSize.cy) div 2;
    APoints[0] := Point(X, Y);
    APoints[1] := Point(X + AArrowSize.cx, Y);
    APoints[2] := Point(X + AArrowSize.cx div 2, Y + AArrowSize.cy + 1);

    ABrush := CreateSolidBrush(ColorToRGB(AColor));
    ARegion := CreatePolygonRgn({$IFDEF FPC}@{$ENDIF}APoints[0], 3, WINDING);
    FillRgn(DC, ARegion, ABrush);
    DeleteObject(ARegion);
    DeleteObject(ABrush);
  end;
end;

procedure acDrawFrame(ACanvas: TCanvas;
  const ARect: TRect; AColor: TColor; AThickness: Integer = 1);
begin
  acDrawFrameEx(ACanvas, ARect, AColor, acAllBorders, AThickness);
end;

procedure acDrawFrame(ACanvas: TCanvas;
  const ARect: TRect; AColor: TAlphaColor; AThickness: Integer = 1);
begin
  acDrawFrameEx(ACanvas, ARect, AColor, acAllBorders, AThickness);
end;

procedure acDrawFrameEx(ACanvas: TCanvas; const ARect: TRect;
  AColor: TColor; ABorders: TACLBorders; AThickness: Integer = 1);
var
  LClipRegion: TRegionHandle;
  LClipRect: TRect;
begin
  if AColor <> clNone then
  begin
    LClipRegion := acSaveClipRegion(ACanvas.Handle);
    try
      LClipRect := ARect;
      LClipRect.Content(AThickness, ABorders);
      acExcludeFromClipRegion(ACanvas.Handle, LClipRect);
      acFillRect(ACanvas, ARect, AColor);
    finally
      acRestoreClipRegion(ACanvas.Handle, LClipRegion);
    end;
  end;
end;

procedure acDrawFrameEx(ACanvas: TCanvas; const ARect: TRect;
  AColor: TAlphaColor; ABorders: TACLBorders; AThickness: Integer = 1);
var
  LClipRegion: TRegionHandle;
  LClipRect: TRect;
begin
  if AColor.IsValid then
  begin
    LClipRegion := acSaveClipRegion(ACanvas.Handle);
    try
      LClipRect := ARect;
      LClipRect.Content(AThickness, ABorders);
      acExcludeFromClipRegion(ACanvas.Handle, LClipRect);
      acFillRect(ACanvas, ARect, AColor);
    finally
      acRestoreClipRegion(ACanvas.Handle, LClipRegion);
    end;
  end;
end;

procedure acFillRect(ACanvas: TCanvas; const ARect: TRect; AColor: TColor);
begin
  if AColor <> clNone then
  begin
    ACanvas.Brush.Color := AColor;
    ACanvas.FillRect(ARect);
  end;
end;

procedure acFillRect(ACanvas: TCanvas; const ARect: TRect; AColor: TAlphaColor);
begin
  if AColor.IsValid then
  begin
    ExPainter.BeginPaint(ACanvas);
    ExPainter.FillRectangle(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom, AColor);
    ExPainter.EndPaint;
  end;
end;

procedure acFillRect(ACanvas: TCanvas; const ARect: TRect; AColor: TAlphaColor; ARadius: Integer); overload;
var
  LPath: TACL2DRenderPath;
begin
  if AColor.IsValid then
  begin
    ExPainter.BeginPaint(ACanvas);
    try
      if ARadius > 0 then
      begin
        LPath := ExPainter.CreatePath;
        try
          LPath.AddRoundRect(ARect, ARadius, ARadius);
          ExPainter.SetGeometrySmoothing(TACLBoolean.True);
          ExPainter.FillPath(LPath, AColor);
        finally
          LPath.Free;
        end;
      end
      else
        ExPainter.FillRectangle(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom, AColor);
    finally
      ExPainter.EndPaint;
    end;
  end;
end;

procedure acDrawComplexFrame(ACanvas: TCanvas; const R: TRect;
  AColor1, AColor2: TColor; ABorders: TACLBorders = acAllBorders);
var
  LInnerFrame: TRect;
begin
  LInnerFrame := R;
  LInnerFrame.Content(1, ABorders);
  acDrawFrameEx(ACanvas, R, AColor1, ABorders);
  acDrawFrameEx(ACanvas, LInnerFrame, AColor2, ABorders);
end;

procedure acDrawComplexFrame(ACanvas: TCanvas; const R: TRect;
  AColor1, AColor2: TAlphaColor; ABorders: TACLBorders = acAllBorders);
var
  LInnerFrame: TRect;
begin
  LInnerFrame := R;
  LInnerFrame.Content(1, ABorders);
  acDrawFrameEx(ACanvas, R, AColor1, ABorders);
  acDrawFrameEx(ACanvas, LInnerFrame, AColor2, ABorders);
end;

procedure acDrawGradient(ACanvas: TCanvas; const ARect: TRect; AFrom, ATo: TColor; AVertical: Boolean);
begin
  if AFrom = clNone then
    acFillRect(ACanvas, ARect, ATo)
  else if (ATo = clNone) or (AFrom = ATo) then
    acFillRect(ACanvas, ARect, AFrom)
  else
    acDrawGradient(ACanvas, ARect, TAlphaColor.FromColor(AFrom), TAlphaColor.FromColor(ATo), AVertical);
end;

procedure acDrawGradient(ACanvas: TCanvas; const ARect: TRect; AFrom, ATo: TAlphaColor; AVertical: Boolean);
begin
  if (AFrom = ATo) or not AFrom.IsValid then
    acFillRect(ACanvas, ARect, ATo)
  else
    if ATo.IsValid then
    begin
      ExPainter.BeginPaint(ACanvas);
      ExPainter.FillRectangleByGradient(ARect, AFrom, ATo, AVertical);
      ExPainter.EndPaint;
    end
    else
      acFillRect(ACanvas, ARect, AFrom);
end;

procedure acDrawHueIntensityBar(ACanvas: TCanvas; const R: TRect; AHue: Byte = 0);
var
  AColor: TColor;
  ADelta: Single;
  AValue: Single;
  I: Integer;
begin
  if not R.IsEmpty then
  begin
    AValue := 0;
    ADelta := 1.0 / R.Width;
    for I := R.Left to R.Right do
    begin
      TACLColors.HSLtoRGB(AHue / 255, AValue, 0.5, AColor);
      acFillRect(ACanvas, Rect(I, R.Top, I + 1, R.Bottom), AColor);
      AValue := AValue + ADelta;
    end;
  end;
end;

procedure acDrawHueColorBar(ACanvas: TCanvas; const R: TRect);
var
  AColor: TColor;
  ADelta: Single;
  AValue: Single;
  I: Integer;
begin
  if not R.IsEmpty then
  begin
    AValue := 0;
    ADelta := 1.0 / R.Width;
    for I := R.Left to R.Right do
    begin
      TACLColors.HSLtoRGB(AValue, 1.0, 0.5, AColor);
      acFillRect(ACanvas, Rect(I, R.Top, I + 1, R.Bottom), AColor);
      AValue := AValue + ADelta;
    end;
  end;
end;

{ TACLPixel32 }

class function TACLPixel32.Create(A, R, G, B: Byte): TACLPixel32;
begin
  Result.B := B;
  Result.G := G;
  Result.R := R;
  Result.A := A;
end;

class function TACLPixel32.Create(AColor: TAlphaColor): TACLPixel32;
begin
  Result.B := AColor.B;
  Result.G := AColor.G;
  Result.R := AColor.R;
  Result.A := AColor.A;
end;

class function TACLPixel32.Create(AColor: TColor; AAlpha: Byte = MaxByte): TACLPixel32;
begin
  AColor := ColorToRGB(AColor);
  Result.R := GetRValue(AColor);
  Result.G := GetGValue(AColor);
  Result.B := GetBValue(AColor);
  Result.A := AAlpha;
end;

class operator TACLPixel32.Implicit(const Value: TACLPixel32): TRGBQuad;
begin
  DWORD(Result) := DWORD(Value);
end;

class operator TACLPixel32.Implicit(const Value: TRGBQuad): TACLPixel32;
begin
  DWORD(Result) := DWORD(Value);
end;

function TACLPixel32.ToColor: TColor;
begin
  Result := RGB(R, G, B);
end;

{ TAlphaColorHelper }

class function TAlphaColorHelper.ApplyColorSchema(
  AColor: TAlphaColor; const ASchema: TACLColorSchema): TAlphaColor;
begin
  Result := AColor;
  TACLColors.ApplyColorSchema(Result, ASchema);
end;

class function TAlphaColorHelper.FromARGB(const A, R, G, B: Byte): TAlphaColor;
begin
  Result := (A shl 24) or (R shl 16) or (G shl 8) or B;
end;

class function TAlphaColorHelper.FromColor(const AColor: TColor; AAlpha: Byte): TAlphaColor;
begin
  if AColor = clDefault then
    Exit(TAlphaColor.Default);
  if AColor = clNone then
    Exit(TAlphaColor.None);
  Result := FromColor(TACLPixel32.Create(AColor, AAlpha));
end;

class function TAlphaColorHelper.FromColor(const AColor: TACLPixel32): TAlphaColor;
begin
  Result := FromARGB(AColor.A, AColor.R, AColor.G, AColor.B);
end;

class function TAlphaColorHelper.FromString(AColor: string): TAlphaColor;
var
  P: TACLPixel32;
begin
  if AColor = '' then
    Exit(Default);
  if Length(AColor) < 6 then
    AColor := AColor + DupeString('0', 6 - Length(AColor));
  if Length(AColor) = 6 then
    AColor := 'FF' + AColor
  else
    if Length(AColor) < 8 then
      AColor := DupeString('0', 8 - Length(AColor)) + AColor;

  P.A := StrToIntDef('$' + Copy(AColor, 1, 2), 0);
  P.R := StrToIntDef('$' + Copy(AColor, 3, 2), 0);
  P.G := StrToIntDef('$' + Copy(AColor, 5, 2), 0);
  P.B := StrToIntDef('$' + Copy(AColor, 7, 2), 0);
  Result := TAlphaColor.FromColor(P);
end;

function TAlphaColorHelper.IsDefault: Boolean;
begin
  Result := Self = TAlphaColor.Default;
end;

function TAlphaColorHelper.IsValid: Boolean;
begin
  Result := (Self <> TAlphaColor.None) and (Self <> TAlphaColor.Default);
end;

function TAlphaColorHelper.ToColor: TColor;
begin
  if Self = TAlphaColor.Default then
    Result := clDefault
  else
    if Self = TAlphaColor.None then
      Result := clNone
    else
      Result := (GetRValue(Self) shl 16) or (GetGValue(Self) shl 8) or (GetBValue(Self));
end;

function TAlphaColorHelper.ToPixel: TACLPixel32;
const
  AlphaShift  = 24;
  RedShift    = 16;
  GreenShift  = 8;
  BlueShift   = 0;
begin
  Result.B := Byte(Self shr BlueShift);
  Result.G := Byte(Self shr GreenShift);
  Result.R := Byte(Self shr RedShift);
  Result.A := Self shr AlphaShift;
end;

function TAlphaColorHelper.ToString: string;
begin
  if Self = TAlphaColor.None then
    Result := 'None'
  else
    if Self = TAlphaColor.Default then
      Result := 'Default'
    else
      with ToPixel do
        Result :=
          IntToHex(A, 2) +
          IntToHex(R, 2) +
          IntToHex(G, 2) +
          IntToHex(B, 2);
end;

function TAlphaColorHelper.GetAlpha(const Index: Integer): Byte;
begin
  if IsDefault then
    Result := MaxByte
  else
    Result := GetComponent(Index);
end;

function TAlphaColorHelper.GetComponent(const Index: Integer): Byte;
begin
  Result := PARGB(@Self)^[Index];
end;

procedure TAlphaColorHelper.SetComponent(const Index: Integer; const Value: Byte);
begin
  PARGB(@Self)^[Index] := Value;
end;

{ TACLRegion }

constructor TACLRegion.Create;
begin
  CreateRect(NullRect);
end;

constructor TACLRegion.CreateRect(const R: TRect);
begin
  FHandle := CreateRectRgnIndirect(R);
end;

constructor TACLRegion.CreateFromDC(DC: HDC);
var
  LPoint: TPoint;
begin
  Create;
  if GetClipRgn(DC, Handle) = 1 then
  begin
    GetWindowOrgEx(DC, LPoint{%H-});
    Offset(LPoint.X, LPoint.Y);
  end
  else
    SetRectRgn(Handle, 0, 0, MaxRegionSize, MaxRegionSize);
end;

constructor TACLRegion.CreateFromHandle(AHandle: TRegionHandle);
begin
  FHandle := AHandle;
end;

destructor TACLRegion.Destroy;
begin
  FreeHandle;
  inherited Destroy;
end;

procedure TACLRegion.FreeHandle;
begin
  if FHandle <> 0 then
  begin
    DeleteObject(FHandle);
    FHandle := 0;
  end;
end;

function TACLRegion.GetBounds: TRect;
begin
  if GetRgnBox(Handle, {$IFDEF FPC}@{$ENDIF}Result) = NULLREGION then
    Result := NullRect;
end;

function TACLRegion.GetIsEmpty: Boolean;
var
  R: TRect;
begin
  Result := GetRgnBox(Handle, {$IFDEF FPC}@{$ENDIF}R) = NULLREGION;
end;

function TACLRegion.Clone: TRegionHandle;
begin
  Result := CreateRectRgnIndirect(NullRect);
  CombineRgn(Result, Result, Handle, RGN_OR);
end;

procedure TACLRegion.Combine(ARegion: TACLRegion;
  ACombineFunc: TACLRegionCombineFunc; AFreeRegion: Boolean = False);
begin
  CombineRgn(Handle, Handle, ARegion.Handle, CombineFuncMap[ACombineFunc]);
  if AFreeRegion then
    FreeAndNil(ARegion);
end;

procedure TACLRegion.Combine(const R: TRect; ACombineFunc: TACLRegionCombineFunc);
var
  ARgn: TRegionHandle;
begin
  ARgn := CreateRectRgnIndirect(R);
  if ACombineFunc <> rcmCopy then
    CombineRgn(Handle, Handle, ARgn, CombineFuncMap[ACombineFunc])
  else
    TACLMath.Exchange<TRegionHandle>(FHandle, ARgn);

  DeleteObject(ARgn)
end;

function TACLRegion.Contains(const R: TRect): Boolean;
begin
  Result := RectInRegion(Handle, R);
end;

function TACLRegion.Contains(const P: TPoint): Boolean;
begin
  Result := PtInRegion(Handle, P.X, P.Y);
end;

procedure TACLRegion.Offset(X, Y: Integer);
begin
  OffsetRgn(Handle, X, Y);
end;

procedure TACLRegion.Reset;
begin
  SetRectRgn(Handle, 0, 0, 0, 0);
end;

procedure TACLRegion.SetHandle(AValue: TRegionHandle);
begin
  if (AValue <> 0) and (AValue <> FHandle) then
  begin
    FreeHandle;
    FHandle := AValue;
  end;
end;

procedure TACLRegion.SetToWindow(AHandle: HWND; ARedraw: Boolean = True);
begin
  acRegionSetToWindow(AHandle, Clone, ARedraw);
end;

{ TACLRegionData }

constructor TACLRegionData.Create(ACount: Integer);
begin
  inherited Create;
  DataAllocate(ACount);
end;

constructor TACLRegionData.CreateFromDC(DC: HDC);
{$IF DEFINED(LCLGtk2)}
var
  LRegion: PGdiObject;
begin
  LRegion := TGtkDeviceContext(DC).ClipRegion;
  if LRegion <> nil then
    DataAllocateFromNativeHandle(LRegion^.GDIRegionObject);
{$ELSE}
var
  LOrigin: TPoint;
  LRegion: TRegionHandle;
begin
  LRegion := CreateRectRgn(0, 0, 0, 0);
  try
    if GetClipRgn(DC, LRegion) = 1 then
    begin
      GetWindowOrgEx(DC, LOrigin);
      OffsetRgn(LRegion, LOrigin.X, LOrigin.Y);
      CreateFromHandle(LRegion);
    end;
  finally
    acRegionFree(LRegion);
  end;
{$ENDIF}
end;

constructor TACLRegionData.CreateFromHandle(ARgn: TRegionHandle);
{$IF DEFINED(LCLGtk2)}
var
  LRect: TRect;
begin
  case GetRgnBox(ARgn, @LRect) of
    SimpleRegion, ComplexRegion:
      DataAllocateFromNativeHandle({%H-}PGDIObject(ARgn)^.GDIRegionObject);
  end;
{$ELSEIF DEFINED(MSWINDOWS)}
begin
  FDataSize := GetRegionData(ARgn, 0, nil);
  if FDataSize > 0 then
  begin
    FData := AllocMem(FDataSize);
    GetRegionData(ARgn, FDataSize, FData);
    FRects := @PRgnData(FData)^.Buffer[0];
    FCount := PRgnData(FData)^.rdh.nCount;
  end;
{$ELSE}
  {$MESSAGE FATAL 'TACLRegionData.CreateFromHandle not implemented'}
{$ENDIF}
end;

destructor TACLRegionData.Destroy;
begin
  DataFree;
  inherited Destroy;
end;

function TACLRegionData.BoundingBox: TRect;
var
  I: Integer;
begin
  if Count = 0 then
    Exit(NullRect);

  Result := Rects[0];
  for I := 1 to Count - 1 do
    Result.Add(Rects[I]);
end;

function TACLRegionData.CreateHandle(const ABoundingBox: TRect): TRegionHandle;
{$IFNDEF MSWINDOWS}
var
  I: Integer;
  LRect: TGdkRectangle;
{$ENDIF}
begin
  if Count = 0 then
    Exit(CreateRectRgnIndirect(NullRect));

{$IF DEFINED(MSWINDOWS)}
  PRgnData(FData)^.rdh.rcBound := ABoundingBox;
  Result := ExtCreateRegion(nil, FDataSize, PRgnData(FData)^);
{$ELSEIF DEFINED(LCLGtk2)}
  Result := CreateRectRgnIndirect(NullRect);
  for I := 0 to Count - 1 do
  begin
    with Rects^[I] do
    begin
      LRect.x := Left;
      LRect.y := Top;
      LRect.width := Width;
      LRect.height := Height;
    end;
    gdk_region_union_with_rect({%H-}PGDIObject(Result)^.GDIRegionObject, @LRect);
  end;
{$ELSE}
  raise ENotImplemented.Create('TACLRegionData.CreateHandle');
{$ENDIF}
end;

procedure TACLRegionData.DataAllocate(ACount: Integer);
begin
  FCount := ACount;
{$IFDEF MSWINDOWS}
  FDataSize := SizeOf(TRgnData) + SizeOf(TRect) * Count;
  FData := AllocMem(FDataSize);
  PRgnData(FData)^.rdh.dwSize := SizeOf(PRgnData(FData)^.rdh);
  PRgnData(FData)^.rdh.iType := RDH_RECTANGLES;
  PRgnData(FData)^.rdh.nCount := Count;
  PRgnData(FData)^.rdh.nRgnSize := 0;
  FRects := PRectArray(@PRgnData(FData)^.Buffer[0]);
{$ELSE}
  FDataSize := SizeOf(TRect) * Count;
  FData := AllocMem(FDataSize);
  FRects := FData;
{$ENDIF}
end;

procedure TACLRegionData.DataAllocateFromNativeHandle(APtr: Pointer);
{$IF DEFINED(LCLGtk2)}
type
  PGdkRectangleArray = ^TGdkRectangleArray;
  TGdkRectangleArray = array[0..0] of TGdkRectangle;
var
  LGdkRectCount: Integer;
  LGdkRects: PGdkRectangle;
  I: Integer;
begin
  if APtr = nil then Exit;
  LGdkRects := nil;
  LGdkRectCount := 0;
  gdk_region_get_rectangles(APtr, LGdkRects, @LGdkRectCount);
  if LGdkRects <> nil then
  try
    DataAllocate(LGdkRectCount);
    for I := 0 to LGdkRectCount - 1 do
    begin
      with PGdkRectangleArray(LGdkRects)^[I] do
        Rects^[I] := Rect(x, y, x + width, y + height);
    end;
  finally
    g_free(LGdkRects);
  end;
{$ELSE}
begin
{$ENDIF}
end;

procedure TACLRegionData.DataFree;
begin
  FreeMem(FData);
  FDataSize := 0;
  FData := nil;
  FRects := nil;
  FCount := 0;
end;

procedure TACLRegionData.SetCount(AValue: Integer);
begin
  AValue := Max(AValue, 0);
  if Count <> AValue then
  begin
    DataFree;
    DataAllocate(AValue);
  end;
end;

{ TACLColorSchema }

constructor TACLColorSchema.Create(AHue, AHueIntensity: Byte);
begin
  Hue := AHue;
  HueIntensity := AHueIntensity;
end;

class function TACLColorSchema.CreateFromColor(AColor: TAlphaColor): TACLColorSchema;
var
  H, S, L: Byte;
begin
  if AColor.IsValid then
  begin
    TACLColors.RGBtoHSLi(AColor.R, AColor.G, AColor.B, H, S, L);
    Result := TACLColorSchema.Create(H, MulDiv(100, S, MaxByte));
  end
  else
    Result := TACLColorSchema.Default;
end;

class function TACLColorSchema.Default: TACLColorSchema;
begin
  Result := TACLColorSchema.Create(0);
end;

function TACLColorSchema.IsAssigned: Boolean;
begin
  Result := Hue > 0;
end;

class operator TACLColorSchema.Equal(const C1, C2: TACLColorSchema): Boolean;
begin
  Result := (C1.Hue = C2.Hue) and (C1.HueIntensity = C2.HueIntensity);
end;

class operator TACLColorSchema.NotEqual(const C1, C2: TACLColorSchema): Boolean;
begin
  Result := not (C1 = C2);
end;

{ TFontHelper }

procedure TFontHelper.Assign(Source: TFont; SourceDpi, TargetDpi: Integer);
begin
  Assign(Source);
  if SourceDpi <> TargetDpi then
    Height := dpiApply(dpiRevert(Source.Height, SourceDpi), TargetDpi)
  else
    // Height may be changed during Assign(), if the fonts has different PixelsPerInch
    Height := Source.Height;
end;

function TFontHelper.Clone: TFont;
type
  TFontClass = class of TFont;
begin
  Result := TFontClass(ClassType).Create;
  Result.PixelsPerInch := PixelsPerInch;
  Result.Assign(Self);
end;

procedure TFontHelper.ResolveHeight;
var
  LLogFont: TLogFont;
begin
  if Height = 0 then
  begin
    if GetObject(Handle, SizeOf(LLogFont), @LLogFont) <> 0 then
      Height := {$IFDEF LCLGtk2}-{$ENDIF}LLogFont.lfHeight;
  end;
end;

procedure TFontHelper.SetSize(ASize, ATargetDpi: Integer);
begin
  Size := MulDiv(ASize, ATargetDpi, PixelsPerInch);
end;

{ TCanvasHelper }

procedure TCanvasHelper.SetScaledFont(AFont: TFont);
begin
{$IFDEF FPC}
  Font.BeginUpdate;
  try
{$ENDIF}
    Font.Assign(AFont);
    // Height may be changed during Assign(), if the fonts has different PixelsPerInch
    Font.Height := AFont.Height;
{$IFDEF FPC}
  finally
    Font.EndUpdate;
  end;
{$ENDIF}
end;

{ TACLDib }

constructor TACLDib.Create;
begin
  Create(0, 0);
end;

constructor TACLDib.Create(const R: TRect);
begin
  Create(R.Width, R.Height);
end;

constructor TACLDib.Create(const S: TSize);
begin
  Create(S.cx, S.cy);
end;

constructor TACLDib.Create(const W, H: Integer);
begin
  CreateHandles(W, H);
end;

destructor TACLDib.Destroy;
begin
  FreeHandles;
  inherited Destroy;
end;

procedure TACLDib.Assign(AColors: PACLPixel32; AWidth, AHeight: Integer);
begin
  Resize(AWidth, AHeight);
  FastMove(AColors^, Colors^, ColorCount * SizeOf(TACLPixel32));
end;

procedure TACLDib.Assign(ASource: TACLDib);
begin
  if ASource <> Self then
  begin
    if (ASource <> nil) and not ASource.Empty then
      Assign(PACLPixel32(ASource.Colors), ASource.Width, ASource.Height)
    else
      Resize(0, 0);
  end;
end;

procedure TACLDib.Assign(ASource: TGraphic);
begin
  if (ASource = nil) or ASource.Empty then
  begin
    Resize(0, 0);
    Exit;
  end;

  Resize(ASource.Width, ASource.Height);
{$IFDEF FPC}
  if ASource is TRasterImage then
    Assign(TRasterImage(ASource).RawImage)
  else
{$ELSE}
  if ASource.SupportsPartialTransparency then
    Canvas.Draw(0, 0, ASource)
  else
{$ENDIF}
    if ASource.Transparent then
    begin
      Canvas.Brush.Color := clFuchsia;
      Canvas.FillRect(ClientRect);
      Canvas.Draw(0, 0, ASource);
      MakeTransparent(clFuchsia);
    end
    else
    begin
      Canvas.Draw(0, 0, ASource);
      MakeOpaque;
    end;
end;

{$IFDEF LCLGtk2}
procedure TACLDib.Assign(ASource: PGdkPixbuf);
var
  LImage: TRawImage;
begin
  LImage.Init;
  if (ASource <> nil) and GTK2WidgetSet.RawImage_DescriptionFromPixbuf(LImage.Description, ASource) then
  begin
    LImage.Data := gdk_pixbuf_get_pixels(ASource);
    LImage.DataSize := LImage.Description.BytesPerLine * LImage.Description.Height;
    Assign(LImage);
  end
  else
    Resize(0, 0);
end;
{$ENDIF}

{$IFDEF FPC}
procedure TACLDib.Assign(ASource: TLazIntfImage);
var
  LImage: TLazIntfImage;
begin
  Resize(ASource.Width, ASource.Height);
  if not Empty then
    acRawImageToBits(PACLPixel32(Colors), ASource);
end;

procedure TACLDib.Assign(ASource: TRawImage);
begin
  Resize(ASource.Description.Width, ASource.Description.Height);
  if Empty then
    Exit;
  if ASource.Description.BitsPerPixel = 32 then
  begin
    if ASource.DataSize <> ColorCount * SizeOf(TACLPixel32) then
      raise EInvalidArgument.Create('RawImage.DataSize does not match');
    Move(ASource.Data^, Colors^, ASource.DataSize);
    if ASource.Description.RedShift = 0 then
      TACLColors.BGRAtoRGBA(@Colors[0], ColorCount);
    if ASource.Description.Depth < 32 then
      MakeOpaque;
    if not IsPremultiplied then // AI: у картинки из-под имеджлиста белая подложка с нулевой альфой
      Premultiply;
  end
  else
    acRawImageToBits(PACLPixel32(Colors), ASource);
end;
{$ENDIF}

procedure TACLDib.AssignTo;
{$IFDEF FPC}
var
  LRawImage: TRawImage;
begin
  LRawImage.Init;
  LRawImage.Data := PByte(Colors);
  LRawImage.DataSize := ColorCount * SizeOf(TACLPixel32);
  LRawImage.Description.Init_BPP32_B8G8R8A8_BIO_TTB(Width, Height);
  ATarget.LoadFromRawImage(LRawImage, False);
{$ELSE}
begin
  ATarget.PixelFormat := pf32bit;
  ATarget.SetSize(Width, Height);
  DrawCopy(ATarget.Canvas, NullPoint);
{$ENDIF}
end;

function TACLDib.Clone(out AData: PACLPixel32Array): Boolean;
var
  ASize: Integer;
begin
  ASize := ColorCount * SizeOf(TACLPixel32);
  Result := ASize > 0;
  if Result then
  begin
    AData := AllocMem(ASize);
    FastMove(Colors^, AData^, ASize);
  end;
end;

function TACLDib.CoordToFlatIndex(X, Y: Integer): Integer;
begin
  if (X >= 0) and (X < Width) and (Y >= 0) and (Y < Height) then
    Result := X + Y * Width
  else
    Result := -1;
end;

function TACLDib.Equals(Obj: TObject): Boolean;
begin
  if Obj = Self then
    Exit(True);
  if Obj is TACLDib then
  begin
    Result :=
      (Width = TACLDib(Obj).Width) and (Height = TACLDib(Obj).Height) and
      (CompareMem(Colors, TACLDib(Obj).Colors, ColorCount * SizeOf(TACLPixel32)));
  end
  else
    Result := False;
end;

function TACLDib.IsPremultiplied: Boolean;
begin
  Result := TACLColors.ArePremultiplied(PACLPixel32(Colors), ColorCount);
end;

procedure TACLDib.ApplyTint(const AColor: TColor);
begin
  ApplyTint(TAlphaColor.FromColor(AColor).ToPixel);
end;

procedure TACLDib.ApplyTint(const AColor: TACLPixel32);
var
  P: PACLPixel32;
  I: Integer;
begin
  P := @Colors^[0];
  for I := 0 to ColorCount - 1 do
  begin
    if P^.A > 0 then
    begin
      TACLColors.Unpremultiply(P^);
      P^.B := AColor.B;
      P^.G := AColor.G;
      P^.R := AColor.R;
      TACLColors.Premultiply(P^);
    end;
    Inc(P);
  end;
end;

procedure TACLDib.CopyRect(ACanvas: TCanvas; const R: TRect; X: Integer = 0; Y: Integer = 0);
begin
  BitBlt(Handle, X, Y, R.Width, R.Height, ACanvas.Handle, R.Left, R.Top, SRCCOPY);
end;

{$IFDEF ACL_CAIRO}
procedure TACLDib.DrawBlend(ACairo: Pcairo_t;
  const ATargetRect, ASourceRect: TRect; AAlpha: Byte = MaxByte);
var
  LSurface: Pcairo_surface_t;
begin
  LSurface := cairo_create_surface(Colors, Width, Height);
  try
    cairo_fill_surface(ACairo, LSurface, ATargetRect, ASourceRect, NullPoint, AAlpha / 255, False);
  finally
    cairo_surface_destroy(LSurface);
  end;
end;
{$ENDIF}

procedure TACLDib.DrawBlend(ACanvas: HDC;
  const ATargetRect, ASourceRect: TRect; AAlpha: Byte = MaxByte);
{$IFDEF MSWINDOWS}
var
  LBlendFunc: TBlendFunction;
begin
  LBlendFunc.AlphaFormat := AC_SRC_ALPHA;
  LBlendFunc.BlendOp := AC_SRC_OVER;
  LBlendFunc.BlendFlags := 0;
  LBlendFunc.SourceConstantAlpha := AAlpha;
  AlphaBlend(ACanvas,
    ATargetRect.Left, ATargetRect.Top, ATargetRect.Width, ATargetRect.Height,
    Handle,
    ASourceRect.Left, ASourceRect.Top, ASourceRect.Width, ASourceRect.Height,
    LBlendFunc);
{$ELSE}
var
  LSurface: Pcairo_surface_t;
begin
  LSurface := cairo_create_surface(Colors, Width, Height);
  try
    CairoPainter.BeginPaint(ACanvas);
    CairoPainter.FillSurface(ATargetRect, ASourceRect, LSurface, AAlpha / 255, False);
    CairoPainter.EndPaint;
  finally
    cairo_surface_destroy(LSurface);
  end;
{$ENDIF}
end;

procedure TACLDib.DrawBlend(ACanvas: TCanvas; const P: TPoint; AAlpha: Byte = 255);
begin
  DrawBlend(ACanvas, Bounds(P.X, P.Y, Width, Height), AAlpha);
end;

procedure TACLDib.DrawBlend(ACanvas: TCanvas;
  const R: TRect; AAlpha: Byte; ASmoothStretch: Boolean);
begin
  DrawBlend(ACanvas, R, ClientRect, AAlpha, ASmoothStretch);
end;

procedure TACLDib.DrawBlend(ACanvas: TCanvas;
  const ATargetRect, ASourceRect: TRect; AAlpha: Byte; ASmoothStretch: Boolean);
{$IFDEF MSWINDOWS}
var
  LGpCanvas: GpGraphics;
  LGpHandle: GpImage;
begin
  if ASmoothStretch and not ATargetRect.EqualSizes(ASourceRect) then
  begin
    LGpHandle := GpCreateBitmap(Width, Height, PByte(Colors));
    try
      if GdipCreateFromHDC(ACanvas.Handle, LGpCanvas) = Ok then
      try
        GdipSetCompositingMode(LGpCanvas, CompositingModeSourceOver);
        GdipSetInterpolationMode(LGpCanvas, InterpolationModeLowQuality);
        GdipSetPixelOffsetMode(LGpCanvas, PixelOffsetModeHalf);
        GpDrawImage(LGpCanvas, LGpHandle,
          TACLGdiplusAlphaBlendAttributes.Get(AAlpha),
          ATargetRect, ASourceRect, False);
      finally
        GdipDeleteGraphics(LGpCanvas);
      end;
    finally
      GdipDisposeImage(LGpHandle);
    end;
  end
  else
    DrawBlend(ACanvas.Handle, ATargetRect, ASourceRect, AAlpha);
{$ELSE}
var
  LSurface: Pcairo_surface_t;
begin
  LSurface := cairo_create_surface(Colors, Width, Height);
  try
    CairoPainter.BeginPaint(ACanvas);
    CairoPainter.SetImageSmoothing(TACLBoolean.From(ASmoothStretch));
    CairoPainter.FillSurface(ATargetRect, ASourceRect, LSurface, AAlpha / 255, False);
    CairoPainter.EndPaint;
  finally
    cairo_surface_destroy(LSurface);
  end;
{$ENDIF}
end;

procedure TACLDib.DrawCopy(ACanvas: TCanvas; const P: TPoint);
begin
  acBitBlt(ACanvas.Handle, Handle, Bounds(P.X, P.Y, Width, Height), NullPoint);
end;

procedure TACLDib.DrawCopy(ACanvas: TCanvas; const R: TRect; ASmoothStretch: Boolean = False);
var
  AMode: Integer;
begin
  if ASmoothStretch and not R.EqualSizes(ClientRect) then
  begin
    AMode := SetStretchBltMode(ACanvas.Handle, HALFTONE);
    acStretchBlt(ACanvas.Handle, Handle, R, ClientRect);
    SetStretchBltMode(ACanvas.Handle, AMode);
  end
  else
    acStretchBlt(ACanvas.Handle, Handle, R, ClientRect);
end;

procedure TACLDib.Flip(AHorizontally, AVertically: Boolean);
begin
  TACLColors.Flip(Colors, Width, Height, AHorizontally, AVertically);
end;

procedure TACLDib.MakeDisabled(AIgnoreMask: Boolean = False);
begin
  TACLColors.MakeDisabled(@Colors^[0], ColorCount, AIgnoreMask);
end;

procedure TACLDib.MakeMirror(ASize: Integer);
var
  LAlpha: Single;
  LAlphaDelta: Single;
  LAlphaValue: Integer;
  LIndex: Integer;
  I, J, O1, O2: Integer;
begin
  if (ASize > 0) and (ASize < Height div 2) then
  begin
    LAlpha := 60;
    LAlphaDelta := LAlpha / ASize;
    O2 := Width;
    O1 := O2 * (Height - ASize);

    LIndex := O1;
    for J := 0 to ASize - 1 do
    begin
      LAlphaValue := Round(LAlpha);
      for I := 0 to O2 - 1 do
      begin
        TACLColors.Mix(Colors^[LIndex], Colors^[O1 + I], LAlphaValue);
        Inc(LIndex);
      end;
      LAlpha := LAlpha - LAlphaDelta;
      Dec(O1, O2);
    end;
  end;
end;

procedure TACLDib.MakeOpaque;
begin
  TACLColors.MakeOpaque(@Colors^[0], ColorCount);
end;

procedure TACLDib.MakeTransparent(const AColor: TACLPixel32);
var
  I: Integer;
  P: PACLPixel32;
begin
  P := @Colors^[0];
  for I := 0 to ColorCount - 1 do
  begin
    if TACLColors.CompareRGB(P^, AColor) then
      TACLColors.Flush(P^)
    else
      P^.A := $FF;
    Inc(P);
  end;
end;

procedure TACLDib.MakeTransparent(const AColor: TColor);
begin
  MakeTransparent(TACLPixel32.Create(AColor));
end;

procedure TACLDib.Premultiply(R: TRect);
var
  Y: Integer;
begin
  if IntersectRect(R, R, ClientRect) then
  begin
    for Y := R.Top to R.Bottom - 1 do
      TACLColors.Premultiply(@Colors^[Y * Width + R.Left], R.Width);
  end;
end;

procedure TACLDib.Premultiply;
begin
  TACLColors.Premultiply(@Colors^[0], ColorCount);
end;

procedure TACLDib.Unpremultiply;
begin
  TACLColors.Unpremultiply(@Colors^[0], ColorCount);
end;

procedure TACLDib.Reset;
var
  LPrevPoint: TPoint;
begin
{$IFDEF FPC}
  if not FCanvasChanged then
  begin
    FastZeroMem(Colors, ColorCount * SizeOf(TACLPixel32));
    Exit;
  end;
{$ENDIF}
  SetWindowOrgEx(Handle, 0, 0, @LPrevPoint);
  acResetRect(Handle, ClientRect);
  SetWindowOrgEx(Handle, LPrevPoint.X, LPrevPoint.Y, nil);
end;

procedure TACLDib.Reset(const ARect: TRect);
{$IFDEF FPC}
var
  R: TRect;
  Y: Integer;
begin
  if not FCanvasChanged then
  begin
    if IntersectRect(R, ARect, ClientRect) then
    begin
      for Y := R.Top to R.Bottom - 1 do
        FastZeroMem(@Colors^[Y * Width + R.Left], R.Width * SizeOf(TACLPixel32));
    end;
    Exit;
  end;
{$ELSE}
begin
{$ENDIF}
  acResetRect(Handle, ARect);
end;

function TACLDib.Resize(const ANewBounds: TRect): Boolean;
begin
  Result := Resize(ANewBounds.Width, ANewBounds.Height);
end;

function TACLDib.Resize(const ANewWidth, ANewHeight: Integer): Boolean;
begin
  Result := (ANewWidth <> Width) or (ANewHeight <> Height);
  if Result then
  begin
    FreeHandles;
    CreateHandles(ANewWidth, ANewHeight);
  end;
end;

procedure TACLDib.CreateHandles(W, H: Integer);
var
  LBitmap: TBitmapInfo;
  LErrorText: string;
begin
  if (W <= 0) or (H <= 0) then
    Exit;

  FWidth := W;
  FHeight := H;
  FColorCount := W * H;
  FHandle := CreateCompatibleDC(0);
  acInitBitmap32Info(LBitmap, Width, Height);
{$IFDEF LCLGtk2}
  FColors := AllocMem(FColorCount * SizeOf(TACLPixel32));
  FBitmap := CreateCompatibleBitmap(FHandle, Width, Height);
{$ELSE}
  FColors := nil;
  FBitmap := CreateDIBSection(0, LBitmap, DIB_RGB_COLORS, Pointer(FColors), 0, 0);
{$ENDIF}
  DeleteObject(SelectObject(FHandle, FBitmap));
  if FColors = nil then
  begin
    LErrorText := Format('Failed to create DIB (%dx%d)', [W, H]);
  {$IFDEF MSWINDOWS}
    LErrorText := Format('%d: %s, %d', [GetLastError, LErrorText,
      GetGuiResources(GetCurrentProcess, GR_GDIOBJECTS)]);
  {$ENDIF}
    FreeHandles;
    raise EInvalidGraphicOperation.Create(LErrorText);
  end;
end;

procedure TACLDib.FreeHandles;
begin
  FreeAndNil(FCanvas);
  if FHandle <> 0 then
  begin
    DeleteObject(FBitmap);
    DeleteDC(FHandle);
  {$IFDEF LCLGtk2}
    FreeMem(FColors);
  {$ENDIF}
    FColorCount := 0;
    FColors := nil;
    FHeight := 0;
    FBitmap := 0;
    FHandle := 0;
    FWidth := 0;
  end;
end;

function TACLDib.GetCanvas: TCanvas;
begin
  if FCanvas = nil then
    FCanvas := TACLDibCanvas.Create(Self);
  // Если DC уже задействован - сразу назначаем его канвасу
  if not FCanvas.HandleAllocated {$IFDEF FPC}and FCanvasChanged{$ENDIF} then
    FCanvas.Handle := FHandle;
  Result := FCanvas;
end;

function TACLDib.GetClientRect: TRect;
begin
  Result := Rect(0, 0, Width, Height);
end;

function TACLDib.GetEmpty: Boolean;
begin
  Result := FColorCount = 0;
end;

function TACLDib.GetSize: TSize;
begin
  Result := TSize.Create(Width, Height);
end;

{$IFDEF FPC}
procedure TACLDib.CopyCanvasToColors;
{$IFDEF LCLGtk2}
var
  LBuf: PGdkPixbuf;
  LDst: PACLPixel32;
  LSrc: PACLPixel32;
  LTmp: Byte;
  I: Integer;
begin
  LBuf := gdk_pixbuf_new(GDK_COLORSPACE_RGB, True, 8, Width, Height);
  try
    // gdk_pixbuf_get_from_drawable сбросит альфа-канал в 255.
    // Это задокументированное поведение.
    gdk_pixbuf_get_from_drawable(LBuf, TGtkDeviceContext(FHandle).Drawable, nil, 0, 0, 0, 0, Width, Height);
    // В общем случае виджеты gtk2 не поддерживают альфа-канал.
    // Поэтому пытаемся перенести альфу вручную
    LSrc := PACLPixel32(gdk_pixbuf_get_pixels(LBuf));
    LDst := PACLPixel32(FColors);
    for I := 1 to ColorCount do
    begin
      // Gtk2 использует модель RGBA, тогда как Windows, Cairo (ну и мы) - BGRA.
      // Посему конвертируем
      LTmp    := LSrc^.R;
      LSrc^.R := LSrc^.B;
      LSrc^.B := LTmp;
      // Если контент пикселя (не альфа) изменился - забираем его
      if PDWORD(LSrc)^ and TACLPixel32.EssenceMask <> PDWORD(LDst)^ and TACLPixel32.EssenceMask then
        // todo: попробовать восстановить альфу, исходя из фоного и результирующего цветов
        PDWORD(LDst)^ := PDWORD(LSrc)^;
      Inc(LDst);
      Inc(LSrc);
    end;
  finally
    gdk_pixbuf_unref(LBuf);
  end;
{$ELSE}
begin
{$ENDIF}
  FColorsChanged := False;
  FCanvasChanged := False;
end;

procedure TACLDib.CopyColorsToCanvas;
{$IFDEF LCLGtk2}
var
  LCairo: Pcairo_t;
  LImage: Pcairo_surface_t;
{$ENDIF}
begin
  FColorsChanged := False;
  FCanvasChanged := False;
{$IFDEF LCLGtk2}
  //gdk_draw_rgb_32_image(LCtx.Drawable, LCtx.GC,
  //  0, 0, Width, Height, GDK_RGB_DITHER_NONE,
  //  Pguchar(FColors), Width * SizeOf(TACLPixel32));

  LCairo := cairo_create_context(FHandle);
  LImage := cairo_create_surface(FColors, Width, Height);
  cairo_set_operator(LCairo, CAIRO_OPERATOR_SOURCE);
  cairo_set_source_surface(LCairo, LImage, 0, 0);
  cairo_rectangle(LCairo, 0, 0, Width, Height);
  cairo_fill(LCairo);
  cairo_destroy(LCairo);
  cairo_surface_destroy(LImage);
{$ENDIF}
end;

function TACLDib.GetColors: PACLPixel32Array;
begin
  if FCanvasChanged then
    CopyCanvasToColors;
  if FCanvas <> nil then
    FCanvas.Handle := 0;
  FColorsChanged := True;
  Result := FColors;
end;

function TACLDib.GetDC: HDC;
begin
  if FColorsChanged then
    CopyColorsToCanvas;
  FCanvasChanged := True;
  Result := FHandle;
end;
{$ENDIF}

procedure TACLDib.DrawBlend(ACanvas: TCanvas; const P: TPoint; AMode: TACLBlendMode; AAlpha: Byte);
var
  LDib: TACLDib;
begin
  if AMode = bmNormal then
    DrawBlend(ACanvas, P, AAlpha)
  else
  begin
    LDib := TACLDib.Create(Width, Height);
    try
      acBitBlt(LDib.Handle, ACanvas.Handle, LDib.ClientRect, P);
      BlendFunctions[AMode](LDib, Self, AAlpha);
      LDib.DrawCopy(ACanvas, P);
    finally
      LDib.Free;
    end;
  end;
end;

{ TACLDibCanvas }

constructor TACLDibCanvas.Create(AOwner: TACLDib);
begin
  FOwner := AOwner;
  inherited Create;
end;

procedure TACLDibCanvas.CreateHandle;
begin
  SetHandle(FOwner.Handle);
end;

{ TACLBitmap }

constructor TACLBitmap.CreateEx(const S: TSize;
  APixelFormat: TPixelFormat = pf32bit; AResetContent: Boolean = False);
begin
  CreateEx(S.cx, S.cy, APixelFormat, AResetContent);
end;

constructor TACLBitmap.CreateEx(const R: TRect;
  APixelFormat: TPixelFormat = pf32bit; AResetContent: Boolean = False);
begin
  CreateEx(R.Right - R.Left, R.Bottom - R.Top, APixelFormat, AResetContent);
end;

constructor TACLBitmap.CreateEx(W, H: Integer;
  APixelFormat: TPixelFormat = pf32bit; AResetContent: Boolean = False);
begin
  Create;
  PixelFormat := APixelFormat;
  SetSize(W, H);
  if AResetContent then
    Reset;
end;

function TACLBitmap.GetClientRect: TRect;
begin
  Result := Rect(0, 0, Width, Height);
end;

procedure TACLBitmap.LoadFromResource(Inst: HINST; const AName, AType: string);
var
  AStream: TStream;
begin
  AStream := TResourceStream.Create(Inst, AName, PChar(AType));
  try
    LoadFromStream(AStream);
  finally
    AStream.Free;
  end;
end;

procedure TACLBitmap.LoadFromStream(Stream: TStream);
{$IFNDEF FPC}
var
  AHack: TBitmapImageAccess;
{$ENDIF}
begin
  inherited LoadFromStream(Stream);
{$IFNDEF FPC}
  if not Empty then
  begin
    //#AI: Workaround for bitmap that created via old version of delphies
    AHack := TBitmapImageAccess(TBitmapAccess(Self).FImage);
    if (AHack <> nil) and (AHack.FDIB.dsBmih.biBitCount > 16) then
      AHack.FDIB.dsBmih.biClrUsed := 0;
  end;
{$ENDIF}
end;

procedure TACLBitmap.ApplyColorSchema(const AValue: TACLColorSchema);
var
  ABits: TACLPixel32DynArray;
begin
  if AValue.IsAssigned then
  begin
    ABits := acGetBitmapBits(Self);
    try
      TACLColors.ApplyColorSchema(@ABits[0], Length(ABits), AValue);
    finally
      acSetBitmapBits(Self, ABits);
    end;
  end;
end;

procedure TACLBitmap.MakeOpaque;
var
  ABits: TACLPixel32DynArray;
  I: Integer;
begin
  ABits := acGetBitmapBits(Self);
  try
    for I := 0 to Length(ABits) - 1 do
      ABits[I].A := MaxByte;
  finally
    acSetBitmapBits(Self, ABits);
  end;
end;

procedure TACLBitmap.MakeTransparent(AColor: TColor);
var
  ABits: TACLPixel32DynArray;
begin
  if not Empty then
  begin
    ABits := acGetBitmapBits(Self);
    try
      TACLColors.MakeTransparent(@ABits[0], Length(ABits), TACLPixel32.Create(AColor));
    finally
      PixelFormat := pf32bit;
      acSetBitmapBits(Self, ABits);
    end;
  end;
end;

procedure TACLBitmap.Reset;
begin
  acResetRect(Canvas.Handle, ClientRect);
end;

procedure TACLBitmap.SetSize(const R: TRect);
begin
  SetSize(Max(0, R.Width), Max(0, R.Height));
end;

{$IFDEF FPC}
function TACLBitmap._AddRef;
begin
  Result := -1;
end;

function TACLBitmap._Release;
begin
  Result := -1;
end;

function TACLBitmap.QueryInterface;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;;
end;
{$ENDIF}

{ TACLColors }

class constructor TACLColors.Create;
var
  I, J: Integer;
begin
  for I := 1 to 255 do
    for J := I to 255 do
    begin
      PremultiplyTable[I, J] := MulDiv(I, J, 255);
      PremultiplyTable[J, I] := PremultiplyTable[I, J];

      UnpremultiplyTable[I, J] := MulDiv(I, 255, J);
      UnpremultiplyTable[J, I] := UnpremultiplyTable[I, J];
    end;
end;

class function TACLColors.CompareRGB(const Q1, Q2: TACLPixel32): Boolean;
begin
  Result := (Q1.B = Q2.B) and (Q1.G = Q2.G) and (Q1.R = Q2.R);
end;

class function TACLColors.IsDark(Color: TColor): Boolean;
begin
  Result := Lightness(Color) < 0.45;
end;

class function TACLColors.IsMask(const P: TACLPixel32): Boolean;
begin
  Result := (P.G = MaskPixel.G) and (P.B = MaskPixel.B) and (P.R = MaskPixel.R);
end;

class procedure TACLColors.AlphaBlend(var D: TColor; S: TColor; AAlpha: Byte = 255);
var
  DQ: TACLPixel32;
begin
  DQ := TACLPixel32.Create(D);
  AlphaBlend(DQ, TACLPixel32.Create(S), AAlpha);
  D := DQ.ToColor;
end;

class procedure TACLColors.AlphaBlend(
  var D: TACLPixel32; const S: TACLPixel32; AAlpha: Byte = 255);
var
  LTargetAlpha: Byte;
begin
  if (AAlpha < MaxByte) or (S.A < MaxByte) then
  begin
    LTargetAlpha := MaxByte - PremultiplyTable[S.A, AAlpha];
    D.R := PremultiplyTable[D.R, LTargetAlpha] + PremultiplyTable[S.R, AAlpha];
    D.B := PremultiplyTable[D.B, LTargetAlpha] + PremultiplyTable[S.B, AAlpha];
    D.G := PremultiplyTable[D.G, LTargetAlpha] + PremultiplyTable[S.G, AAlpha];
    D.A := PremultiplyTable[D.A, LTargetAlpha] + PremultiplyTable[S.A, AAlpha];
  end
  else
    TAlphaColor(D) := TAlphaColor(S);
end;

class procedure TACLColors.ApplyColorSchema(var AColor: TColor; const AValue: TACLColorSchema);
var
  P: TACLPixel32;
begin
  if AValue.IsAssigned then
  begin
    P := TACLPixel32.Create(AColor);
    ApplyColorSchema(P, AValue);
    AColor := P.ToColor;
  end;
end;

class procedure TACLColors.ApplyColorSchema(
  AColors: PACLPixel32; ACount: Integer; const AValue: TACLColorSchema);
begin
  if AValue.IsAssigned then
    ChangeHue(AColors, ACount, AValue.Hue, AValue.HueIntensity);
end;

class procedure TACLColors.ApplyColorSchema(const AFont: TFont; const AValue: TACLColorSchema);
var
  AColor: TColor;
begin
  if AValue.IsAssigned then
  begin
    AColor := AFont.Color;
    ApplyColorSchema(AColor, AValue);
    AFont.Color := AColor;
  end;
end;

class procedure TACLColors.ApplyColorSchema(var AColor: TAlphaColor; const AValue: TACLColorSchema);
var
  P: TACLPixel32;
begin
  if AColor.IsValid and AValue.IsAssigned then
  begin
    P := TACLPixel32.Create(AColor);
    ApplyColorSchema(P, AValue);
    AColor := TAlphaColor.FromColor(P);
  end;
end;

class procedure TACLColors.ApplyColorSchema(
  var AColor: TACLPixel32; const AValue: TACLColorSchema);
begin
  if AValue.IsAssigned then
    ChangeHue(AColor, AValue.Hue, AValue.HueIntensity);
end;

//#AI: https://github.com/chromium/chromium/blob/master/ui/base/clipboard/clipboard_win.cc#L652
class function TACLColors.ArePremultiplied(AColors: PACLPixel32; ACount: Integer): Boolean;
begin
  while ACount > 0 do
  begin
    with AColors^ do
    begin
      if R > A then Exit(False);
      if G > A then Exit(False);
      if B > A then Exit(False);
    end;
    Inc(AColors);
    Dec(ACount);
  end;
  Result := True;
end;

class procedure TACLColors.ChangeColor(P: PACLPixel32; ACount: Integer; const AColor: TACLPixel32);
var
  Cmax, Cmin: Integer;
  H, S, L: Byte;
begin
  RGBtoHSLi(AColor.R, AColor.G, AColor.B, H, S, L);
  while ACount > 0 do
  begin
    if not IsMask(P^) then
    begin
      Cmax := Max(P^.R, Max(P^.G, P^.B));
      Cmin := Min(P^.R, Min(P^.G, P^.B));
      HSLtoRGBi(H, S, MulDiv(MaxByte, Cmax + Cmin, 2 * MaxByte), P^.R, P^.G, P^.B);
    end;
    Dec(ACount);
    Inc(P);
  end;
end;

class procedure TACLColors.ChangeHue(var P: TACLPixel32; AHue: Byte; AIntensity: Byte = 100);
var
  H, S, L: Byte;
begin
  if not IsMask(P) then
  begin
    TACLColors.RGBtoHSLi(P.R, P.G, P.B, H, S, L);
    TACLColors.HSLtoRGBi(AHue, MulDiv(S, AIntensity, 100), L, P.R, P.G, P.B);
  end;
end;

class procedure TACLColors.ChangeHue(P: PACLPixel32; ACount: Integer; AHue: Byte; AIntensity: Byte = 100);
begin
  while ACount > 0 do
  begin
    ChangeHue(P^, AHue, AIntensity);
    Dec(ACount);
    Inc(P);
  end;
end;

class procedure TACLColors.Flip(AColors: PACLPixel32Array;
  AWidth, AHeight: Integer; AHorizontally, AVertically: Boolean);
var
  I: Integer;
  Q1, Q2, Q3: PACLPixel32;
  Q4: TACLPixel32;
  RS: Integer;
begin
  if AVertically then
  begin
    Q1 := @AColors^[0];
    Q2 := @AColors^[(AHeight - 1) * AWidth];
    RS := AWidth * SizeOf(TACLPixel32);
    Q3 := AllocMem(RS);
    try
      while Q1 < Q2 do
      begin
        FastMove(Q2^, Q3^, RS);
        FastMove(Q1^, Q2^, RS);
        FastMove(Q3^, Q1^, RS);
        Inc(Q1, AWidth);
        Dec(Q2, AWidth);
      end;
    finally
      FreeMem(Q3, RS);
    end;
  end;

  if AHorizontally then
    for I := 0 to AHeight - 1 do
    begin
      Q1 := @AColors^[I * AWidth];
      Q2 := @AColors^[I * AWidth + AWidth - 1];
      while Q1 < Q2 do
      begin
        Q4  := Q2^;
        Q2^ := Q1^;
        Q1^ := Q4;
        Inc(Q1);
        Dec(Q2);
      end;
    end;
end;

class procedure TACLColors.Flush(var P: TACLPixel32);
begin
  PCardinal(@P)^ := 0;
end;

class procedure TACLColors.Grayscale(P: PACLPixel32; Count: Integer);
begin
  while Count > 0 do
  begin
    Grayscale(P^);
    Dec(Count);
    Inc(P);
  end;
end;

class procedure TACLColors.Grayscale(var P: TACLPixel32);
begin
  P.B := PremultiplyTable[P.B, 77] + PremultiplyTable[P.G, 150] + PremultiplyTable[P.R, 28];
  P.G := P.B;
  P.R := P.B;
end;

class function TACLColors.Lightness(Color: TColor): Single;
var
  H, S: Single;
begin
  TACLColors.RGBtoHSL(Color, H, S, Result);
end;

class procedure TACLColors.MakeDisabled(P: PACLPixel32; Count: Integer; IgnoreMask: Boolean = False);
begin
  while Count > 0 do
  begin
    MakeDisabled(P^, IgnoreMask);
    Dec(Count);
    Inc(P);
  end;
end;

class procedure TACLColors.MakeDisabled(var P: TACLPixel32; IgnoreMask: Boolean = False);
var
  APixel: Byte;
begin
  if (P.A > 0) and (IgnoreMask or not IsMask(P)) then
  begin
    Unpremultiply(P);
    P.A := PremultiplyTable[P.A, 128];
    APixel := PremultiplyTable[P.B, 77] + PremultiplyTable[P.G, 150] + PremultiplyTable[P.R, 28];
    APixel := PremultiplyTable[APixel, P.A];
    P.B := APixel;
    P.G := APixel;
    P.R := APixel;
  end;
end;

class procedure TACLColors.MakeOpaque(P: PACLPixel32; Count: Integer);
begin
  while Count > 0 do
  begin
    P^.A := MaxByte;
    Dec(Count);
    Inc(P);
  end;
end;

class procedure TACLColors.MakeTransparent(P: PACLPixel32; ACount: Integer; const AColor: TACLPixel32);
begin
  while ACount > 0 do
  begin
    if CompareRGB(P^, AColor) then
      PDWORD(P)^ := 0
    else
      P^.A := MaxByte;
    Dec(ACount);
    Inc(P);
  end;
end;

class procedure TACLColors.Mix(var D: TACLPixel32; const S: TACLPixel32; AAlpha: Byte);
var
  LAlpha: Byte;
begin
  LAlpha := MaxByte - AAlpha;
  D.R := PremultiplyTable[D.R, LAlpha] + PremultiplyTable[S.R, AAlpha];
  D.B := PremultiplyTable[D.B, LAlpha] + PremultiplyTable[S.B, AAlpha];
  D.G := PremultiplyTable[D.G, LAlpha] + PremultiplyTable[S.G, AAlpha];
  D.A := PremultiplyTable[D.A, LAlpha] + PremultiplyTable[S.A, AAlpha];
end;

class procedure TACLColors.Tint(P: PACLPixel32; ACount: Integer; const ATintColor: TACLPixel32);
var
  AAlpha: Byte;
begin
  if ATintColor.A = 0 then
    Exit;
  if ATintColor.A = MaxByte then
  begin
    while ACount > 0 do
    begin
      P.B := ATintColor.B;
      P.G := ATintColor.G;
      P.R := ATintColor.R;
      Dec(ACount);
      Inc(P);
    end;
  end
  else
  begin
    AAlpha := MaxByte - ATintColor.A;
    while ACount > 0 do
    begin
      P.B := PremultiplyTable[P.B, AAlpha] + PremultiplyTable[ATintColor.B, ATintColor.A];
      P.G := PremultiplyTable[P.G, AAlpha] + PremultiplyTable[ATintColor.G, ATintColor.A];
      P.R := PremultiplyTable[P.R, AAlpha] + PremultiplyTable[ATintColor.R, ATintColor.A];
      Dec(ACount);
      Inc(P);
    end;
  end;
end;

class procedure TACLColors.BGRAtoRGBA(P: PACLPixel32; ACount: Integer);
var
  Tmp: Byte;
begin
  while ACount > 0 do
  begin
    Tmp := P.B;
    P.B := P.R;
    P.R := Tmp;
    Dec(ACount);
    Inc(P);
  end;
end;

class procedure TACLColors.Premultiply(var P: TACLPixel32);
begin
  if P.A = 0 then
    DWORD(P) := 0
  else
    if P.A < 255 then
    begin
      P.R := PremultiplyTable[P.R, P.A];
      P.B := PremultiplyTable[P.B, P.A];
      P.G := PremultiplyTable[P.G, P.A];
    end;
end;

class procedure TACLColors.Premultiply(P: PACLPixel32; ACount: Integer);
begin
  while ACount > 0 do
  begin
    Premultiply(P^);
    Dec(ACount);
    Inc(P);
  end;
end;

class procedure TACLColors.Unpremultiply(var P: TACLPixel32);
begin
  if (P.A > 0) and (P.A < MaxByte) then
  begin
    P.G := UnpremultiplyTable[P.G, P.A];
    P.B := UnpremultiplyTable[P.B, P.A];
    P.R := UnpremultiplyTable[P.R, P.A];
  end;
end;

class procedure TACLColors.Unpremultiply(P: PACLPixel32; ACount: Integer);
begin
  while ACount > 0 do
  begin
    Unpremultiply(P^);
    Dec(ACount);
    Inc(P);
  end;
end;

class procedure TACLColors.HSLtoRGB(H, S, L: Single; out R, G, B: Byte);

  function HueToColor(M1, M2, Hue: Single): Byte;
  var
    V, AHue6: Double;
  begin
    Hue := Hue - Floor(Hue);
    AHue6 := 6 * Hue;
    if AHue6 < 1 then
      V := M1 + (M2 - M1) * AHue6
    else if AHue6 < 3 then // 2 * Hue < 1
      V := M2
    else if AHue6 < 4 then // 3 * Hue < 2
      V := M1 + (M2 - M1) * (4 - AHue6)
    else
      V := M1;

    Result := Round(255 * V);
  end;

var
  M1, M2: Single;
begin
  if S = 0 then
  begin
    R := Round(255 * L);
    G := R;
    B := R;
  end
  else
  begin
    if L <= 0.5 then
      M2 := L * (1 + S)
    else
      M2 := L + S - L * S;

    M1 := 2 * L - M2;
    R := HueToColor(M1, M2, H + 1 / 3);
    G := HueToColor(M1, M2, H);
    B := HueToColor(M1, M2, H - 1 / 3)
  end;
end;

class procedure TACLColors.HSLtoRGBi(H, S, L: Byte; out AColor: TColor);
var
  R, G, B: Byte;
begin
  HSLtoRGBi(H, S, L, R, G, B);
  AColor := RGB(R, G, B);
end;

class procedure TACLColors.HSLtoRGBi(H, S, L: Byte; out R, G, B: Byte);
const
  PartOfSix = MaxByte div 6;
  PartOfTwo = MaxByte div 2;
  PartOfTwoThirds = 2 * MaxByte div 3;

  function HueToColor(M1, M2, Hue: Integer): Byte;
  begin
    if Hue < 0 then
      Inc(Hue, MaxByte);
    if Hue > MaxByte then
      Dec(Hue, MaxByte);

    if Hue < PartOfSix then
      Result := Min(M1 + ((M2 - M1) * Hue) div PartOfSix, MaxByte)
    else if Hue < PartOfTwo then
      Result := Min(M2, MaxByte)
    else if Hue < PartOfTwoThirds then
      Result := Min(M1 + ((M2 - M1) * (4 * MaxByte - 6 * Hue)) div MaxByte, MaxByte)
    else
      Result := Min(M1, MaxByte);
  end;

var
  M1: Integer;
  M2: Integer;
begin
  if S = 0 then
  begin
    R := L;
    G := L;
    B := L;
  end
  else
  begin
    if L <= 128 then
      M2 := L * (MaxByte + S) div MaxByte
    else
      M2 := L + S - PremultiplyTable[L, S];

    M1 := 2 * L - M2;
    R := HueToColor(M1, M2, H + 85);
    G := HueToColor(M1, M2, H);
    B := HueToColor(M1, M2, H - 85)
  end;
end;

class function TACLColors.HSLtoRGB(H, S, L: Single): TColor;
begin
  HSLtoRGB(H, S, L, Result);
end;

class procedure TACLColors.HSLtoRGB(H, S, L: Single; out AColor: TColor);
var
  R, G, B: Byte;
begin
  HSLtoRGB(H, S, L, R, G, B);
  AColor := RGB(R, G, B);
end;

class procedure TACLColors.RGBtoHSL(AColor: TColor; out H, S, L: Single);
begin
  AColor := ColorToRGB(AColor);
  RGBtoHSL(GetRValue(AColor), GetGValue(AColor), GetBValue(AColor), H, S, L);
end;

class procedure TACLColors.RGBtoHSL(R, G, B: Byte; out H, S, L: Single);
var
  ADelta, Cmax, Cmin: Integer;
begin
  Cmax := Max(R, Max(G, B));
  Cmin := Min(R, Min(G, B));
  L := (Cmax + Cmin) / (2 * MaxByte);
  H := 0;
  S := 0;

  ADelta := Cmax - Cmin;
  if ADelta <> 0 then
  begin
    if L < 0.5 then
      S := ADelta / (Cmax + Cmin)
    else
      S := ADelta / (2 * MaxByte - Cmax - Cmin);

    if R = Cmax then
      H := (G - B) / ADelta
    else if G = Cmax then
      H := 2 + (B - R) / ADelta
    else
      H := 4 + (R - G) / ADelta;

    H := H / 6;
    if H < 0 then
      H := H + 1
  end;
end;

class procedure TACLColors.RGBtoHSLi(AColor: TColor; out H, S, L: Byte);
begin
  AColor := ColorToRGB(AColor);
  RGBtoHSLi(GetRValue(AColor), GetGValue(AColor), GetBValue(AColor), H, S, L);
end;

class procedure TACLColors.RGBtoHSLi(R, G, B: Byte; out H, S, L: Byte);
var
  AHue, ADelta, Cmax, Cmin: Integer;
begin
  Cmax := Max(R, Max(G, B));
  Cmin := Min(R, Min(G, B));
  L := MulDiv(MaxByte, Cmax + Cmin, 2 * MaxByte);
  H := 0;
  S := 0;

  ADelta := Cmax - Cmin;
  if ADelta <> 0 then
  begin
    if L < 128 then
      S := MulDiv(MaxByte, ADelta, Cmax + Cmin)
    else
      S := MulDiv(MaxByte, ADelta, 2 * MaxByte - Cmax - Cmin);

    if R = Cmax then
      AHue := MulDiv(MaxByte, G - B, ADelta)
    else if G = Cmax then
      AHue := 2 * MaxByte + MulDiv(MaxByte, B - R, ADelta)
    else
      AHue := 4 * MaxByte + MulDiv(MaxByte, R - G, ADelta);

    AHue := AHue div 6;
    if AHue < 0 then
      Inc(AHue, MaxByte);
    H := AHue;
  end;
end;

class function TACLColors.HSVtoRGB(H, S, V: Single): TColor;
var
  R, G, B: Byte;
begin
  HSVtoRGB(H, S, V, R, G, B);
  Result := RGB(R, G, B);
end;

class procedure TACLColors.HSVtoRGB(H, S, V: Single; out AColor: TColor);
begin
  AColor := HSVtoRGB(H, S, V);
end;

class procedure TACLColors.HSVtoRGB(H, S, V: Single; out R, G, B: Byte);

  procedure SetResult(RS, GS, BS: Single);
  begin
    R := Round(RS);
    G := Round(GS);
    B := Round(BS);
  end;

var
  AFrac: Single;
  AMax: Single;
  AMid1: Single;
  AMid2: Single;
  AMin: Single;
  ASector: Byte;
begin
  AMax := V * 255;
  AMin := AMax * (1 - S);
  ASector := Trunc(H / 60) mod 6;
  AFrac := H / 60 - ASector;
  AMid1 := AMax * (1 - AFrac * S);
  AMid2 := AMax * (1 - (1 - AFrac) * S);
  case ASector of
    0: SetResult(AMax, AMid2, AMin);
    1: SetResult(AMid1, AMax, AMin);
    2: SetResult(AMin, AMax, AMid2);
    3: SetResult(AMin, AMid1, AMax);
    4: SetResult(AMid2, AMin, AMax);
  else // 5
    SetResult(AMax, AMin, AMid1);
  end;
end;

class function TACLColors.Hue(Color: TColor): Single;
var
  S, L: Single;
begin
  RGBToHSL(Color, Result, S, L);
end;

class procedure TACLColors.RGBtoHSV(R, G, B: Byte; out H, S, V: Single);
var
  AMax, AMin: Byte;
begin
  AMax := Max(Max(B, G), R);
  AMin := Min(Min(B, G), R);

  V := AMax / 255;
  if V = 0 then
    S := 0
  else
    S := 1 - AMin / AMax;

  if AMax = AMin then
    H := 0
  else if AMax = R then
    H := 60 * (G - B) / (AMax - AMin) + 0
  else if AMax = G then
    H := 60 * (B - R) / (AMax - AMin) + 120
  else if AMax = B then
    H := 60 * (R - G) / (AMax - AMin) + 240
  else
    H := 0;

  if H < 0 then
    H := H + 360;
end;

class procedure TACLColors.RGBtoHSV(AColor: TColor; out H, S, V: Single);
begin
  AColor := ColorToRGB(AColor);
  RGBtoHSV(GetRValue(AColor), GetGValue(AColor), GetBValue(AColor), H, S, V);
end;

{ TACLRegionManager }

class destructor TACLRegionManager.Finalize;
var
  I: Integer;
begin
  for I := 0 to CacheSize - 1 do
    DeleteObject(Cache[I]);
end;

class function TACLRegionManager.Get: TRegionHandle;
var
  AIndex: Integer;
begin
  Result := 0;
  AIndex := 0;
  while (Result = 0) and (AIndex < CacheSize) do
  begin
    Result := AtomicExchange(Cache[AIndex], 0);
    Inc(AIndex);
  end;
  if Result = 0 then
    Result := CreateRectRgn(0, 0, 0, 0);
end;

class procedure TACLRegionManager.Release(var ARegion: TRegionHandle);
var
  AIndex: Integer;
begin
  AIndex := 0;
  while (ARegion <> 0) and (AIndex < CacheSize) do
  begin
    ARegion := AtomicExchange(Cache[AIndex], ARegion);
    Inc(AIndex);
  end;
  DeleteObject(ARegion)
end;

initialization
{$IFDEF FPC}
  if not Assigned(FindIntToIdent(TypeInfo(TAlphaColor))) then
    RegisterIntegerConsts(TypeInfo(TAlphaColor), @IdentToAlphaColor, @AlphaColorToIdent);
{$ENDIF}
{$IFDEF ACL_CAIRO_TEXTOUT}
  DefaultTextLayoutCanvasRender := TACLTextLayoutCairoRender;
{$ENDIF}
{$IF DEFINED(ACL_CAIRO_RENDER)}
  ExPainter := TACLCairoRender.Create;
{$ELSEIF DEFINED(MSWINDOWS)}
  ExPainter := TACLGdiplusPaintCanvas.Create;
{$ENDIF}

finalization
  FreeAndNil(FMeasureCanvas);
  FreeAndNil(FScreenCanvas);
end.
