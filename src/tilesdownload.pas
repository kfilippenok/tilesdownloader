unit TilesDownload;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Classes, Math,
  fphttpclient, openssl, opensslsockets;

const
  defProvider = 'osm';
  defDownloadDir = 'tiles';
  defProviderName = 'OpenStreetMap';
  defProviderLink = 'http://a.tile.openstreetmap.org';
  defMinZoom = 6;
  defMaxZoom = 7;

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

  CTilesDownloader = class(TFPCustomHTTPClient)
  private
    FMapProvider:  RMapProvider;
    FDownloadDir:  String;
    FMinZoom:      Integer;
    FMaxZoom:      Integer;
    FCoordinates:  array[0..1] of RCoordinate;
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
    property ProviderName: String read getProviderName write setProviderName;
    property ProviderLink: String read getProviderLink write setProviderLink;
    property DownloadDir:  String read FDownloadDir    write FDownloadDir;
    property MinZoom: Integer read FMinZoom write FMinZoom default 6;
    property MaxZoom: Integer read FMaxZoom write FMaxZoom default 7;
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

  DownloadDir := defDownloadDir;
  ProviderName := defProviderName;
  ProviderLink := defProviderLink;
  MinZoom := defMinZoom;
  MaxZoom := defMinZoom;
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
var
  LStream: TStream;
  LFileName, LFilePath: String;
begin
  LFileName := Format('%s_%d_%d_%d.png', [ProviderName, AZoom,  ATile.x, ATile.y]);
  LFilePath := Format('%s/%s', [DownloadDir, LFileName]);
  {$IFDEF DEBUG}
  WriteLn(Format('FilePath: %s', [LFilePath]));
  {$ENDIF}
  LStream := TFileStream.Create(LFilePath, fmCreate or fmOpenWrite);

  InitSSLInterface;
  try
    try
      Self.AllowRedirect := true;
      Self.ConnectTimeOut := 10000;
      Self.AddHeader('User-Agent', 'Mozilla/5.0 (compatible; fpweb)');
      //Self.AddHeader('User-Agent', 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 YaBrowser/24.6.0.0 Safari/537.36\');
      {$IFDEF DEBUG}
      WriteLn(Format('TileLink: %s/%d/%d/%d.png', [ProviderLink, AZoom,  ATile.x, ATile.y]));
      {$ENDIF}
      Self.Get(Format('%s/%d/%d/%d.png', [ProviderLink, AZoom,  ATile.x, ATile.y]), LStream);
    except
      on E: EHttpClient do
        writeln(E.Message)
      else
        raise;
    end;
  finally
    LStream.Free;
  end;
end;

procedure CTilesDownloader.Download;
var
  LTile1, LTile2, LTileTmp: RTile;
  LZoom: Integer;
  iz, ix, iy: Integer;
begin
  if not DirectoryExists(DownloadDir) then
  if not CreateDir(GetCurrentDir + PathDelim + DownloadDir) then
    Halt(1);

  LZoom := MinZoom;
  calcTileNumber(Coordinates[0], LZoom, LTile1);
  calcTileNumber(Coordinates[1], LZoom, LTile2);
  {$IFDEF DEBUG}
  WriteLn(Format('Coordinates[0]: %f, %f -> Tile: %d, %d', [Coordinates[0].lat, Coordinates[0].lon,  LTile1.x, LTile1.y]));
  WriteLn(Format('Coordinates[1]: %f, %f -> Tile: %d, %d', [Coordinates[1].lat, Coordinates[1].lon,  LTile2.x, LTile2.y]));
  {$ENDIF}

  for iz := MinZoom to MaxZoom do
  for ix := LTile1.X to LTile2.x do
  for iy := LTile2.y to LTile1.y do
  begin
    LTileTmp.x := ix;
    LTileTmp.y := iy;
    DownloadTile(iz, LTileTmp);
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

  ProviderName := 'OpenRailwayMap';
  ProviderLink := 'http://b.tiles.openrailwaymap.org/standard';
end;

end.

