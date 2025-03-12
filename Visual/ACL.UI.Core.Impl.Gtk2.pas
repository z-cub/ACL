////////////////////////////////////////////////////////////////////////////////
//
//  Project:   Artem's Controls Library aka ACL
//             v6.0
//
//  Purpose:   Gtk2 Adapters and Helpers
//
//  Author:    Artem Izmaylov
//             © 2006-2025
//             www.aimp.ru
//
//  FPC:       OK
//
unit ACL.UI.Core.Impl.Gtk2;

{$I ACL.Config.inc}

{$SCOPEDENUMS ON}

{.$DEFINE DEBUG_MESSAGELOOP}

interface

uses
  LCLIntf,
  LCLType,
  LMessages,
  Messages,
  // Gtk
  Cairo,
  Gtk2,
  Glib2,
  Gdk2,
  Gdk2pixbuf,
  Gtk2Int,
  Gtk2Proc,
  Gtk2Def,
  Gtk2Extra,
  Gtk2Globals,
  Gtk2WSControls,
  Gtk2WSForms,
  Gtk2WSStdCtrls,
  WSLCLClasses,
  // System
  Classes,
  Generics.Collections,
  Math,
  System.UITypes,
  SysUtils,
  Types,
  // ACL
  ACL.Graphics,
  ACL.Utils.Common,
  // VCL
  Graphics,
  Controls,
  Forms;

const
  WS_EX_LAYERED    = $0080000;
  WS_EX_NOACTIVATE = $8000000;

const
  HTNOWHERE     = 0;
  HTCLIENT      = 1;
  HTCAPTION     = 2;
  HTSYSMENU     = 3;
  HTMINBUTTON   = 8;
  HTMAXBUTTON   = 9;
  HTLEFT        = 10;
  HTRIGHT       = 11;
  HTTOP         = 12;
  HTTOPLEFT     = 13;
  HTTOPRIGHT    = 14;
  HTBOTTOM      = 15;
  HTBOTTOMLEFT  = 16;
  HTBOTTOMRIGHT = 17;
  HTCLOSE       = 20;

type
  TGtk2EventCallback = procedure (AEvent: PGdkEvent; var AHandled: Boolean) of object;

  { IACLLayeredPaint }

  IACLLayeredPaint = interface
  ['{3FE006F2-67DE-4317-B402-D872A77373E4}']
    procedure PaintTo(ACairo: Pcairo_t);
  end;

  { TGtk2App }

  TGtk2App = class
  strict private
    class var FHandlerInit: Boolean;
    class var FHooks: TStack<TGtk2EventCallback>;
    class var FInputTarget: PGtkWidget;
    class var FOldExceptionHandler: TExceptionEvent;
    class var FPopupControl: TWinControl;
    class var FPopupError: string;
    class var FPopupWindow: PGdkWindow;

    class procedure Handler(event: PGdkEvent; data: gpointer); cdecl; static;
    class procedure HandlerException(Sender: TObject; Error: Exception);
    class procedure HandlerInit;
    class procedure HandlerOnDestroy(data: gpointer); cdecl; static;
    class procedure PopupEventHandler(AEvent: PGdkEvent; var AHandled: Boolean);
  public
    class constructor Create;
    class destructor Destroy;
    class procedure Hook(ACallback: TGtk2EventCallback);
    class procedure Unhook;

    class procedure BeginPopup(APopupControl: TWinControl); overload;
    class procedure BeginPopup(APopupControl: TWinControl; ACallback: TGtk2EventCallback); overload;
    class procedure EndPopup;
    class function IsPopupAborted: Boolean;

    class procedure ProcessMessages;
    class procedure SetInputRedirection(AControl: TWinControl);
  end;

  { TGtk2Controls }

  TGtk2Controls = class
  strict private type
    TDragState = (None, Started, Canceled);
  strict private
    class var FDragState: TDragState;
    class var FDragTarget: TRect;

    class procedure DoDragEvents(AEvent: PGdkEvent; var AHandled: Boolean);
    class function DoDrawNonClientBorder(Widget: PGtkWidget;
      Event: PGDKEventExpose; Data: gPointer): GBoolean; cdecl; static;
  public
    class function CheckStartDrag(AControl: TWinControl; X, Y, AThreshold: Integer): Boolean;
    class procedure SetNonClientBorder(AControl: TWinControl; ASize: Integer);
  end;

  { TACLGtk2PopupControl }

  TACLGtk2PopupControl = class(TGtk2WSWinControl)
  protected
    class function MustBeFocusable(AControl: TWinControl): Boolean; virtual;
  published
    class function CreateHandle(const AWinControl: TWinControl;
      const AParams: TCreateParams): TLCLHandle; override;
    class procedure SetBounds(const AWinControl: TWinControl;
      const ALeft, ATop, AWidth, AHeight: Integer); override;
  end;

  { TACLGtk2WSEdit }

  TACLGtk2WSEdit = class(TGtk2WSCustomEdit)
  published
    class procedure SetColor(const AWinControl: TWinControl); override;
  end;

  { TACLGtk2WSMemo }

  TACLGtk2WSMemo = class(TGtk2WSCustomMemo)
  published
    class procedure SetColor(const AWinControl: TWinControl); override;
  end;

  { TACLGtk2WSAdvancedForm }

  TACLGtk2WSAdvancedForm = class(TGtk2WSCustomForm)
  strict private
    class function DoExposeEvent(Widget: PGtkWidget;
      Event: PGDKEventExpose; Data: gPointer): GBoolean; cdecl; static;
    class function DoRealize(Widget: PGtkWidget; Data: Pointer): GBoolean; cdecl; static;
  published
    class function CreateHandle(const AWinControl: TWinControl;
      const AParams: TCreateParams): TLCLHandle; override;
    class procedure SetCallbacks(const AWidget: PGtkWidget;
      const AWidgetInfo: PWidgetInfo); override;
    class procedure SetColor(const AWinControl: TWinControl); override;
    class procedure SetFormBorderStyle(const AForm: TCustomForm;
      const AFormBorderStyle: TFormBorderStyle); override;
    class procedure SetWindowCapabities(AForm: TCustomForm; AWidget: PGtkWidget);
    class procedure ShowHide(const AWinControl: TWinControl); override;
  end;

function CheckStartDragImpl(AControl: TWinControl; X, Y, AThreshold: Integer): Boolean;
function GdkLoadStockIcon(AWidget: PGtkWidget; AName: PChar; ASize: Integer): TACLDib;
procedure Gtk2StartDrag(AForm: TCustomForm; const AScreenPoint: TPoint; AHitCode: Integer);

function LoadDialogIcon(AOwnerWnd: TWndHandle; AType: TMsgDlgType; ASize: Integer): TACLDib;
implementation

uses
  ACL.Geometry,
  ACL.Geometry.Utils;

type
  TFormAccess = class(TForm);
  TGtk2WidgetSetAccess = class(TGtk2WidgetSet);

//procedure BringWindowOverTheOwner(AWnd: HWND);
//var
//  LWidget: PGtkWidget absolute AWnd;
//  LWindow: PGdkWindow;
//begin
//  if GtkWidgetIsA(LWidget, GTK_TYPE_WINDOW) then
//  begin
//    LWindow := GetControlWindow(LWidget);
//    if (LWindow <> nil) and gdk_window_is_visible(LWindow) then
//      gdk_window_raise(LWindow);
//  end;
//end;

//procedure gdk_window_show_window_menu(window: PGdkWindow; event: PGdkEvent);
//const
//  SubstructureNotifyMask   = 1 shl 19;
//  SubstructureRedirectMask = 1 shl 20;
//var
//  deviceId: Integer;
//  display: PGdkDisplay;
//  x, y: gdouble;
//  xclient: TXClientMessageEvent;
//begin
//  case event^._type of
//    GDK_BUTTON_PRESS, GDK_BUTTON_RELEASE:;
//  else
//    Exit;
//  end;
//
//  gdk_event_get_root_coords(event, @x, @y);
//
//  display := gdk_drawable_get_display(window);
//  deviceId := 0;
//  g_object_get(event^.button.device, 'device-id', @deviceId, nil);
//
//  GDK_WINDOW_IMPL_X11(window);
//
//  FillChar(xclient, sizeOf(xclient), 0);
//  xclient._type := 33;//ClientMessage = 33;
//  xclient.window := GDK_WINDOW_XID (window);
//  xclient.message_type := gdk_x11_get_xatom_by_name_for_display(display, '_GTK_SHOW_WINDOW_MENU');
//  xclient.data.l[0] := deviceId;
//  xclient.data.l[1] := 0;
//  xclient.data.l[2] := 0;
//  //xclient.data.l[0] := device_id;
//  //xclient.data.l[1] := x_root * impl->window_scale;
//  //xclient.data.l[2] := y_root * impl->window_scale;
//  xclient.format := 32;
//
//  XSendEvent(GDK_DISPLAY_XDISPLAY(display), GDK_WINDOW_XROOTWIN (window),
//    False, SubstructureRedirectMask or SubstructureNotifyMask, @xclient);
//end;

procedure Gtk2StartDrag(AForm: TCustomForm; const AScreenPoint: TPoint; AHitCode: Integer);
const
  BorderMap: array[HTLEFT..HTBOTTOMRIGHT] of TGdkWindowEdge = (
    GDK_WINDOW_EDGE_WEST, GDK_WINDOW_EDGE_EAST,
    GDK_WINDOW_EDGE_NORTH, GDK_WINDOW_EDGE_NORTH_WEST, GDK_WINDOW_EDGE_NORTH_EAST,
    GDK_WINDOW_EDGE_SOUTH, GDK_WINDOW_EDGE_SOUTH_WEST, GDK_WINDOW_EDGE_SOUTH_EAST
  );
var
  LXPos, LYPos: gint;
  LWindow: PGtkWindow;
begin
  TFormAccess(AForm).MouseCapture := False;
  LWindow := PGtkWindow(AForm.Handle);
  LastMouse.Down := False;
  case AHitCode of
    HTLEFT..HTBOTTOMRIGHT:
      gtk_window_begin_resize_drag(LWindow, BorderMap[AHitCode], 1,
        AScreenPoint.X, AScreenPoint.Y, GDK_CURRENT_TIME);
  else
    begin
      LXPos := 0; LYPos := 0;
      gdk_window_get_origin(GetControlWindow(LWindow), @LXPos, @LYPos);
      gtk_widget_set_uposition(PGtkWidget(LWindow), LXPos, LYPos);
      gtk_window_begin_move_drag(LWindow, 1, AScreenPoint.X, AScreenPoint.Y, GDK_CURRENT_TIME);
    end;
  end;
end;

function CheckStartDragImpl(AControl: TWinControl; X, Y, AThreshold: Integer): Boolean;
begin
  Result := TGtk2Controls.CheckStartDrag(AControl, X, Y, AThreshold);
end;

function IsChild(AChild, AParent: PGtkWidget): Boolean;
begin
  while AChild <> nil do
  begin
    if AChild = AParent then
      Exit(True);
    AChild := AChild.parent;
  end;
  Result := False;
end;

function LoadDialogIcon(AOwnerWnd: TWndHandle; AType: TMsgDlgType; ASize: Integer): TACLDib;
const
  Map: array[TMsgDlgType] of PChar = (
    'gtk-dialog-warning', 'gtk-dialog-error', 'gtk-dialog-info', 'gtk-dialog-question', ''
  );
begin
  Result := GdkLoadStockIcon(Pointer(AOwnerWnd), Map[AType], ASize);
end;

function GdkLoadStockIcon(AWidget: PGtkWidget; AName: PChar; ASize: Integer): TACLDib;
var
  LBestScore: Integer;
  LBestSize: TGtkIconSize;
  LBuffer: PGdkPixbuf;
  LIconSet: PGtkIconSet;
  LScore: Integer;
  LSizes: PGtkIconSize;
  LSizesCount: Integer;
  LHeight: Integer;
  LWidth: Integer;
  I: Integer;
begin
  Result := nil;

  LIconSet := gtk_icon_factory_lookup_default(AName);
  if LIconSet = nil then
    Exit;

  LBestScore := MaxInt;
  LBestSize := GTK_ICON_SIZE_INVALID;
  gtk_icon_set_get_sizes(LIconSet, @LSizes, @LSizesCount);
  try
    for I := 0 to LSizesCount - 1 do
    begin
      gtk_icon_size_lookup(LSizes[I], @LWidth, @LHeight);
      LScore := Max(Abs(LWidth - ASize), Abs(LHeight - ASize));
      if (LBestSize = GTK_ICON_SIZE_INVALID) or (LScore < LBestScore) then
      begin
        LBestSize := LSizes[I];
        LBestScore := LScore;
      end;
    end;
  finally
    g_free(LSizes);
  end;

  if LBestSize <> GTK_ICON_SIZE_INVALID then
  begin
    LBuffer := gtk_widget_render_icon(AWidget, AName, LBestSize, nil);
    if LBuffer <> nil then
    try
      Result := TACLDib.Create;
      Result.Assign(LBuffer);
    finally
      gdk_pixbuf_unref(LBuffer);
    end;
  end;
end;

function WidgetSet: TGtk2WidgetSetAccess;
begin
  Result := TGtk2WidgetSetAccess(GTK2WidgetSet);
end;

{ TGtk2App }

class constructor TGtk2App.Create;
begin
  FHooks := TStack<TGtk2EventCallback>.Create;
end;

class destructor TGtk2App.Destroy;
begin
  if FHandlerInit then
  begin
    FHandlerInit := False;
    gdk_event_handler_set(@gtk_main_do_event, nil, nil);
  end;
  FreeAndNil(FHooks);
end;

class procedure TGtk2App.Hook(ACallback: TGtk2EventCallback);
begin
  FHooks.Push(ACallback);
  HandlerInit;
end;

class procedure TGtk2App.Unhook;
begin
  FHooks.Pop;
end;

class procedure TGtk2App.Handler(event: PGdkEvent; data: gpointer); cdecl;
var
  LCallback: TGtk2EventCallback;
  LHandled: Boolean;
begin
  if (FHooks <> nil) and (FHooks.Count > 0) then
  begin
    // #AI:
    // Без вызова GtkKeySnooper функции GetAsyncKeyState/GetKeyState
    // будут возвращать неактуальные данные, а у нас в тулбарах есть
    // проверки на нажатость кнопок мыши и Escape
    if event._type = GDK_KEY_PRESS then
      GtkKeySnooper(nil, @event.key, WidgetSet.FKeyStateList_);

    LHandled := False;
    LCallback := FHooks.Peek;
    LCallback(event, LHandled);

    if LHandled then
    begin
      // #AI:
      // GDK_KEY_RELEASE обрабатываем после callback-а и только в том случае,
      // если callback запросил "съесть" эвент. В штатном режиме, snopper уже
      // дернется со стороны обработчика gtk_main_do_event
      if event._type = GDK_KEY_RELEASE then
        GtkKeySnooper(nil, @event.key, WidgetSet.FKeyStateList_);
      Exit;
    end;
  end;

  // Input-Redirection
  case event._type of
    GDK_MOTION_NOTIFY,
    GDK_BUTTON_RELEASE,
    GDK_BUTTON_PRESS,
    GDK_2BUTTON_PRESS,
    GDK_3BUTTON_PRESS,
    GDK_KEY_PRESS,
    GDK_KEY_RELEASE,
    GDK_SCROLL:
      if FInputTarget <> nil then
      begin
        gtk_widget_event(FInputTarget, event);
        Exit;
      end;
  end;

  gtk_main_do_event(event);
end;

class procedure TGtk2App.HandlerException(Sender: TObject; Error: Exception);
begin
  FPopupError := Error.ToString;
end;

class procedure TGtk2App.HandlerInit;
begin
  if not FHandlerInit then
  begin
    FHandlerInit := True;
    gdk_event_handler_set(Handler, nil, HandlerOnDestroy);
  end;
end;

class procedure TGtk2App.HandlerOnDestroy(data: gpointer); cdecl;
begin
  FHandlerInit := False;
end;

class procedure TGtk2App.BeginPopup(APopupControl: TWinControl);
begin
  BeginPopup(APopupControl, PopupEventHandler);
end;

class procedure TGtk2App.BeginPopup(
  APopupControl: TWinControl; ACallback: TGtk2EventCallback);
{$IFNDEF DEBUG_MESSAGELOOP}
const
  GdkHookFlags = GDK_POINTER_MOTION_MASK or
    GDK_BUTTON_PRESS_MASK or GDK_BUTTON_RELEASE_MASK or
    GDK_ENTER_NOTIFY_MASK or GDK_LEAVE_NOTIFY_MASK;
{$ENDIF}
var
{$IFNDEF DEBUG_MESSAGELOOP}
  AAttrs: TGdkWindowAttr;
  ACurrTime: Integer;
{$ENDIF}
  AWindow: PGdkWindow;
begin
  if FPopupWindow <> nil then
    raise EInvalidOperation.Create('Gtk2: recursive popups are not supported');

{$IFDEF DEBUG_MESSAGELOOP}
  AWindow := nil;
{$ELSE}
  // AI: ref.to: gtk2/gtkmenu.c, menu_grab_transfer_window_get
  FillChar(AAttrs{%H-}, SizeOf(AAttrs), 0);
  AAttrs.x := -100;
  AAttrs.y := -100;
  AAttrs.width := 10;
  AAttrs.height := 10;
  AAttrs.override_redirect := True;
  AAttrs.window_type := GDK_WINDOW_TEMP;
  AAttrs.wclass := GDK_INPUT_ONLY;

  ACurrTime := gtk_get_current_event_time;
  AWindow := gtk_widget_get_root_window({%H-}PGtkWidget(APopupControl.Handle));
  AWindow := gdk_window_new(AWindow, @AAttrs, GDK_WA_X or GDK_WA_Y or GDK_WA_NOREDIR);
  gdk_window_show(AWindow);

  // захватываем мышь глобально (на уровне оконного менеджера)
  if gdk_pointer_grab(AWindow, True, GdkHookFlags, nil, nil, ACurrTime) <> 0 then
  begin
    gdk_window_destroy(AWindow);
    raise EInvalidOperation.Create('GTK2.Popup: unable to grap the pointer');
  end;

  //#AI:
  // В FlyWM (Astra Linux) при захвате клавиатурного хука, top-level форма
  // в режиме StayOnTop проваливается на задний план.
  //
  // Поверхостный тест показал, что в принципе-то граббинг клавиатуры нам
  // и не нужен - мы перехватываем нужные события через SetKeyboardRedirection
  //
  // Захватываем клавиатуру глобально
  //if gdk_keyboard_grab(AWindow, True, ACurrTime) <> 0 then
  //begin
  //  gdk_display_pointer_ungrab(gdk_drawable_get_display(AWindow), ACurrTime);
  //  gdk_window_destroy(AWindow);
  //  raise EInvalidOperation.Create('GTK2.Popup: unable to grap the keyboard');
  //end;
{$ENDIF}

// если мы тут - все прошло ОК, инициализируем приемник сообщений и перехватчик
  FPopupError := '';
  FPopupControl := APopupControl;
  FPopupWindow := AWindow;
  try
    FOldExceptionHandler := Application.OnException;
    Application.OnException := HandlerException;
    Hook(ACallback);
  except
    EndPopup;
    raise;
  end;
end;

class procedure TGtk2App.EndPopup;
var
  LDisplay: PGdkDisplay;
begin
  Unhook;
  FPopupControl := nil;
  SetInputRedirection(nil);
  Application.OnException := FOldExceptionHandler;
  if FPopupWindow <> nil then
  try
    LDisplay := gdk_drawable_get_display(FPopupWindow);
    //gdk_display_keyboard_ungrab(ADisplay, GDK_CURRENT_TIME);
    gdk_display_pointer_ungrab(LDisplay, GDK_CURRENT_TIME);
    gdk_window_destroy(FPopupWindow);
  finally
    FPopupWindow := nil;
  end;
  if FPopupError <> '' then
    raise Exception.Create(FPopupError);
end;

class function TGtk2App.IsPopupAborted: Boolean;
begin
  Result := FPopupError <> '';
end;

class procedure TGtk2App.ProcessMessages;
begin
  WidgetSet.AppProcessMessages;
end;

class procedure TGtk2App.PopupEventHandler(AEvent: PGdkEvent; var AHandled: Boolean);
var
  LWidget: PGtkWidget;
  LWidgetOfPopupWnd: PGtkWidget;
begin
  case AEvent._type of
    GDK_KEY_PRESS, GDK_KEY_RELEASE:
      if FInputTarget <> nil then
      begin
        gtk_widget_event(FInputTarget, AEvent);
        AHandled := True;
        Exit;
      end;
  end;

  case AEvent._type of
    GDK_BUTTON_RELEASE,
    GDK_BUTTON_PRESS,
    GDK_2BUTTON_PRESS,
    GDK_3BUTTON_PRESS,
    GDK_MOTION_NOTIFY,
    GDK_KEY_PRESS,
    GDK_KEY_RELEASE,
    GDK_SCROLL:
      begin
        AHandled := True;
        LWidget := gtk_get_event_widget(AEvent);
        LWidgetOfPopupWnd := PGtkWidget(FPopupControl.Handle);
        if not IsChild(LWidget, LWidgetOfPopupWnd) then
          LWidget := GetFixedWidget(LWidgetOfPopupWnd);
        gtk_widget_event(LWidget, AEvent);
      end;
  end;
end;

class procedure TGtk2App.SetInputRedirection(AControl: TWinControl);
begin
  if AControl <> nil then
    FInputTarget := GetFixedWidget({%H-}PGtkWidget(AControl.Handle))
  else
    FInputTarget := nil;

  HandlerInit;
end;

{ TGtk2Controls }

class function TGtk2Controls.CheckStartDrag(
  AControl: TWinControl; X, Y, AThreshold: Integer): Boolean;
var
  LPoint: TPoint;
begin
  FDragState := TDragState.None;
  FDragTarget := TRect.Create(AControl.ClientToScreen(Point(X, Y)));
  FDragTarget.Inflate(AThreshold);

  TGtk2App.Hook(DoDragEvents);
  try
    repeat
      try
        TGtk2App.ProcessMessages;
      except
        if Application.CaptureExceptions then
          Application.HandleException(AControl)
        else
          raise;
      end;
      if Application.Terminated or not AControl.Visible then
        Break;
      Application.Idle(True);
    until FDragState <> TDragState.None;
    Result := FDragState = TDragState.Started;
  finally
    TGtk2App.Unhook;
  end;
end;

class function TGtk2Controls.DoDrawNonClientBorder(Widget: PGtkWidget;
  Event: PGDKEventExpose; Data: gPointer): GBoolean; cdecl;
var
  LPrevClient: PGtkWidget;
  LWidgetInfo: PWinWidgetInfo;
  LWnd: HWND;
  LWndDC: HDC;
begin
  if gtk_container_get_border_width(PGtkContainer(Widget)) > 0 then
  begin
    LWnd := {%H-}HWND(Widget);
    LWidgetInfo := GetWidgetInfo(Widget);

    // AI: делаем вот такой финт ушами, чтобы LCL-ая обвязка создала DC именно
    // вокруг контейнер-виджета, а не вокруг его CoreWidget (как оно по есть)
    LPrevClient := LWidgetInfo^.ClientWidget;
    try
      LWidgetInfo^.ClientWidget := Widget;
      LWndDC := GetDC(LWnd);
    finally
      LWidgetInfo^.ClientWidget := LPrevClient;
    end;

    SetWindowOrgEx(LWndDC, -Widget^.Allocation.x, -Widget^.Allocation.y, nil);
    SendMessage(LWnd, WM_NCPAINT, 0, LWndDC);
    ReleaseDC(LWnd, LWndDC);
  end;
  Result := CallBackDefaultReturn;
end;

class procedure TGtk2Controls.DoDragEvents(AEvent: PGdkEvent; var AHandled: Boolean);
begin
  if FDragState = TDragState.None then
    case AEvent._type of
      GDK_MOTION_NOTIFY:
        if not FDragTarget.Contains(Mouse.CursorPos) then
          FDragState := TDragState.Started;
      GDK_BUTTON_RELEASE:
        begin
          FDragState := TDragState.Canceled;
          //AHandled := True;
        end;
    end;
end;

class procedure TGtk2Controls.SetNonClientBorder(AControl: TWinControl; ASize: Integer);
var
  LWidget: PGtkWidget;
begin
  LWidget := {%H-}PGtkWidget(AControl.Handle);
  // Ref.to: GTKAPIWidget_new (Gtk2WinapiWindow.pp)
  if GTK_IS_CONTAINER(LWidget) then
  begin
    gtk_container_set_border_width(GTK_CONTAINER(LWidget), ASize);
    ConnectSignalAfter(GTK_OBJECT(LWidget), 'expose-event', @DoDrawNonClientBorder, AControl);
  end;
end;

{ TACLGtk2WSEdit }

class procedure TACLGtk2WSEdit.SetColor(const AWinControl: TWinControl);
var
  LWidget: PGtkWidget;
begin
  LWidget := {%H-}PGtkWidget(AWinControl.Handle);
  LWidget := GetOrCreateWidgetInfo(LWidget)^.CoreWidget;
  Gtk2WidgetSet.SetWidgetColor(LWidget, clNone, AWinControl.Color,
    [GTK_STATE_NORMAL, GTK_STATE_INSENSITIVE, GTK_STYLE_BASE]);
end;

{ TACLGtk2WSMemo }

class procedure TACLGtk2WSMemo.SetColor(const AWinControl: TWinControl);
begin
  TACLGtk2WSEdit.SetColor(AWinControl);
end;

{ TACLGtk2WSAdvancedForm }

class function TACLGtk2WSAdvancedForm.CreateHandle(
  const AWinControl: TWinControl; const AParams: TCreateParams): TLCLHandle;
var
  LAllocation: TGtkAllocation;
  LBox: PGtkWidget;
  LColorMap: PGdkColormap;
  LForm: TCustomForm absolute AWinControl;
  LScreen: PGdkScreen;
  LWidgetInfo: PWidgetInfo;
  LWnd: PGtkWidget;
  LWndType: TGtkWindowType;
begin
  if (csDesigning in AWinControl.ComponentState) then
    Exit(inherited);
  if AParams.Style and WS_CHILD <> 0 then
    Exit(inherited);

  if AParams.ExStyle and WS_EX_NOACTIVATE <> 0 then
    LWndType := GTK_WINDOW_POPUP
  else if AParams.ExStyle and WS_EX_LAYERED <> 0 then
    LWndType := GTK_WINDOW_TOPLEVEL
  else
    LWndType := FormStyleMap[LForm.BorderStyle];

  LWnd := gtk_window_new(LWndType);
  // This is done with the expectation to avoid the button blinking for forms
  // that hide it, but currently it doesn't seem to make a difference.
  gtk_window_set_skip_taskbar_hint(PGtkWindow(LWnd), True);
  gtk_window_set_decorated(PGtkWindow(LWnd), False);
  gtk_widget_set_app_paintable(LWnd, True);
  gtk_window_set_resizable(PGtkWindow(LWnd), FormResizableMap[LForm.BorderStyle] <> 0);
  gtk_window_set_title(PGtkWindow(LWnd), AParams.Caption);

  if AParams.WndParent <> 0 then
    gtk_window_set_transient_for(PGtkWindow(LWnd), {%H-}PGtkWindow(AParams.WndParent))
  else
    if LForm.FormStyle in fsAllStayOnTop then
      gtk_window_set_keep_above(PGtkWindow(LWnd), true);

  case LForm.WindowState of
    wsMaximized:
      gtk_window_maximize(PGtkWindow(LWnd));
    wsMinimized:
      gtk_window_iconify(PGtkWindow(LWnd));
    wsFullscreen:
      gtk_window_fullscreen(PGtkWindow(LWnd));
  else;
  end;

  // the clipboard needs a widget
  if ClipboardWidget = nil then
    Gtk2WidgetSet.SetClipboardWidget(LWnd);

  {.$IFDEF HASX}
  if (LForm = Application.MainForm) and not Application.HasOption('disableaccurateframe') then
    Gtk2WidgetSet.CreateDummyWidgetFrame(-1, -1, -1, -1);
  {.$ENDIF}

  LWidgetInfo := CreateWidgetInfo(LWnd, LForm, AParams);
  LWidgetInfo^.FormBorderStyle := Ord(LForm.BorderStyle);
  FillChar(LWidgetInfo^.FormWindowState, SizeOf(LWidgetInfo^.FormWindowState), #0);
  LWidgetInfo^.FormWindowState.new_window_state := GDK_WINDOW_STATE_WITHDRAWN;
  LWidgetInfo^.UserData := Pointer(1);

  if AParams.ExStyle and WS_EX_LAYERED = 0 then
  begin
    LBox := CreateFormContents(LForm, LWnd, LWidgetInfo);
    gtk_container_add(PGtkContainer(LWnd), LBox);
    gtk_widget_show(LBox);
  end;

  LAllocation.X := AParams.X;
  LAllocation.Y := AParams.Y;
  LAllocation.Width := AParams.Width;
  LAllocation.Height := AParams.Height;
  gtk_widget_size_allocate(LWnd, @LAllocation);

  Set_RC_Name(LForm, LWnd);
  SetCallbacks(LWnd, LWidgetInfo);
  SetWindowCapabities(LForm, LWnd);

  // Включаем AlphaComposing, если оконный менеджер поддерживает его
  if AParams.ExStyle and WS_EX_LAYERED <> 0 then
  begin
    LScreen := gtk_widget_get_screen(LWnd);
    if LScreen <> nil then
    begin
      LColorMap := gdk_screen_get_rgba_colormap(LScreen);
      if LColorMap <> nil then
        gtk_widget_set_colormap(LWnd, LColorMap);
    end;
  end;

  SetWindowCapabities(LForm, LWnd);
  Result := TLCLHandle({%H-}PtrUInt(LWnd));
end;

class function TACLGtk2WSAdvancedForm.DoExposeEvent(
  Widget: PGtkWidget; Event: PGDKEventExpose; Data: gPointer): GBoolean; cdecl;
var
  LCairo: pcairo_t;
  LPainter: IACLLayeredPaint;
begin
  Result := False;
  if Supports(TObject(Data), IACLLayeredPaint, LPainter) then
  begin
    LCairo := gdk_cairo_create(Widget^.window);
    try
      LPainter.PaintTo(LCairo);
    finally
      cairo_destroy(LCairo);
    end;
  end;
end;

class function TACLGtk2WSAdvancedForm.DoRealize(Widget: PGtkWidget; Data: Pointer): GBoolean; cdecl;
begin
  // таким образом пытаемся добраться до метода RealizeAccelerator
  Result := gtkRealizeCB(Widget, Data);
  SetWindowCapabities(TCustomForm(Data), Widget);
end;

class procedure TACLGtk2WSAdvancedForm.SetCallbacks(
  const AWidget: PGtkWidget; const AWidgetInfo: PWidgetInfo);
var
  LFixed: PGtkWidget;
begin
  inherited SetCallbacks(AWidget, AWidgetInfo);

  if AWidgetInfo^.Style and WS_CHILD = 0 then
  begin
    // подменяем gtkRealizeCB нашим обработчиком, чтобы подсунуть окну правильную декорацию и функционал
    g_signal_handlers_disconnect_by_func(AWidget, @gtkRealizeCB, AWidgetInfo^.LCLObject);
    g_signal_connect(AWidget, 'realize', TGTKSignalFunc(@DoRealize), AWidgetInfo^.LCLObject);

    LFixed := GetFixedWidget(AWidget);
    if LFixed <> nil then
    begin
      g_signal_handlers_disconnect_by_func(LFixed, @gtkRealizeCB, AWidgetInfo^.LCLObject);
      g_signal_connect(LFixed, 'realize', TGTKSignalFunc(@DoRealize), AWidgetInfo^.LCLObject);
    end;

    // подменяем gtkExpose нашим обработчиком
    if AWidgetInfo^.ExStyle and WS_EX_LAYERED <> 0 then
    begin
      g_signal_handlers_disconnect_by_func(AWidget, @gtkExposeEvent, AWidgetInfo^.LCLObject);
      g_signal_connect(AWidget, 'expose-event', TGTKSignalFunc(@DoExposeEvent), AWidgetInfo^.LCLObject);
    end;
  end;
end;

class procedure TACLGtk2WSAdvancedForm.SetColor(const AWinControl: TWinControl);
var
  LWidgetInfo: PWidgetInfo;
begin
  LWidgetInfo := GetWidgetInfo(Pointer(AWinControl.Handle));
  if (LWidgetInfo = nil) or (LWidgetInfo^.ExStyle and WS_EX_LAYERED = 0) then
    inherited;
end;

class procedure TACLGtk2WSAdvancedForm.SetFormBorderStyle(
  const AForm: TCustomForm; const AFormBorderStyle: TFormBorderStyle);
var
  LWidget: PGtkWidget;
  LWidgetInfo: PWidgetInfo;
begin
  if AForm.Parent <> nil then Exit;
  LWidget := {%H-}PGtkWidget(AForm.Handle);
  LWidgetInfo := GetWidgetInfo(LWidget);
  if FormStyleMap[AFormBorderStyle] <> FormStyleMap[TFormBorderStyle(LWidgetInfo.FormBorderStyle)] then
    RecreateWnd(AForm)
  else
  begin
    SetWindowCapabities(AForm, LWidget);
    LWidgetInfo^.FormBorderStyle := Ord(AFormBorderStyle);
  end;
end;

class procedure TACLGtk2WSAdvancedForm.SetWindowCapabities(AForm: TCustomForm; AWidget: PGtkWidget);
var
  LWnd: PGdkWindow;
begin
  if AForm.Parent = nil then
  begin
    LWnd := gtk_widget_get_toplevel(AWidget)^.window;
    if LWnd <> nil then
    begin
      gdk_window_set_decorations(LWnd, 0);
      gdk_window_set_functions(LWnd, GetWindowFunction(AForm));
    end;
  end;
end;

class procedure TACLGtk2WSAdvancedForm.ShowHide(const AWinControl: TWinControl);
var
  LForm: TCustomForm absolute AWinControl;
  LWindow: PGtkWindow;
  LWidgetInfo: PWidgetInfo;
begin
  LWindow := {%H-}PGtkWindow(LForm.Handle);
  LWidgetInfo := GetWidgetInfo(LWindow);
  if (fsModal in LForm.FormState) and LForm.HandleObjectShouldBeVisible then
  begin
    // только ради GDK_WINDOW_TYPE_HINT_DIALOG, чтобы модалка
    // ни при каких условиях не создавала собственную кнопку на таскбаре
    gtk_window_set_default_size(LWindow, Max(1, LForm.Width), Max(1, LForm.Height));
    gtk_widget_set_uposition(PGtkWidget(LWindow), LForm.Left, LForm.Top);
    gtk_window_set_type_hint(LWindow, GDK_WINDOW_TYPE_HINT_DIALOG);
    GtkWindowShowModal(LForm, LWindow);

    InvalidateLastWFPResult(LForm, LForm.BoundsRect);
  end
  else
  begin
    if LWidgetInfo^.ExStyle and WS_EX_NOACTIVATE <> 0 then
    begin
      if LForm.HandleObjectShouldBeVisible then
        gtk_window_set_type_hint(LWindow, GDK_WINDOW_TYPE_HINT_TOOLTIP);
    end;
    inherited;
    SetWindowCapabities(LForm, PGtkWidget(LWindow));
  end;
end;

{ TACLGtk2PopupControl }

class function TACLGtk2PopupControl.CreateHandle(
  const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLHandle;
var
  AAllocation: TGtkAllocation;
  AClientAreaWidget: PGtkWidget;
  AWidget: PGtkWidget;
  AWidgetInfo: PWidgetInfo;
begin
  if (AParams.Style and WS_POPUP) = 0 then
    Exit(inherited);

  // В этом случае у нас вместо контрола будет урезанная попап-форма
  if MustBeFocusable(AWinControl) then
    AWidget := gtk_window_new(GTK_WINDOW_TOPLEVEL)
  else
    AWidget := gtk_window_new(GTK_WINDOW_POPUP);

  gtk_widget_set_app_paintable(AWidget, True);
  gtk_window_set_decorated(PGtkWindow(AWidget), False);
  gtk_window_set_skip_taskbar_hint(PGtkWindow(AWidget), True);
  if AParams.WndParent <> 0 then
  begin
    gtk_window_set_transient_for(PGtkWindow(AWidget),
      GTK_WINDOW(gtk_widget_get_toplevel({%H-}PGtkWidget(AParams.WndParent))));
  end
  else
    gtk_window_set_keep_above(PGtkWindow(AWidget), true); // stay-on-top

  AWidgetInfo := CreateWidgetInfo(AWidget, AWinControl, AParams);
  FillChar(AWidgetInfo^.FormWindowState, SizeOf(AWidgetInfo^.FormWindowState), #0);
  AWidgetInfo^.FormWindowState.new_window_state := GDK_WINDOW_STATE_WITHDRAWN;

  // Размеры
  AAllocation.X := AParams.X;
  AAllocation.Y := AParams.Y;
  AAllocation.Width := AParams.Width;
  AAllocation.Height := AParams.Height;
  gtk_widget_size_allocate(AWidget, @AAllocation);

  Set_RC_Name(AWinControl, AWidget);
  SetCallbacks(PGtkObject(AWidget), AWinControl);

  // Если у попап-контрола есть дочерние элементы - мы должны создать подложку,
  // на которой они будут лежать (по аналогии с тем, как делается для формы -
  // см. CreateFormContents), в противном случае LCL не найдет куда их положить
  // и контролы не будут видны на экране.
  if AWinControl.ControlCount > 0 then
  begin
    AClientAreaWidget := gtk_layout_new(nil, nil);
    gtk_container_add(PGtkContainer(AWidget), AClientAreaWidget);
    gtk_widget_show(AClientAreaWidget);
    SetFixedWidget(AWidget, AClientAreaWidget);
    SetMainWidget(AWidget, AClientAreaWidget);
  end
  else
    AWidgetInfo^.ClientWidget := AWidget; // для Paint и MouseCapture, после setCallbacks

  // После того, как мы актуализировали ClientWidget - ставим обработчик сигнала на LM_PAINT
  WidgetSet.SetCallback(LM_PAINT, PGtkObject(AWidget), AWinControl);

  // Финалочка
  Result := TLCLHandle({%H-}PtrUInt(AWidget));
end;

class function TACLGtk2PopupControl.MustBeFocusable(AControl: TWinControl): Boolean;
begin
  Result := False;
end;

class procedure TACLGtk2PopupControl.SetBounds(
  const AWinControl: TWinControl;
  const ALeft, ATop, AWidth, AHeight: Integer);
var
  AWindow: PGtkWindow;
begin
  AWindow := {%H-}PGtkWindow(AWinControl.Handle);
  if GTK_IS_WINDOW(AWindow) then
  begin
    gtk_window_move(AWindow, ALeft, ATop);
    gtk_window_resize(AWindow, AWidth, AHeight);
  end
  else
    inherited SetBounds(AWinControl, ALeft, ATop, AWidth, AHeight);
end;

end.
