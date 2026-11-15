COLOR 15, 0 : CLS
PEN ON

w_elo = 1200 : b_elo = 1200
IF EXIST("chess_elo.txt") THEN
  OPEN "chess_elo.txt" FOR INPUT AS #1
  INPUT #1, w_elo : INPUT #1, b_elo
  CLOSE #1
ENDIF

SQ = INT(MIN(XMAX - 20, YMAX - 190) / 8)
BOARD_X = INT((XMAX - (SQ * 8)) / 2) : BOARD_Y = 115
DIM board(7, 7) : DIM history
turn = 1 : sel_r = -1 : sel_c = -1 : game_over = 0 : status_msg$ = "WHITE'S TURN"
w_kmoved = 0 : w_r0moved = 0 : w_r7moved = 0 : b_kmoved = 0 : b_r0moved = 0 : b_r7moved = 0
ep_r = -1 : ep_c = -1 : w_time = 600.0 : b_time = 600.0 : last_tick = TICKS

FOR r = 0 TO 7
  FOR c = 0 TO 7
    btn.type = "button" : btn.x = BOARD_X + (c * SQ) : btn.y = BOARD_Y + (r * SQ)
    btn.width = SQ - 2 : btn.height = SQ - 2 : btn.label = "" : btn.onclick = @SquareClicked
    myform.inputs << btn
  NEXT
NEXT

lbl_elo.type = "label" : lbl_elo.x = BOARD_X : lbl_elo.y = 12 : lbl_elo.width = SQ * 8 : lbl_elo.height = 30
lbl_elo.color = rgb(250, 210, 90) : lbl_elo.backgroundColor = rgb(0, 0, 0) : myform.inputs << lbl_elo

lbl_clocks.type = "label" : lbl_clocks.x = BOARD_X : lbl_clocks.y = 44 : lbl_clocks.width = SQ * 8 : lbl_clocks.height = 30
lbl_clocks.color = rgb(110, 225, 255) : lbl_clocks.backgroundColor = rgb(0, 0, 0) : myform.inputs << lbl_clocks

lbl_status.type = "label" : lbl_status.x = BOARD_X : lbl_status.y = 76 : lbl_status.width = SQ * 8 : lbl_status.height = 32
lbl_status.color = rgb(255, 255, 255) : lbl_status.backgroundColor = rgb(0, 0, 0) : myform.inputs << lbl_status

btn_reset.type = "button" : btn_reset.x = BOARD_X : btn_reset.y = BOARD_Y + (SQ * 8) + 12
btn_reset.width = SQ * 8 : btn_reset.height = 46 : btn_reset.label = "NEW MATCH"
btn_reset.color = rgb(255, 255, 255) : btn_reset.backgroundColor = rgb(45, 110, 185)
btn_reset.onclick = @ResetGame : myform.inputs << btn_reset

f = form(myform) : ResetGame

WHILE 1
  f.doEvents()
  now_tick = TICKS : dt = (now_tick - last_tick) / 1000.0 : last_tick = now_tick
  IF game_over = 0 AND dt > 0 AND dt < 2.0 THEN
    prev_sec = INT(IFF(turn = 1, w_time, b_time))
    IF turn = 1 THEN
      w_time = w_time - dt
      IF w_time <= 0 THEN w_time = 0 : EndMatch(-1, "TIME OUT! BLACK WINS (+16 ELO)")
    ELSE
      b_time = b_time - dt
      IF b_time <= 0 THEN b_time = 0 : EndMatch(1, "TIME OUT! WHITE WINS (+16 ELO)")
    ENDIF
    IF INT(IFF(turn = 1, w_time, b_time)) <> prev_sec THEN UpdateTopLabels
  ENDIF
  DELAY 25
WEND
SUB ResetGame
  ERASE board : DIM board(7, 7) : ERASE history
  SPLIT "r,n,b,q,k,b,n,r", ",", b_row : SPLIT "R,N,B,Q,K,B,N,R", ",", w_row
  FOR c = 0 TO 7
    board(0, c) = b_row(c) : board(1, c) = "p" : board(6, c) = "P" : board(7, c) = w_row(c)
  NEXT
  turn = 1 : sel_r = -1 : sel_c = -1 : game_over = 0 : status_msg$ = "WHITE'S TURN"
  w_kmoved = 0 : w_r0moved = 0 : w_r7moved = 0 : b_kmoved = 0 : b_r0moved = 0 : b_r7moved = 0
  ep_r = -1 : ep_c = -1 : w_time = 600.0 : b_time = 600.0 : last_tick = TICKS
  history << GetBoardStateKey() : RefreshBoard
END SUB

SUB EndMatch(winner_side, msg$)
  IF game_over = 1 THEN EXIT SUB
  game_over = 1 : status_msg$ = msg$
  IF winner_side = 1 THEN
    w_elo = w_elo + 16 : b_elo = MAX(100, b_elo - 16)
  ELIF winner_side = -1 THEN
    b_elo = b_elo + 16 : w_elo = MAX(100, w_elo - 16)
  ENDIF
  OPEN "chess_elo.txt" FOR OUTPUT AS #1
  PRINT #1, w_elo : PRINT #1, b_elo
  CLOSE #1
  SOUND 700, 120 : RefreshBoard
END SUB

FUNC FormatTime(sec_val)
  s = INT(MAX(0, sec_val))
  FormatTime = RIGHT("0" + STR(INT(s / 60)), 2) + ":" + RIGHT("0" + STR(s MOD 60), 2)
END FUNC

SUB UpdateTopLabels
  f.inputs(64).label = "WHITE ELO: " + STR(w_elo) + "   |   BLACK ELO: " + STR(b_elo)
  f.inputs(65).label = "W CLOCK: " + FormatTime(w_time) + "   |   B CLOCK: " + FormatTime(b_time)
  f.inputs(66).label = status_msg$
  f.refresh(0)
END SUB

SUB RefreshBoard
  FOR r = 0 TO 7
    FOR c = 0 TO 7
      idx = (r * 8) + c : p$ = board(r, c) : is_legal_hint = 0
      IF sel_r <> -1 AND game_over = 0 THEN
        IF IsLegalMove(sel_r, sel_c, r, c) = 1 THEN is_legal_hint = 1
      ENDIF
      IF r = sel_r AND c = sel_c THEN
        f.inputs(idx).backgroundColor = rgb(70, 145, 220)
      ELIF is_legal_hint = 1 THEN
        f.inputs(idx).backgroundColor = rgb(65, 165, 95)
      ELIF (r + c) MOD 2 = 0 THEN
        f.inputs(idx).backgroundColor = rgb(235, 235, 235)
      ELSE
        f.inputs(idx).backgroundColor = rgb(65, 65, 65)
      ENDIF
      IF p$ = "" THEN
        f.inputs(idx).label = ""
      ELIF PieceSide(p$) = 1 THEN
        f.inputs(idx).label = "[" + p$ + "]" : f.inputs(idx).color = rgb(0, 0, 0)
      ELSE
        f.inputs(idx).label = "(" + p$ + ")" : f.inputs(idx).color = rgb(255, 200, 80)
      ENDIF
    NEXT
  NEXT
  UpdateTopLabels
END SUB

FUNC GetBoardStateKey()
  key$ = STR(turn) + STR(w_kmoved) + STR(w_r0moved) + STR(w_r7moved) + STR(b_kmoved) + STR(b_r0moved) + STR(b_r7moved) + STR(ep_r) + STR(ep_c)
  FOR r = 0 TO 7
    FOR c = 0 TO 7
      key$ = key$ + IFF(board(r, c) = "", ".", board(r, c))
    NEXT
  NEXT
  GetBoardStateKey = key$
END FUNC

FUNC CheckThreefoldRepetition()
  curr_key$ = GetBoardStateKey() : history << curr_key$ : cnt = 0
  FOR h IN history
    IF h = curr_key$ THEN cnt = cnt + 1
  NEXT
  CheckThreefoldRepetition = IFF(cnt >= 3, 1, 0)
END FUNC

FUNC IsInsufficientMaterial()
  wn = 0 : wb = 0 : wb_sq = -1 : bn = 0 : bb = 0 : bb_sq = -1
  FOR r = 0 TO 7
    FOR c = 0 TO 7
      p$ = board(r, c) : up$ = UCASE(p$)
      IF up$ = "P" OR up$ = "R" OR up$ = "Q" THEN IsInsufficientMaterial = 0 : EXIT FUNC
      IF p$ = "N" THEN wn = wn + 1
      IF p$ = "n" THEN bn = bn + 1
      IF p$ = "B" THEN wb = wb + 1 : wb_sq = (r + c) MOD 2
      IF p$ = "b" THEN bb = bb + 1 : bb_sq = (r + c) MOD 2
    NEXT
  NEXT
  wm = wn + wb : bm = bn + bb
  IF (wm <= 1 AND bm = 0) OR (bm <= 1 AND wm = 0) OR (wn = 0 AND bn = 0 AND wb = 1 AND bb = 1 AND wb_sq = bb_sq) THEN
    IsInsufficientMaterial = 1
  ELSE
    IsInsufficientMaterial = 0
  ENDIF
END FUNC
SUB SquareClicked
  IF game_over = 1 THEN EXIT SUB
  tx = PEN(4) : ty = PEN(5)
  IF tx < BOARD_X OR ty < BOARD_Y THEN EXIT SUB
  c = INT((tx - BOARD_X) / SQ) : r = INT((ty - BOARD_Y) / SQ)
  IF r < 0 OR r > 7 OR c < 0 OR c > 7 THEN EXIT SUB
  clicked_side = PieceSide(board(r, c))
  IF sel_r = -1 THEN
    IF clicked_side = turn THEN sel_r = r : sel_c = c : RefreshBoard
  ELSE
    IF r = sel_r AND c = sel_c THEN
      sel_r = -1 : sel_c = -1 : RefreshBoard
    ELIF clicked_side = turn THEN
      sel_r = r : sel_c = c : RefreshBoard
    ELIF IsLegalMove(sel_r, sel_c, r, c) = 1 THEN
      ExecuteMove(sel_r, sel_c, r, c) : sel_r = -1 : sel_c = -1 : turn = -turn
      IF IsInsufficientMaterial() = 1 THEN EndMatch(0, "INSUFFICIENT MATERIAL! DRAW") : EXIT SUB
      IF CheckThreefoldRepetition() = 1 THEN EndMatch(0, "THREEFOLD REPETITION! DRAW") : EXIT SUB
      in_chk = IsKingInCheck(turn) : has_mv = HasAnyLegalMove(turn)
      IF has_mv = 0 THEN
        IF in_chk = 1 THEN
          EndMatch(-turn, IFF(turn = -1, "CHECKMATE! WHITE WINS (+16 ELO)", "CHECKMATE! BLACK WINS (+16 ELO)"))
        ELSE
          EndMatch(0, "STALEMATE! DRAW (0 ELO)")
        ENDIF
      ELSE
        status_msg$ = IFF(turn = 1, "WHITE'S TURN", "BLACK'S TURN") + IFF(in_chk = 1, " (CHECK!)", "")
        SOUND 550, 30 : RefreshBoard
      ENDIF
    ENDIF
  ENDIF
END SUB

SUB ExecuteMove(r1, c1, r2, c2)
  p$ = board(r1, c1) : up$ = UCASE(p$)
  IF up$ = "P" AND r2 = ep_r AND c2 = ep_c AND board(r2, c2) = "" THEN board(r1, c2) = ""
  IF up$ = "K" AND ABS(c2 - c1) = 2 THEN
    IF c2 = 6 THEN board(r1, 5) = board(r1, 7) : board(r1, 7) = ""
    IF c2 = 2 THEN board(r1, 3) = board(r1, 0) : board(r1, 0) = ""
  ENDIF
  IF p$ = "K" THEN w_kmoved = 1
  IF p$ = "k" THEN b_kmoved = 1
  IF (r1 = 7 AND c1 = 0) OR (r2 = 7 AND c2 = 0) THEN w_r0moved = 1
  IF (r1 = 7 AND c1 = 7) OR (r2 = 7 AND c2 = 7) THEN w_r7moved = 1
  IF (r1 = 0 AND c1 = 0) OR (r2 = 0 AND c2 = 0) THEN b_r0moved = 1
  IF (r1 = 0 AND c1 = 7) OR (r2 = 0 AND c2 = 7) THEN b_r7moved = 1
  ep_r = -1 : ep_c = -1
  IF up$ = "P" AND ABS(r2 - r1) = 2 THEN ep_r = (r1 + r2) / 2 : ep_c = c1
  board(r2, c2) = p$ : board(r1, c1) = ""
  IF p$ = "P" AND r2 = 0 THEN board(r2, c2) = "Q"
  IF p$ = "p" AND r2 = 7 THEN board(r2, c2) = "q"
END SUB

FUNC PieceSide(p$)
  IF p$ = "" THEN PieceSide = 0 : EXIT FUNC
  PieceSide = IFF(ASC(p$) >= 65 AND ASC(p$) <= 90, 1, -1)
END FUNC

FUNC IsPathClear(r1, c1, r2, c2)
  sr = SGN(r2 - r1) : sc = SGN(c2 - c1) : cr = r1 + sr : cc = c1 + sc
  WHILE cr <> r2 OR cc <> c2
    IF board(cr, cc) <> "" THEN IsPathClear = 0 : EXIT FUNC
    cr = cr + sr : cc = cc + sc
  WEND
  IsPathClear = 1
END FUNC

FUNC CanPieceAttack(r1, c1, r2, c2)
  p$ = board(r1, c1) : side = PieceSide(p$)
  IF side = 0 OR PieceSide(board(r2, c2)) = side THEN CanPieceAttack = 0 : EXIT FUNC
  up$ = UCASE(p$) : dr = ABS(r2 - r1) : dc = ABS(c2 - c1)
  SELECT CASE up$
    CASE "P"
      dir = IFF(side = 1, -1, 1) : s_row = IFF(side = 1, 6, 1)
      IF c1 = c2 AND r2 = r1 + dir AND board(r2, c2) = "" THEN CanPieceAttack = 1 : EXIT FUNC
      IF c1 = c2 AND r1 = s_row AND r2 = r1 + (2 * dir) AND board(r1 + dir, c1) = "" AND board(r2, c2) = "" THEN CanPieceAttack = 1 : EXIT FUNC
      IF dc = 1 AND r2 = r1 + dir AND (PieceSide(board(r2, c2)) = -side OR (r2 = ep_r AND c2 = ep_c)) THEN CanPieceAttack = 1 : EXIT FUNC
      CanPieceAttack = 0
    CASE "N" : CanPieceAttack = IFF((dr = 2 AND dc = 1) OR (dr = 1 AND dc = 2), 1, 0)
    CASE "B" : CanPieceAttack = IFF(dr = dc AND dr > 0, IsPathClear(r1, c1, r2, c2), 0)
    CASE "R" : CanPieceAttack = IFF((dr = 0 OR dc = 0) AND (dr + dc > 0), IsPathClear(r1, c1, r2, c2), 0)
    CASE "Q" : CanPieceAttack = IFF((dr = dc OR dr = 0 OR dc = 0) AND (dr + dc > 0), IsPathClear(r1, c1, r2, c2), 0)
    CASE "K" : CanPieceAttack = IFF(dr <= 1 AND dc <= 1 AND (dr + dc > 0), 1, 0)
  END SELECT
END FUNC

FUNC IsSquareAttacked(tr, tc, by_side)
  FOR r = 0 TO 7
    FOR c = 0 TO 7
      IF PieceSide(board(r, c)) = by_side THEN
        IF CanPieceAttack(r, c, tr, tc) = 1 THEN IsSquareAttacked = 1 : EXIT FUNC
      ENDIF
    NEXT
  NEXT
  IsSquareAttacked = 0
END FUNC

FUNC IsKingInCheck(side)
  tk$ = IFF(side = 1, "K", "k")
  FOR r = 0 TO 7
    FOR c = 0 TO 7
      IF board(r, c) = tk$ THEN IsKingInCheck = IsSquareAttacked(r, c, -side) : EXIT FUNC
    NEXT
  NEXT
  IsKingInCheck = 1
END FUNC

FUNC IsLegalMove(r1, c1, r2, c2)
  p$ = board(r1, c1) : side = PieceSide(p$)
  IF side = 0 OR PieceSide(board(r2, c2)) = side THEN IsLegalMove = 0 : EXIT FUNC
  up$ = UCASE(p$)
  IF up$ = "K" AND r1 = r2 AND ABS(c2 - c1) = 2 THEN
    IF IsKingInCheck(side) = 1 THEN IsLegalMove = 0 : EXIT FUNC
    IF side = 1 AND w_kmoved = 0 AND r1 = 7 THEN
      IF c2 = 6 AND w_r7moved = 0 AND board(7, 5) = "" AND board(7, 6) = "" AND board(7, 7) = "R" AND IsSquareAttacked(7, 5, -1) = 0 AND IsSquareAttacked(7, 6, -1) = 0 THEN IsLegalMove = 1 : EXIT FUNC
      IF c2 = 2 AND w_r0moved = 0 AND board(7, 1) = "" AND board(7, 2) = "" AND board(7, 3) = "" AND board(7, 0) = "R" AND IsSquareAttacked(7, 3, -1) = 0 AND IsSquareAttacked(7, 2, -1) = 0 THEN IsLegalMove = 1 : EXIT FUNC
    ELIF side = -1 AND b_kmoved = 0 AND r1 = 0 THEN
      IF c2 = 6 AND b_r7moved = 0 AND board(0, 5) = "" AND board(0, 6) = "" AND board(0, 7) = "r" AND IsSquareAttacked(0, 5, 1) = 0 AND IsSquareAttacked(0, 6, 1) = 0 THEN IsLegalMove = 1 : EXIT FUNC
      IF c2 = 2 AND b_r0moved = 0 AND board(0, 1) = "" AND board(0, 2) = "" AND board(0, 3) = "" AND board(0, 0) = "r" AND IsSquareAttacked(0, 3, 1) = 0 AND IsSquareAttacked(0, 2, 1) = 0 THEN IsLegalMove = 1 : EXIT FUNC
    ENDIF
    IsLegalMove = 0 : EXIT FUNC
  ENDIF
  IF CanPieceAttack(r1, c1, r2, c2) = 0 THEN IsLegalMove = 0 : EXIT FUNC
  s_src$ = board(r1, c1) : s_dst$ = board(r2, c2) : s_ep$ = ""
  is_ep = (up$ = "P" AND r2 = ep_r AND c2 = ep_c AND s_dst$ = "")
  IF is_ep THEN s_ep$ = board(r1, c2) : board(r1, c2) = ""
  board(r2, c2) = s_src$ : board(r1, c1) = ""
  in_chk = IsKingInCheck(side)
  board(r1, c1) = s_src$ : board(r2, c2) = s_dst$
  IF is_ep THEN board(r1, c2) = s_ep$
  IsLegalMove = IFF(in_chk = 0, 1, 0)
END FUNC

FUNC HasAnyLegalMove(side)
  FOR r1 = 0 TO 7
    FOR c1 = 0 TO 7
      IF PieceSide(board(r1, c1)) = side THEN
        FOR r2 = 0 TO 7
          FOR c2 = 0 TO 7
            IF IsLegalMove(r1, c1, r2, c2) = 1 THEN HasAnyLegalMove = 1 : EXIT FUNC
          NEXT
        NEXT
      ENDIF
    NEXT
  NEXT
  HasAnyLegalMove = 0
END FUNC
