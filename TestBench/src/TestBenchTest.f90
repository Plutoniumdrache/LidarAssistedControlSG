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

  CHARACTER(*), PARAMETER :: RoutineName = 'TestBench_IN_Only'

  ! parsed values (just to prove parsing works)
  CHARACTER(:), ALLOCATABLE :: param_path
  CHARACTER(:), ALLOCATABLE :: csv_path
  INTEGER :: swap_idx, ierr
  LOGICAL :: do_interp
  CHARACTER(256) :: ErrMsg

  aviFAIL = 0
  ErrMsg  = ''

  param_path = c_char_array_to_string(accINFILE)

  CALL parse_testbench_infile(param_path, csv_path, swap_idx, do_interp, ierr, ErrMsg)
  IF (ierr /= 0) THEN
    aviFAIL = -1
    CALL set_discon_message(avcMSG, RoutineName//': '//TRIM(ErrMsg))
    RETURN
  ENDIF

  ! Success message includes parsed content (helps confirm correct read)
  CALL set_discon_message(avcMSG, RoutineName//': OK. CsvFilePath="'//TRIM(csv_path)// &
       '", SwapIndex='//trim(int_to_str(swap_idx))// &
       ', Interp='//trim(bool_to_str(do_interp)))

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
  ! Parse Key: value file (no CSV reading)
  !========================
  SUBROUTINE parse_testbench_infile(pfile, csvOut, swapIdx, interp, ierr, err)
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

    ierr = 0
    err  = ''
    swapIdx = -1
    interp  = .TRUE.
    haveCsv = .FALSE.
    haveSwap = .FALSE.
    haveInterp = .FALSE.
    csvOut = ''

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
        csvOut = TRIM(val)
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
    ! InterpolateBetweenValues optional: default remains .TRUE. if missing

  END SUBROUTINE parse_testbench_infile

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
    key = TRIM(ADJUSTL(line(1:p-1)))
    val = TRIM(ADJUSTL(line(p+1:)))
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
      IF (c >= IACHAR('A') .AND. c <= IACHAR('Z')) s(i:i) = ACHAR(c + 32)
    END DO
  END SUBROUTINE to_lower_inplace

  LOGICAL FUNCTION parse_bool(txt, ios)
    CHARACTER(*), INTENT(IN) :: txt
    INTEGER, INTENT(OUT) :: ios
    CHARACTER(:), ALLOCATABLE :: t
    ios = 0
    t = TRIM(ADJUSTL(txt))
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

  FUNCTION int_to_str(i) RESULT(s)
    INTEGER, INTENT(IN) :: i
    CHARACTER(32) :: tmp
    CHARACTER(:), ALLOCATABLE :: s
    WRITE(tmp,'(I0)') i
    s = TRIM(tmp)
  END FUNCTION int_to_str

  FUNCTION bool_to_str(b) RESULT(s)
    LOGICAL, INTENT(IN) :: b
    CHARACTER(:), ALLOCATABLE :: s
    IF (b) THEN
      s = 'true'
    ELSE
      s = 'false'
    ENDIF
  END FUNCTION bool_to_str

END SUBROUTINE DISCON
