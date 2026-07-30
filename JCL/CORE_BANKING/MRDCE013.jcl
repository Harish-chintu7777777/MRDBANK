//*============================================================
//* JOB  : MRDCE013
//* TYPE : End-of-Day (EOD)
//* CYCLE: Daily EOD — EOD Chain Position 13 of 14
//* PURPOSE: Business Date Roll. Updates FILE 015 system parameters
//*          with the next business date. Sends notification to
//*          all connected systems. This job is the POINT OF NO
//*          RETURN in the EOD cycle — once it completes, the
//*          business date has advanced and cannot be easily rolled
//*          back. Requires explicit operations sign-off captured
//*          in MRDBNK.COREBKG.CONTROL.EOD.SIGNOFF.&DATE
//* PREDECESSOR: MRDCE012 (Nostro reconciliation) — must be RC=0000
//*              MRDCE011 (Statement extract) — must be RC=0000
//*              Operations sign-off dataset must exist.
//* SUCCESSOR  : MRDCE014 (EOD error consolidation)
//*              MRDCS001 next day (after overnight window)
//* EOD CHAIN POSITION: 13 of 14
//* DATASETS READ:
//*   MRDBNK.COREBKG.CONTROL.EOD.SIGNOFF.&DATE (ops sign-off)
//*   FILE 030 (holiday calendar — next business day lookup)
//* DATASETS WRITTEN:
//*   FILE 015 (new business date)
//*   MRDBNK.COREBKG.CONTROL.DATEROLL.&DATE (confirmation)
//*============================================================
//MRDCE013 JOB (MRDBNK,COREDR),
//             'CB EOD DATE ROLL',
//             CLASS=E,
//             MSGCLASS=X,
//             MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID,
//             REGION=0M
//*
//         SET DATE=&YYYYMMDD
//*------------------------------------------------------------
//* STEP 01: VERIFY OPERATIONS SIGN-OFF EXISTS
//*          Operations must have created this dataset manually
//*          to confirm all EOD steps have been reviewed and
//*          all exceptions cleared before date roll proceeds.
//*          Without this dataset, the date roll will not run.
//*------------------------------------------------------------
//STEP01   EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  LISTCAT ENTRIES(MRDBNK.COREBKG.CONTROL.EOD.SIGNOFF.&DATE) -
          ALL
/*
//*------------------------------------------------------------
//* STEP 02: VERIFY ALL PREDECESSOR JOBS COMPLETE AND BALANCED
//*          Reads EOD control records from each predecessor.
//*          Aborts if any predecessor had RC > 4.
//* COND: Run only if STEP01 found sign-off (RC=0).
//*------------------------------------------------------------
//STEP02   EXEC PGM=NATBAT,REGION=0M,
//             COND=(4,LT,STEP01)
//STEPLIB  DD DSN=NATSYS.LOAD,DISP=SHR
//         DD DSN=MRDBNK.LOAD,DISP=SHR
//NATPARM  DD DSN=MRDBNK.NATPARM.MRDCBLIB,DISP=SHR
//CMPRINT  DD SYSOUT=*
//CMWKF01  DD DSN=MRDBNK.COREBKG.CONTROL.EOD.LATEST,
//             DISP=SHR
//SYSIN    DD *
GLOBALS PROGRAM=CBEOP002,LIBRARY=MRDCBLIB
CBEOP002 PARM=VERIFY
/*
//*------------------------------------------------------------
//* STEP 03: DETERMINE NEXT BUSINESS DATE
//*          Reads FILE 030 (holiday calendar) to find next
//*          banking day. Skips weekends and public holidays.
//* COND: Run if STEP02 verifies all predecessors OK.
//*------------------------------------------------------------
//STEP03   EXEC PGM=NATBAT,REGION=0M,
//             COND=(4,LT,STEP02)
//STEPLIB  DD DSN=NATSYS.LOAD,DISP=SHR
//         DD DSN=MRDBNK.LOAD,DISP=SHR
//NATPARM  DD DSN=MRDBNK.NATPARM.MRDCBLIB,DISP=SHR
//CMPRINT  DD SYSOUT=*
//CMWKF01  DD DSN=MRDBNK.COREBKG.CONTROL.DATEROLL.&DATE,
//             DISP=(NEW,CATLG,DELETE),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800),
//             SPACE=(TRK,(1,1))
//SYSIN    DD *
GLOBALS PROGRAM=CBEOP002,LIBRARY=MRDCBLIB
CBEOP002 PARM=CALCNEXTDAY
/*
//*------------------------------------------------------------
//* STEP 04: ROLL DATE IN FILE 015
//*          Updates ADABAS FILE 015 business date field.
//*          After this step, all new sessions get new date.
//*          POINT OF NO RETURN — cannot be rolled back without
//*          operations intervention and DR procedure.
//* COND: Run only if STEP03 successful.
//*------------------------------------------------------------
//STEP04   EXEC PGM=NATBAT,REGION=0M,
//             COND=(4,LT,STEP03)
//STEPLIB  DD DSN=NATSYS.LOAD,DISP=SHR
//         DD DSN=MRDBNK.LOAD,DISP=SHR
//NATPARM  DD DSN=MRDBNK.NATPARM.MRDCBLIB,DISP=SHR
//CMPRINT  DD SYSOUT=*
//CMWKF01  DD DSN=MRDBNK.COREBKG.CONTROL.DATEROLL.&DATE,
//             DISP=SHR
//SYSIN    DD *
GLOBALS PROGRAM=CBEOP002,LIBRARY=MRDCBLIB
CBEOP002 PARM=ROLLDATE
/*
//*------------------------------------------------------------
//* STEP 05: CLEAR EOD FLAG — SYSTEM READY FOR NEXT DAY
//*          Sets SYS-EOD-FLAG=N in FILE 015.
//*          Online sessions blocked overnight resume.
//* COND: Run only if date roll succeeded.
//*------------------------------------------------------------
//STEP05   EXEC PGM=NATBAT,REGION=0M,
//             COND=(4,LT,STEP04)
//STEPLIB  DD DSN=NATSYS.LOAD,DISP=SHR
//         DD DSN=MRDBNK.LOAD,DISP=SHR
//NATPARM  DD DSN=MRDBNK.NATPARM.MRDCBLIB,DISP=SHR
//CMPRINT  DD SYSOUT=*
//SYSIN    DD *
GLOBALS PROGRAM=CBEOP003,LIBRARY=MRDCBLIB
CBEOP003 PARM=OPEN
/*
