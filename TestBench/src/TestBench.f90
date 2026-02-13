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

  INTEGER, SAVE :: npts = 0
  REAL(8), ALLOCATABLE, SAVE :: t_csv(:), v_csv(:)

  CHARACTER(:), ALLOCATABLE, SAVE :: param_path
  CHARACTER(:), ALLOCATABLE, SAVE :: csv_path

  CHARACTER(*), PARAMETER :: RoutineName = 'TestBenchCsv'

  !-----------------------------
  ! Locals  
  !-----------------------------
  INTEGER :: ierr
  INTEGER :: avrSWAP_Status
  REAL(8) :: t_now, y_now
  CHARACTER(:), ALLOCATABLE :: inFileStr
  


  aviFAIL = 0
  ErrMsg  = ''

  inFileStr  = c_char_array_to_string(accINFILE)

  !---------------------------------------------
  ! One-time init: parse parameter file + load CSV
  !---------------------------------------------
  IF (.NOT. initialized) THEN
    initialized = .TRUE.
    param_path  = TRIM(inFileStr)

    CALL parse_testbenchcsv_infile(param_path, csv_path, swap_out_index, do_interp, ierr, ErrMsg)
    IF (ierr /= 0) THEN
      aviFAIL = -1
      CALL set_discon_message(avcMSG, RoutineName//': '//TRIM(ErrMsg))
      RETURN
    ENDIF

    CALL load_csv_two_columns(csv_path, t_csv, v_csv, npts, ierr, ErrMsg)
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
  
  IF (do_interp) THEN
    y_now = interp_linear_clamped(t_csv, v_csv, npts, t_now)
  ELSE
    y_now = sample_hold_previous(t_csv, v_csv, npts, t_now)
  ENDIF
  
  avrSWAP_Status = NINT(avrSWAP(1))
  
  IF (avrSWAP_Status >= 0) THEN
      avrSWAP(swap_out_index) = REAL(y_now, KIND=C_FLOAT)
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
  SUBROUTINE parse_testbenchcsv_infile(pfile, csvOut, swapIdx, interp, ierr, err)
    CHARACTER(*), INTENT(IN)  :: pfile
    CHARACTER(:), ALLOCATABLE, INTENT(OUT) :: csvOut
    INTEGER,      INTENT(OUT) :: swapIdx
    LOGICAL,      INTENT(OUT) :: interp
    INTEGER,      INTENT(OUT) :: ierr
    CHARACTER(*), INTENT(OUT) :: err

    INTEGER :: u, ios
    CHARACTER(512) :: line
    CHARACTER(:), ALLOCATABLE :: key, val
    LOGICAL :: haveCsv, haveSwap, haveInterp
    CHARACTER(:), ALLOCATABLE :: baseDir, csvRaw

    ierr = 0
    err  = ''
    swapIdx = -1
    interp  = .TRUE.
    haveCsv = .FALSE.
    haveSwap = .FALSE.
    haveInterp = .FALSE.

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

    csvOut = resolve_relative_path(baseDir, csvRaw)
  END SUBROUTINE parse_testbenchcsv_infile

  SUBROUTINE strip_comment_and_trim(s)
    CHARACTER(*), INTENT(INOUT) :: s
    INTEGER :: p
    p = INDEX(s, '#')
    IF (p > 0) s = s(1:p-1)
    s = ADJUSTL(s)
  END SUBROUTINE strip_comment_and_trim

  LOGICAL FUNCTION split_key_value(line, key, val)
    CHARACTER(*), INTENT(IN) :: line
    CHARACTER(:), ALLOCATABLE, INTENT(OUT) :: key, val
    INTEGER :: p
    p = INDEX(line, ':')
    IF (p <= 0) THEN
      split_key_value = .FALSE.
      RETURN
    ENDIF
    key = ADJUSTL(line(1:p-1))
    val = ADJUSTL(line(p+1:))
    key = TRIM(key)
    val = TRIM(val)
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
    t = ADJUSTL(TRIM(txt))
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

  !========================
  ! CSV loader: 2 numeric columns (time,value)
  !========================
  SUBROUTINE load_csv_two_columns(path, t, v, n, ierr, err)
    CHARACTER(*), INTENT(IN) :: path
    REAL(8), ALLOCATABLE, INTENT(OUT) :: t(:), v(:)
    INTEGER, INTENT(OUT) :: n, ierr
    CHARACTER(*), INTENT(OUT) :: err

    INTEGER :: u, ios, count, i
    CHARACTER(512) :: line
    REAL(8) :: tt, vv

    ierr = 0; err = ''; n = 0

    OPEN(NEWUNIT=u, FILE=TRIM(path), STATUS='OLD', ACTION='READ', IOSTAT=ios)
    IF (ios /= 0) THEN
      ierr = 1
      err  = 'Could not open CSV: '//TRIM(path)
      RETURN
    ENDIF

    count = 0
    DO
      READ(u,'(A)',IOSTAT=ios) line
      IF (ios /= 0) EXIT
      IF (is_blank_or_comment(line)) CYCLE
      IF (try_parse_two_reals(line, tt, vv)) count = count + 1
    END DO
    CLOSE(u)

    IF (count < 2) THEN
      ierr = 2
      err  = 'CSV has fewer than 2 numeric rows (need time,value).'
      RETURN
    ENDIF

    ALLOCATE(t(count), v(count))
    n = count

    OPEN(NEWUNIT=u, FILE=TRIM(path), STATUS='OLD', ACTION='READ', IOSTAT=ios)
    IF (ios /= 0) THEN
      ierr = 3
      err  = 'Could not re-open CSV: '//TRIM(path)
      RETURN
    ENDIF

    i = 0
    DO
      READ(u,'(A)',IOSTAT=ios) line
      IF (ios /= 0) EXIT
      IF (is_blank_or_comment(line)) CYCLE
      IF (try_parse_two_reals(line, tt, vv)) THEN
        i = i + 1
        t(i) = tt
        v(i) = vv
      ENDIF
    END DO
    CLOSE(u)

    CALL ensure_sorted_by_time(t, v, n, ierr, err)
  END SUBROUTINE load_csv_two_columns

  LOGICAL FUNCTION is_blank_or_comment(line)
    CHARACTER(*), INTENT(IN) :: line
    CHARACTER(:), ALLOCATABLE :: s
    s = ADJUSTL(line)
    is_blank_or_comment = (LEN_TRIM(s) == 0) .OR. (s(1:1) == '#') .OR. (s(1:1) == '!')
  END FUNCTION is_blank_or_comment

  LOGICAL FUNCTION try_parse_two_reals(line, a, b)
    CHARACTER(*), INTENT(IN) :: line
    REAL(8), INTENT(OUT) :: a, b
    CHARACTER(512) :: tmp
    INTEGER :: ios, p
    tmp = line
    DO p = 1, LEN(tmp)
      IF (tmp(p:p) == ',') tmp(p:p) = ' '
    END DO
    READ(tmp, *, IOSTAT=ios) a, b
    try_parse_two_reals = (ios == 0)
  END FUNCTION try_parse_two_reals

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
  
END SUBROUTINE DISCON