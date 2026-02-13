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

  CHARACTER(*), PARAMETER :: RoutineName = 'TestBench_LogSwap'

  !-----------------------------
  ! Persistent state
  !-----------------------------
  LOGICAL, SAVE :: initialized = .FALSE.
  INTEGER, SAVE :: swap_idx = -1
  INTEGER, SAVE :: log_unit = -1

  !-----------------------------
  ! Locals
  !-----------------------------
  CHARACTER(:), ALLOCATABLE :: inFile
  REAL(8) :: t_now, v_now
  INTEGER :: ierr
  CHARACTER(256) :: ErrMsg
  INTEGER :: avrSWAP_Status


  aviFAIL = 0
  ErrMsg  = ''

  !---------------------------------
  ! One-time initialization
  !---------------------------------
  IF (.NOT. initialized) THEN
    initialized = .TRUE.

    inFile = c_char_array_to_string(accINFILE)

    CALL read_swapindex_from_infile(inFile, swap_idx, ierr, ErrMsg)
    IF (ierr /= 0) THEN
      aviFAIL = -1
      CALL set_discon_message(avcMSG, RoutineName//': '//TRIM(ErrMsg))
      RETURN
    ENDIF

    IF (swap_idx < 1) THEN
      aviFAIL = -1
      CALL set_discon_message(avcMSG, RoutineName//': SwapIndex must be >= 1.')
      RETURN
    ENDIF

    OPEN(NEWUNIT=log_unit, FILE='TestBench_SwapLog.txt', &
         STATUS='REPLACE', ACTION='WRITE')

    WRITE(log_unit,'(A)') '# time(s), avrSWAP(SwapIndex)'
  ENDIF

  !---------------------------------
  ! Each time step
  !---------------------------------
  avrSWAP_Status = NINT(avrSWAP(1))
  IF (avrSWAP_Status >= 0) THEN
	t_now = REAL(avrSWAP(2), KIND=8)
	v_now = REAL(avrSWAP(swap_idx), KIND=8)
  END IF

  WRITE(log_unit,'(F12.5,1X,ES14.6)') t_now, v_now
  FLUSH(log_unit)

  CALL set_discon_message(avcMSG, '')
  aviFAIL = 0
  RETURN

CONTAINS

  !========================
  ! Safe C char[] -> string
  !========================
  FUNCTION c_char_array_to_string(ca) RESULT(s)
    CHARACTER(KIND=C_CHAR), INTENT(IN) :: ca(:)
    CHARACTER(:), ALLOCATABLE :: s
    INTEGER :: i, n, nch

    n = SIZE(ca)
    nch = 0
    DO i = 1, n
      IF (ca(i) == C_NULL_CHAR) EXIT
      nch = nch + 1
    END DO

    IF (nch == 0) THEN
      s = ''
      RETURN
    ENDIF

    ALLOCATE(CHARACTER(LEN=nch) :: s)
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
  ! Read SwapIndex only
  !========================
  SUBROUTINE read_swapindex_from_infile(pfile, idx, ierr, err)
    CHARACTER(*), INTENT(IN)  :: pfile
    INTEGER,      INTENT(OUT) :: idx
    INTEGER,      INTENT(OUT) :: ierr
    CHARACTER(*), INTENT(OUT) :: err

    INTEGER :: u, ios
    CHARACTER(256) :: line
    CHARACTER(:), ALLOCATABLE :: key, val

    ierr = 0
    err  = ''
    idx  = -1

    OPEN(NEWUNIT=u, FILE=TRIM(pfile), STATUS='OLD', ACTION='READ', IOSTAT=ios)
    IF (ios /= 0) THEN
      ierr = 1
      err  = 'Could not open IN file: '//TRIM(pfile)
      RETURN
    ENDIF

    DO
      READ(u,'(A)',IOSTAT=ios) line
      IF (ios /= 0) EXIT

      CALL strip_comment(line)
      IF (LEN_TRIM(line) == 0) CYCLE

      IF (.NOT. split_key_value(line, key, val)) CYCLE
      CALL to_lower(key)

      IF (TRIM(key) == 'swapindex') THEN
        READ(val,*,IOSTAT=ios) idx
        IF (ios /= 0) THEN
          ierr = 2
          err  = 'Invalid SwapIndex value.'
        ENDIF
        EXIT
      ENDIF
    END DO

    CLOSE(u)

    IF (idx < 0 .AND. ierr == 0) THEN
      ierr = 3
      err  = 'SwapIndex not found in IN file.'
    ENDIF
  END SUBROUTINE read_swapindex_from_infile

  SUBROUTINE strip_comment(s)
    CHARACTER(*), INTENT(INOUT) :: s
    INTEGER :: p
    p = INDEX(s, '#')
    IF (p > 0) s = s(1:p-1)
    s = ADJUSTL(s)
  END SUBROUTINE strip_comment

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
    split_key_value = .TRUE.
  END FUNCTION split_key_value

  SUBROUTINE to_lower(s)
    CHARACTER(:), ALLOCATABLE, INTENT(INOUT) :: s
    INTEGER :: i, c
    DO i = 1, LEN(s)
      c = IACHAR(s(i:i))
      IF (c >= IACHAR('A') .AND. c <= IACHAR('Z')) s(i:i) = ACHAR(c+32)
    END DO
  END SUBROUTINE to_lower

END SUBROUTINE DISCON
