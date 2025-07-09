{
  New script template, only shows processed records
  Assigning any nonzero value to Result will terminate script
}
unit DoStuff;

const
  signatures = 'STAT,SCOL';
  multireflod = '001C9A49';
  multireflodremove = '001CCFD3';

// Called before processing
// You can remove it if script doesn't require initialization code
function Initialize: integer;
begin
  Result := 0;
end;

// called for every record selected in xEdit
function Process(e: IInterface): integer;
var
  previousOverride, base, basecopy: IInterface;
  layer, lod: String;
begin
  Result := 0;

  if Signature(e) = 'ACHR' then begin
    Remove(e);
    Exit;
  end;

  if Signature(e) <> 'REFR' then Exit;

  // if GetIsDeleted(e) then begin
  //   AddMessage('Record ' + Name(e) + ' is deleted, removing.');
  //   Remove(e);
  //   Exit;
  // end;

  // if GetIsCleanDeleted(e) then begin
  //   AddMessage('Record ' + Name(e) + ' is clean deleted, removing.');
  //   Remove(e);
  //   Exit;
  // end;

  base := WinningOverride(LinksTo(ElementBySignature(e, 'NAME')));
  if not Assigned(base) then begin
    AddMessage('No base record found for ' + Name(e));
    Remove(e);
    Exit;
  end;

  if Pos(Signature(base), signatures) = 0 then begin
    AddMessage('Base record ' + Name(base) + ' is not a valid type: ' + Signature(base));
    Remove(e);
    Exit;
  end;

  if not StrToBool(GetElementEditValues(base, 'Record Header\Record Flags\Has Distant LOD')) then begin
    AddMessage('Base record ' + Name(base) + ' does not have distant LOD.');
    Remove(e);
    Exit;
  end;

  lod := GetElementEditValues(base, 'MNAM\LOD #0 (Level 0)\Mesh');
  if lod = '' then begin
    AddMessage('Base record ' + Name(base) + ' does not have a LOD mesh.');
    Remove(e);
    Exit;
  end;

  if GetFile(base) <> GetFile(e) then begin
    basecopy := wbCopyElementToFile(base, GetFile(e), False, True);
    SetElementEditValues(basecopy, 'Model\MODL', lod);
  end else begin
    SetElementEditValues(base, 'Model\MODL', lod);
  end;

  // previousOverride := MasterOrSelf(e);
  // layer := GetElementEditValues(previousOverride, 'XLYR');
  // if layer = '00000000' then begin
  //   RemoveElement(e, 'XLYR');
  // end else begin
  //   SetElementEditValues(e, 'XLYR', GetElementEditValues(previousOverride, 'XLYR'));
  // end;

  // if not CheckForLinkedReference(e, '00195411', multireflod) then AddLinkedReference(e, '00195411', multireflod);
  // if CheckForLinkedReference(e, '00195411', multireflodremove) then RemoveLinkedReference(e, '00195411', multireflodremove);

end;

function CheckForLinkedReference(e: IInterface; keyword, ref: String): Boolean;
{
  Check if a linked reference with the given keyword and ref exists.
}
var
    linkedrefs, lref: IInterface;
    i: Integer;
begin
    Result := False;
    if not ElementExists(e, 'Linked References') then Exit;
    linkedrefs := ElementByPath(e, 'Linked References');
    for i := 0 to Pred(ElementCount(linkedrefs)) do begin
        lref := ElementByIndex(linkedrefs, i);
        if (IntToHex(GetLoadOrderFormID(LinksTo(ElementByPath(lref, 'Keyword/Ref'))), 8) = keyword) and (IntToHex(GetLoadOrderFormID(LinksTo(ElementByPath(lref, 'Ref'))), 8) = ref) then begin
            Result := True;
        end;
        if IntToHex(GetLoadOrderFormID(LinksTo(ElementByPath(lref, 'Keyword/Ref'))), 8) = '00000000' then begin
            AddMessage('Linked Reference with Keyword/Ref 00000000 found in ' + FullPath(e));
            Continue;
        end;
    end;
end;

function AddLinkedReference(e: IInterface; keyword, ref: String): Integer;
{
  Add a linked reference.
}
var
  el, linkedrefs, lref: IInterface;
  i: Integer;
begin
  Result := 0;
  if not ElementExists(e, 'Linked References') then begin
    linkedrefs := Add(e, 'Linked References', True);
    lref := ElementByIndex(linkedrefs, 0);
    SetElementEditValues(lref, 'Keyword/Ref', keyword);
    SetElementEditValues(lref, 'Ref', ref);
  end
  else
    begin
      linkedrefs := ElementByPath(e, 'Linked References');
      lref := ElementAssign(linkedrefs, HighInteger, nil, False);
      SetElementEditValues(lref, 'Keyword/Ref', keyword);
      SetElementEditValues(lref, 'Ref', ref);
    end;
end;

function RemoveLinkedReference(e: IInterface; keyword, ref: String):  Integer;
{
  Remove a linked reference.
}
var
  linkedrefs, lref: IInterface;
  i: Integer;
begin
  Result := 0;
  if not ElementExists(e, 'Linked References') then Exit;

  linkedrefs := ElementByPath(e, 'Linked References');
  for i := Pred(ElementCount(linkedrefs)) downto 0 do begin
    lref := ElementByIndex(linkedrefs, i);
    if (IntToHex(GetLoadOrderFormID(LinksTo(ElementByPath(lref, 'Keyword/Ref'))), 8) = keyword) and
       (IntToHex(GetLoadOrderFormID(LinksTo(ElementByPath(lref, 'Ref'))), 8) = ref) then begin
      Remove(lref);
    end;
  end;
end;

// Called after processing
// You can remove it if script doesn't require finalization code
function Finalize: integer;
begin
  Result := 0;
end;

function StrToBool(str: string): boolean;
{
    Given a string, return a boolean.
}
begin
    if (str = 'true') or (str = '1') then Result := True else Result := False;
end;

function GetIsCleanDeleted(r: IInterface): Boolean;
{
    Checks to see if a reference has an XESP set to opposite of the PlayerRef
}
begin
    Result := False;
    if not ElementExists(r, 'XESP') then Exit;
    if not GetElementEditValues(r, 'XESP\Flags\Set Enable State to Opposite of Parent') = '1' then Exit;
    if GetElementEditValues(r, 'XESP\Reference') <> 'PlayerRef [PLYR:00000014]' then Exit;
    Result := True;
end;

end.