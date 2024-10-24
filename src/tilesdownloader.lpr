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

program tilesdownloader;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Classes, CustApp,
  TilesDownload.Classes, TilesDownload.Types, TilesDownload.Exceptions;

var
  OptionParameter: array[TOptionKind] of String;
  Options: TOptions;

type

  { ATilesDownloader }

  ATilesDownloader = class(TCustomApplication)
  protected
    procedure DoRun; override;
  private
    procedure parseParameters;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure writeHelp; virtual;
  end;

  procedure ATilesDownloader.DoRun;
  var
    objTilesDownloader: CTilesDownloader;
    ConcreteCTilesDownloader: class of CTilesDownloader;
    Coordinate: RCoordinate;
  begin
    parseParameters;

    case OptionParameter[okProvider] of
      'osm': ConcreteCTilesDownloader := CTDOpenStreetMap;
      'otm': ConcreteCTilesDownloader := CTDOpenTopotMap;
      'osm-cycle': ConcreteCTilesDownloader := CTDCycleOSM;
      'railway': ConcreteCTilesDownloader := CTDOpenRailwayMap;
    else
      ConcreteCTilesDownloader := CTilesDownloader;
    end;

    objTilesDownloader := ConcreteCTilesDownloader.Create(nil);
    with objTilesDownloader do
    begin
      if not OptionParameter[okMinZoom].IsEmpty then
        MinZoom := OptionParameter[okMinZoom].ToInteger;
      if not OptionParameter[okMaxZoom].IsEmpty then
        MaxZoom := OptionParameter[okMaxZoom].ToInteger;
      if not OptionParameter[okSaveMethod].IsEmpty then
        case OptionParameter[okSaveMethod] of
          'pattern':
            begin
              SaveMethod := smPattern;
              if not OptionParameter[okDivider].IsEmpty then
                Divider := OptionParameter[okDivider];
            end;
        end;
      if not OptionParameter[okProviderName].IsEmpty then
        ProviderName := OptionParameter[okProviderName];
      if not OptionParameter[okOutput].IsEmpty then
        OutPath := OptionParameter[okProviderName];

      if OptionParameter[okFirstCoordLat].IsEmpty
      or OptionParameter[okFirstCoordLon].IsEmpty
      or OptionParameter[okSecondCoordLat].IsEmpty
      or OptionParameter[okSecondCoordLon].IsEmpty then
      begin
        WriteLn('error: Not all coordinate values are specified');
        Halt(1);
      end;
      Coordinate.lat := OptionParameter[okFirstCoordLat].ToDouble;
      Coordinate.lon := OptionParameter[okFirstCoordLon].ToDouble;
      Coordinates[0] := Coordinate;
      Coordinate.lat := OptionParameter[okSecondCoordLat].ToDouble;
      Coordinate.lon := OptionParameter[okSecondCoordLon].ToDouble;
      Coordinates[1] := Coordinate;
    end;
    try
      objTilesDownloader.Download;
    finally
      objTilesDownloader.Free;
    end;

    // stop program loop
    Terminate;
  end;

  procedure ATilesDownloader.parseParameters;
  var
    OptionKind: TOptionKind;
    //ErrorMsg: String;
  begin
    //ErrorMsg:=CheckOptions('h', 'help');
    //if ErrorMsg<>'' then begin
    //  ShowException(Exception.Create(ErrorMsg));
    //  Terminate;
    //  Exit;
    //end;

    for OptionKind := Low(TOptionKind) to High(TOptionKind) do
    begin
      writeLn(getOptionName(OptionKind));
      if hasOption(getOptionName(OptionKind)) then
      begin
         Include(Options, OptionKind);
         {$IFDEF DEBUG}
         write(getOptionName(OptionKind) + ' finded, value = ');
         {$ENDIF}
         OptionParameter[OptionKind] := getOptionValue(getOptionName(OptionKind));
         {$IFDEF DEBUG}
         writeLn(OptionParameter[OptionKind]);
         {$ENDIF}
      end;
    end;
  end;

  constructor ATilesDownloader.Create(TheOwner: TComponent);
  begin
    inherited Create(TheOwner);
    StopOnException:=True;
  end;

  destructor ATilesDownloader.Destroy;
  begin
    inherited Destroy;
  end;

  procedure ATilesDownloader.writeHelp;
  begin
    { add your help code here }
    writeln('Usage: ', ExeName, ' -h');
  end;

var
  appTilesDownloader: ATilesDownloader;
begin
  appTilesDownloader:=ATilesDownloader.Create(nil);
  appTilesDownloader.Title:='Tiles downloader';
  appTilesDownloader.Run;
  appTilesDownloader.Free;
end.

