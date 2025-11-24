////////////////////////////////////////////////////////////////////////////////
//
//  Project:   Artem's Components Library aka ACL
//             v7.0
//
//  Purpose:   Multi-language UI Engine
//
//  Author:    Artem Izmaylov
//             © 2006-2025
//             www.aimp.ru
//
//  FPC:       OK
//
unit ACL.MUI;

{$I ACL.Config.inc}

interface

uses
{$IFDEF FPC}
  LCLIntf,
  LCLType,
  LMessages,
{$ELSE}
  {Winapi.}Windows,
  {Winapi.}Messages,
{$ENDIF}
  // System
  {System.}Classes,
  {System.}TypInfo,
  {System.}SysUtils,
  // VCL
{$IFNDEF ACL_BASE_NOVCL}
  {Vcl.}Forms,
  {Vcl.}Graphics,
{$ENDIF}
  // ACL
  ACL.Classes.Collections,
  ACL.Classes.StringList,
  ACL.FileFormats.INI;

const
  sLangExt = '.lng';
  sDefaultLang  = 'english' + sLangExt;
  sDefaultLang2 = 'russian' + sLangExt;

  sLangAuthor = 'Author';
  sLangIcon = 'Icon';
  sLangID = 'LangId';
  sLangMainSection = 'File';
  sLangMsg = 'MSG';
  sLangName = 'Name';
  sLangPartSeparator = '|';
  sLangVersionId = 'VersionId';

  sLangMacroBegin = '@Lng:';
  sLangMacroEnd = ';';

const
  WM_ACL_LANG = WM_USER + 101;

  LANG_EN_US = 1033;//LANG_ENGLISH   or (SUBLANG_ENGLISH_US shl 10); // 1033
  LANG_RU_RU = 1049;//LANG_RUSSIAN   or (SUBLANG_DEFAULT    shl 10); // 1049
  LANG_UK_UA = 1058;//LANG_UKRAINIAN or (SUBLANG_DEFAULT    shl 10); // 1058

type

  { IACLLocalizableComponent }

  IACLLocalizableComponent = interface
  ['{41434C4D-5549-436F-6D70-6F6E656E7400}']
    procedure Localize(const ASection, AName: string);
  end;

  { IACLLocalizableComponentRoot }

  IACLLocalizableComponentRoot = interface
  ['{9250A6D0-932D-4996-811F-4F8B0CC72DFE}']
    function GetLangSection: string;
  end;

  { IACLLocalizationListener }

  IACLLocalizationListener = interface
  ['{5A92CDBE-DBF8-42EE-9661-2D6392618D64}']
    procedure LangChanged;
  end;

  { IACLLocalizationListener2 }

  IACLLocalizationListener2 = interface(IACLLocalizationListener)
  ['{AB6E20E3-32B9-49F6-9309-B1B3BFFA0633}']
    procedure LangInitialize;
  end;

  { IACLLocalizationListener3 }

  IACLLocalizationListener3 = interface(IACLLocalizationListener)
  ['{EED7CE81-1E91-4382-A3EF-46BA995E3CF5}']
    procedure LangChanging;
  end;

  { TACLLocalizationInfo }

  TACLLocalizationInfo = packed record
    Author: string;
    LangID: Integer;
    Name: string;
    VersionID: Integer;
  end;

  { TACLLocalization }

  TACLLocalizationClass = class of TACLLocalization;
  TACLLocalization = class(TACLIniFile)
  strict private
    FListeners: TACLListenerList;

    function GetLangID: Integer;
    function GetShortFileName: string;
    procedure SetLangID(const Value: Integer);
  protected
    procedure LangChanged;
  public
    constructor Create(const AFileName: string; AutoSave: Boolean = True); override;
    destructor Destroy; override;
    procedure ExpandLinks(AInst: HMODULE; const AName: string; AType: PChar); overload;
    procedure ExpandLinks(ALinks: TACLIniFile); overload;
    procedure LoadFromFile(const AFileName: string); override;
    procedure LoadFromStream(AStream: TStream); override;
    function ReadStringEx(const ASection, AKey: string; out AValue: string): Boolean; override;
    // Listeners
    class procedure ListenerAdd(const AListener: IACLLocalizationListener);
    class procedure ListenerRemove(const AListener: IACLLocalizationListener);
    // Properties
    property LangID: Integer read GetLangID write SetLangID;
    property ShortFileName: string read GetShortFileName;
  end;

var
  LangFilePath: string = '';

function LangFile: TACLLocalization;

procedure LangApplyTo(const AParentSection: string; AComponent: TComponent);
procedure LangApplyToItems(const ASection: string; AItems: TStrings);

function LangExpandMacros(const AText: string; const ADefaultSection: string = ''): string;
function LangExtractPart(const AValue: string; APartIndex: Integer): string;
function LangGetComponentPath(const AComponent: TComponent): string;
procedure LangGetFiles(AList: TACLStringList);

function LangGet(const ASection, AItemName: string; const ADefaultValue: string = ''): string;
function LangGetMsg(ID: Integer): string;
function LangGetMsgPart(ID, APart: Integer): string;

function LangSubSection(const ASection, AName: string): string;

{$IFNDEF ACL_BASE_NOVCL}
function LangGetInfo(const ALangFile: TACLIniFile;
  out AData: TACLLocalizationInfo; AIcon: TIcon): Boolean; overload;
function LangGetInfo(const ALangFile: string;
  out AData: TACLLocalizationInfo): Boolean; overload;
function LangGetInfo(const ALangFile: string;
  out AData: TACLLocalizationInfo; AIcon: TIcon): Boolean; overload;
{$ENDIF}

procedure LangSetFileClass(AClass: TACLLocalizationClass);
implementation

uses
{$IFNDEF ACL_BASE_NOVCL}
  {Vcl.}ActnList,
  {Vcl.}Controls,
  {Vcl.}Menus,
{$ENDIF}
  // ACL
  ACL.Utils.FileSystem,
  ACL.Utils.Messaging,
  ACL.Utils.Strings;

var
  FLangFile: TACLLocalization;
  FLangFileClass: TACLLocalizationCLass = TACLLocalization;

function LangGetComponentPath(const AComponent: TComponent): string;
var
  S: IACLLocalizableComponentRoot;
begin
  if Supports(AComponent, IACLLocalizableComponentRoot, S) then
    Result := S.GetLangSection
  else
    if AComponent <> nil then
    begin
      Result := LangGetComponentPath(AComponent.Owner);
      if AComponent.Name <> '' then
        Result := Result + IfThenW(Result <> '', '.') + AComponent.Name;
    end
    else
      Result := '';
end;

function LangFile: TACLLocalization;
begin
  if FLangFile = nil then
    FLangFile := FLangFileClass.Create;
  Result := FLangFile;
end;

procedure LangSetFileClass(AClass: TACLLocalizationClass);
begin
  FLangFileClass := AClass;
  FreeAndNil(FLangFile);
end;

procedure LangApplyTo(const AParentSection: string; AComponent: TComponent);
{$IFNDEF ACL_BASE_NOVCL}
  function IsActionAssigned(AObject: TObject): Boolean;
  var
    APropInfo: PPropInfo;
  begin
    APropInfo := GetPropInfo(AObject, 'Action');
    Result := (APropInfo <> nil) and (GetOrdProp(AObject, APropInfo) <> 0);
  end;

  function CanLocalizeCaptionAndHint: Boolean;
  begin
    Result := not (IsActionAssigned(AComponent) or
      (AComponent is TMenuItem) and TMenuItem(AComponent).IsLine);
  end;
{$ENDIF}

  procedure SetStringValue(APropInfo: PPropInfo; const S: string);
  begin
    if APropInfo <> nil then
      SetStrProp(AComponent, APropInfo, S);
  end;

var
  AIntf: IACLLocalizableComponent;
  I: Integer;
  S: string;
begin
  if not LangFile.IsEmpty then
  begin
    if AComponent.Name <> '' then
    begin
    {$IFNDEF ACL_BASE_NOVCL}
      if AComponent is TAction then
      begin
        TAction(AComponent).Caption :=
          LangFile.ReadString(AParentSection, AComponent.Name);
        TAction(AComponent).Hint := IfThenW(
          LangFile.ReadString(AParentSection, AComponent.Name + '.h'),
          TAction(AComponent).Caption);
      end
      else
        if CanLocalizeCaptionAndHint then
    {$ENDIF}
        begin
          if LangFile.ReadStringEx(AParentSection, AComponent.Name, S) then
            SetStringValue(GetPropInfo(AComponent, 'Caption'), S);
          if LangFile.ReadStringEx(AParentSection, AComponent.Name + '.h', S) then
            SetStringValue(GetPropInfo(AComponent, 'Hint'), S);
        end;
    end;

    if Supports(AComponent, IACLLocalizableComponent, AIntf) then
      AIntf.Localize(AParentSection, AComponent.Name)
    else
      for I := 0 to AComponent.ComponentCount - 1 do
        LangApplyTo(AParentSection, AComponent.Components[I]);
  end;
end;

procedure LangApplyToItems(const ASection: string; AItems: TStrings);
var
  I: Integer;
begin
  AItems.BeginUpdate;
  try
    for I := 0 to AItems.Count - 1 do
      AItems.Strings[I] := LangFile.ReadString(ASection, 'i[' + IntToStr(I) + ']', AItems.Strings[I]);
  finally
    AItems.EndUpdate;
  end;
end;

function LangExpandMacros(const AText: string; const ADefaultSection: string = ''): string;
var
  K, I, J, L: Integer;
  S: TACLStringBuilder;
  V: string;
begin
  if Pos(sLangMacroBegin, AText) = 0 then
    Exit(AText);

  S := TACLStringBuilder.Get(Length(AText));
  try
    I := 1;
    repeat
      J := Pos(sLangMacroBegin, AText, I);
      L := Pos(sLangMacroEnd, AText, J + 1);
      if (J = 0) or (L = 0) then
      begin
        S.Append(AText, I - 1, Length(AText) - I + 1);
        Break;
      end;
      S.Append(AText, I - 1, J - I);

      // Expand
      J := J + Length(sLangMacroBegin);
      V := Copy(AText, J, L - J);
      K := acPos('\', V);
      if K = 0 then
        S.Append(LangGet(ADefaultSection, V))
      else
        S.Append(LangGet(Copy(V, 1, K - 1), Copy(V, K + 1, MaxInt)));

      I := L + Length(sLangMacroEnd);
    until False;
    Result := S.ToString;
  finally
    S.Release;
  end;
end;

function LangExtractPart(const AValue: string; APartIndex: Integer): string;
var
  APos: Integer;
begin
  Result := AValue;
  while APartIndex > 0 do
  begin
    APos := acPos(sLangPartSeparator, Result);
    if APos = 0 then
      APos := Length(Result);
    Delete(Result, 1, APos);
    Dec(APartIndex);
  end;
  APos := acPos(sLangPartSeparator, Result) - 1;
  if APos < 0 then
    APos := Length(Result);
  Result := Copy(Result, 1, APos);
end;

procedure LangGetFiles(AList: TACLStringList);
begin
  acEnumFiles(LangFilePath, '*' + sLangExt + ';', AList.AddEx);
  AList.SortLogical;
end;

function LangGet(const ASection, AItemName, ADefaultValue: string): string;
begin
  Result := LangFile.ReadString(ASection, AItemName, ADefaultValue);
end;

function LangGetMsg(ID: Integer): string;
begin
  Result := Langfile.ReadString(sLangMsg, IntToStr(ID));
end;

function LangGetMsgPart(ID, APart: Integer): string;
begin
  Result := LangExtractPart(LangGetMsg(ID), APart);
end;

function LangSubSection(const ASection, AName: string): string;
begin
  if AName <> '' then
    Result := ASection + '.' + AName
  else
    Result := ASection;
end;

{$IFNDEF ACL_BASE_NOVCL}
function LangGetInfo(const ALangFile: TACLIniFile;
  out AData: TACLLocalizationInfo; AIcon: TIcon): Boolean;
begin
  AData.Author := ALangFile.ReadString(sLangMainSection, sLangAuthor);
  AData.LangID := ALangFile.ReadInteger(sLangMainSection, sLangID);
  AData.Name := ALangFile.ReadString(sLangMainSection, sLangName);
  AData.VersionID := ALangFile.ReadInteger(sLangMainSection, sLangVersionId, 0);
  if AIcon <> nil then
  begin
    if not ALangFile.ReadObject(sLangMainSection, sLangIcon,
      procedure (AStream: TStream)
      begin
        AIcon.LoadFromStream(AStream);
      end)
    then
      AIcon.Handle := 0;
  end;
  Result := True;
end;

function LangGetInfo(const ALangFile: string; out AData: TACLLocalizationInfo): Boolean;
begin
  Result := LangGetInfo(ALangFile, AData, nil);
end;

function LangGetInfo(const ALangFile: string; out AData: TACLLocalizationInfo; AIcon: TIcon): Boolean;
var
  AInfo: TACLIniFile;
begin
  AInfo := TACLIniFile.Create(ALangFile, False);
  try
    Result := LangGetInfo(AInfo, AData, AIcon);
  finally
    AInfo.Free;
  end;
end;
{$ENDIF}

{ TACLLocalization }

constructor TACLLocalization.Create(const AFileName: string; AutoSave: Boolean = True);
begin
  inherited Create(AFileName, False);
  FListeners := TACLListenerList.Create;
end;

destructor TACLLocalization.Destroy;
begin
  FreeAndNil(FListeners);
  inherited Destroy;
end;

procedure TACLLocalization.ExpandLinks(AInst: HMODULE; const AName: string; AType: PChar);
var
  LLinks: TACLIniFile;
begin
  LLinks := TACLIniFile.Create;
  try
    LLinks.LoadFromResource(AInst, AName, AType);
    ExpandLinks(LLinks);
  finally
    LLinks.Free;
  end;
end;

procedure TACLLocalization.ExpandLinks(ALinks: TACLIniFile);
var
  LKey: string;
  LSection: TACLIniFileSection;
  LValue: string;
  I, J, P: Integer;
begin
  for I := 0 to ALinks.SectionCount - 1 do
  begin
    LSection := ALinks.SectionObjs[I];
    for J := 0 to LSection.Count - 1 do
    begin
      LKey := LSection.Names[J];
      if not ExistsKey(LSection.Name, LKey) then
      begin
        LValue := LSection.ValueFromIndex[J];
        P := acPos('>', LValue);
        if P = 0 then
          LValue := ReadString(LSection.Name, Copy(LValue, 2, MaxInt))
        else
          LValue := ReadString(Copy(LValue, 2, P - 2), Copy(LValue, P + 1, MaxInt));

        WriteString(LSection.Name, LKey, LValue);
      end;
    end;
  end;
end;

procedure TACLLocalization.LoadFromFile(const AFileName: string);
begin
  FileName := LangFilePath + AFileName;
  inherited LoadFromFile(FileName);
end;

procedure TACLLocalization.LoadFromStream(AStream: TStream);
begin
  inherited LoadFromStream(AStream);
  DefaultCodePage := ReadInteger(sLangMainSection, 'ANSICP', CP_ACP);
  LangChanged;
end;

function TACLLocalization.ReadStringEx(const ASection, AKey: string; out AValue: string): Boolean;
begin
  Result := inherited ReadStringEx(ASection, AKey, AValue);
  if Result then
    AValue := acDecodeLineBreaks(AValue);
end;

class procedure TACLLocalization.ListenerAdd(const AListener: IACLLocalizationListener);
begin
  LangFile.FListeners.Add(AListener);
end;

class procedure TACLLocalization.ListenerRemove(const AListener: IACLLocalizationListener);
begin
  if FLangFile <> nil then
    LangFile.FListeners.Remove(AListener);
end;

procedure TACLLocalization.LangChanged;
var
{$IFNDEF ACL_BASE_NOVCL}
  I: Integer;
{$ENDIF}
  LIntf1: IACLLocalizationListener;
  LIntf2: IACLLocalizationListener2;
  LIntf3: IACLLocalizationListener3;
begin
  if not acContains(ShortFileName, [sDefaultLang, sDefaultLang2], True) then
    Merge(LangFilePath + sDefaultLang, False);

  for LIntf2 in FListeners.Enumerate<IACLLocalizationListener2> do
    LIntf2.LangInitialize;
  for LIntf3 in FListeners.Enumerate<IACLLocalizationListener3> do
    LIntf3.LangChanging;

{$IFNDEF ACL_BASE_NOVCL}
  if Assigned(Application.MainForm) then
    acSendMessage(Application.MainForm.Handle, WM_ACL_LANG, 0, 0);
  for I := 0 to Screen.FormCount - 1 do
    acSendMessage(Screen.Forms[I].Handle, WM_ACL_LANG, 0, 0);
{$ENDIF}

  for LIntf1 in FListeners.Enumerate<IACLLocalizationListener> do
    LIntf1.LangChanged;
end;

function TACLLocalization.GetLangID: Integer;
begin
  Result := ReadInteger(sLangMainSection, sLangID);
end;

function TACLLocalization.GetShortFileName: string;
begin
  Result := acExtractFileName(FileName);
end;

procedure TACLLocalization.SetLangID(const Value: Integer);
begin
  WriteInteger(sLangMainSection, sLangID, Value);
end;

initialization
  LangFilePath := acSelfPath + 'Langs' + PathDelim;

finalization
  FreeAndNil(FLangFile);
end.
