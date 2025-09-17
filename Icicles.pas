{
  New script template, only shows processed records
  Assigning any nonzero value to Result will terminate script
}
unit userscript;

const
  // epsilon to use for CompareValue calls
  // between positions and rotations, positions have more significant decimals (6), so this is set
  // to compliment that
  EPSILON = 0.000001;
  sIciclesFileName = 'icicles.esm';

var
  fRotation, fScale, fOffsetX, fOffsetY, fOffsetZ: Double;
  count: integer;
  IciclesMainFile, iCurrentPlugin: IInterface;
  slIciclesOn, slChanceNone: TStringList;
  tlIciclesCells, tlStats, tlStatsIciclesOn: TList;

// Called before processing
// You can remove it if script doesn't require initialization code
function Initialize: integer;
begin
  CreateObjects;
  count := 0;

  if not LoadPlugins then begin
    Result := 1;
    Exit;
  end;

  if not LoadFormLists then begin
    Result := 1;
    Exit;
  end;

  CollectRecords;
  ProcessStats;
  ProcessStatsIciclesOn;

  Result := 0;
end;

procedure CreateObjects;
{
    Create objects.
}
begin
  slIciclesOn := TStringList.Create;
  slChanceNone := TStringList.Create;
  slChanceNone.Add('true');
  slChanceNone.Add('false');
  tlIciclesCells := TList.Create;
  tlStats := TList.Create;
  tlStatsIciclesOn := TList.Create;
end;

// Called after processing
// You can remove it if script doesn't require finalization code
function Finalize: integer;
begin
  AddMessage('Added ' + IntToStr(count)+ ' icicles.');
  slIciclesOn.Free;
  slChanceNone.Free;
  tlIciclesCells.Free;
  tlStats.Free;
  tlStatsIciclesOn.Free;
  Result := 0;
end;

function LoadPlugins: boolean;
{
  Load plugins
}
var
  i: integer;
  f: string;
begin
  for i := 0 to Pred(FileCount) do begin
    f := GetFileName(FileByIndex(i));
    if SameText(f, sIciclesFileName) then
      IciclesMainFile := FileByIndex(i)
  end;

  iCurrentPlugin := IciclesMainFile;

  if not Assigned(IciclesMainFile) then begin
    MessageDlg('icicles.esm is not loaded: ' + IciclesMainFile, mtError, [mbOk], 0);
    Result := False;
    Exit;
  end;
  Result := True;
end;

function LoadFormLists: boolean;
{
  Load the formlists in Seasons
}
var
  formLists, formids: IInterface;
  i, n, C: Integer;
  f, editorID, s: String;
begin
  formLists := GroupBySignature(IciclesMainFile, 'FLST');
  if not Assigned(formLists) then begin
    AddMessage('No Formlists found');
    Result := False;
    Exit;
  end;

  for i := 0 to Pred(ElementCount(formLists)) do begin
    //AddMessage(Name(ElementByIndex(formLists, i)));
    formids := ElementByName(WinningOverride(ElementByIndex(formLists, i)), 'FormIDs');
    editorID := GetElementEditValues(ElementByIndex(formLists, i), 'EDID');
    if editorID = 'IciclesOn' then
      C := 1
    else if editorID = 'IciclesCells' then
      C := 2
    else
      C := 99;
    //AddMessage(editorID);
    for n := 0 to Pred(ElementCount(formids)) do begin
      s := GetEditValue(ElementByIndex(formids, n));
      //AddMessage(s);
      Case C of
        1 : slIciclesOn.Add(s);
        2 : tlIciclesCells.Add(LinksTo(ElementByIndex(formids, n)));
      else AddMessage('Skipped formlist: ' + s);
      end;
    end;
  end;
  Result := True;
end;

procedure CollectRecords;
var
  i, j, idx: integer;
  recordId: string;
  f, g, r: IInterface;
  slStats: TStringList;
begin
  slStats := TStringList.Create;
  try
    for i := 0 to Pred(FileCount) do begin
      f := FileByIndex(i);
      //STAT
      g := GroupBySignature(f, 'STAT');
      for j := 0 to Pred(ElementCount(g)) do begin
          r := WinningOverride(ElementByIndex(g, j));
          recordId := GetFileName(r) + #9 + ShortName(r);
          idx := slStats.IndexOf(recordId);
          if idx > -1 then continue
          slStats.Add(recordId);
          tlStats.Add(r);
      end;
    end;
  finally
    slStats.Free;
  end;
end;

procedure ProcessStats;
var
  i, idx: integer;
  r, s: IInterface;
begin
  for i := 0 to Pred(tlStats.Count) do begin
    s := ObjectToElement(tlStats[i]);
    idx := slIciclesOn.IndexOf(Name(s));
    if idx = -1 then continue;
    tlStatsIciclesOn.Add(s);
  end;
end;

procedure ProcessStatsIciclesOn;
var
  io, si: integer;
  r, s, rCell: IInterface;
begin
  for io := 0 to Pred(tlStatsIciclesOn.Count) do begin
    s := ObjectToElement(tlStatsIciclesOn[io]);
    for si := Pred(ReferencedByCount(s)) downto 0 do begin
      r := ReferencedByIndex(s, si);
      if Signature(r) <> 'REFR' then continue;
      if not IsWinningOverride(r) then continue;
      if GetIsDeleted(r) then continue;
      if GetIsCleanDeleted(r) then continue;
      rCell := WinningOverride(LinksTo(ElementByIndex(r, 0)));
      try
        if GetElementEditValues(rCell, 'DATA - Flags\Is Interior Cell') = 1 then continue;
      except
        AddMessage('Skipped problem record: '+ GetFileName(rCell) + #9 + Name(rCell));
        continue;
      end;
      //if we made it this far, the reference is one we want to add icicles to.
      AddIciclesToRef(r, s, rCell);
    end;
  end;
end;

procedure AddIciclesToRef(r, s, rCell: IInterface);
var
  x, y, z, xi, yi, zi, rx, ry, rz, rzi, scale, scalei, raw_x, raw_y, raw_z: double;
  i, idx: integer;
  packinCell, refs, ri, rWrld, nCell, cell, n: IInterface;
  base: string;
  c: TwbGridCell;
begin
  x := GetElementNativeValues(r, 'DATA\Position\X');
  y := GetElementNativeValues(r, 'DATA\Position\Y');
  z := GetElementNativeValues(r, 'DATA\Position\Z');

  rx := GetElementNativeValues(r, 'DATA\Rotation\X');
  ry := GetElementNativeValues(r, 'DATA\Rotation\Y');
  //if rx + ry > 0 then Exit;
  rz := GetElementNativeValues(r, 'DATA\Rotation\Z');

  if ElementExists(r, 'XSCL') then scale := GetElementNativeValues(r, 'XSCL - Scale') else scale := 1;
  fScale := scale;

  rWrld := WinningOverride(LinksTo(ElementByIndex(rCell, 0)));

  AddRequiredElementMasters(rCell, iCurrentPlugin, False, True);
  AddRequiredElementMasters(rWrld, iCurrentPlugin, False, True);

  //get pack in cell
  idx := slIciclesOn.IndexOf(Name(s));
  packinCell := ObjectToElement(tlIciclesCells[idx]);
  //AddMessage(Name(packinCell));
  refs := FindChildGroup(ChildGroup(packinCell), 9, packinCell);

  for i := Pred(ElementCount(refs)) downto 0 do begin
    ri := ElementByIndex(refs, i);
    base := GetElementEditValues(ri, 'NAME');
    if not ContainsText(base, 'FloraIcicle') then continue;
    Shuffle(slChanceNone);
    if StrToBool(slChanceNone[0]) then continue; //Adds 50-50 chance none
    //AddMessage(Name(ri));
    count := count + 1;

    xi := GetElementNativeValues(ri, 'DATA\Position\X');
    yi := GetElementNativeValues(ri, 'DATA\Position\Y');
    zi := GetElementNativeValues(ri, 'DATA\Position\Z');

    //RotatePoint(xi, yi, rz);

    rotate_position(
      xi, yi, zi,                      // initial position
      rx, ry, rz,              // rotation to apply - x y z
      raw_x, raw_y, raw_z           // (output) raw final position
    );

    xi := raw_x * scale + x;
    yi := raw_y * scale + y;
    zi := raw_z * scale + z;

    // rotate_rotation(   // no need since icicles will always be straight down.
    //   rxi, ryi, rzi,                   // initial rotation
    //   rx, ry, rz,              // rotation to apply - x y z
    //   raw_x, raw_y, raw_z           // (output) raw rotation
    // );

    rzi := normalize_angle(GetElementNativeValues(ri, 'DATA\Rotation\Z') + rz);
    if ElementExists(ri, 'XSCL') then scalei := GetElementNativeValues(ri, 'XSCL - Scale') * scale else scalei := scale;
    AddMessage(ShortName(rCell) + #9 + IntToStr(xi) + ' ' + IntToStr(yi) + ' ' + IntToStr(zi) + ' Scale: ' + IntToStr(scalei));

    nCell := wbCopyElementToFile(rCell, iCurrentPlugin, False, True);
    wbCopyElementToFile(rWrld, iCurrentPlugin, False, True);
    n := Add(nCell, 'REFR', True);
    SetElementEditValues(n, 'Name', base);
    SetElementNativeValues(n, 'XSCL - Scale', scalei);
    SetElementNativeValues(n, 'DATA\Position\X', xi);
    SetElementNativeValues(n, 'DATA\Position\Y', yi);
    SetElementNativeValues(n, 'DATA\Position\Z', zi);
    SetElementNativeValues(n, 'DATA\Rotation\X', 0);
    SetElementNativeValues(n, 'DATA\Rotation\Y', 0);
    SetElementNativeValues(n, 'DATA\Rotation\Z', rzi);
    AddLinkedReference(n, 'WorkshopStackedItemParentKEYWORD [KYWD:001C5EDD]', Name(r));

    c := wbPositionToGridCell(GetPosition(n));
    cell := GetCellFromWorldspace(rWrld, c.X, c.Y);
    if not Assigned(cell) then cell := nCell;
    SetElementEditValues(n, 'Cell', Name(cell));
    SetIsPersistent(n, False);

  end;
end;

// normalize an angle (in degrees) to [0.0, 360.0)
function normalize_angle(angle: double): double;
const
  NORMALIZER = 360.0;
begin
  // FMod(a,b) returns a value between -Abs(b) and Abs(b) exclusive, so need to add b and do it again
  // to fully catch negative angles
  Result := FMod(FMod(angle, NORMALIZER) + NORMALIZER, NORMALIZER);
end;

// clamp given value d between min and max (inclusive)
function clamp(d, min, max: double): double;
begin
  if (CompareValue(d, min, EPSILON) = LessThanValue) then begin
    Result := min;
  end else if (CompareValue(d, max, EPSILON) = GreaterThanValue) then begin
    Result := max;
  end else begin
    Result := d;
  end;
end;


procedure quaternion_to_euler(
  qw, qx, qy, qz: double;                    // input quaternion
  var return_x, return_y, return_z: double;  // euler angle (in degrees)
);
var
  p0, p1, p2, p3: double;              // variables representing dynamically-ordered quaternion components
  singularity_check: double;           // contains value used for the singularity check
  e: integer;                          // variable representing sign used in angle calculations
  euler_order: array[0..2] of double;  // holds mapping between rotation sequence angles and output angles
  euler_angle: array[0..2] of double;  // output angles
begin
  // map quaternion components to generic p-variables, and set the sign
  p0 := qw;

  //rotation sequence
  p1 := qz; p2 := qy; p3 := qx; e :=  1;

  // create mapping between the euler angle and the rotation sequence
  euler_order[0] := 2; euler_order[1] := 1; euler_order[2] := 0;

  // calculate the value to be used to check for singularities
  singularity_check := 2.0 * (p0 * p2 - e * p1 * p3);

  // calculate second rotation angle, clamping it to prevent ArcSin from erroring
  euler_angle[euler_order[1]] := ArcSin(clamp(singularity_check, -1.0, 1.0));

  // a singularity exists when the second angle in a rotation sequence is at +/-90 degrees
  if (CompareValue(Abs(singularity_check), 1.0, EPSILON) = LessThanValue) then begin
    euler_angle[euler_order[0]] := ArcTan2(2.0 * (p0 * p1 + e * p2 * p3), 1.0 - 2.0 * (p1 * p1 + p2 * p2));
    euler_angle[euler_order[2]] := ArcTan2(2.0 * (p0 * p3 + e * p1 * p2), 1.0 - 2.0 * (p2 * p2 + p3 * p3));
  end else begin
    // when a singularity is detected, the third angle basically loses all meaning so is set to 0
    euler_angle[euler_order[0]] := ArcTan2(2.0 * (p0 * p1 - e * p2 * p3), 1.0 - 2.0 * (p1 * p1 + p3 * p3));
    euler_angle[euler_order[2]] := 0.0;
  end;

  // convert results to degrees and then normalize them
  return_x := normalize_angle(RadToDeg(euler_angle[0]));
  return_y := normalize_angle(RadToDeg(euler_angle[1]));
  return_z := normalize_angle(RadToDeg(euler_angle[2]));
end;

procedure euler_to_quaternion(
  x, y, z: double;                                         // euler angle in degrees
  var return_qw, return_qx, return_qy, return_qz: double;  // quaternion components
);
var
  cos_x, cos_y, cos_z, sin_x, sin_y, sin_z: double;
  sign_w, sign_x, sign_y, sign_z: integer;
begin
  // normalize angles and convert them to radians
  x := DegToRad(normalize_angle(x));
  y := DegToRad(normalize_angle(y));
  z := DegToRad(normalize_angle(z));

  // calculate cosine and sine of the various angles once instead of multiple times
  cos_x := Cos(x / 2.0); cos_y := Cos(y / 2.0); cos_z := Cos(z / 2.0);
  sin_x := Sin(x / 2.0); sin_y := Sin(y / 2.0); sin_z := Sin(z / 2.0);

  // use the rotation sequence to determine what signs are used when calculating quaternion components
  // Rotation sequence
  sign_w :=  1; sign_x := -1; sign_y :=  1; sign_z := -1;

  // calculate the quaternion components
  return_qw := cos_x * cos_y * cos_z + sign_w * sin_x * sin_y * sin_z;
  return_qx := sin_x * cos_y * cos_z + sign_x * cos_x * sin_y * sin_z;
  return_qy := cos_x * sin_y * cos_z + sign_y * sin_x * cos_y * sin_z;
  return_qz := cos_x * cos_y * sin_z + sign_z * sin_x * sin_y * cos_z;
end;

// multiply two quaternions together - note that quaternion multiplication is NOT commutative, so
// (q1 * q2) != (q2 * q1)
procedure quaternion_multiply(
  qw1, qx1, qy1, qz1: double;                              // input quaternion 1
  qw2, qx2, qy2, qz2: double;                              // input quaternion 2
  var return_qw, return_qx, return_qy, return_qz: double;  // result quaternion
);
begin
  return_qw := qw1 * qw2 - qx1 * qx2 - qy1 * qy2 - qz1 * qz2;
  return_qx := qw1 * qx2 + qx1 * qw2 + qy1 * qz2 - qz1 * qy2;
  return_qy := qw1 * qy2 - qx1 * qz2 + qy1 * qw2 + qz1 * qx2;
  return_qz := qw1 * qz2 + qx1 * qy2 - qy1 * qx2 + qz1 * qw2;
end;

// compute the difference between two quaternions, q1 and q2, using the formula (q_result = q1' * q2),
// where q1' is the inverse (conjugate) of the first quaternion
procedure quaternion_difference(
  qw1, qx1, qy1, qz1: double;                              // first quaternion
  qw2, qx2, qy2, qz2: double;                              // second quaternion
  var return_qw, return_qx, return_qy, return_qz: double;  // difference quaternion
);
var
  qw1i, qx1i, qy1i, qz1i: double;  // inverse (conjugate) of the first quaternion
begin
  quaternion_inverse(  // calculate (q1')
    qw1, qx1, qy1, qz1,
    qw1i, qx1i, qy1i, qz1i
  );
  quaternion_multiply(  // calculate (q1' * q2)
    qw1i, qx1i, qy1i, qz1i,
    qw2, qx2, qy2, qz2,
    return_qw, return_qx, return_qy, return_qz
  );
end;

// get the inverse of a quaternion
procedure quaternion_inverse(
  qw, qx, qy, qz: double;                                  // input quaternion
  var return_qw, return_qx, return_qy, return_qz: double;  // inverted quaternion
);
begin
  return_qw := qw;
  return_qx := -qx;
  return_qy := -qy;
  return_qz := -qz;
end;

procedure rotate_position(
  vx, vy, vz: double;                           // initial position vector (x, y, z coordinates)
  rx, ry, rz: double;                           // rotation to apply (euler angle)
  var return_vx, return_vy, return_vz: double;  // final position vector (x, y, z coordinates)
);
var
  qx, qy, qz, qw: double;      // quaternion representing rotation to be applied
  qwv, qxv, qyv, qzv: double;  // quaternion representing the result of the vector/quaternion multiplication
begin
  euler_to_quaternion(
    rx, ry, rz,
    qw, qx, qy, qz
  );

  // everything i've read says this should be (q * v * q'), but only (q' * (v * q)) gives the correct
  // results *shrug*
  quaternion_multiply(  // calculate (v * q)
    0.0, vx, vy, vz,
    qw, qx, qy, qz,
    qwv, qxv, qyv, qzv
  );
  // instead of computing q', then multiplying that by (v * q) manually, we can compute the
  // difference between them and get the same result (because it's the same math)
  quaternion_difference(  // calculate (q' * (v * q))
    qw, qx, qy, qz,
    qwv, qxv, qyv, qzv,
    nil, return_vx, return_vy, return_vz  // the returned w component is irrelevant and so is discarded
  );
end;

// rotate a rotation (duh) via quaternion math (vs matrix math)
procedure rotate_rotation(
  x, y, z: double;                          // initial rotation (euler angle)
  rx, ry, rz: double;                       // rotation to apply (euler angle)
  var return_x, return_y, return_z: double  // final rotation (euler angle)
);
var
  qw1, qx1, qy1, qz1: double;  // quaternion representing initial rotation
  qw2, qx2, qy2, qz2: double;  // quaternion representing rotation to be applied
  qw3, qx3, qy3, qz3: double;  // quaternion representing final rotation
begin
  euler_to_quaternion(
    x, y, z,
    qw1, qx1, qy1, qz1
  );
  euler_to_quaternion(
    rx, ry, rz,
    qw2, qx2, qy2, qz2
  );

  // everything i've read says this should be (q2 * q1), but only (q1 * q2) gives the correct results
  // *shrug*
  quaternion_multiply(  // calculate (q1 * q2)
    qw1, qx1, qy1, qz1,
    qw2, qx2, qy2, qz2,
    qw3, qx3, qy3, qz3
  );

  quaternion_to_euler(
    qw3, qx3, qy3, qz3,
    return_x, return_y, return_z
  );
end;

// compute the difference between two rotations by converting them to quaternions, using the
// quaternion_difference function, and converting the result back to an euler angle
procedure rotation_difference(
  x1, y1, z1: double;                        // input rotation 1 (euler angle)
  x2, y2, z2: double;                        // input rotation 2 (euler angle)
  var return_x, return_y, return_z: double;  // output rotation (euler angle)
);
var
  qw1, qx1, qy1, qz1: double;  // quaternion representing rotation 1
  qw2, qx2, qy2, qz2: double;  // quaternion representing rotation 2
  qw3, qx3, qy3, qz3: double;  // quaternion representing the difference between the two rotations
begin
  euler_to_quaternion(
    x1, y1, z1,
    qw1, qx1, qy1, qz1
  );
  euler_to_quaternion(
    x2, y2, z2,
    qw2, qx2, qy2, qz2
  );
  quaternion_difference(
    qw1, qx1, qy1, qz1,
    qw2, qx2, qy2, qz2,
    qw3, qx3, qy3, qz3
  );
  quaternion_to_euler(
    qw3, qx3, qy3, qz3,
    return_x, return_y, return_z
  );
end;

function GetCellFromWorldspace(Worldspace: IInterface; GridX, GridY: integer): IInterface;
var
    blockidx, subblockidx, cellidx: integer;
    wrldgrup, block, subblock, cell: IInterface;
    Grid, GridBlock, GridSubBlock: TwbGridCell;
    LabelBlock, LabelSubBlock: Cardinal;
begin
    Grid := wbGridCell(GridX, GridY);
    GridSubBlock := wbSubBlockFromGridCell(Grid);
    LabelSubBlock := wbGridCellToGroupLabel(GridSubBlock);
    GridBlock := wbBlockFromSubBlock(GridSubBlock);
    LabelBlock := wbGridCellToGroupLabel(GridBlock);

    wrldgrup := ChildGroup(Worldspace);
    // iterate over Exterior Blocks
    for blockidx := 0 to Pred(ElementCount(wrldgrup)) do begin
        block := ElementByIndex(wrldgrup, blockidx);
        if GroupLabel(block) <> LabelBlock then Continue;
        // iterate over SubBlocks
        for subblockidx := 0 to Pred(ElementCount(block)) do begin
            subblock := ElementByIndex(block, subblockidx);
            if GroupLabel(subblock) <> LabelSubBlock then Continue;
            // iterate over Cells
            for cellidx := 0 to Pred(ElementCount(subblock)) do begin
                cell := ElementByIndex(subblock, cellidx);
                if (Signature(cell) <> 'CELL') or GetIsPersistent(cell) then Continue;
                if (GetElementNativeValues(cell, 'XCLC\X') = Grid.x) and (GetElementNativeValues(cell, 'XCLC\Y') = Grid.y) then begin
                    Result := cell;
                    Exit;
                end;
            end;
            Break;
        end;
        Break;
    end;
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

function AddLinkedReference(e: IInterface; keyword, ref: String): Integer;
{
  Add a linked reference.
}
var
  el, linkedrefs, lref: IInterface;
  i: Integer;
begin
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

procedure Shuffle(Strings: TStrings);
{
  Shuffles the order of strings.
}
var
  i: Integer;
begin
  for i := Strings.Count - 1 downto 1 do
    Strings.Exchange(i, Random(i + 1));
end;

function StrToBool(str: string): boolean;
{
    Given a string, return a boolean.
}
begin
    if (LowerCase(str) = 'true') or (str = '1') then Result := True else Result := False;
end;

end.