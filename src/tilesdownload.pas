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

unit TilesDownload;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Classes, StrUtils, Math,
  fphttpclient, openssl, opensslsockets;

type

  RMapProvider = record
    name: String;
    link: String;
  end;

  RCoordinate = record
    lat: Float;
    lon: Float;
  end;

  RTile = record
    x: Integer;
    y: Integer;
  end;

  TSaveMethod = (smFolders, smPattern);

const
  defUserAgent = 'Mozilla/5.0 (compatible; fpweb)';
  defProvider = 'osm';
  defOutPath = 'tiles';
  defSaveMethod = smFolders;
  defDivider = '_';
  defProviderName = 'OpenStreetMap';
  defProviderLink = 'http://a.tile.openstreetmap.org';
  defMinZoom = 6;
  defMaxZoom = 7;
  defShowFileTypes = False;

type

  CTilesDownloader = class(TFPCustomHTTPClient)
  private
    FUserAgent: String;
    FMapProvider: RMapProvider;
    FOutPath: String;
    FSaveMethod: TSaveMethod;
    FDivider: String;
    FMinZoom: Integer;
    FMaxZoom: Integer;
    FCoordinates: array[0..1] of RCoordinate;
    FShowFileTypes: Boolean;
  private
    function getProviderLink: String;
    procedure setProviderLink(AValue: String);
    function getProviderName: String;
    procedure setProviderName(AValue: String);
    function getCoordinate(Index: Integer): RCoordinate;
    procedure setCoordinate(Index: Integer; AValue: RCoordinate);
  private
    procedure calcTileNumber(const ACoordinate: RCoordinate; const AZoom: Integer; out Tile: RTile);
    procedure DownloadTile(const AZoom: Integer; const ATile: RTile);
  public
    Constructor Create(AOwner: TComponent); override;
    property ProviderName : String      read getProviderName write setProviderName;
    property ProviderLink : String      read getProviderLink write setProviderLink;
    property OutPath      : String      read FOutPath        write FOutPath       ;
    property SaveMethod   : TSaveMethod read FSaveMethod     write FSaveMethod     default defSaveMethod;
    property Divider      : String      read FDivider        write FDivider       ;
    property MinZoom      : Integer     read FMinZoom        write FMinZoom        default defMinZoom;
    property MaxZoom      : Integer     read FMaxZoom        write FMaxZoom        default defMaxZoom;
    property ShowFileTypes: Boolean     read FShowFileTypes  write FShowFileTypes  default defShowFileTypes;
    property Coordinates[Index: Integer]: RCoordinate read getCoordinate write setCoordinate;
    procedure Download;
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

implementation

uses ssockets;

operator = (const First, Second: RCoordinate) R : boolean;
begin
  R := SameValue(First.lat, Second.lat) and SameValue(First.lon, Second.lon);
end;

function CTilesDownloader.getProviderLink: String;
begin
  Result := FMapProvider.link;
end;

procedure CTilesDownloader.setProviderLink(AValue: String);
begin
  if FMapProvider.link = AValue then Exit;
  FMapProvider.link := AValue;
end;

function CTilesDownloader.getProviderName: String;
begin
  Result := FMapProvider.name;
end;

procedure CTilesDownloader.setProviderName(AValue: String);
begin
  if FMapProvider.name = AValue then Exit;
  FMapProvider.name := AValue;
end;

function CTilesDownloader.getCoordinate(Index: Integer): RCoordinate;
begin
  Result := FCoordinates[Index];
end;

procedure CTilesDownloader.setCoordinate(Index: Integer; AValue: RCoordinate);
begin
  if FCoordinates[Index] = AValue then Exit;
  FCoordinates[Index] := AValue;
end;

constructor CTilesDownloader.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FUserAgent := defUserAgent;
  ProviderName := defProviderName;
  ProviderLink := defProviderLink;
  OutPath := defOutPath;
  SaveMethod := smFolders;
  Divider := defDivider;
  MinZoom := defMinZoom;
  MaxZoom := defMinZoom;
  ShowFileTypes := defShowFileTypes;
end;

procedure CTilesDownloader.calcTileNumber(const ACoordinate: RCoordinate;
const AZoom: Integer; out Tile: RTile);
var
  lat_rad, n: Float;
begin
  lat_rad := DegToRad(ACoordinate.lat);
  n := Power(2, AZoom);
  Tile.x := Trunc(((ACoordinate.lon + 180) / 360) * n);
  Tile.y := Trunc((1 - ArcSinH(Tan(lat_rad)) / Pi) / 2.0 * n);
end;

procedure CTilesDownloader.DownloadTile(const AZoom: Integer; const ATile: RTile);

  function _getFileName: String;
  begin
    case SaveMethod of
      smFolders:
        begin
          Result := Format('%s%s%d%s%d%s%d%s', [ProviderName, PathDelim, AZoom, PathDelim, ATile.x, PathDelim, ATile.y, IfThen(ShowFileTypes, '.png')]);
        end;
      smPattern:
        begin
          Result := Format('%s%s%d%s%d%s%d%s', [ProviderName, Divider, AZoom, Divider, ATile.x, Divider, ATile.y, IfThen(ShowFileTypes, '.png', '')]);
        end;
    end;
  end;

var
  LStream: TStream;
  LFileName, LFilePath: String;
begin
  LFileName := _getFileName;
  LFilePath := Format('%s%s%s', [OutPath, PathDelim, LFileName]);
  WriteLn(Format('FilePath: %s', [LFilePath]));
  LStream := TFileStream.Create(LFilePath, fmCreate or fmOpenWrite);

  InitSSLInterface;
  Self.AllowRedirect := true;
  Self.ConnectTimeOut := 10000;
  Self.AddHeader('User-Agent', FUserAgent);
  //Self.AddHeader('User-Agent', 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 YaBrowser/24.6.0.0 Safari/537.36\');
  WriteLn(Format('TileLink: %s/%d/%d/%d.png', [ProviderLink, AZoom,  ATile.x, ATile.y]));
  try
    while True do
      try
        Self.Get(Format('%s/%d/%d/%d.png', [ProviderLink, AZoom,  ATile.x, ATile.y]), LStream);
        break;
      except
        on E: ESocketError do
          continue;
      end;
  finally
    LStream.Free;
  end;
end;

procedure CTilesDownloader.Download;
var
  LTile1, LTile2, LTileTmp: RTile;
  iz, ix, iy: Integer;
begin
  if not DirectoryExists(OutPath) then
  if not ForceDirectories(Format('%s%s%s%s%s', [GetCurrentDir, PathDelim, OutPath, PathDelim, ProviderName])) then
    Halt(1);

  for iz := MinZoom to MaxZoom do
  begin
    if SaveMethod = smFolders then
    if not DirectoryExists(Format('%s/%s/%d', [OutPath, ProviderName, iz])) then
      CreateDir(Format('%s/%s/%d', [OutPath, ProviderName, iz]));

    calcTileNumber(Coordinates[0], iz, LTile1);
    calcTileNumber(Coordinates[1], iz, LTile2);
    {$IFDEF DEBUG}
    WriteLn(Format('Coordinates[0]: %f, %f, Zoom: %d -> Tile: %d, %d', [Coordinates[0].lat, Coordinates[0].lon, iz,  LTile1.x, LTile1.y]));
    WriteLn(Format('Coordinates[1]: %f, %fm Zoom: %d -> Tile: %d, %d', [Coordinates[1].lat, Coordinates[1].lon, iz,  LTile2.x, LTile2.y]));
    {$ENDIF}

    for ix := LTile1.X to LTile2.x do
    begin
      if SaveMethod = smFolders then
      if not DirectoryExists(Format('%s/%s/%d/%d', [OutPath, ProviderName, iz, ix])) then
           CreateDir(Format('%s/%s/%d/%d', [OutPath, ProviderName, iz, ix]));
      for iy := LTile2.y to LTile1.y do
      begin
        LTileTmp.x := ix;
        LTileTmp.y := iy;
        DownloadTile(iz, LTileTmp);
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

end.

