!
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
!                    General Support Routines
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------

MODULE SUPPORT

PRIVATE
PUBLIC :: MUELLER, EIG, PI, GESC, NLVC, NRMLZ, RNRMV, AUTIM0, AUTIM1

CONTAINS

! ---------- -------
  SUBROUTINE MUELLER(Q0,Q1,Q,S0,S1,S,RDS)

! Mueller's method with bracketing

    IMPLICIT DOUBLE PRECISION (A-H,O-Z)

    PARAMETER (HMACH=1.0d-7,RSMALL=1.0d-30,RLARGE=1.0d+30)

    H0=S0-S
    H1=S1-S
    D=H0*H1*(H1-H0)
    A=( H1**2*(Q0-Q) - H0**2*(Q1-Q) ) / D
    B=(-H1*(Q0-Q)    + H0*(Q1-Q)    ) / D
    IF(ABS(B).LE.RSMALL)THEN
       RDS=-Q/A
    ELSE
       C=A/(2*B)
       R=DSQRT(C**2-Q/B)
       IF(C.LT.0.d0)THEN
          RDS=-C - R
       ELSE
          RDS=-C + R
       ENDIF
    ENDIF

    DQ=Q1*Q
    IF(DQ.LT.0.d0)THEN
       Q0=Q1
       S0=S1
    ENDIF
    Q1=Q
    S1=S
  END SUBROUTINE MUELLER

! ---------- ---
  SUBROUTINE EIG(IAP,NDIM,M1A,A,EV,IER)

    INCLUDE 'auto.h'

    IMPLICIT DOUBLE PRECISION (A-H,O-Z)

! This subroutine uses the EISPACK subroutine RG to compute the
! eigenvalues of the general real matrix A.
! NDIM is the dimension of A.
! M1A is the first dimension of A as in the DIMENSION statement.
! The eigenvalues are to be returned in the complex vector EV.

    DIMENSION A(M1A,*),IAP(*)

    COMPLEX(KIND(1.0D0)) EV(*)
! Local
    ALLOCATABLE WR(:),WI(:),Z(:),FV1(:),IV1(:)
    ALLOCATE(WR(NDIM),WI(NDIM),Z(M1A*NDIM),FV1(NDIM),IV1(NDIM))

    IID=IAP(18)
    IBR=IAP(30)
    NTOT=IAP(32)
    NTOP=MOD(NTOT-1,9999)+1

    IER=0
    IF(IID.GE.4)THEN 
       MATZ=1
    ELSE
       MATZ=0
    ENDIF

    CALL RG(M1A,NDIM,A,WR,WI,MATZ,Z,IV1,FV1,IER)
    IF(IER.NE.0)IER=1
    IF(IER.EQ.1)WRITE(9,101)IBR,NTOP

    IF(MATZ.NE.0)THEN
       WRITE(9,102)
       DO I=1,NDIM
          WRITE(9,104)WR(I),WI(I)
       ENDDO
       WRITE(9,103)
       DO I=1,NDIM
          WRITE(9,104)(Z((I-1)*M1A+J),J=1,NDIM)
       ENDDO
    ENDIF

    DO I=1,NDIM
       EV(I) = CMPLX(WR(I),WI(I),KIND(1.0D0))
    ENDDO


101 FORMAT(I4,I6,' NOTE:Error return from EISPACK routine RG')
102 FORMAT(/,' Eigenvalues:')
103 FORMAT(/,' Eigenvectors (by row):')
104 FORMAT(4X,7ES19.10)

    DEALLOCATE(WR,WI,Z,FV1,IV1)
  END SUBROUTINE EIG

! ---------- ----
  SUBROUTINE NLVC(N,M,K,A,U,IR,IC)

    IMPLICIT DOUBLE PRECISION (A-H,O-Z)

    PARAMETER (HMACH=1.0d-7,RSMALL=1.0d-30,RLARGE=1.0d+30)

! Finds a null-vector of a singular matrix A.
! The null space of A is assumed to be K-dimensional.
!
! Parameters :
!
!     N : number of equations,
!     M : first dimension of A from DIMENSION statement,
!     K : dimension of nullspace,
!     A : N * N matrix of coefficients,
!     U : on exit U contains the null vector,
! IR,IC : integer arrays of dimension at least N.
!

    DIMENSION IR(*),IC(*),A(M,*),U(*)

    DO I=1,N
       IC(I)=I
       IR(I)=I
    ENDDO

!   Elimination.

    NMK=N-K

    DO JJ=1,NMK
       IPIV=JJ
       JPIV=JJ
       PIV=0.d0
       DO I=JJ,N
          DO J=JJ,N
             P=ABS(A(IR(I),IC(J)))
             IF(P.GT.PIV)THEN
                PIV=P
                IPIV=I
                JPIV=J
             ENDIF
          ENDDO
       ENDDO
       IF(PIV.LT.RSMALL)WRITE(9,101)JJ,RSMALL

       KK=IR(JJ)
       IR(JJ)=IR(IPIV)
       IR(IPIV)=KK

       KK=IC(JJ)
       IC(JJ)=IC(JPIV)
       IC(JPIV)=KK

       JJP1=JJ+1
       DO L=JJP1,N
          RM=A(IR(L),IC(JJ))/A(IR(JJ),IC(JJ))
          IF(RM.NE.0.d0)THEN
             DO I=JJP1,N
                A(IR(L),IC(I))=A(IR(L),IC(I))-RM*A(IR(JJ),IC(I))
             ENDDO
          ENDIF
       ENDDO
    ENDDO

!   Backsubstitution :

    DO I=1,K
       U(IC(N+1-I))=1.d0
    ENDDO

    DO I1=1,NMK
       I=NMK+1-I1
       SM=0.d0
       IP1=I+1
       DO J=IP1,N
          SM=SM+A(IR(I),IC(J))*U(IC(J))
       ENDDO
       U(IC(I))=-SM/A(IR(I),IC(I))
    ENDDO

101 FORMAT(8x,' NOTE:Pivot ',I3,' < ',E10.3,' in NLVC : ', &
         /,'        A null space may be multi-dimensional')

  END SUBROUTINE NLVC

! ------ --------- -------- -----
  DOUBLE PRECISION FUNCTION RNRMV(N,V)

    IMPLICIT DOUBLE PRECISION (A-H,O-Z)

    DIMENSION V(*)

! Returns the L2-norm of the vector V.

    RNRMV = 0.d0
    DO I=1,N
       RNRMV=RNRMV+V(I)**2
    ENDDO
    RNRMV=DSQRT(RNRMV)

  END FUNCTION RNRMV

! ---------- -----
  SUBROUTINE NRMLZ(NDIM,V)

    IMPLICIT DOUBLE PRECISION (A-H,O-Z)

    DIMENSION V(*)

! Scale the vector V so that its discrete L2-norm becomes 1.

    SS=0.d0
    DO I=1,NDIM
       SS=SS+V(I)*V(I)
    ENDDO
    C=1.d0/DSQRT(SS)
    DO I=1,NDIM
       V(I)=V(I)*C
    ENDDO

  END SUBROUTINE NRMLZ

! ------ --------- --------
  DOUBLE PRECISION FUNCTION PI(R)

    IMPLICIT DOUBLE PRECISION (A-H,O-Z)

    PI=R*4.0d0*DATAN(1.d0)

  END FUNCTION PI

! ---------- ----
  SUBROUTINE GESC(IAM,N,M1A,A,NRHS,NDX,U,M1F,F,IR,IC,DET)

    IMPLICIT DOUBLE PRECISION (A-H,O-Z)

    PARAMETER (HMACH=1.0d-7,RSMALL=1.0d-30,RLARGE=1.0d+30)

! Solves the linear system  A U = F by Gauss elimination
! with complete pivoting. Returns a scaled determinant.
!
! Parameters :
!
!   N   : number of equations,
!   M1A : first dimension of A from DIMENSION statement,
!   A   : N * N matrix of coefficients,
!   NRHS: 0   if no right hand sides (determinant only),
!         >0   if there are NRHS right hand sides,
!   NDX : first dimension of U from DIMENSION statement,
!   U   : on exit U contains the solution vector(s),
!   M1F : first dimension of F from DIMENSION statement,
!   F   : right hand side vector(s),
!  IR,IC: integer vectors of dimension at least N.
!
! The input matrix A is overwritten.

    DIMENSION IR(*),IC(*),A(M1A,*),U(NDX,*),F(M1F,*)

    DO I=1,N
       IC(I)=I
       IR(I)=I
    ENDDO

!   Elimination.

    DET=1.d0
    NM1=N-1

    DO JJ=1,NM1
       IPIV=JJ
       JPIV=JJ
       PIV=0.d0
       DO I=JJ,N
          DO J=JJ,N
             P=ABS(A(IR(I),IC(J)))
             IF(P.GT.PIV)THEN
                PIV=P
                IPIV=I
                JPIV=J
             ENDIF
          ENDDO
       ENDDO

       AP=A(IR(IPIV),IC(JPIV)) 
       DET=DET*LOG10(10+ABS(AP)) * atan(AP)
       IF(IPIV.NE.JJ)DET=-DET
       IF(JPIV.NE.JJ)DET=-DET

       IF(PIV.LT.RSMALL)WRITE(9,101)JJ,RSMALL

       K=IR(JJ)
       IR(JJ)=IR(IPIV)
       IR(IPIV)=K

       K=IC(JJ)
       IC(JJ)=IC(JPIV)
       IC(JPIV)=K

       JJP1=JJ+1
       DO L=JJP1,N
          RM=A(IR(L),IC(JJ))/A(IR(JJ),IC(JJ))
          IF(RM.NE.0.d0)THEN
             DO I=JJP1,N
                A(IR(L),IC(I))=A(IR(L),IC(I))-RM*A(IR(JJ),IC(I))
             ENDDO
             IF(NRHS.NE.0)THEN
                DO IRH=1,NRHS
                   F(IR(L),IRH)=F(IR(L),IRH)-RM*F(IR(JJ),IRH)
                ENDDO
             ENDIF
          ENDIF
       ENDDO
    ENDDO
    AP=A(IR(N),IC(N)) 
    DET=DET*LOG10(10+ABS(AP)) * atan(AP)

    IF(NRHS.EQ.0)RETURN

!   Backsubstitution :

    DO IRH=1,NRHS
       U(IC(N),IRH)=F(IR(N),IRH)/A(IR(N),IC(N))
       DO I1=1,NM1
          I=N-I1
          SM=0.d0
          IP1=I+1
          DO J=IP1,N
             SM=SM+A(IR(I),IC(J))*U(IC(J),IRH)
          ENDDO
          U(IC(I),IRH)=(F(IR(I),IRH)-SM)/A(IR(I),IC(I))
       ENDDO
    ENDDO

101 FORMAT(8x,' NOTE:Pivot ',I3,' < ',D10.3,' in GE')

  END SUBROUTINE GESC

!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
!          System Dependent Subroutines for Timing AUTO
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
!
! ---------- ------
  SUBROUTINE AUTIM0(T)

!$  USE OMP_LIB
    IMPLICIT DOUBLE PRECISION (A-H,O-Z)
    REAL etime
    REAL timaray(2)

! Set initial time for measuring CPU time used.

    T=etime(timaray)
!$  T=omp_get_wtime()

  END SUBROUTINE AUTIM0

! ---------- ------
  SUBROUTINE AUTIM1(T)

!$  USE OMP_LIB
    IMPLICIT DOUBLE PRECISION (A-H,O-Z)
    REAL etime
    REAL timaray(2)

! Set final time for measuring CPU time used.

    T=etime(timaray)
!$  T=omp_get_wtime()

  END SUBROUTINE AUTIM1

END MODULE SUPPORT

! The following functions and subroutines are called from
! various demos so cannot be inside the module

! ---------- --
  SUBROUTINE GE(IAM,N,M1A,A,NRHS,NDX,U,M1F,F,IR,IC,DET)

    IMPLICIT DOUBLE PRECISION (A-H,O-Z)

    PARAMETER (HMACH=1.0d-7,RSMALL=1.0d-30,RLARGE=1.0d+30)

! Solves the linear system  A U = F by Gauss elimination
! with complete pivoting.
!
! Parameters :
!
!   N   : number of equations,
!   M1A : first dimension of A from DIMENSION statement,
!   A   : N * N matrix of coefficients,
!   NRHS: 0   if no right hand sides (determinant only),
!         >0   if there are NRHS right hand sides,
!   NDX : first dimension of U from DIMENSION statement,
!   U   : on exit U contains the solution vector(s),
!   M1F : first dimension of F from DIMENSION statement,
!   F   : right hand side vector(s),
!  IR,IC: integer vectors of dimension at least N.
!
! The input matrix A is overwritten.
!
    DIMENSION IR(*),IC(*),A(M1A,*),U(NDX,*),F(M1F,*)

    DO I=1,N
       IC(I)=I
       IR(I)=I
    ENDDO

!   Elimination.

    DET=1.d0
    NM1=N-1

    DO JJ=1,NM1
       IPIV=JJ
       JPIV=JJ
       PIV=0.d0
       DO I=JJ,N
          DO J=JJ,N
             P=ABS(A(IR(I),IC(J)))
             IF(P.GT.PIV)THEN
                PIV=P
                IPIV=I
                JPIV=J
             ENDIF
          ENDDO
       ENDDO

       DET=DET*A(IR(IPIV),IC(JPIV))
       IF(IPIV.NE.JJ)DET=-DET
       IF(JPIV.NE.JJ)DET=-DET

       IF(PIV.LT.RSMALL)WRITE(9,101)JJ,RSMALL

       K=IR(JJ)
       IR(JJ)=IR(IPIV)
       IR(IPIV)=K

       K=IC(JJ)
       IC(JJ)=IC(JPIV)
       IC(JPIV)=K

       JJP1=JJ+1
       DO L=JJP1,N
          RM=A(IR(L),IC(JJ))/A(IR(JJ),IC(JJ))
          IF(RM.NE.0.d0)THEN
             DO I=JJP1,N
                A(IR(L),IC(I))=A(IR(L),IC(I))-RM*A(IR(JJ),IC(I))
             ENDDO
             IF(NRHS.NE.0)THEN
                DO IRH=1,NRHS
                   F(IR(L),IRH)=F(IR(L),IRH)-RM*F(IR(JJ),IRH)
                ENDDO
             ENDIF
          ENDIF
       ENDDO
    ENDDO
    DET=DET*A(IR(N),IC(N))

    IF(NRHS.EQ.0)RETURN

!   Backsubstitution :

    DO IRH=1,NRHS
       U(IC(N),IRH)=F(IR(N),IRH)/A(IR(N),IC(N))
       DO I1=1,NM1
          I=N-I1
          SM=0.d0
          IP1=I+1
          DO J=IP1,N
             SM=SM+A(IR(I),IC(J))*U(IC(J),IRH)
          ENDDO
          U(IC(I),IRH)=(F(IR(I),IRH)-SM)/A(IR(I),IC(I))
       ENDDO
    ENDDO

101 FORMAT(8x,' NOTE:Pivot ',I3,' < ',D10.3,' in GE')

  END SUBROUTINE GE

! ------ --------- -------- ----
  DOUBLE PRECISION FUNCTION GETP(CODE,IC,UPS)

    USE MESH

    IMPLICIT DOUBLE PRECISION (A-H,O-Z)
    POINTER DTV(:),RAV(:),IAV(:),P0V(:,:),P1V(:,:)
    COMMON /BLPV/ DTV,RAV,IAV,P0V,P1V
    DIMENSION UPS(IAV(1)*IAV(6),*)
    CHARACTER*3 CODE

    IPS=IAV(2)
    NX=IAV(1)*IAV(6)
    GETP=0

    IF( ABS(IPS).LE.1 .OR. IPS.EQ.5)THEN
       IF(CODE.EQ.'NRM'.OR.CODE.EQ.'nrm')THEN
          GETP=ABS(UPS(IC,1))    
       ELSEIF(CODE.EQ.'INT'.OR.CODE.EQ.'int')THEN
          GETP=UPS(IC,1)
       ELSEIF(CODE.EQ.'MAX'.OR.CODE.EQ.'max')THEN
          GETP=UPS(IC,1)
       ELSEIF(CODE.EQ.'MIN'.OR.CODE.EQ.'min')THEN
          GETP=UPS(IC,1)
       ELSEIF(CODE.EQ.'BV0'.OR.CODE.EQ.'bv0')THEN
          GETP=UPS(IC,1)
       ELSEIF(CODE.EQ.'BV1'.OR.CODE.EQ.'bv1')THEN
          GETP=UPS(IC,1)
       ELSEIF(CODE.EQ.'STP'.OR.CODE.EQ.'stp')THEN
          GETP=RAV(5)
       ELSEIF(CODE.EQ.'FLD'.OR.CODE.EQ.'fld')THEN
          GETP=RAV(16)
       ELSEIF(CODE.EQ.'HBF'.OR.CODE.EQ.'hbf')THEN
          GETP=RAV(17)
       ELSEIF(CODE.EQ.'BIF'.OR.CODE.EQ.'bif')THEN
          GETP=RAV(14)
       ELSEIF(CODE.EQ.'SPB'.OR.CODE.EQ.'spb')THEN
          GETP=0.
       ELSEIF(CODE.EQ.'STA'.OR.CODE.EQ.'sta')THEN
          GETP=IAV(33)
       ENDIF
    ELSE
       IF(CODE.EQ.'NRM'.OR.CODE.EQ.'nrm')THEN
          GETP=RNRM2(IAV,NX,IC,UPS,DTV)    
       ELSEIF(CODE.EQ.'INT'.OR.CODE.EQ.'int')THEN
          GETP=RINTG(IAV,NX,IC,UPS,DTV)
       ELSEIF(CODE.EQ.'MAX'.OR.CODE.EQ.'max')THEN
          GETP=RMXUPS(IAV,NX,IC,UPS)
       ELSEIF(CODE.EQ.'MIN'.OR.CODE.EQ.'min')THEN
          GETP=RMNUPS(IAV,NX,IC,UPS)
       ELSEIF(CODE.EQ.'BV0'.OR.CODE.EQ.'bv0')THEN
          GETP=UPS(IC,1)
       ELSEIF(CODE.EQ.'BV1'.OR.CODE.EQ.'bv1')THEN
          GETP=UPS(IC,IAV(5)+1)
       ELSEIF(CODE.EQ.'STP'.OR.CODE.EQ.'stp')THEN
          GETP=RAV(5)
       ELSEIF(CODE.EQ.'FLD'.OR.CODE.EQ.'fld')THEN
          GETP=RAV(16)
       ELSEIF(CODE.EQ.'HBF'.OR.CODE.EQ.'hbf')THEN
          GETP=0.
       ELSEIF(CODE.EQ.'BIF'.OR.CODE.EQ.'bif')THEN
          GETP=RAV(18)
       ELSEIF(CODE.EQ.'SPB'.OR.CODE.EQ.'spb')THEN
          GETP=RAV(19)
       ELSEIF(CODE.EQ.'STA'.OR.CODE.EQ.'sta')THEN
          GETP=IAV(33)
       ENDIF
    ENDIF

  END FUNCTION GETP

! ---------- -------
  SUBROUTINE GETMDMX(NDIM1,P0,P1,NMM)
    IMPLICIT NONE

    DOUBLE PRECISION, INTENT(OUT) :: P0(NDIM1,NDIM1),P1(NDIM1,NDIM1)
    INTEGER, INTENT(IN) :: NDIM1
    LOGICAL, INTENT(OUT) :: NMM

    DOUBLE PRECISION, POINTER :: DTV(:),RAV(:),P0V(:,:),P1V(:,:)
    INTEGER, POINTER :: IAV(:)
    COMMON /BLPV/ DTV,RAV,IAV,P0V,P1V

    INTEGER NDIM,IPS,ISP,NTOT

    NDIM=IAV(1)
    IPS=IAV(2)
    ISP=IAV(9)
    NTOT=IAV(32)
    NMM=.FALSE.
    IF(NDIM==NDIM1.AND.NTOT>0.AND.ABS(ISP)>0.AND. &
         (IPS==2.OR.IPS==7.OR.IPS==12))THEN
       P0=P0V
       P1=P1V
       NMM=.TRUE.
    ENDIF

  END SUBROUTINE GETMDMX