{
    Add empty landscape data to cells missing them in the current plugin.
}
unit AddEmptyLandscape;

function Process(e: IInterface): integer;
var
    landscape: IInterface;
    nonMasteredCells: TStringList;
begin
    //if not IsMaster(e) then Exit;
    if Signature(e) <> 'CELL' then Exit;
    landscape := GetLandscapeForCell(MasterOrSelf(e));
    nonMasteredCells := TStringList.Create;
    try
        if not Assigned(landscape) then begin
            AddLandscape(e);
            if not IsMaster(e) then begin
                nonMasteredCells.Add(Name(e));
            end else AddMessage('Added empty landscape data to ' + Name(e));
        end;
    except
        on E: Exception do begin
            AddMessage('Error adding landscape data to ' + Name(e) + ': ' + E.Message);
            Result := 1;
            Exit;
        end;
    finally
        ListStringsInStringList(nonMasteredCells);
        nonMasteredCells.Free;
    end;
    Result := 0;
end;

procedure AddLandscape(cell: IInterface);
{
    Adds empty landscape data to CELL record.
    If Temporary group does not exist, it creates it.
    Please check if LAND record already exists before calling this procedure.
}
var
    landscape, cellchild, vhgt, DataFlags, f, wrld: IInterface;
    landHeight, waterHeight: Double;
begin
    cellchild := FindChildGroup(ChildGroup(cell), 9, cell); // get Temporary group of cell
    f := GetFile(cell); // get file of CELL record
    if not Assigned(cellchild) then begin // if Temporary group does not exist, create it
        cellchild := Add(cell, 'Temporary', True);
    end;
    landscape := Add(cellchild, 'LAND', True); // add LAND record to Temporary group
    vhgt := Add(landscape, 'VHGT', True); // add VHGT subrecord to CELL record
    ElementAssign(vhgt, LowInteger, nil, False); // assign empty VHGT subrecord
    DataFlags := Add(landscape, 'DATA', True); // add DATA subrecord to LAND record
    ElementAssign(DataFlags, HighInteger, nil, False); // assign empty DATA subrecord
    SetElementNativeValues(DataFlags, 'Has Vertex Normals/Height Map', 1);
    SetElementNativeValues(DataFlags, 'Unknown 4', 1);
    SetElementNativeValues(DataFlags, 'Auto-Calc Normals', 1);
    wrld := WinningOverride(LinksTo(ElementByIndex(cell, 0)));
    landHeight := GetElementNativeValues(wrld, 'DNAM\Default Land Height');
    waterHeight := GetElementNativeValues(wrld, 'DNAM\Default Water Height');
    if waterHeight > landHeight then begin
        SetElementNativeValues(cell, 'DATA\No LOD Water', 1);
    end;
end;

// returns LAND record for CELL record
function GetLandscapeForCell(cell: IInterface): IInterface;
var
  cellchild, r: IInterface;
  i: integer;
begin
  cellchild := FindChildGroup(ChildGroup(cell), 9, cell); // get Temporary group of cell
  for i := 0 to Pred(ElementCount(cellchild)) do begin
    r := ElementByIndex(cellchild, i);
    if Signature(r) = 'LAND' then begin
      Result := r;
      Exit;
    end;
  end;
end;

procedure ListStringsInStringList(sl: TStringList);
{
    Given a TStringList, add a message for all items in the list.
}
var
    i: integer;
begin
    AddMessage('=======================================================================================');
    for i := 0 to Pred(sl.Count) do AddMessage(sl[i]);
    AddMessage('=======================================================================================');
end;

end.
