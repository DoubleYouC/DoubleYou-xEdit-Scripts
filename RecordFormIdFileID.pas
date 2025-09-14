{
  New script template, only shows processed records
  Assigning any nonzero value to Result will terminate script
}
unit DoStuff;


// Called before processing
// You can remove it if script doesn't require initialization code
function Initialize: integer;
begin
    Result := 0;

end;

// called for every record selected in xEdit
function Process(e: IInterface): integer;
begin
    Result := 0;
    //AddMessage('"' + RecordFormIdFileId(e) + '": -32,');
    AddMessage(RecordFormIdFileId(e));
    //AddMessage(ShortName(GetRecordFromFormIdFileId(RecordFormIdFileId(e))));
end;


// Called after processing
// You can remove it if script doesn't require finalization code
function Finalize: integer;
begin
    Result := 0;

end;


function TrimRightChars(s: string; chars: integer): string;
{
    Returns right string - chars
}
begin
    Result := RightStr(s, Length(s) - chars);
end;

function TrimLeftChars(s: string; chars: integer): string;
{
    Returns left string - chars
}
begin
    Result := LeftStr(s, Length(s) - chars);
end;

function RecordFormIdFileId(e: IwbElement): string;
{
    Returns the record ID of an element.
}
begin
    Result := IntToHex(FormID(e), 8) + ':' + GetFileName(GetFile(MasterOrSelf(e)));
end;

function GetRecordFromFormIdFileId(recordId: string): IwbElement;
{
    Returns the record from the given formid:filename.
}
var
    colonPos, recordFormId: integer;
    f: IwbFile;
begin
    colonPos := Pos(':', recordId);
    recordFormId := StrToInt('$' + Copy(recordId, 1, Pred(colonPos)));
    f := FileByName(Copy(recordId, Succ(colonPos), Length(recordId)));
    Result := RecordByFormID(f, recordFormId, False);
end;

end.