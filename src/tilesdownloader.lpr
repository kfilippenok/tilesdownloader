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
  {$IFDEF WINDOWS}
  Interfaces, // For BGRABitmap
  {$ENDIF}
  SysUtils, Classes, CustApp,
  TilesDownload.Classes, TilesDownload.Types, TilesDownload.Exceptions, TilesDownload.Utilities;

var
  OptionParameter: array[TOptionKind] of String;
  glOptions: TOptions;
  FormatSettings: TFormatSettings;

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
    Coordinate: RCoordinate;
  begin
    if hasOption(getOptionName(okHelp)) then
    begin
      writeHelp;
      Terminate;
      Exit;
    end;

    parseParameters;

    if (okMerge in glOptions) then
    begin
      try
        objTilesDownloader := GetMergedTDClassOnIdent(OptionParameter[okProvider])
                                .Create(Self, GetTDClassOnIdent(OptionParameter[okMerge]).Create(Self));
      except
        on E: Exception do
        begin
          WriteLn(E.Message);
          if Assigned(objTilesDownloader) then
            objTilesDownloader.Free;
          Halt(1);
        end;
      end;
    end
    else
    begin
      if (okProvider in glOptions) then
      try
        objTilesDownloader := GetTDClassOnIdent(OptionParameter[okProvider]).Create(Self);
      except
        on E: Exception do
        begin
          WriteLn('Error: ' + E.Message);
          if Assigned(objTilesDownloader) then
            objTilesDownloader.Free;
          Halt(1);
        end;
      end
    else
      objTilesDownloader := CTilesDownloader.Create(Self);

    end;

    with objTilesDownloader do
    begin
      if not OptionParameter[okMinZoom].IsEmpty then
        MinZoom := OptionParameter[okMinZoom].ToInteger;
      if not OptionParameter[okMaxZoom].IsEmpty then
        MaxZoom := OptionParameter[okMaxZoom].ToInteger;
      if not OptionParameter[okProviderName].IsEmpty then
        ProviderName := OptionParameter[okProviderName];
      if not OptionParameter[okProviderLink].IsEmpty then
        ProviderLink := OptionParameter[okProviderLink];
      if not OptionParameter[okOutput].IsEmpty then
        OutPath := OptionParameter[okOutput];

      if not (okFullMap in glOptions) then
      if OptionParameter[okFirstCoordLat].IsEmpty
      or OptionParameter[okFirstCoordLon].IsEmpty
      or OptionParameter[okSecondCoordLat].IsEmpty
      or OptionParameter[okSecondCoordLon].IsEmpty then
      begin
        WriteLn('error: Not all coordinate values are specified');
        Halt(1);
      end
      else
      begin
        Coordinate.lat := StrToFloat(OptionParameter[okFirstCoordLat], FormatSettings);
        Coordinate.lon := StrToFloat(OptionParameter[okFirstCoordLon], FormatSettings);
        Coordinates[0] := Coordinate;
        Coordinate.lat := StrToFloat(OptionParameter[okSecondCoordLat], FormatSettings);
        Coordinate.lon := StrToFloat(OptionParameter[okSecondCoordLon], FormatSettings);
        Coordinates[1] := Coordinate;
      end;

      if not OptionParameter[okTileRes].IsEmpty then
        TileRes := OptionParameter[okTileRes].ToInteger;

      if okPattern in glOptions then
      begin
        if not OptionParameter[okPattern].IsEmpty then
          Pattern := OptionParameter[okPattern];
      end
      else if (okLazmapviewer in glOptions) then
        SaveMethod := smLazmapviewer;

      ShowFileType := okShowFileType in glOptions;
      SkipMissing := okSkipMissing in glOptions;
      if okGrayscale in glOptions then
        Filter := ftGrayscale;
    end;
    try
      try
        if (okFullMap in glOptions) then
          objTilesDownloader.DownloadFullMap
        else
          objTilesDownloader.Download;
      except
        on E: Exception do
          WriteLn('Error: ' + E.Message);
      end;
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
      {$IFDEF DEBUG}
      write(getOptionName(OptionKind));
      {$ENDIF}
      if hasOption(getOptionName(OptionKind)) then
      begin
         Include(glOptions, OptionKind);
         {$IFDEF DEBUG}
         write(' finded, value = ');
         {$ENDIF}
         OptionParameter[OptionKind] := getOptionValue(getOptionName(OptionKind));
         {$IFDEF DEBUG}
         writeLn(OptionParameter[OptionKind]);
         {$ENDIF}
      end
      else
        {$IFDEF DEBUG}
        WriteLn;
        {$ENDIF}
    end;
  end;

  constructor ATilesDownloader.Create(TheOwner: TComponent);
  begin
    inherited Create(TheOwner);
    StopOnException:=True;
    FormatSettings.DecimalSeparator := '.';
  end;

  destructor ATilesDownloader.Destroy;
  begin
    inherited Destroy;
  end;

  procedure ATilesDownloader.writeHelp;
  begin
    WriteLn('tilesdownloader : Usage : ');
    WriteLn('    ./tilesdownloader [OPTION] [PARAMETER]...');
    WriteLn('');
    WriteLn('Donwload tiles from map providers.');
    WriteLn('');
    WriteLn('       Option               Value                       Description');
    WriteLn('    -provider              [String]          prepared provider.');
    WriteLn('    -provider-name         [String]          specify provider name.');
    WriteLn('    -provider-link         [String]          custom link to provider.');
    WriteLn('    -output                [String]          out path, default is current path in dir "tiles".');
    WriteLn('    -pattern               [String]          saving files with a pattern-generated name. Keywords:');
    WriteLn('                                               - %provider-name%');
    WriteLn('                                               - %x%');
    WriteLn('                                               - %y%');
    WriteLn('                                               - %z%');
    WriteLn('    -min-zoom         [Unsigned Integer]     lower zoom limit, in range 0..19.');
    WriteLn('    -max-zoom         [Unsigned Integer]     highest zoom limit, in range 0..19.');
    WriteLn('    -fсoord-lat            [Double]          latitude of first coordinate.');
    WriteLn('    -fсoord-lon            [Double]          longtitude of first coordinate.');
    WriteLn('    -sсoord-lat            [Double]          latitude of second coordinate.');
    WriteLn('    -sсoord-lon            [Double]          longtitude of second coordinate.');
    WriteLn('    -show-file-type          [x]             show file extension in filename.');
    WriteLn('    -full-map                [x]             download full map.');
    WriteLn('    -tile-res         [Unsigned Integer]     resolution of the saved images.');
    WriteLn('    -merge                 [String]          combining tiles from two different providers.');
    WriteLn('');
    WriteLn('Examples:');
    WriteLn('    ./tilesdownloader -provider osm -min-zoom 1 -max-zoom 7 -full-map');
    WriteLn('    ./tilesdownloader -provider osm -min-zoom 1 -max-zoom 7 -provider-name MyProviderName --fсoord-lat=57.02137767 --fсoord-lon=120 --sсoord-lat=42.7 --sсoord-lat=143.1');
    WriteLn('    ./tilesdownloader -provider osm -merge railway -min-zoom 0 -max-zoom 7 -pattern %provider-name%_%x%_%y%_%z% -full-map');
  end;

var
  appTilesDownloader: ATilesDownloader;
begin
  appTilesDownloader:=ATilesDownloader.Create(nil);
  appTilesDownloader.Title:='Tiles downloader';
  appTilesDownloader.Run;
  appTilesDownloader.Free;
end.

