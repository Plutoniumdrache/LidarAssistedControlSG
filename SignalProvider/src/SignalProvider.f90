SUBROUTINE DISCON(avrSWAP, aviFAIL, accINFILE, avcOUTNAME, avcMSG) BIND (C, NAME='DISCON')
! DO NOT REMOVE or MODIFY LINES starting with "!DEC$" or "!GCC$"

  USE, INTRINSIC :: ISO_C_BINDING
  IMPLICIT NONE

#ifndef IMPLICIT_DLLEXPORT
!DEC$ ATTRIBUTES DLLEXPORT :: DISCON
!GCC$ ATTRIBUTES DLLEXPORT :: DISCON
#endif

  REAL(C_FLOAT),          INTENT(INOUT) :: avrSWAP(*)
  INTEGER(C_INT),         INTENT(INOUT) :: aviFAIL
  CHARACTER(KIND=C_CHAR), INTENT(IN   ) :: accINFILE(NINT(avrSWAP(50)))
  CHARACTER(KIND=C_CHAR), INTENT(IN   ) :: avcOUTNAME(NINT(avrSWAP(51)))
  CHARACTER(KIND=C_CHAR), INTENT(INOUT) :: avcMSG(NINT(avrSWAP(49)))

  CHARACTER(SIZE(avcMSG)-1) :: ErrMsg

  !-----------------------------
  ! Persistent state
  !-----------------------------
  LOGICAL, SAVE :: initialized = .FALSE.
  INTEGER, SAVE :: swap_out_index = -1
  LOGICAL, SAVE :: do_interp = .TRUE.
  REAL(8), SAVE :: preview_time = 0.0D0

  INTEGER, SAVE :: npts = 0
  INTEGER, SAVE :: time_col = -1
  INTEGER, SAVE :: value_col = -1
  REAL(8), ALLOCATABLE, SAVE :: t_csv(:), v_csv(:)

  CHARACTER(:), ALLOCATABLE, SAVE :: param_path
  CHARACTER(:), ALLOCATABLE, SAVE :: csv_path

  CHARACTER(*), PARAMETER :: RoutineName = 'SignalProviderCSV'

  !-----------------------------
  ! Locals  
  !-----------------------------
  INTEGER :: ierr
  INTEGER :: avrSWAP_Status
  REAL(8) :: t_now, t_eval, y_now
  CHARACTER(:), ALLOCATABLE :: inFileStr
  


  aviFAIL = 0
  ErrMsg  = ''

  inFileStr  = c_char_array_to_string(accINFILE)
  CALL log_line('Raw inFileStr=['//inFileStr//']')
  CALL log_line('Length from avrSWAP(50)=['//trim(to_str_i4(NINT(avrSWAP(50))))//']')
      CALL log_line('SIZE(accINFILE)=['//trim(to_str_i4(SIZE(accINFILE)))//']')
    CALL log_line('avrSWAP(50)=['//trim(to_str_i4(NINT(avrSWAP(50))))//']')
  CALL log_line('DISCON entered') ! debug
  
  !---------------------------------------------
  ! One-time init: parse parameter file + load CSV
  !---------------------------------------------
  IF (.NOT. initialized) THEN
    CALL log_line('Starting initialization')
    
    param_path  = TRIM(inFileStr)

    CALL parse_SignalProviderCsv_infile(param_path, csv_path, swap_out_index, do_interp, preview_time, &
        time_col, value_col, ierr, ErrMsg)
    IF (ierr /= 0) THEN
        CALL log_line('parse_SignalProviderCsv_infile failed: '//TRIM(ErrMsg))
        aviFAIL = -1
        CALL set_discon_message(avcMSG, RoutineName//': '//TRIM(ErrMsg))
      RETURN
    ENDIF

    CALL load_delimited_columns(csv_path, time_col, value_col, t_csv, v_csv, npts, ierr, ErrMsg)
    IF (ierr /= 0) THEN
      aviFAIL = -1
      CALL set_discon_message(avcMSG, RoutineName//': '//TRIM(ErrMsg))
      RETURN
    ENDIF

    IF (swap_out_index < 1) THEN
      aviFAIL = -1
      CALL set_discon_message(avcMSG, RoutineName//': SwapIndex must be >= 1.')
      RETURN
    ENDIF
    initialized = .TRUE.
  ENDIF

  IF (npts < 2) THEN
    aviFAIL = -1
    CALL set_discon_message(avcMSG, RoutineName//': CSV has too few points.')
    RETURN
  ENDIF

  !---------------------------------------------
  ! Main processing each call
  !---------------------------------------------
  ! From FAST Extended Bladed Interface Documentation: avrSWAP(2) is time (s)
  ! https://openfast.readthedocs.io/en/dev/source/user/servodyn/ExtendedBladedInterface.html
  t_now = REAL(avrSWAP(2), KIND=8)
  
  IF (ABS(preview_time) > 0.0D0) THEN
    t_eval = wrap_time_periodic(t_now + preview_time, t_csv(1), t_csv(npts))
  ELSE
    t_eval = t_now
  END IF

  IF (do_interp) THEN
    IF (ABS(preview_time) > 0.0D0) THEN
      y_now = interp_linear_periodic(t_csv, v_csv, npts, t_eval)
    ELSE
      y_now = interp_linear_clamped(t_csv, v_csv, npts, t_eval)
    END IF
  ELSE
    IF (ABS(preview_time) > 0.0D0) THEN
      y_now = sample_hold_previous_periodic(t_csv, v_csv, npts, t_eval)
    ELSE
      y_now = sample_hold_previous(t_csv, v_csv, npts, t_eval)
    END IF
  END IF
  
  avrSWAP_Status = NINT(avrSWAP(1))
  
IF (avrSWAP_Status >= 0) THEN
      CALL log_line(': before write to swap')
      CALL log_line('TB: swp idx='//trim(adjustl(to_str_i4(swap_out_index))))
      CALL log_line('TB: swp entry idx 1='//trim(adjustl(to_str_i4(avrSWAP_Status))) )
      avrSWAP(swap_out_index) = REAL(y_now, KIND=C_FLOAT)
        CALL log_line('TB: t='//trim(adjustl(to_str(t_now))) )
      CALL log_line(': after write to swap')
    END IF

  CALL set_discon_message(avcMSG, '')
  aviFAIL = 0
  RETURN

CONTAINS

  !========================
  ! C char[] -> Fortran string
  !========================
  FUNCTION c_char_array_to_string(ca) RESULT(s)
  USE, INTRINSIC :: ISO_C_BINDING
  CHARACTER(KIND=C_CHAR), INTENT(IN) :: ca(:)
  CHARACTER(:), ALLOCATABLE :: s
  INTEGER :: i, n, nch

  n = SIZE(ca)

  ! Find first NUL or end
  nch = 0
  DO i = 1, n
    IF (ca(i) == C_NULL_CHAR) EXIT
    nch = nch + 1
  END DO

  ! Allocate exact length (or empty string)
  IF (nch <= 0) THEN
    s = ''
    RETURN
  ENDIF

  ALLOCATE(CHARACTER(LEN=nch) :: s)

  ! Copy character-by-character (C_CHAR -> default CHARACTER)
  DO i = 1, nch
    s(i:i) = ACHAR(IACHAR(ca(i)))
  END DO
END FUNCTION c_char_array_to_string


  SUBROUTINE set_discon_message(msgArray, text)
    CHARACTER(KIND=C_CHAR), INTENT(INOUT) :: msgArray(:)
    CHARACTER(*),           INTENT(IN)    :: text
    INTEGER :: i, n

    n = SIZE(msgArray)
    msgArray = C_NULL_CHAR
    DO i = 1, MIN(LEN_TRIM(text), n-1)
      msgArray(i) = text(i:i)
    END DO
    msgArray(MIN(LEN_TRIM(text)+1, n)) = C_NULL_CHAR
  END SUBROUTINE set_discon_message

  !========================
  ! Parse your Key: value .in file
  !========================
SUBROUTINE parse_SignalProviderCsv_infile(pfile, csvOut, swapIdx, interp, preview, timeCol, valueCol, ierr, err)
    CHARACTER(*), INTENT(IN)  :: pfile
    CHARACTER(:), ALLOCATABLE, INTENT(OUT) :: csvOut
    INTEGER,      INTENT(OUT) :: swapIdx
    LOGICAL,      INTENT(OUT) :: interp
    INTEGER,      INTENT(OUT) :: ierr
    CHARACTER(*), INTENT(OUT) :: err
    REAL(8),      INTENT(OUT) :: preview
    INTEGER,      INTENT(OUT) :: timeCol
    INTEGER,      INTENT(OUT) :: valueCol

    INTEGER :: u, ios
    CHARACTER(512) :: line
    CHARACTER(:), ALLOCATABLE :: key, val
    LOGICAL :: haveCsv, haveSwap, haveInterp, havePreview, haveTimeCol, haveValueCol
    CHARACTER(:), ALLOCATABLE :: baseDir, csvRaw

    ierr = 0
    err  = ''
    swapIdx = -1
    preview = 0.0D0
    timeCol  = -1
    valueCol = -1
    interp  = .TRUE.
    haveCsv = .FALSE.
    haveSwap = .FALSE.
    haveInterp = .FALSE.
    havePreview = .FALSE.
    haveTimeCol  = .FALSE.
    haveValueCol = .FALSE.

    baseDir = dirname_of_path(TRIM(pfile))

    OPEN(NEWUNIT=u, FILE=TRIM(pfile), STATUS='OLD', ACTION='READ', IOSTAT=ios)
    IF (ios /= 0) THEN
      ierr = 1
      err  = 'Could not open parameter file: '//TRIM(pfile)
      RETURN
    ENDIF

    DO
      READ(u,'(A)',IOSTAT=ios) line
      IF (ios /= 0) EXIT

      CALL strip_comment_and_trim(line)
      IF (LEN_TRIM(line) == 0) CYCLE
      IF (.NOT. split_key_value(line, key, val)) CYCLE

      CALL to_lower_inplace(key)

      SELECT CASE (TRIM(key))
      CASE ('csvfilepath', 'csvfile', 'filename')
        csvRaw = TRIM(val)
        haveCsv = .TRUE.

      CASE ('swapindex', 'swapindextowrite', 'indextowrite')
        READ(val, *, IOSTAT=ios) swapIdx
        IF (ios /= 0) THEN
          ierr = 2
          err  = 'SwapIndex is not a valid integer.'
          CLOSE(u)
          RETURN
        ENDIF
        haveSwap = .TRUE.

      CASE ('interpolatebetweenvalues', 'interpolate')
        interp = parse_bool(val, ios)
        IF (ios /= 0) THEN
          ierr = 3
          err  = 'InterpolateBetweenValues must be true/false.'
          CLOSE(u)
          RETURN
        ENDIF
        haveInterp = .TRUE.
        
    CASE ('previewtime', 'preview', 'previewtimesec', 'previewseconds')
        READ(val, *, IOSTAT=ios) preview
        IF (ios /= 0) THEN
          ierr = 6
          err  = 'PreviewTime is not a valid real number.'
          CLOSE(u)
          RETURN
        ENDIF
        havePreview = .TRUE.
    
    CASE ('timecolumnindex', 'timecol')
        READ(val, *, IOSTAT=ios) timeCol
        IF (ios /= 0 .OR. timeCol < 1) THEN
          ierr = 7
          err  = 'TimeColumn must be an integer >= 1.'
          CLOSE(u)
          RETURN
        ENDIF
        haveTimeCol = .TRUE.
    
   CASE ('valuecolumnindex', 'valuecol')
        READ(val, *, IOSTAT=ios) valueCol
        IF (ios /= 0 .OR. valueCol < 1) THEN
          ierr = 8
          err  = 'ValueColumn must be an integer >= 1.'
          CLOSE(u)
          RETURN
        ENDIF
        haveValueCol = .TRUE.
        
      CASE DEFAULT
        ! ignore unknown keys
      END SELECT
    END DO
    CLOSE(u)

    IF (.NOT. haveCsv) THEN
      ierr = 4
      err  = 'Missing required key: CsvFilePath'
      RETURN
    ENDIF
    IF (.NOT. haveSwap) THEN
      ierr = 5
      err  = 'Missing required key: SwapIndex'
      RETURN
    ENDIF
    IF (.NOT. haveInterp) THEN
      ! If omitted, default stays .TRUE. (fine)
    ENDIF
    IF (.NOT. haveTimeCol) THEN
      ierr = 9
      err  = 'Missing required key: TimeColumnIndex'
      RETURN
    ENDIF
    IF (.NOT. haveValueCol) THEN
      ierr = 10
      err  = 'Missing required key: ValueColumnIndex'
      RETURN
    ENDIF

    csvOut = resolve_relative_path(baseDir, csvRaw)
END SUBROUTINE parse_SignalProviderCsv_infile

  !========================
  ! Generic comma-separated loader:
  ! reads selected time/value columns from any comma-separated file
  !========================
  SUBROUTINE load_delimited_columns(path, timeCol, valueCol, t, v, n, ierr, err)
    CHARACTER(*), INTENT(IN) :: path
    INTEGER,      INTENT(IN) :: timeCol, valueCol
    REAL(8), ALLOCATABLE, INTENT(OUT) :: t(:), v(:)
    INTEGER, INTENT(OUT) :: n, ierr
    CHARACTER(*), INTENT(OUT) :: err

    INTEGER :: u, ios, count, i
    CHARACTER(2048) :: line
    REAL(8) :: tt, vv

    ierr = 0
    err  = ''
    n    = 0

    IF (timeCol < 1 .OR. valueCol < 1) THEN
      ierr = 1
      err  = 'TimeColumn and ValueColumn must be >= 1.'
      RETURN
    ENDIF

    OPEN(NEWUNIT=u, FILE=TRIM(path), STATUS='OLD', ACTION='READ', IOSTAT=ios)
    IF (ios /= 0) THEN
      ierr = 2
      err  = 'Could not open comma-separated file: '//TRIM(path)
      RETURN
    ENDIF

    count = 0
    DO
      READ(u,'(A)',IOSTAT=ios) line
      IF (ios /= 0) EXIT
      IF (is_blank_or_comment(line)) CYCLE
      IF (try_parse_selected_columns(line, timeCol, valueCol, tt, vv)) count = count + 1
    END DO
    CLOSE(u)

    IF (count < 2) THEN
      ierr = 3
      err  = 'File has fewer than 2 valid numeric rows for the selected TimeColumn and ValueColumn.'
      RETURN
    ENDIF

    ALLOCATE(t(count), v(count))
    n = count

    OPEN(NEWUNIT=u, FILE=TRIM(path), STATUS='OLD', ACTION='READ', IOSTAT=ios)
    IF (ios /= 0) THEN
      ierr = 4
      err  = 'Could not re-open comma-separated file: '//TRIM(path)
      RETURN
    ENDIF

    i = 0
    DO
      READ(u,'(A)',IOSTAT=ios) line
      IF (ios /= 0) EXIT
      IF (is_blank_or_comment(line)) CYCLE
      IF (try_parse_selected_columns(line, timeCol, valueCol, tt, vv)) THEN
        i = i + 1
        t(i) = tt
        v(i) = vv
      ENDIF
    END DO
    CLOSE(u)

    CALL ensure_sorted_by_time(t, v, n, ierr, err)
  END SUBROUTINE load_delimited_columns


  LOGICAL FUNCTION try_parse_selected_columns(line, timeCol, valueCol, tval, vval)
    CHARACTER(*), INTENT(IN) :: line
    INTEGER,      INTENT(IN) :: timeCol, valueCol
    REAL(8),      INTENT(OUT) :: tval, vval

    CHARACTER(:), ALLOCATABLE :: f1, f2
    INTEGER :: ios1, ios2

    try_parse_selected_columns = .FALSE.

    f1 = get_csv_field(line, timeCol)
    f2 = get_csv_field(line, valueCol)

    IF (.NOT. ALLOCATED(f1)) RETURN
    IF (.NOT. ALLOCATED(f2)) RETURN
    IF (LEN_TRIM(f1) == 0 .OR. LEN_TRIM(f2) == 0) RETURN

    READ(f1, *, IOSTAT=ios1) tval
    READ(f2, *, IOSTAT=ios2) vval

    IF (ios1 == 0 .AND. ios2 == 0) THEN
      try_parse_selected_columns = .TRUE.
    ENDIF
  END FUNCTION try_parse_selected_columns


  FUNCTION get_csv_field(line, fieldIndex) RESULT(field)
    CHARACTER(*), INTENT(IN) :: line
    INTEGER,      INTENT(IN) :: fieldIndex
    CHARACTER(:), ALLOCATABLE :: field

    INTEGER :: i, n, startPos, endPos, currentField
    LOGICAL :: inQuotes
    CHARACTER(1) :: ch

    field = ''

    IF (fieldIndex < 1) RETURN

    n = LEN_TRIM(line)
    IF (n <= 0) RETURN

    currentField = 1
    startPos = 1
    inQuotes = .FALSE.

    DO i = 1, n
      ch = line(i:i)

      IF (ch == '"') THEN
        inQuotes = .NOT. inQuotes
      ELSEIF (ch == ',' .AND. .NOT. inQuotes) THEN
        IF (currentField == fieldIndex) THEN
          endPos = i - 1
          field = trim_whitespace(strip_optional_quotes(line(startPos:endPos)))
          RETURN
        ENDIF
        currentField = currentField + 1
        startPos = i + 1
      ENDIF
    END DO

    ! last field
    IF (currentField == fieldIndex) THEN
      field = trim_whitespace(strip_optional_quotes(line(startPos:n)))
    ENDIF
  END FUNCTION get_csv_field


  FUNCTION strip_optional_quotes(s) RESULT(out)
    CHARACTER(*), INTENT(IN) :: s
    CHARACTER(:), ALLOCATABLE :: out
    CHARACTER(:), ALLOCATABLE :: tmp
    INTEGER :: n

    tmp = trim_whitespace(s)
    n = LEN(tmp)

    IF (n >= 2) THEN
      IF ((tmp(1:1) == '"' .AND. tmp(n:n) == '"') .OR. &
          (tmp(1:1) == "'" .AND. tmp(n:n) == "'")) THEN
        out = tmp(2:n-1)
        RETURN
      ENDIF
    ENDIF

    out = tmp
  END FUNCTION strip_optional_quotes

SUBROUTINE strip_comment_and_trim(s)
  CHARACTER(*), INTENT(INOUT) :: s
  INTEGER :: p

  CALL tabs_to_spaces(s)
  p = INDEX(s, '#')
  IF (p > 0) s = s(1:p-1)
  s = trim_whitespace(s)
END SUBROUTINE strip_comment_and_trim

  SUBROUTINE tabs_to_spaces(s)
  CHARACTER(*), INTENT(INOUT) :: s
  INTEGER :: i
  DO i = 1, LEN(s)
    IF (s(i:i) == ACHAR(9)) s(i:i) = ' '
  END DO
  END SUBROUTINE tabs_to_spaces
  
  
  
  LOGICAL FUNCTION split_key_value(line, key, val)
    CHARACTER(*), INTENT(IN) :: line
    CHARACTER(:), ALLOCATABLE, INTENT(OUT) :: key, val
    INTEGER :: p
    p = INDEX(line, ':')
    IF (p <= 0) THEN
      split_key_value = .FALSE.
      RETURN
    ENDIF
    key = trim_whitespace(line(1:p-1))
    val = trim_whitespace(line(p+1:))
    ! strip optional quotes
    IF (LEN(val) >= 2) THEN
      IF ((val(1:1) == '"' .AND. val(LEN(val):LEN(val)) == '"') .OR. &
          (val(1:1) == "'" .AND. val(LEN(val):LEN(val)) == "'")) THEN
        val = val(2:LEN(val)-1)
      ENDIF
    ENDIF
    split_key_value = .TRUE.
  END FUNCTION split_key_value

  SUBROUTINE to_lower_inplace(s)
    CHARACTER(:), ALLOCATABLE, INTENT(INOUT) :: s
    INTEGER :: i, c
    DO i = 1, LEN(s)
      c = IACHAR(s(i:i))
      IF (c >= IACHAR('A') .AND. c <= IACHAR('Z')) THEN
        s(i:i) = ACHAR(c + 32)
      ENDIF
    END DO
  END SUBROUTINE to_lower_inplace

  LOGICAL FUNCTION parse_bool(txt, ios)
    CHARACTER(*), INTENT(IN) :: txt
    INTEGER, INTENT(OUT) :: ios
    CHARACTER(:), ALLOCATABLE :: t
    ios = 0
    t = trim_whitespace(txt)
    CALL to_lower_inplace(t)
    SELECT CASE (TRIM(t))
    CASE ('true','t','1','yes','y')
      parse_bool = .TRUE.
    CASE ('false','f','0','no','n')
      parse_bool = .FALSE.
    CASE DEFAULT
      ios = 1
      parse_bool = .TRUE.
    END SELECT
  END FUNCTION parse_bool

  FUNCTION dirname_of_path(p) RESULT(d)
    CHARACTER(*), INTENT(IN) :: p
    CHARACTER(:), ALLOCATABLE :: d
    INTEGER :: i
    d = '.'
    DO i = LEN_TRIM(p), 1, -1
      IF (p(i:i) == '/' .OR. p(i:i) == '\') THEN
        IF (i > 1) THEN
          d = p(1:i-1)
        ELSE
          d = p(1:1)
        ENDIF
        RETURN
      ENDIF
    END DO
  END FUNCTION dirname_of_path

  FUNCTION resolve_relative_path(baseDir, rel) RESULT(full)
    CHARACTER(*), INTENT(IN) :: baseDir, rel
    CHARACTER(:), ALLOCATABLE :: full
    ! If rel looks absolute (Unix "/" or Windows "C:\") leave it.
    IF (LEN_TRIM(rel) >= 1) THEN
      IF (rel(1:1) == '/' .OR. rel(1:1) == '\') THEN
        full = TRIM(rel)
        RETURN
      ENDIF
      IF (LEN_TRIM(rel) >= 2) THEN
        IF (rel(2:2) == ':') THEN
          full = TRIM(rel)
          RETURN
        ENDIF
      ENDIF
    ENDIF
    full = TRIM(baseDir)//'/'//TRIM(rel)
  END FUNCTION resolve_relative_path

  

  LOGICAL FUNCTION is_blank_or_comment(line)
    CHARACTER(*), INTENT(IN) :: line
    CHARACTER(:), ALLOCATABLE :: s
    s = ADJUSTL(line)
    is_blank_or_comment = (LEN_TRIM(s) == 0) .OR. (s(1:1) == '#') .OR. (s(1:1) == '!')
  END FUNCTION is_blank_or_comment

  SUBROUTINE ensure_sorted_by_time(t, v, n, ierr, err)
    REAL(8), INTENT(IN) :: t(:), v(:)
    INTEGER, INTENT(IN) :: n
    INTEGER, INTENT(OUT) :: ierr
    CHARACTER(*), INTENT(OUT) :: err
    INTEGER :: i
    ierr = 0; err = ''
    DO i = 2, n
      IF (t(i) < t(i-1)) THEN
        ierr = 10
        err  = 'CSV timestamps must be nondecreasing. Sort by time.'
        RETURN
      ENDIF
    END DO
  END SUBROUTINE ensure_sorted_by_time

  !========================
  ! Interpolation modes
  !========================
  REAL(8) FUNCTION interp_linear_clamped(t, v, n, x)
    REAL(8), INTENT(IN) :: t(:), v(:), x
    INTEGER, INTENT(IN) :: n
    INTEGER, SAVE :: k = 1
    REAL(8) :: x0, x1, y0, y1, a

    IF (x <= t(1)) THEN
      interp_linear_clamped = v(1); k = 1; RETURN
    ELSEIF (x >= t(n)) THEN
      interp_linear_clamped = v(n); k = n-1; RETURN
    ENDIF

    IF (k < 1) k = 1
    IF (k > n-1) k = n-1

    DO WHILE (k < n-1 .AND. x > t(k+1))
      k = k + 1
    END DO
    DO WHILE (k > 1 .AND. x < t(k))
      k = k - 1
    END DO

    x0 = t(k); x1 = t(k+1)
    y0 = v(k); y1 = v(k+1)

    IF (x1 == x0) THEN
      interp_linear_clamped = y0 ! prevent division by zero
    ELSE
      a = (x - x0) / (x1 - x0)
      interp_linear_clamped = (1.0D0-a)*y0 + a*y1
    ENDIF
  END FUNCTION interp_linear_clamped

  ! sample and hold function
  REAL(8) FUNCTION sample_hold_previous(t, v, n, x)
    REAL(8), INTENT(IN) :: t(:), v(:), x
    INTEGER, INTENT(IN) :: n
    INTEGER, SAVE :: k = 1 ! keep k during function calls

    IF (x <= t(1)) THEN
      sample_hold_previous = v(1); k = 1; RETURN
    ELSEIF (x >= t(n)) THEN
      sample_hold_previous = v(n); k = n; RETURN
    ENDIF

    IF (k < 1) k = 1
    IF (k > n) k = n

    DO WHILE (k < n .AND. x >= t(k+1))
      k = k + 1
    END DO
    DO WHILE (k > 1 .AND. x < t(k))
      k = k - 1
    END DO

    sample_hold_previous = v(k)
  END FUNCTION sample_hold_previous
  
  FUNCTION trim_whitespace(s) RESULT(out)
  CHARACTER(*), INTENT(IN) :: s
  CHARACTER(:), ALLOCATABLE :: out
  INTEGER :: i1, i2

  i1 = 1
  i2 = LEN(s)

  DO WHILE (i1 <= i2 .AND. (s(i1:i1) == ' ' .OR. s(i1:i1) == ACHAR(9)))
    i1 = i1 + 1
  END DO

  DO WHILE (i2 >= i1 .AND. (s(i2:i2) == ' ' .OR. s(i2:i2) == ACHAR(9)))
    i2 = i2 - 1
  END DO

  IF (i2 < i1) THEN
    out = ''
  ELSE
    out = s(i1:i2)
  END IF
  END FUNCTION trim_whitespace
  
  REAL(8) FUNCTION wrap_time_periodic(x, t0, t1)
    REAL(8), INTENT(IN) :: x, t0, t1
    REAL(8) :: period

    period = t1 - t0
    IF (period <= 0.0D0) THEN
      wrap_time_periodic = t0
    ELSE
      wrap_time_periodic = t0 + MODULO(x - t0, period)
    END IF
  END FUNCTION wrap_time_periodic
  
  REAL(8) FUNCTION interp_linear_periodic(t, v, n, x)
    REAL(8), INTENT(IN) :: t(:), v(:), x
    INTEGER, INTENT(IN) :: n
    INTEGER :: i
    REAL(8) :: xw, period, x0, x1, y0, y1, a

    period = t(n) - t(1)
    IF (n < 2 .OR. period <= 0.0D0) THEN
      interp_linear_periodic = v(1)
      RETURN
    END IF

    xw = wrap_time_periodic(x, t(1), t(n))

    ! Find interval [t(i), t(i+1)) for i=1..n-1
    DO i = 1, n-1
      IF (xw >= t(i) .AND. xw < t(i+1)) THEN
        x0 = t(i)
        x1 = t(i+1)
        y0 = v(i)
        y1 = v(i+1)

        IF (x1 <= x0) THEN
          interp_linear_periodic = y0
        ELSE
          a = (xw - x0) / (x1 - x0)
          interp_linear_periodic = (1.0D0-a)*y0 + a*y1
        END IF
        RETURN
      END IF
    END DO

    ! If xw lands exactly at the end due to roundoff, use the last point
    interp_linear_periodic = v(n)
  END FUNCTION interp_linear_periodic
  
    REAL(8) FUNCTION sample_hold_previous_periodic(t, v, n, x)
    REAL(8), INTENT(IN) :: t(:), v(:), x
    INTEGER, INTENT(IN) :: n
    INTEGER :: i
    REAL(8) :: xw, period

    period = t(n) - t(1)
    IF (n < 2 .OR. period <= 0.0D0) THEN
      sample_hold_previous_periodic = v(1)
      RETURN
    END IF

    xw = wrap_time_periodic(x, t(1), t(n))

    DO i = n, 1, -1
      IF (xw >= t(i)) THEN
        sample_hold_previous_periodic = v(i)
        RETURN
      END IF
    END DO

    sample_hold_previous_periodic = v(1)
  END FUNCTION sample_hold_previous_periodic
  
  FUNCTION to_str(x) RESULT(s)
  REAL(8), INTENT(IN) :: x
  CHARACTER(64) :: s
  WRITE(s,'(G0.16)') x
END FUNCTION

FUNCTION to_str_i4(i) RESULT(s)
  INTEGER, INTENT(IN) :: i
  CHARACTER(32) :: s
  WRITE(s,'(I0)') i
END FUNCTION
  
    END SUBROUTINE DISCON
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!    
SUBROUTINE log_line(txt)

  ! for logging
    INTEGER, SAVE :: ulog = -1
    LOGICAL, SAVE :: log_open = .FALSE.

    CHARACTER(*), INTENT(IN) :: txt
    INTEGER :: ios
    IF (.NOT. log_open) THEN
      OPEN(NEWUNIT=ulog, FILE='SignalProvider_debug.log', STATUS='REPLACE', ACTION='WRITE', IOSTAT=ios)
      IF (ios == 0) log_open = .TRUE.
    END IF
    IF (log_open) THEN
      WRITE(ulog,'(A)') TRIM(txt)
      CALL FLUSH(ulog)
    END IF
    
END SUBROUTINE log_line