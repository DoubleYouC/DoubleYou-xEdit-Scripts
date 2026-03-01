{
  New script template, only shows processed records
  Assigning any nonzero value to Result will terminate script
}
unit FixScrapping;

var
    joMasterBaseObjects: TJsonObject;
    fileHere: IwbFile;


// Called before processing
// You can remove it if script doesn't require initialization code
function Initialize: integer;
var
    i, j: integer;
    sig, recordid, edid: string;
    f: IwbFile;
    g: IwbGroupRecord;
    r: IwbElement;
begin
    Result := 0;
    joMasterBaseObjects := TJsonObject.Create;
    for i := 0 to Pred(FileCount) do begin
        f := FileByIndex(i);
        sig := 'MSTT';
        g := GroupBySignature(f, sig);
        for j := 0 to Pred(ElementCount(g)) do begin
            r := ElementByIndex(g, j);
            if not IsWinningOverride(r) then continue;
            recordid := RecordFormIdFileId(r);
            edid := GetElementEditValues(r, 'EDID');
            joMasterBaseObjects.O[sig].O[edid].S['RecordID'] := recordid;
        end;
    end;
end;

// called for every record selected in xEdit
function Process(e: IInterface): integer;
var
    edid, recordid, formlistRecordId, replacementRecordID: string;
    i: integer;
    base, r: IInterface;
begin
    Result := 0;
    fileHere := GetFile(e);
    edid := StringReplace(GetElementEditValues(e, 'EDID'), 'winterReplacement_', '', [rfIgnoreCase]);
    replacementRecordID := RecordFormIdFileId(e);
    recordid := joMasterBaseObjects.O[Signature(e)].O[edid].S['RecordID'];
    base := GetRecordFromFormIdFileId(recordid);
    //Addmessage(ShortName(base));
    for i := 0 to Pred(ReferencedByCount(base)) do begin
        r := ReferencedByIndex(base, i);
        if Signature(r) = 'FLST' then begin
            formlistRecordId := RecordFormIdFileId(r);
            joMasterBaseObjects.O['Formlists'].O[formlistRecordId].A['add'].Add(replacementRecordID);
            //AddMessage(ShortName(e) + #9 + ShortName(r));
        end;
    end;
end;


// Called after processing
// You can remove it if script doesn't require finalization code
function Finalize: integer;
var
    i, j: integer;
    formlistRecordId, replacementRecordID: string;
    f, r, fl: IwbElement;
begin
    Result := 0;
    for i := 0 to Pred(joMasterBaseObjects.O['Formlists'].Count) do begin
        formlistRecordId := joMasterBaseObjects.O['Formlists'].Names[i];
        fl := wbCopyElementToFile(GetRecordFromFormIdFileId(formlistRecordId), fileHere, False, True);
        for j := 0 to Pred(joMasterBaseObjects.O['Formlists'].O[formlistRecordId].A['add'].Count) do begin
            replacementRecordID := joMasterBaseObjects.O['Formlists'].O[formlistRecordId].A['add'].S[j];
            AddRefToMyFormlist(GetRecordFromFormIdFileId(replacementRecordID), fl);
        end;
    end;


    joMasterBaseObjects.Free;

end;

procedure AddRefToMyFormlist(r, frmlst: IwbElement);
var
    formids, lnam: IwbElement;
begin
    if not ElementExists(frmlst, 'FormIDs') then begin
        formids := Add(frmlst, 'FormIDs', True);
        lnam := ElementByIndex(formids, 0);
    end
    else begin
        formids := ElementByName(frmlst, 'FormIDs');
        lnam := ElementAssign(formids, HighInteger, nil, False);
    end;
    SetEditValue(lnam, ShortName(r));
end;

function RecordFormIdFileId(e: IwbElement): string;
{
    Returns the record ID of an element.
}
begin
    e := MasterOrSelf(e);
    Result := IntToHex(FormID(e), 8) + ':' + GetFileName(GetFile(e));
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