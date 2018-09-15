unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.Imaging.jpeg, DateUtils;

type
  TForm1 = class(TForm)
    Panel1: TPanel;
    Button2: TButton;
    Edit1: TEdit;
    Label1: TLabel;
    Button6: TButton;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    Button1: TButton;
    Button5: TButton;
    ComboBox1: TComboBox;
    Label2: TLabel;
    Timer1: TTimer;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Button10: TButton;
    CheckBox1: TCheckBox;
    Label6: TLabel;
    ComboBox2: TComboBox;
    Button3: TButton;
    Button4: TButton;
    Image1: TImage;
    Timer2: TTimer;
    Button7: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure ComboBox2Change(Sender: TObject);
    procedure Button10Click(Sender: TObject);
    procedure Timer2Timer(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

  TDifficulty = (Easy, Normal, Hard, ACE);

  TSdkType = (NormalSdk, X_Sdk, SuperSdk, ColorSdk);

  TSudoku = class
    Num: array[1..9, 1..9] of longint;
    Con: array[1..9, 1..9] of longint;
    draft: array[1..9, 1..9, 1..9] of boolean;
    SdkType: TSdkType;
    constructor Create;
    procedure CopyFrom(sd: TSudoku);
    function Equal(sd: TSudoku): boolean;
    procedure FillGrid(Row, Col, n: longint);
    procedure RenewDraft;
    procedure ResetDraft(b: boolean);
    procedure ClearSdk;
    function SolveSdk: longint;
    function NakedSingle: boolean;
    function HiddenSingle: boolean;
    procedure SimpleSolve;
    function DFSSolve(isMulti: boolean): boolean;
    procedure RemoveFromSdk(sd: TSudoku);
    function CheckValid: boolean;
    function CheckComplete: boolean;
    procedure GeneratePuzzle(dif: TDifficulty);
    function DFSGenerate(FillNum, BlockId: longint): boolean;
    function DFSBlanking(count: longint; dif: TDifficulty): boolean;
    function DFSDeepBlk(count: longint): boolean;
  end;

  TSdkPanel = class
    Cells: array[1..9, 1..9] of TPanel;
    Labels: array[1..9, 1..9] of TLabel;
    CurSdk: TSudoku;
    Left, Top: longint;
    Hight, Width: longint;
    CellHeight, CellWidth, LineWidth: longint;
    constructor Create(cellh, cellw: longint);
    procedure CellSelect(Row, Col: longint);
    procedure CellClick(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure RenewPanel(draft: boolean);
    procedure ShowSudoku(sd: TSudoku; draft: boolean);
    procedure ShowDraft(Row, Col: longint);
    procedure ClearLabel(Row, Col: longint);
    procedure ClearAll;
    procedure ClearPanel(resColor: boolean);
    procedure ResetColor;
    procedure LightSame(Row, Col: longint);
  end;

  TPair = record
    r, c: longint;
  end;

const
  SuperBlockRow: array[1..4] of longint = (2, 6, 2, 6);
  SuperBlockCol: array[1..4] of longint = (2, 2, 6, 6);
  SuperBlock: array[1..4] of TPair = ((r:2; c:2), (r:2; c:6),
                                      (r:6; c:2), (r:6; c:6));
  GridColors: array[1..9] of TColor = ($C9C9FF, $F6DFCF, $88FFFF, $CFF6D5, $F7C5FC,
                                       $FAFCC5, $9FDAFF, $C6C6C6, $FFFFFF);

var
  Form1: TForm1;
  Root: string;
  SdkPanel: TSdkPanel;
  initSdk, SdkSolution, Answer: TSudoku;
  Difficulty: TDifficulty;
  cCol, cRow: longint;
  cSelect, isSolving, isGenerating, MultiSolution, GnrComplete: boolean;
  isAssist, isBreak, isFilling, isHint, isDrafting: boolean;

implementation

{$R *.dfm}

procedure swap(var a, b: longint);
var
  t: longint;
begin
  t := a;
  a := b;
  b := t;
end;

procedure MixArray(var arr: array of longint; len: longint);
var
  arr2: array[0..80] of longint;
  count: longint;
  i, top: longint;
begin
    top := 0;
	count := len;
	repeat
		i := random(count);
		arr2[top] := arr[i];
		inc(top);
		swap(arr[i], arr[count - 1]);
		dec(count);
	until count <= 0;
	for i := 1 to len do arr[i] := arr2[i];
end;

function inBlock(c: longint): longint;
//Get position of the first grid in this block
begin
  exit(c-(c-1)mod 3);
end;

function CountTrue(arr: array of boolean): longint;
//Counting the amount of 'true' member of an boolean array.
var
  i, count: longint;
begin
  count := 0;
  for i := 0 to 8 do
    if arr[i] then inc(count);
  exit(count);
end;

function FindBlock(Id: longint): TPair;
var
	i, j: longint;
	pair: TPair;
begin
	i := (Id - 1) div 3;
	j := (Id - 1) mod 3;
	pair.r := i * 3 + 1;
	pair.c := j * 3 + 1;
	exit(pair);
end;

function BlockRandomPick(sd: TSudoku; BlockId, Num: longint): TPair;
var
	rep, block: TPair;
	i, j, top: longint;
	stack: array[1..9] of TPair;
begin
	top := 0;
	rep.r := 0;
	rep.c := 0;
	block := FindBlock(BlockId);
	for i := block.r to block.r + 2 do begin
		for j := block.c to block.c + 2 do begin
			if (sd.Num[i, j] = 0) and (sd.Draft[i, j, Num]) then begin
				inc(top);
				stack[top].r := i;
				stack[top].c := j;
			end;
		end;
	end;
	if top <> 0 then rep := stack[random(top) + 1];
	exit(rep);
end;

//Implementation of class TSdkPanel
constructor TSdkPanel.Create(cellh, cellw: longint);
var
  i, j, l, t: longint;
begin
  l:= Form1.Panel1.Left;
  t := Form1.Panel1.Top;
  Left := l;
  Top := t;
  CellHeight := Cellh;
  CellWidth := Cellw;
  LineWidth := 2;
  with Form1.Panel1 do begin
    SendToBack;
    Color := clBlack;
    Height := 9 * cellh + 2 * LineWidth;
    Width := 9 * cellw + 2 * LineWidth;
    ParentBackground := false;
  end;
  for i := 1 to 9 do begin
    for j := 1 to 9 do begin
      Cells[i, j] := TPanel.Create(Form1);
      Labels[i, j] := TLabel.Create(Form1);
      with Cells[i, j] do begin
        Parent := Form1;
        ParentBackground := false;
        Left := l + (j - 1) * cellw + (j - 1) div 3 * LineWidth;
        Top := t + (i - 1) * cellh + (i - 1) div 3 * LineWidth;
        Height := cellh;
        Width := cellw;
        Color := clWhite;
        Font.Size := 30;
        //Caption := '0';
        Visible := true;
        OnMouseDown := CellClick;
      end;
      with Labels[i, j] do begin
        Parent := Cells[i, j];
        AutoSize := false;
        WordWrap := true;
        Left := 0;
        Top := 0;
        Height := cellh;
        Width := cellw;
        Font.Size := 10;
        //Caption := ' 1  2  3'#10' 4  5  6'#10' 7  8  9';
        Visible := true;
        OnMouseDown := CellClick;
      end;
    end;
  end;
  CurSdk := TSudoku.Create;
end;

procedure TSdkPanel.CellSelect(Row, Col: longint);
begin
  if (cCol <> 0) and (cRow <> 0) then
    ResetColor;
  if (Col = cCol) and (Row = cRow) and cSelect and (not isDrafting) then begin
    cCol := 0;
    cRow := 0;
    exit;
  end;
  cCol := Col;
  cRow := Row;
  if CurSdk.SdkType <> ColorSdk then begin
    if isDrafting then Cells[cRow, cCol].Color := clAqua
    else Cells[cRow, cCol].Color:= clLime;
  end;
  Cells[cRow, cCol].BevelInner := bvLowered;
  cSelect := true;
  LightSame(cRow, cCol);
end;

procedure TSdkPanel.CellClick(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  panel: TPanel;
  lbl: TLabel;
  Col, Row: longint;
begin
  if Sender.ClassType = TLabel then begin
    lbl := Sender as TLabel;
    panel := lbl.Parent as TPanel;
  end else panel := Sender as TPanel;

  Col := (panel.Left - Left) div CellWidth + 1;
  Row := (panel.Top - Top) div CellHeight + 1;
  if (Button = mbRight) and isFilling then begin
    isDrafting := not isDrafting;
    if (cCol = Col) and (cRow = Row) then CellSelect(Row, Col);
  end;
  CellSelect(Row, Col);
end;

procedure TSdkPanel.RenewPanel(draft: boolean);
var
  i, j, k, t: longint;
  flag: boolean;
begin
  ClearPanel(false);
  for i := 1 to 9 do
    for j := 1 to 9 do begin
      t := CurSdk.Num[i, j];
      if t > 0 then SdkPanel.Cells[i, j].Caption := IntToStr(t)
      else if draft then begin
        flag := false;
        for k := 1 to 9 do
          if not CurSdk.draft[i, j, k] then begin
            flag := true;
            break;
          end;
        if flag then ShowDraft(i, j);
      end;
    end;
end;

procedure TSdkPanel.ShowSudoku(sd: TSudoku; draft: boolean);
begin
  CurSdk.CopyFrom(sd);
  RenewPanel(draft);
end;

procedure TSdkPanel.ShowDraft(Row, Col: longint);
var
  i: longint;
  s: string;
begin
  s := ' ';
  for i := 1 to 9 do begin
    if CurSdk.Draft[Row, Col, i] then begin
      s := s + IntToStr(i)+ '  ';
    end else begin
      if i mod 3 <> 0 then s := s + '   '
      else s := s + ' ';
    end;
    if i mod 3 = 0 then s := s + #10' ';
  end;
  Labels[Row, Col].Caption := s;
end;

procedure TSdkPanel.ClearLabel(Row, Col: longint);
begin
  Labels[Row, Col].Caption := '';
end;

procedure TSdkPanel.ClearPanel(resColor: boolean);
var
  i, j:longint;
begin
  for i := 1 to 9 do
    for j := 1 to 9 do begin
      Cells[i, j].Caption := '';
      ClearLabel(i, j);
    end;
  if resColor then ResetColor;
end;

procedure TSdkPanel.ClearAll;
begin
  ClearPanel(true);
  CurSdk.ClearSdk;
end;

procedure TSdkPanel.ResetColor;
var
  i, j, k, r, c:longint;
begin
  cSelect := false;
  case CurSdk.SdkType of
    NormalSdk: begin
      for i := 1 to 9 do
        for j := 1 to 9 do begin
          Cells[i, j].Color := clWhite;
          Cells[i, j].BevelInner := bvNone;
        end;
    end;
    X_Sdk: begin
      for i := 1 to 9 do
        for j := 1 to 9 do begin
          if (i = j) or (i + j = 10) then
            Cells[i, j].Color := clMoneyGreen
          else
            Cells[i, j].Color := clWhite;
          Cells[i, j].BevelInner := bvNone;
        end;
    end;
    SuperSdk: begin
      for i := 1 to 9 do
        for j := 1 to 9 do begin
          Cells[i, j].Color := clWhite;
          Cells[i, j].BevelInner := bvNone;
        end;
      for k := 1 to 4 do begin
        for i := SuperBlock[k].r to SuperBlock[k].r + 2 do begin
          for j := SuperBlock[k].c to SuperBlock[k].c + 2 do begin
            Cells[i, j].Color := clMoneyGreen;
          end;
        end;
      end;
    end;
    ColorSdk: begin
      for i := 1 to 9 do
        for j := 1 to 9 do begin
          r := i - inBlock(i);
          c := j - inBlock(j);
          k := r * 3 + c + 1;
          Cells[i, j].Color := GridColors[k];
          Cells[i, j].BevelInner := bvNone;
        end;
    end;
  end;
end;

procedure TSdkPanel.LightSame(Row: Integer; Col: Integer);
var
  i, j: longint;
begin
  if isAssist and (CurSdk.Num[Row, Col] <> 0) then begin
    for i := 1 to 9 do begin
      for j := 1 to 9 do begin
        if (CurSdk.Num[i, j] = CurSdk.Num[Row, Col]) and ((i <> Row) or (j <> Col)) then
          Cells[i, j].Color := clYellow;
      end;
    end;
  end;
end;


//Implementation of class TSudoku
constructor TSudoku.Create;
begin
  ClearSdk;
  SdkType := NormalSdk;
end;

procedure TSudoku.CopyFrom(sd: TSudoku);
var
  i, j, k: longint;
begin
  for i := 1 to 9 do begin
    for j := 1 to 9 do begin
      Num[i, j] := sd.Num[i, j];
      Con[i, j] := sd.Con[i, j];
      for k := 1 to 9 do begin
        Draft[i, j, k] := sd.draft[i, j, k];
      end;
    end;
  end;
  SdkType := sd.SdkType;
end;

function TSudoku.Equal(sd: TSudoku): boolean;
var
  i, j: longint;
begin
  for i := 1 to 9 do
    for j := 1 to 9 do
      if Num[i, j] <> sd.Num[i, j] then
        exit(false);
  exit(true);
end;

procedure TSudoku.RenewDraft;
var
  i,j,i2,j2,k,l,t:longint;
begin
  ResetDraft(true);
  for i := 1 to 9 do
    for j := 1 to 9 do begin
      if Num[i, j] > 0 then begin
        t := Num[i, j];
        for k := 1 to 9 do begin
          if Num[i, k] = 0 then Draft[i,k,t] := false;
          if Num[k, j] = 0 then Draft[k,j,t] := false;
        end;
        for i2 := 0 to 2 do
          for j2 := 0 to 2 do begin
            k := i2 + inBlock(i);
            l := j2 + inBlock(j);
            if Num[k, l] = 0 then Draft[k, l, t] := false;
          end;
      end;
    end;
end;

procedure TSudoku.ResetDraft(b: boolean);
var
  i, j, k: longint;
begin
  for i := 1 to 9 do
    for j := 1 to 9 do
      for k := 1 to 9 do
        draft[i, j, k] := b;
end;

procedure TSudoku.ClearSdk;
var
  i, j: longint;
begin
  ResetDraft(true);
  for i := 1 to 9 do begin
    for j := 1 to 9 do begin
      Num[i, j] := 0;
      //Con[i, j] := 0;
    end;
  end;
end;

procedure TSudoku.FillGrid(Row, Col, n: longint);
begin
  if isSolving and (Num[Row, Col] > 0) then begin
    exit;
  end;
  Num[Row, Col] := n;
  if isSolving or isGenerating then RenewDraft;
end;

function TSudoku.SolveSdk: longint;
var
	flag: longint;
begin
	isSolving := true;
	MultiSolution := false;
	SdkSolution.ClearSdk;
	flag := 0;

	RenewDraft;
  SimpleSolve;
	if CheckComplete then begin
		flag := 1;
	end
	else if DFSSolve(true) then begin
		if MultiSolution then flag := 2
		else flag := 1;
		Self.CopyFrom(SdkSolution);
  end;
	isSolving := false;
  SdkSolution.ClearSdk;
  exit(flag);
end;

function TSudoku.NakedSingle: boolean;
var
  i, j, k, t:longint;
  doFlag: boolean;
begin
  doFlag := false;
  for i := 1 to 9 do
    for j := 1 to 9 do begin
      if Num[i, j] = 0 then begin
        t := 0;
        for k := 1 to 9 do
          if Draft[i, j, k] then begin
            if t = 0 then t := k
            else t := -1;
          end;
        if (t > 0) then begin
          if not doFlag then doFlag := true;
          FillGrid(i, j, t);
        end;
      end;
    end;
  exit(doFlag);
end;

function TSudoku.HiddenSingle: boolean;
var
  i, j, i1, j1, i2, j2, k, t, ti, tj: longint;
  tgRow, tgCol: array[1..9] of longint;
  doFlag: boolean;
begin
  doFlag := false;
  //Checking rows
  for i := 1 to 9 do begin
    FillChar(tgCol, SizeOf(tgCol), 0);
    for j := 1 to 9 do begin
      if Num[i, j] > 0 then continue;
      for k := 1 to 9 do begin
        if Draft[i, j, k] then begin
          if tgCol[k] = 0 then tgCol[k] := j
          else tgCol[k] := -1;
        end;
      end;
    end;
    for k := 1 to 9 do begin
      if tgCol[k] > 0 then begin
        doFlag := true;
        t := tgCol[k];
        FillGrid(i, t, k);
      end;
    end;
  end;

  //Checking columns
  for j := 1 to 9 do begin
    FillChar(tgRow, SizeOf(tgRow), 0);
    for i := 1 to 9 do begin
      if Num[i, j] > 0 then continue;
      for k := 1 to 9 do begin
        if Draft[i, j, k] then begin
          if tgRow[k] = 0 then tgRow[k] := i
          else tgRow[k] := -1;
        end;
      end;
    end;
    for k := 1 to 9 do begin
      if tgRow[k] > 0 then begin
        doFlag := true;
        t := tgRow[k];
        FillGrid(t, j, k);
      end;
    end;
  end;

  //Checking Blocks
  for i1 := 0 to 2 do begin
    i := i1 * 3 + 1;
    for j1 := 0 to 2 do begin
      j := j1 * 3 + 1;
      FillChar(tgRow, SizeOf(tgRow), 0);
      FillChar(tgCol, SizeOf(tgCol), 0);
      for i2 := i to i+2 do begin
        for j2 := j to j+2 do begin
          if Num[i2, j2] > 0 then continue;
          for k := 1 to 9 do begin
            if Draft[i2, j2, k] then begin
              if (tgRow[k] = 0) and (tgCol[k] = 0) then begin
                tgRow[k] := i2;
                tgCol[k] := j2;
              end else begin
                tgRow[k] := -1;
                tgCol[k] := -1;
              end;
            end;
          end;
        end;
      end;
      for k := 1 to 9 do begin
        if (tgRow[k] > 0) and (tgCol[k] > 0) then begin
          doFlag := true;
          ti := tgRow[k];
          tj := tgCol[k];
          FillGrid(ti, tj, k);
        end;
      end;
    end;
  end;
  exit(doFlag);
end;

procedure TSudoku.SimpleSolve;
begin
  repeat
    while NakedSingle do Application.ProcessMessages;
  until not HiddenSingle;
  RenewDraft;
end;

function TSudoku.DFSSolve(isMulti: boolean): boolean;
//参数：是否尝试解出多个解；返回值：是否有解
var
  i, j, k, t: longint;
  flags: array[1..9, 1..9] of boolean;
  min, mi, mj: longint;
  WorkDone, flag: boolean;
  this, sd: TSudoku;
begin
  //DFS预处理
  if not Self.CheckValid then begin
    exit(false);
  end;
  if Self.CheckComplete then begin
    if not SdkSolution.CheckComplete then begin
      SdkSolution.CopyFrom(Self);
    end
    else if not SdkSolution.Equal(Self) then begin
      MultiSolution := true;
    end;
    exit(true);
  end;
  flag := false;
  this := TSudoku.Create;
  sd := TSudoku.Create;
  this.CopyFrom(Self);

  FillChar(flags, SizeOf(flags), 0);
  min := 10;
  mi := 0;
  mj := 0;

  WorkDone := false;
  while not WorkDone do begin
    WorkDone := true;
    for i := 1 to 9 do begin
      for j := 1 to 9 do begin
	      if Num[i, j] > 0 then flags[i, j] := true
	      else if not flags[i, j] then begin
          t := CountTrue(Draft[i, j]);
		      if t < min then begin
		        min := t;
			      mi := i;
			      mj := j;
			      WorkDone := false;
		      end;
        end;
	    end;
	  end;
    if WorkDone then begin
      break;
    end;
    flags[mi, mj] := true;

	for k := 1 to 9 do begin
      if Draft[mi, mj, k] then begin
        sd.ClearSdk;
        sd.CopyFrom(this);
        with sd do begin
          FillGrid(mi, mj, k);
          SimpleSolve;
          if not CheckValid then continue;
          if DFSSolve(isMulti) then begin
            flag := true;
            if (not isMulti) or MultiSolution then break;
          end;
        end;
      end;
    end;
    if flag and ((not isMulti) or MultiSolution) then exit(true);
  end;
  exit(flag);
end;

procedure TSudoku.RemoveFromSdk(sd: TSudoku);
//Remove the same number as another sudoku from the draft. Used only in DFS.
var
  i, j, k: longint;
begin
  for i := 1 to 9 do begin
    for j := 1 to 9 do begin
       k := sd.Num[i, j];
       Draft[i, j, k] := false;
    end;
  end;
end;

function TSudoku.CheckValid;
var
  i, j, k, t: longint;
  RowSum, ColSum, BlkSum: array[1..9, 1..9] of longint;
  flag, flag2: boolean;
begin
  FillChar(RowSum, SizeOf(RowSum), 0);
  FillChar(ColSum, SizeOf(ColSum), 0);
  FillChar(BlkSum, SizeOf(BlkSum), 0);
  flag := true;
  for i := 1 to 9 do begin
    for j := 1 to 9 do begin
      if Num[i, j] > 0 then begin
        t := Num[i, j];
        inc(RowSum[i, t], 1);
        inc(ColSum[j, t], 1);
        inc(BlkSum[inBlock(i) div 3 + inBlock(j), t], 1);
      end else if isSolving then begin
        flag2 := false;
        for k := 1 to 9 do begin
          if Draft[i, j, k] then begin
            flag2 := true;
            break;
          end;
          if flag2 then break;
        end;
        if not flag2 then flag := false;
      end;
    end;
  end;
  if not flag then exit(false);
  for i := 1 to 9 do
    for j := 1 to 9 do
      if (RowSum[i, j] > 1)or(ColSum[i, j] > 1) or (BlkSum[i, j] > 1) then
        exit(false);
  exit(true);
end;

function TSudoku.CheckComplete: boolean;
var
  i, j: longint;
begin
  for i := 1 to 9 do begin
    for j := 1 to 9 do begin
      if Num[i, j] = 0 then exit(false);
    end;
  end;
  exit(true);
end;

procedure TSudoku.GeneratePuzzle(dif: TDifficulty);
var
  count: longint;
begin
  ClearSdk;
  SdkSolution.ClearSdk;
  isGenerating := true;
  if DFSGenerate(1, 1) then begin
    Self.CopyFrom(SdkSolution);
  end else ShowMessage('Failed to Generate.');
  SdkSolution.ClearSdk;
  count := 81;
  GnrComplete := false;
  DFSBlanking(count, dif);
  if isBreak then begin
    Self.ClearSdk;
    exit;
  end;
  if GnrComplete then begin
    Self.CopyFrom(SdkSolution);
    SdkSolution.ClearSdk;
    MultiSolution := false;
    GnrComplete := false;
  end;
  isGenerating := false;
end;

function TSudoku.DFSGenerate(FillNum, BlockId: longint): boolean;
var
  i, j, i2, j2: longint;
  n, bid, inRow, inCol: longint;
  p: TPair;
  sd: TSudoku;
  WorkDone, flag: boolean;
  used: array[0..2, 0..2] of boolean;
begin
  sd := TSudoku.Create;
	if not Self.CheckValid then exit(false);
	if Self.CheckComplete then begin
		SdkSolution.CopyFrom(Self);
		exit(true);
	end;

	FillChar(used, SizeOf(used), 0);
	WorkDone := false;
	flag := false;
	while not WorkDone do begin
		WorkDone := true;
		p := FindBlock(BlockId);
		for i := 0 to 2 do begin
			i2 := i + p.r;
			for j:= 0 to 2 do begin
        j2 := j + p.c;
				if (Num[i2, j2] = 0) and (Draft[i2, j2, FillNum]) and (not used[i, j]) then begin
					WorkDone := false;
					break;
				end;
			end;
      if not WorkDone then break;
		end;

		if WorkDone then break;

		with sd do begin
			ClearSdk;
			CopyFrom(Self);
			repeat
				p := BlockRandomPick(sd, BlockId, FillNum);
				inRow := p.r - inBlock(p.r);
				inCol := p.c - inBlock(p.c);
			until not used[inRow, inCol];
			if (p.r = 0) and (p.c = 0) then begin
			  exit(false);
			end;
			used[inRow, inCol] := true;
			FillGrid(p.r, p.c, FillNum);
			RenewDraft;
			if BlockId >= 9 then begin
				bid := 1;
				n := FillNum + 1;
			end else begin
        bid := BlockId + 1;
        n := FillNum;
			end;
			if sd.DFSGenerate(n, bid) then begin
				flag := true;
				break;
			end else begin
      end;
		end;
  end;
  exit(flag);
end;

function TSudoku.DFSBlanking(count: longint; dif: TDifficulty): boolean;
var
	sd: TSudoku;
	st: array[1..81] of longint;
	i, j, k, top: longint;
	flag: boolean;
begin
	sd := TSudoku.Create;
	sd.CopyFrom(Self);
	sd.SimpleSolve;
	if not sd.CheckComplete then begin
		exit(false);
	end else begin
		if (dif = Easy) and (count <= 40) then begin
			SdkSolution.CopyFrom(Self);
			GnrComplete := true;
			exit(true);
		end;
	end;

	FillChar(st, SizeOf(st), 0);
	top := 1;
	for i := 1 to 9 do begin
		for j := 1 to 9 do begin
			if Num[i, j] <> 0 then begin
				st[top] := (i - 1) * 9 + j;
				inc(top);
			end;
		end;
	end;
	MixArray(st, top - 1);

	flag := false;
	for k := 1 to top - 1 do begin

    if isBreak then exit(true);

		i := (st[k] - 1) div 9 + 1;
		j := (st[k] - 1) mod 9 + 1;
		sd.CopyFrom(Self);
		with sd do begin
			FillGrid(i, j, 0);
			ResetDraft(true);
			RenewDraft;

			if DFSBlanking(count - 1, dif) then begin
				flag := true;
				if GnrComplete then exit(true);
			end else begin

			end;
		end;
	end;
	if not flag then begin
		case dif of
			Normal: begin
				if count <= 35 then begin
					SdkSolution.CopyFrom(Self);
					GnrComplete := true;
					exit(true);
				end;
			end;
			Hard, Ace: begin
				if count <= 35 then begin
					DFSDeepBlk(count);
					if GnrComplete then exit(true);
        end;
			end;
		end;
		exit(true);
	end;
	exit(true);
end;

function TSudoku.DFSDeepBlk(count: longint): boolean;
var
	sd: TSudoku;
	st: array[1..81] of longint;
	i, j, k, top: longint;
	flag: boolean;
begin
	sd := TSudoku.Create;
	sd.CopyFrom(Self);
  sd.SimpleSolve;
	MultiSolution := false;
	if not sd.DFSSolve(true) then begin
    //ShowMessage('fault');
  end;
	if MultiSolution then begin
		exit(false);
	end;

	FillChar(st, SizeOf(st), 0);
	top := 1;
	for i := 1 to 9 do begin
		for j := 1 to 9 do begin
			if Num[i, j] <> 0 then begin
				st[top] := (i - 1) * 9 + j;
				inc(top);
			end;
		end;
	end;
	MixArray(st, top - 1);

	flag := false;
	for k := 1 to top - 1 do begin

    if isBreak then exit(true);

		i := (st[k] - 1) div 9 + 1;
		j := (st[k] - 1) mod 9 + 1;
		sd.CopyFrom(Self);
		with sd do begin
			FillGrid(i, j, 0);
			ResetDraft(true);
			RenewDraft;

			if DFSDeepBlk(count - 1) then begin
				flag := true;
				if GnrComplete then exit(true);
			end else begin

			end;
		end;
	end;
	if not flag then begin
    sd.CopyFrom(Self);
    sd.SimpleSolve;
    //if count <= 30 then begin
    if not sd.CheckComplete then begin
      SdkSolution.CopyFrom(Self);
      GnrComplete := true;
      exit(true);
    end else exit(true);
    //end else exit(False);
	end;
	exit(true);
end;

//Implementation of TForm1
procedure TForm1.Button10Click(Sender: TObject);
begin
  if not cSelect then exit;
  if not isFilling then exit;
  if isHint then exit;
  SdkPanel.CurSdk.Num[cRow, cCol] := Answer.Num[cRow, cCol];
  SdkPanel.RenewPanel(true);
  isHint := true;
  Button10.Enabled := false;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  Button1.Enabled := false;
  initSdk.CopyFrom(SdkPanel.CurSdk);
  case initSdk.SolveSdk of
    0: begin
      ShowMessage('解算失败！');
    end;
    1: begin
      SdkPanel.ShowSudoku(initSdk, true);
      ShowMessage('解算成功！');
    end;
    2: begin
      SdkPanel.ShowSudoku(initSdk, true);
      ShowMessage('可能存在多组解，目前显示其中一组。');
    end;
  end;
  Button1.Enabled := true;
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  i, j: longint;
  c: char;
begin
  SdkPanel.ClearAll;
  initSdk.ClearSdk;
  for i := 1 to 9 do
    for j := 1 to 9 do begin
      read(c);
      if c = '.' then initSdk.FillGrid(i, j, 0)
      else if (c >= '1') and (c <= '9') then initSdk.FillGrid(i, j, Ord(c)-Ord('0'))
      else continue;
    end;
  readln;
  SdkPanel.ShowSudoku(initSdk, false);
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  SdkPanel.ClearAll;
  Label1.Caption := '00:00:00';
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  if SdkPanel.CurSdk.CheckValid then
    ShowMessage('数独符合规范。')
  else ShowMessage('数独不符合规范！');
end;

procedure TForm1.Button5Click(Sender: TObject);
var
  sd: TSudoku;
begin
  sd := TSudoku.Create;
  Timer1.Enabled := true;
  Button5.Enabled := false;
  SdkPanel.ResetColor;
  sd.ClearSdk;
  sd.GeneratePuzzle(Difficulty);
  if isBreak then exit;
  sd.ResetDraft(false);
  SdkPanel.ShowSudoku(sd, false);
  with Answer do begin
    CopyFrom(Sd);
    SolveSdk;
  end;
  Label1.Caption := '00:00:00';
  Timer2.Enabled := true;
  isFilling := true;
  isHint := false;
  Button10.Enabled := true;
  if Difficulty = ACE then begin
    isHint := true;
    Button10.Enabled := false;
  end;
  Button5.Enabled := true;
end;

procedure TForm1.Button6Click(Sender: TObject);
var
  i, j, t: longint;
  c: char;
begin
  if Length(Edit1.Text) <> 81 then begin
    ShowMessage('长度不符合要求！');
    exit;
  end;
  for i := 1 to 81 do begin
    c := Edit1.Text[i];
    if ((c < '1') or (c > '9')) and (c <> '.') then begin
      ShowMessage('有非法字符！');
      exit;
    end;
  end;
  SdkPanel.ClearAll;
  initSdk.ClearSdk;
  t := 1;
  for i := 1 to 9 do
    for j := 1 to 9 do begin
      c := Edit1.Text[t];
      if Edit1.Text[t] = '.' then initSdk.FillGrid(i, j, 0)
      else initSdk.FillGrid(i, j, Ord(c)-Ord('0'));
      inc(t);
    end;
  initSdk.ResetDraft(true);
  SdkPanel.ShowSudoku(initSdk, false);
end;

procedure TForm1.CheckBox1Click(Sender: TObject);
begin
  isAssist := CheckBox1.Checked;
end;

procedure TForm1.ComboBox1Change(Sender: TObject);
begin
  case ComboBox1.ItemIndex of
    0: Difficulty := Easy;
    1: Difficulty := Normal;
    2: Difficulty := Hard;
    3: Difficulty := ACE;
  end;
  if Difficulty = ACE then begin
    CheckBox1.Checked := false;
    CheckBox1.Enabled := false;
  end else
  begin
    CheckBox1.Enabled := true;
  end;
end;

procedure TForm1.ComboBox2Change(Sender: TObject);
begin
  with SdkPanel.CurSdk do begin
    case ComboBox2.ItemIndex of
      0: SdkType := NormalSdk;
      1: SdkType := X_Sdk;
      2: SdkType := SuperSdk;
      3: SdkType := ColorSdk;
    end;
  end;
  SdkPanel.ResetColor;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  randomize;
  Root := ExtractFileDir(Application.ExeName);
  AssignFile(input, Root + '/MostDifficults.txt');
  Reset(input);
  SdkPanel := TSdkPanel.Create(50, 50);
  initSdk := TSudoku.Create;
  isSolving := false;
  isGenerating := false;
  SdkSolution := TSudoku.Create;
  Answer := TSudoku.Create;
  Difficulty := Easy;
  isAssist := CheckBox1.Checked;
  isDrafting := false;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  c:longint;
begin
  c := Key - 48;
  //没想好
end;

procedure TForm1.FormKeyPress(Sender: TObject; var Key: Char);
var
  c, i: longint;
begin
  c := Ord(Key) - Ord('0');
  if cSelect then begin
    if (c >= 0) and (c <= 9) then begin;
      if not isDrafting then begin
        with SdkPanel do begin
          if c>0 then Cells[cRow, cCol].Caption := IntToStr(c)
          else Cells[cRow, cCol].Caption := '';
          ClearLabel(cRow, cCol);
          CurSdk.FillGrid(cRow, cCol, c);
          for i := 1 to 9 do
            CurSdk.draft[cRow, cCol, i] := false;
          LightSame(cRow, cCol);
        end;
      end
      else begin
        with SdkPanel do begin
          CurSdk.draft[cRow, cCol, c] := not CurSdk.draft[cRow, cCol, c];
          RenewPanel(true);
        end;
      end;
    end;
  end;
end;

procedure TForm1.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Col, Row: longint;
begin
  if cSelect then begin
    Col := cCol;
    Row := cRow;
    case Key of
      VK_Down: inc(Row);
      VK_Up: dec(Row);
      VK_Right: inc(Col);
      VK_Left: dec(Col);
      Ord('S'): inc(Row);
      Ord('W'): dec(Row);
      Ord('D'): inc(Col);
      Ord('A'): dec(Col);
      else exit;
    end;
    if (Row >= 1) and (Row <= 9) and (Col >= 1) and (Col <= 9) then
      SdkPanel.CellSelect(Row, Col);
  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  if isBreak then begin
    isBreak := false;
    Button5.Click;
  end else
  if isGenerating then begin
    isBreak := true;
  end
  else Timer1.Enabled := false;
end;

procedure TForm1.Timer2Timer(Sender: TObject);
var
  CurTime: TTime;
begin
  CurTime := StrToTime(Label1.Caption);
  CurTime := IncSecond(CurTime, 1);
  Label1.Caption := FormatDateTime('HH:mm:ss', CurTime);
  if SdkPanel.CurSdk.CheckComplete then begin
    if SdkPanel.CurSdk.CheckValid then begin
      Timer2.Enabled := false;
      isFilling := false;
      ShowMessage('成功解题，恭喜！用时：' + TimeToStr(CurTime));
    end;
  end;
end;

end.
