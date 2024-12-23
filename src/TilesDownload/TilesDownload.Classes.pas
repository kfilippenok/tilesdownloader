{
  Copyright (c) 2024 Kirill Filippenok

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. }

unit TilesDownload.Classes;

{$mode ObjFPC}{$H+}{$MODESWITCH ADVANCEDRECORDS}

interface

uses
  SysUtils, Classes, StrUtils, Math, FGL,
  fphttpclient, openssl, opensslsockets, BGRABitmap,
  TilesDownload.Exceptions;

type

  RMapProvider = record
    name: String;
    link: String;
  end;

  RCoordinate = record
    Lat: Float;
    Lon: Float;
  end;

  RTile = record
    X: QWord;
    Y: QWord;
  end;

  { HTileHelper }

  HTileHelper = record helper for RTile
    procedure SetValues(x, y: Integer);
  end;

  TSaveMethod = (smFolders, smPattern, smLazmapviewer);
  TFilterType = (ftNone, ftGrayscale);
  TPatternItem = (piProviderName, piZoom, piX, piY);

var
  PatternItemsStr: array[TPatternItem] of String = ('%provider-name%',
                                                    '%z%',
                                                    '%x%',
                                                    '%y%');

const
  defUserAgent = 'Mozilla/5.0 (compatible; fpweb)';
  defProvider = 'osm';
  defSaveMethod = smFolders;
  defFilter = ftNone;
  defProviderName = 'OpenStreetMap';
  defProviderLink = 'http://a.tile.openstreetmap.org';
  defOutPath = 'tiles';
  defMinZoom = 6;
  defMaxZoom = 7;
  defShowFileType = False;
  defSkipMissing = False;
  defTileRes = 256;
  defOtherTileRes = False;

type

  RefCTilesDownloader = class of CTilesDownloader;

  TGetFileName = function (const AZoom, AX, AY: Integer): String of object;
  TGetOutPath  = function : String of object;
  TFilterTile  = procedure (var ATileImg: TBGRABitmap) of object;

  GPatternItems = specialize TFPGMap<TPatternItem, integer>;
  HPatternItemsHelper = class helper for GPatternItems
    procedure SortOnData;
  end;

  { CTilesDownloader }

  CTilesDownloader = class(TFPCustomHTTPClient)
  protected
    FUserAgent: String;
    FMapProvider: RMapProvider;
    FOutPath: String;
    FTileRes: Integer;
    FPattern, FInsertPattern: String;
    FGetFileName: TGetFileName;
    FGetOutPath : TGetOutPath;
    FFilterTile : TFilterTile;
    FPatternItems: GPatternItems;
    FOtherTileRes: Boolean;
    FSaveMethod: TSaveMethod;
    FFilter: TFilterType;
    FDivider: String;
    FMinZoom: Integer;
    FMaxZoom: Integer;
    FCoordinates: array[0..1] of RCoordinate;
    FShowFileType: Boolean;
    FSkipMissing: Boolean;
  strict private
    function GetOutPathAuto: String;
    function GetOutPathCustom: String;
    function GetOutPath: String;
    procedure SetOutPath(AOutPath: String);
    procedure SetFilter(AValue: TFilterType);
    function GetProviderLink: String;
    procedure SetProviderLink(AValue: String);
    function GetProviderName: String;
    procedure SetProviderName(AValue: String);
    procedure SetPattern(APattern: String);
    function GetCoordinate(Index: Integer): RCoordinate;
    procedure SetCoordinate(Index: Integer; AValue: RCoordinate);
    procedure SetSaveMethod(AValue: TSaveMethod);
    procedure SetTileRes(AValue: Integer);
    function GetTotalTilesCount: Longword;
    function GetTotalTilesCountOnCoordinates: Longword;
  public
    procedure Init;
    procedure CalcTileNumber(const ACoordinate: RCoordinate; const AZoom: Integer; out Tile: RTile);
    function CalcRowTilesCount(AZoom: Byte): Longword; overload;
    function CalcRowTilesCount(ATile1, ATile2: RTile): Longword; overload;
    function CalcColumnTilesCount(ATile1, ATile2: RTile): Longword;
    function CalcZoomTilesCount(AZoom: Byte): Longword; overload;
    function CalcZoomTilesCount(ATile1, ATile2: RTile): Longword; overload;
    function GetFileNameDir(const AZoom, AX, AY: Integer): String;
    function GetFileNamePattern(const AZoom, AX, AY: Integer): String;
    function GetFileNameLazmapviewer(const AZoom, AX, AY: Integer): String;
    function GetFileName(const AZoom, AX, AY: Integer): String;
    procedure ReceiveTile(var ATileImg: TBGRABitmap; const AProviderLink: String; const AZoom: Integer; const ATile: RTile);
    procedure ResampleTile(var ATileImg: TBGRABitmap; const ATileRes: Integer);
    procedure GrayscaleTile(var ATileImg: TBGRABitmap);
    procedure FilterTile(var ATileImg: TBGRABitmap);
    procedure SaveTile(const ATileImg: TBGRABitmap; AFilePath: String);
    procedure DownloadTile(const AZoom: Integer; const ATile: RTile); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property ProviderName   : String      read GetProviderName write SetProviderName;
    property ProviderLink   : String      read GetProviderLink write SetProviderLink;
    property OutPath        : String      read GetOutPath      write SetOutPath     ;
    property TileRes        : Integer     read FTileRes        write SetTileRes     ;
    property Pattern        : String      read FPattern        write SetPattern     ;
    property SaveMethod     : TSaveMethod read FSaveMethod     write SetSaveMethod   default defSaveMethod;
    property Filter         : TFilterType read FFilter         write SetFilter       default defFilter;
    property MinZoom        : Integer     read FMinZoom        write FMinZoom        default defMinZoom;
    property MaxZoom        : Integer     read FMaxZoom        write FMaxZoom        default defMaxZoom;
    property ShowFileType   : Boolean     read FShowFileType   write FShowFileType   default defShowFileType;
    property SkipMissing    : Boolean     read FSkipMissing    write FSkipMissing    default defSkipMissing;
    property Coordinates[Index: Integer]: RCoordinate read getCoordinate write setCoordinate;
    property TotalTilesCount             : Longword    read GetTotalTilesCount;
    property TotalTilesCountOnCoordinates: Longword    read GetTotalTilesCountOnCoordinates;
    procedure Download; virtual;
    procedure DownloadFullMap; virtual;
  end;

  { CTDOpenStreetMap }

  CTDOpenStreetMap = class(CTilesDownloader)
  public
    Constructor Create(AOwner: TComponent); override;
  end;

  { CTDOpenTopotMap }

  CTDOpenTopotMap = class(CTilesDownloader)
  public
    Constructor Create(AOwner: TComponent); override;
  end;

  { CTDCycleOSM }

  CTDCycleOSM = class(CTilesDownloader)
  public
    Constructor Create(AOwner: TComponent); override;
  end;

  { CTDOpenRailwayMap }

  CTDOpenRailwayMap = class(CTilesDownloader)
  public
    Constructor Create(AOwner: TComponent); override;
  end;

  { CMergedTD }

  RefCMergedTD = class of CMergedTD;

  CMergedTD = class(CTilesDownloader)
  strict private
    FMergedDownloader: CTilesDownloader;
  public
    constructor Create(AOwner: TComponent; AMergedTD: CTilesDownloader); virtual; overload;
    procedure DownloadTile(const AZoom: Integer; const ATile: RTile); override;
    property MergedDownloader: CTilesDownloader read FMergedDownloader write FMergedDownloader;
    procedure Download; override;
    procedure DownloadFullMap; override;
  end;

  { CMrgTDOpenStreetMap }

  CMrgTDOpenStreetMap = class(CMergedTD)
  public
    Constructor Create(AOwner: TComponent; AMergedTD: CTilesDownloader); override;
  end;

  { CMrgTDOpenTopotMap }

  CMrgTDOpenTopotMap = class(CMergedTD)
  public
    Constructor Create(AOwner: TComponent; AMergedTD: CTilesDownloader); override;
  end;

  { CMrgTDCycleOSM }

  CMrgTDCycleOSM = class(CMergedTD)
  public
    Constructor Create(AOwner: TComponent; AMergedTD: CTilesDownloader); override;
  end;

  { CMrgTDOpenRailwayMap }

  CMrgTDOpenRailwayMap = class(CMergedTD)
  public
    Constructor Create(AOwner: TComponent; AMergedTD: CTilesDownloader); override;
  end;

implementation

uses ssockets, BGRABitmapTypes;

{ HPatternItemsHelper }

procedure HPatternItemsHelper.SortOnData;
var
  AllSorted: Boolean;
  ipatit: Integer;
begin
  while True do
  begin
    AllSorted := True;
    for ipatit := 0 to Count-2 do
    begin
      if Data[ipatit] > Data[ipatit+1] then
      begin
        Move(ipatit, ipatit+1);
        AllSorted := False;
      end;
    end;

    if AllSorted then Exit;
  end;
end;

operator = (const First, Second: RCoordinate) R : boolean;
begin
  R := SameValue(First.lat, Second.lat) and SameValue(First.lon, Second.lon);
end;

{ HTileHelper }

procedure HTileHelper.SetValues(x, y: Integer);
begin
  Self.x := x; Self.y := y;
end;

function CTilesDownloader.GetProviderLink: String;
begin
  Result := FMapProvider.link;
end;

function CTilesDownloader.GetTotalTilesCount: Longword;
var iz: Byte;
begin
  Result := 0;
  for iz := MinZoom to MaxZoom do
    Result := Result + CalcZoomTilesCount(iz);
end;

function CTilesDownloader.GetTotalTilesCountOnCoordinates: Longword;
var
  LTile1, LTile2: RTile;
  iz: Integer;
begin
  Result := 0;
  for iz := MinZoom to MaxZoom do
  begin
    calcTileNumber(Coordinates[0], iz, LTile1);
    calcTileNumber(Coordinates[1], iz, LTile2);
    Result := Result + (CalcRowTilesCount(LTile1, LTile2) * CalcColumnTilesCount(LTile1, LTile2));
  end;
end;

procedure CTilesDownloader.SetOutPath(AOutPath: String);
begin
  if FOutPath = AOutPath then Exit;

  FOutPath := AOutPath;
  FGetOutPath := @GetOutPathCustom;
end;

function CTilesDownloader.GetOutPathAuto: String;
begin
  Result := 'tiles' + PathDelim + ProviderName;
end;

function CTilesDownloader.GetOutPathCustom: String;
begin
  Result := FOutPath;
end;

function CTilesDownloader.GetOutPath: String;
begin
  Result := FGetOutPath();
end;

procedure CTilesDownloader.SetFilter(AValue: TFilterType);
begin
  if FFilter=AValue then Exit;

  case AValue of
    ftNone: FFilterTile := nil;
    ftGrayscale: FFilterTile := @GrayscaleTile;
  end;

  FFilter:=AValue;
end;

procedure CTilesDownloader.SetProviderLink(AValue: String);
begin
  if FMapProvider.Link = AValue then Exit;
  FMapProvider.Link := AValue;
end;

function CTilesDownloader.GetProviderName: String;
begin
  Result := FMapProvider.Name;
end;

procedure CTilesDownloader.SetProviderName(AValue: String);
begin
  if FMapProvider.name = AValue then Exit;
  FMapProvider.name := AValue;
end;

procedure CTilesDownloader.SetPattern(APattern: String);
var
  LInsertPattern, LSearchSource: String;
  tpos, ipatit: Integer;
  LPatternItem: TPatternItem;
begin
  if FPattern = APattern then Exit;

  FPattern := APattern;
  FGetFileName := @GetFileNamePattern;
  SaveMethod := smPattern;

  LInsertPattern := APattern;
  LSearchSource := LowerCase(APattern);

  // Filling in for further sorting
  for LPatternItem := Low(TPatternItem) to High(TPatternItem) do
  begin
    tpos := Pos(PatternItemsStr[LPatternItem], LSearchSource);
    if tpos > 0 then
    begin
      FPatternItems.Add(LPatternItem, tpos);
    end;
  end;

  // Sort on data
  FPatternItems.SortOnData;

  for ipatit := 0 to FPatternItems.Count-1 do
  begin
    tpos := Pos(PatternItemsStr[FPatternItems.Keys[ipatit]], LSearchSource);
    System.Delete(LInsertPattern, tpos, Length(PatternItemsStr[FPatternItems.Keys[ipatit]]));
    System.Delete(LSearchSource, tpos, Length(PatternItemsStr[FPatternItems.Keys[ipatit]]));
    FPatternItems.Data[ipatit] := tpos;
  end;

  FInsertPattern := LInsertPattern;
end;

function CTilesDownloader.GetCoordinate(Index: Integer): RCoordinate;
begin
  Result := FCoordinates[Index];
end;

procedure CTilesDownloader.SetCoordinate(Index: Integer; AValue: RCoordinate);
begin
  if FCoordinates[Index] = AValue then Exit;
  FCoordinates[Index] := AValue;
end;

procedure CTilesDownloader.SetSaveMethod(AValue: TSaveMethod);
begin
  if FSaveMethod = AValue then Exit;

  FSaveMethod := AValue;
  case AValue of
    smLazmapviewer: begin
      FGetFileName := @GetFileNameLazmapviewer;
    end;
  end;
end;

constructor CTilesDownloader.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FOtherTileRes := defOtherTileRes;
  FTileRes := defTileRes;
  FGetFileName := @GetFileNameDir;
  FGetOutPath := @GetOutPathAuto;
  FFilterTile := nil;
  FFilter := ftNone;
  FPatternItems := GPatternItems.Create;
  FUserAgent := defUserAgent;
  ProviderName := defProviderName;
  ProviderLink := defProviderLink;
  FOutPath := defOutPath;
  FSaveMethod := smFolders;
  FMinZoom := defMinZoom;
  FMaxZoom := defMinZoom;
  FShowFileType := defShowFileType;
  FSkipMissing := defSkipMissing;
end;

destructor CTilesDownloader.Destroy;
begin
  inherited Destroy;

  FPatternItems.Free;
end;

procedure CTilesDownloader.CalcTileNumber(const ACoordinate: RCoordinate;
  const AZoom: Integer; out Tile: RTile);
var
  lat_rad, n: Float;
begin
  lat_rad := DegToRad(ACoordinate.lat);
  n := Power(2, AZoom);
  Tile.x := Trunc(((ACoordinate.lon + 180) / 360) * n);
  Tile.y := Trunc((1 - ArcSinH(Tan(lat_rad)) / Pi) / 2.0 * n);
end;

function CTilesDownloader.CalcRowTilesCount(AZoom: Byte): Longword;
begin
  Result := Trunc(Power(2, AZoom));
end;

function CTilesDownloader.CalcRowTilesCount(ATile1, ATile2: RTile): Longword;
begin
  Result := Max(ATile1.X, ATile2.X) - Min(ATile1.X, ATile2.X) + 1;
end;

function CTilesDownloader.CalcColumnTilesCount(ATile1, ATile2: RTile): Longword;
begin
  Result := Max(ATile1.Y, ATile2.Y) - Min(ATile1.Y, ATile2.Y) + 1;
end;

function CTilesDownloader.CalcZoomTilesCount(AZoom: Byte): Longword;
var
  LRowTilesCount: Longword;
begin
  LRowTilesCount := CalcRowTilesCount(AZoom);
  Result := LRowTilesCount * LRowTilesCount;
end;

function CTilesDownloader.CalcZoomTilesCount(ATile1, ATile2: RTile): Longword;
begin
  Result := CalcRowTilesCount(ATile1, ATile2) * CalcColumnTilesCount(ATile1, ATile2)
end;

function CTilesDownloader.GetFileNameDir(const AZoom, AX, AY: Integer): String;
begin
  Result := Format('%d%s%d%s%d%s', [AZoom, PathDelim, AX, PathDelim, AY, IfThen(ShowFileType, '.png')]);
end;

function CTilesDownloader.GetFileNamePattern(const AZoom, AX, AY: Integer
  ): String;
var
  ipi: Integer;
begin
  Result := FInsertPattern;
  for ipi := FPatternItems.Count-1 downto 0 do
  begin
    case FPatternItems.Keys[ipi] of
      piProviderName: Insert(ProviderName,   Result, FPatternItems.Data[ipi]);
      piZoom        : Insert(AZoom.ToString, Result, FPatternItems.Data[ipi]);
      piX           : Insert(AX.ToString,    Result, FPatternItems.Data[ipi]);
      piY           : Insert(AY.ToString,    Result, FPatternItems.Data[ipi]);
    end;
  end;
  Result := Result + IfThen(ShowFileType, '.png');
end;

function CTilesDownloader.GetFileNameLazmapviewer(const AZoom, AX, AY: Integer
  ): String;
begin
  Result := Format('%d%s%d_%d%s', [AZoom, PathDelim, AX, AY, IfThen(ShowFileType, '.png')]);
end;

function CTilesDownloader.GetFileName(const AZoom, AX, AY: Integer): String;
begin
  Result := FGetFileName(AZoom, AX, AY);
end;

procedure CTilesDownloader.ReceiveTile(var ATileImg: TBGRABitmap; const AProviderLink: String; const AZoom: Integer; const ATile: RTile);
var
  LMemoryStream: TMemoryStream;
begin
  WriteLn(Format('TileLink: %s/%d/%d/%d.png', [AProviderLink, AZoom,  ATile.x, ATile.y]));
  try
    LMemoryStream := TMemoryStream.Create;
    while True do
      try
        Self.Get(Format('%s/%d/%d/%d.png', [AProviderLink, AZoom,  ATile.x, ATile.y]), LMemoryStream);
        break;
      except
        on E: ESocketError do
          continue;
      end;
    LMemoryStream.Position := 0;
    ATileImg.LoadFromStream(LMemoryStream);
    LMemoryStream.Free;
  except
    on E: Exception do
    begin
      WriteLn(E.Message);
      LMemoryStream.Free;
      raise ETDReceive.Create('Failed receive file.');
    end;
  end;
end;

procedure CTilesDownloader.ResampleTile(var ATileImg: TBGRABitmap; const ATileRes: Integer);
var
  LOldTile: TBGRABitmap;
begin
  try
    LOldTile := ATileImg;
    ATileImg := ATileImg.Resample(ATileRes, ATileRes);
    LOldTile.Free;
  except
    on E: Exception do
    begin
      WriteLn(E.Message);
      raise ETDResample.Create('Failed resample file.');
    end;
  end;
end;

procedure CTilesDownloader.GrayscaleTile(var ATileImg: TBGRABitmap);
var
  LOldTile: TBGRABitmap;
begin
  try
    LOldTile := ATileImg;
    ATileImg := ATileImg.FilterGrayscale(true);
    LOldTile.Free;
  except
    on E: Exception do
    begin
      WriteLn(E.Message);
      raise ETDFilter.Create('Failed filter file.');
    end;
  end;
end;

procedure CTilesDownloader.FilterTile(var ATileImg: TBGRABitmap);
begin
  if Assigned(FFilterTile) then
    FFilterTile(ATileImg);
end;

procedure CTilesDownloader.SaveTile(const ATileImg: TBGRABitmap; AFilePath: String);
var
  LFileStream: TFileStream;
begin
  WriteLn(Format('FilePath: %s', [AFilePath]));
  try
    LFileStream := TFileStream.Create(AFilePath, fmCreate or fmOpenWrite);
    ATileImg.SaveToStreamAsPng(LFileStream);
    LFileStream.Free;
  except
    on E: Exception do
    begin
      WriteLn(E.Message);
      LFileStream.Free;
      raise ETDSave.Create('Failed save file.');
    end;
  end;
end;

procedure CTilesDownloader.DownloadTile(const AZoom: Integer; const ATile: RTile);
var
  LFileName, LFilePath: String;
  LTileImg: TBGRABitmap;
begin
  try
    LTileImg := TBGRABitmap.Create;
    ReceiveTile(LTileImg, ProviderLink, AZoom, ATile);
    if FOtherTileRes then
      ResampleTile(LTileImg, TileRes);
    FilterTile(LTileImg);
    LFileName := GetFileName(AZoom, ATile.X, ATile.Y);
    LFilePath := Format('%s%s%s', [OutPath, PathDelim, LFileName]);
    SaveTile(LTileImg, LFilePath);
    LTileImg.Free;
  except
    on ETileDownload do
    begin
      if Assigned(LTileImg) then
        LTileImg.Free;
      raise;
    end;
  end;
end;

procedure CTilesDownloader.SetTileRes(AValue: Integer);
begin
  FOtherTileRes := True;
  if FTileRes=AValue then Exit;
  FTileRes:=AValue;
end;

procedure CTilesDownloader.Init;
begin
  InitSSLInterface;
  Self.AllowRedirect := true;
  Self.ConnectTimeOut := 10000;
  Self.AddHeader('User-Agent', FUserAgent);
end;

procedure CTilesDownloader.Download;
var
  LTile1, LTile2, LTileTmp: RTile;
  iz: Byte;
  ix, iy: Longword;
  LZoomCurrentCount, LZoomTotalCount, LCurrentCount, LTotalCount: Longword;
begin
  Init;

  if not DirectoryExists(OutPath) then
  if not ForceDirectories(OutPath) then
    Halt(1);

  LCurrentCount := 0;
  LTotalCount := TotalTilesCountOnCoordinates;

  for iz := MinZoom to MaxZoom do
  begin
    if SaveMethod in [smFolders, smLazmapviewer] then
    if not DirectoryExists(Format('%s/%d', [OutPath, iz])) then
    if not ForceDirectories(Format('%s/%d', [OutPath, iz])) then
      raise Exception.Create('The necessary paths could not be created. Check the specified path');

    CalcTileNumber(Coordinates[0], iz, LTile1);
    CalcTileNumber(Coordinates[1], iz, LTile2);
    {$IFDEF DEBUG}
    WriteLn(Format('Coordinates[0]: %f, %f, Zoom: %d -> Tile: %d, %d', [Coordinates[0].lat, Coordinates[0].lon, iz,  LTile1.x, LTile1.y]));
    WriteLn(Format('Coordinates[1]: %f, %f, Zoom: %d -> Tile: %d, %d', [Coordinates[1].lat, Coordinates[1].lon, iz,  LTile2.x, LTile2.y]));
    {$ENDIF}

    LZoomCurrentCount := 0;
    LZoomTotalCount := CalcZoomTilesCount(LTile1, Ltile2);

    for ix := LTile1.X to LTile2.x do
    begin
      if SaveMethod = smFolders then
      if not DirectoryExists(Format('%s/%d/%d', [OutPath, iz, ix])) then
        ForceDirectories(Format('%s/%d/%d', [OutPath, iz, ix]));

      for iy := LTile1.y to LTile2.y do
      begin
        LTileTmp.x := ix;
        LTileTmp.y := iy;
        try
          DownloadTile(iz, LTileTmp);
          Inc(LZoomCurrentCount);
          Inc(LCurrentCount);
          WriteLn(Format('Total: %d/%d <- (Zoom %d: %d/%d)', [LCurrentCount, LTotalCount, iz, LZoomCurrentCount, LZoomTotalCount]));
        except
          on E: ETileDownload do
          begin
            if SkipMissing and (E is ETDReceive) then
            begin
              WriteLn('! Skip missing tile');
              Continue;
            end;

            WriteLn;
            WriteLn('Error: ', E.Message);
            Exit;
          end;
        end;
      end;
    end;

  end;
end;

procedure CTilesDownloader.DownloadFullMap;
var
  LTile: RTile;
  iz: Byte;
  ix, iy: Longword;
  LZoomCurrentCount, LZoomTotalCount, LCurrentCount, LTotalCount, LRowCount: Longword;
begin
  Init;

  if not DirectoryExists(OutPath) then
  if not ForceDirectories(OutPath) then
    raise Exception.Create('The necessary paths could not be created. Check the specified path');

  LCurrentCount := 0;
  LTotalCount := TotalTilesCount;

  for iz := MinZoom to MaxZoom do
  begin
    LRowCount := CalcRowTilesCount(iz);
    LZoomCurrentCount := 0;
    LZoomTotalCount := CalcZoomTilesCount(iz);

    if SaveMethod in [smFolders, smLazmapviewer] then
    if not DirectoryExists(Format('%s%s%d', [OutPath, PathDelim, iz])) then
      ForceDirectories(Format('%s%s%d', [OutPath, PathDelim, iz]));

    for ix := 0 to LRowCount-1 do
    begin
      if SaveMethod = smFolders then
      if not DirectoryExists(Format('%s%s%d%s%d', [OutPath, PathDelim, iz, PathDelim, ix])) then
        ForceDirectories(Format('%s%s%d%s%d', [OutPath, PathDelim, iz, PathDelim, ix]));

      for iy := 0 to LRowCount-1 do
      begin
        LTile.SetValues(ix, iy);
        try
          DownloadTile(iz, LTile);
          Inc(LZoomCurrentCount);
          Inc(LCurrentCount);
          WriteLn(Format('Total: %d/%d <- (Zoom %d: %d/%d)', [LCurrentCount, LTotalCount, iz, LZoomCurrentCount, LZoomTotalCount]));
        except
          on E: ETileDownload do
          begin
            if SkipMissing and (E is ETDReceive) then
            begin
              WriteLn('! Skip missing tile');
              Continue;
            end;

            WriteLn;
            WriteLn('Error: ', E.Message);
            Exit;
          end;
        end;
      end;
    end;

  end;
end;

{ CTDOpenStreetMap }

constructor CTDOpenStreetMap.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

{ CTDOpenTopotMap }

constructor CTDOpenTopotMap.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  ProviderName := 'Open Topo Map';
  ProviderLink := 'http://a.tile.opentopomap.org';
end;

{ CTDCycleOSM }

constructor CTDCycleOSM.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  ProviderName := 'CycleOSM';
  ProviderLink := 'https://c.tile-cyclosm.openstreetmap.fr/cyclosm/';
end;

{ CTDOpenRailwayMap }

constructor CTDOpenRailwayMap.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FUserAgent := 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 YaBrowser/24.6.0.0 Safari/537.36\';
  ProviderName := 'OpenRailwayMap';
  ProviderLink := 'http://b.tiles.openrailwaymap.org/standard';
end;

{ CMergedTD }

procedure CMergedTD.DownloadTile(const AZoom: Integer; const ATile: RTile);
var
  LFileName, LFilePath: String;
  LTileImg, LMergedTileImg: TBGRABitmap;
begin
  try
    LTileImg := TBGRABitmap.Create;
    LMergedTileImg := TBGRABitmap.Create;

    ReceiveTile(LTileImg, ProviderLink, AZoom, ATile);
    MergedDownloader.ReceiveTile(LMergedTileImg, MergedDownloader.ProviderLink, AZoom, ATile);

    if FOtherTileRes then
    begin
      ResampleTile(LTileImg, TileRes);
    end;
    ResampleTile(LMergedTileImg, LTileImg.Width);
    FilterTile(LTileImg);
    LTileImg.PutImage(0, 0, LMergedTileImg, dmDrawWithTransparency);

    LFileName := GetFileName(AZoom, ATile.X, ATile.Y);
    LFilePath := Format('%s%s%s', [OutPath, PathDelim, LFileName]);
    SaveTile(LTileImg, LFilePath);
    LMergedTileImg.Free;
    LTileImg.Free;
  except
    on E: Exception do
    begin
      if Assigned(LTileImg) then
        LTileImg.Free;
      if Assigned(LMergedTileImg) then
        LMergedTileImg.Free;
      raise;
    end;
  end;
end;

constructor CMergedTD.Create(AOwner: TComponent; AMergedTD: CTilesDownloader);
begin
  Create(AOwner);

  FMergedDownloader := AMergedTD;
end;

procedure CMergedTD.Download;
begin
  MergedDownloader.Init;
  inherited Download;
end;

procedure CMergedTD.DownloadFullMap;
begin
  MergedDownloader.Init;
  inherited DownloadFullMap;
end;

{ CMrgTDOpenStreetMap }

constructor CMrgTDOpenStreetMap.Create(AOwner: TComponent; AMergedTD: CTilesDownloader);
begin
  inherited Create(AOwner, AMergedTD);
end;

{ CMrgTDOpenTopotMap }

constructor CMrgTDOpenTopotMap.Create(AOwner: TComponent; AMergedTD: CTilesDownloader);
begin
  inherited Create(AOwner, AMergedTD);

  ProviderName := 'Open Topo Map';
  ProviderLink := 'http://a.tile.opentopomap.org';
end;

{ CMrgTDCycleOSM }

constructor CMrgTDCycleOSM.Create(AOwner: TComponent; AMergedTD: CTilesDownloader);
begin
  inherited Create(AOwner, AMergedTD);

  ProviderName := 'CycleOSM';
  ProviderLink := 'https://c.tile-cyclosm.openstreetmap.fr/cyclosm/';
end;

{ CMrgTDOpenRailwayMap }

constructor CMrgTDOpenRailwayMap.Create(AOwner: TComponent; AMergedTD: CTilesDownloader);
begin
  inherited Create(AOwner, AMergedTD);

  FUserAgent := 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 YaBrowser/24.6.0.0 Safari/537.36\';
  ProviderName := 'OpenRailwayMap';
  ProviderLink := 'http://b.tiles.openrailwaymap.org/standard';
end;

end.

