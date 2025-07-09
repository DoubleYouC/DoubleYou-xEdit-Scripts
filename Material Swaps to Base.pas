{
    Material Swaps to Base
    Placed references that have a material swap or a color remap will also have the material swap applied to the base record.
    If the base record does not have a material swap, a new base record will be created with the material swap applied.
    At startup, it collects all base records to ensure that duplicates are not unnecessarily created.
}
unit MaterialSwapsToBase;

const
    ValidSignatures = 'STAT,SCOL,MSTT';

var
    joBases: TJsonObject;

function Initialize: integer;
{
    This function is called at the beginning.
}
begin
    Result := 0;
    joBases := TJsonObject.Create;
    CollectRecords;
end;

function Finalize: integer;
{
    This function is called at the end.
}
begin
    Result := 0;
    joBases.Free;
end;

procedure CollectRecords;
{
    This procedure is used to collect all the base records that we need.
}
var
    i, j, idx: integer;
    f: IwbFile;
    g: IwbGroupRecord;
    r: IwbMainRecord;
    recordId, signature, model, matswap, colorRemap: string;
    slRecords: TStringList;
begin
    slRecords := TStringList.Create;
    //Iterate over all files.
    try
        for i := 0 to Pred(FileCount) do begin
            f := FileByIndex(i);

            //STAT
            g := GroupBySignature(f, 'STAT');
            for j := 0 to Pred(ElementCount(g)) do begin
                r := WinningOverride(ElementByIndex(g, j));
                recordId := GetFileName(r) + #9 + ShortName(r);
                idx := slRecords.IndexOf(recordId);
                if idx > -1 then continue
                slRecords.Add(recordId);
                AddBaseRecordToJson(r, 'STAT');
            end;

            //SCOL
            g := GroupBySignature(f, 'SCOL');
            for j := 0 to Pred(ElementCount(g)) do begin
                r := WinningOverride(ElementByIndex(g, j));
                recordId := GetFileName(r) + #9 + ShortName(r);
                idx := slRecords.IndexOf(recordId);
                if idx > -1 then continue
                slRecords.Add(recordId);
                AddBaseRecordToJson(r, 'SCOL');
            end;

            //MSTT
            g := GroupBySignature(f, 'MSTT');
            for j := 0 to Pred(ElementCount(g)) do begin
                r := WinningOverride(ElementByIndex(g, j));
                recordId := GetFileName(r) + #9 + ShortName(r);
                idx := slRecords.IndexOf(recordId);
                if idx > -1 then continue
                slRecords.Add(recordId);
                AddBaseRecordToJson(r, 'MSTT');
            end;

            // //FURN
            // g := GroupBySignature(f, 'FURN');
            // for j := 0 to Pred(ElementCount(g)) do begin
            //     r := WinningOverride(ElementByIndex(g, j));
            //     recordId := GetFileName(r) + #9 + ShortName(r);
            //     idx := slRecords.IndexOf(recordId);
            //     if idx > -1 then continue
            //     slRecords.Add(recordId);
            //     AddBaseRecordToJson(r, 'FURN');
            // end;

            // //ACTI
            // g := GroupBySignature(f, 'ACTI');
            // for j := 0 to Pred(ElementCount(g)) do begin
            //     r := WinningOverride(ElementByIndex(g, j));
            //     recordId := GetFileName(r) + #9 + ShortName(r);
            //     idx := slRecords.IndexOf(recordId);
            //     if idx > -1 then continue
            //     slRecords.Add(recordId);
            //     AddBaseRecordToJson(r, 'ACTI');
            // end;

            // //DOOR
            // g := GroupBySignature(f, 'DOOR');
            // for j := 0 to Pred(ElementCount(g)) do begin
            //     r := WinningOverride(ElementByIndex(g, j));
            //     recordId := GetFileName(r) + #9 + ShortName(r);
            //     idx := slRecords.IndexOf(recordId);
            //     if idx > -1 then continue
            //     slRecords.Add(recordId);
            //     AddBaseRecordToJson(r, 'DOOR');
            // end;
        end;
    finally
        slRecords.Free;
    end;
end;

procedure AddBaseRecordToJson(r: IwbMainRecord; signature: string);
{
    Add a base record to the JSON object.
}
var
    model, matswap: string;
begin
    model := GetElementEditValues(r, 'Model\MODL');
    if model = '' then Exit;
    matswap := GetElementEditValues(r, 'Model\MODS');
    if joBases.O[signature].O[model].Contains(matswap) then begin
        //AddMessage('Skipping duplicate base record: ' + IntToHex(GetLoadOrderFormID(r), 8) + ' appears to be the same as ' + joBases.O[signature].O[model].O[matswap].S['formid']);
        Exit;
    end;
    //Signature --> Model --> Material Swap --> formid
    joBases.O[signature].O[model].O[matswap].S['formid'] := IntToHex(GetLoadOrderFormID(r), 8);
end;

function MakeNewBaseRecord(e: IInterface; base: IwbMainRecord; refMatSwap: IwbElement; matswap, model, baseSignature: string): IwbMainRecord;
{
    Create a new base record with the material swap applied.
}
var
    newBaseForm: IwbMainRecord;
begin
    newBaseForm := wbCopyElementToFile(base, GetFile(e), True, True);
    SetElementEditValues(newBaseForm, 'EDID', GetElementEditValues(base, 'EDID') + '_' + GetElementEditValues(refMatSwap, 'EDID'));
    SetElementEditValues(newBaseForm, 'Model\MODS', matswap);
    joBases.O[baseSignature].O[model].O[matswap].S['formid'] := IntToHex(GetLoadOrderFormID(newBaseForm), 8);
    Result := newBaseForm;
end;

function Process(e: IInterface): integer;
var
    base, newBaseForm: IwbMainRecord;
    baseMatSwap, refMatSwap: IwbElement;
    model, matswap, newBase, baseSignature, refMatSwapFormid, baseMatSwapFormid: string;
begin
    Result := 0;

    if (Signature(e) <> 'REFR') then Exit;

    base := WinningOverride(LinksTo(ElementBySignature(e, 'NAME')));
    baseSignature := Signature(base);
    if Pos(baseSignature, ValidSignatures) = 0 then Exit;

    baseMatSwap := LinksTo(ElementByPath(base, 'Model\MODS'));
    refMatSwap := LinksTo(ElementByPath(e, 'XMSP'));
    refMatSwapFormid := IntToHex(GetLoadOrderFormID(refMatSwap), 8);
    baseMatSwapFormid := IntToHex(GetLoadOrderFormID(baseMatSwap), 8);

    if (assigned(refMatSwap) and not assigned(baseMatSwap)) or ((assigned(refMatSwap) and assigned(baseMatSwap)) and (baseMatSwapFormid <> refMatSwapFormid)) then begin

        // Check joBases for the base record
        model := GetElementEditValues(base, 'Model\MODL');
        matswap := GetElementEditValues(e, 'XMSP');
        if joBases.O[Signature(base)].O[model].Contains(matswap) then begin
            newBase := joBases.O[Signature(base)].O[model].O[matswap].S['formid'];
        end else begin
            // Create a new base record with the material swap applied if one does not exist
            newBaseForm := MakeNewBaseRecord(e, base, refMatSwap, matswap, model, baseSignature);
            if not Assigned(newBaseForm) then begin
                AddMessage('Could not create new base record for ' + Name(e));
                Result := 1;
                Exit;
            end;
            newBase := IntToHex(GetLoadOrderFormID(newBaseForm), 8);
        end;

        // Set the new base record for the reference
        SetElementEditValues(e, 'NAME', newBase);

        AddMessage('Updated ' + ShortName(e) + ' to use base record ' + newBase + ' with material swap ' + matswap);
    end;
end;

end.