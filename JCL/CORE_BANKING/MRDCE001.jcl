//*============================================================
//* JOB  : MRDCE001
//* TYPE : End-of-Day (EOD) — Phase Gate
//* CYCLE: Daily EOD — first job in the EOD chain
//* PURPOSE: EOD Phase Gate Controller. Sets SYS-EOD-FLAG=Y in
//*          FILE 015 to block all online financial writes.
//*          Online programs check this flag via GDA CMDAG001
//*          before any ADABAS write. Sets RC=0 only when:
//*            - All intraday batch jobs have completed (via
//*              scheduler predecessor dependency on MRDCD001)
//*            - Online transaction count matches control total
//*          Successor jobs MUST NOT start until this job RC=0000.
//* PREDECESSOR: MRDCD001 final intraday run (18:00)
//* SUCCESSOR  : MRDCE002 (interest accrual) — start only RC=0
//* EOD CHAIN POSITION: 1 of 14
//* DATASETS WRITTEN:
//*   MRDBNK.COREBKG.CONTROL.EOD.LATEST (EOD control record)
//*   FILE 015 (SYS-EOD-FLAG = Y)
//*============================================================
//MRDCE001 JOB (MRDBNK,COREOD),
//             'CB EOD PHASE GATE',
//             CLASS=E,
//             MSGCLASS=X,
//             MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID,
//             REGION=0M
//*
//         SET DATE=&YYYYMMDD
//*------------------------------------------------------------
//* STEP 01: CHECK ALL INTRADAY JOBS COMPLETE
//*          Reads scheduler control dataset to confirm all
//*          MRDCD* jobs for today have RC <= 4.
//*------------------------------------------------------------
//STEP01   EXEC PGM=NATBAT,REGION=0M
//STEPLIB  DD DSN=NATSYS.LOAD,DISP=SHR
//         DD DSN=MRDBNK.LOAD,DISP=SHR
//NATPARM  DD DSN=MRDBNK.NATPARM.MRDCBLIB,DISP=SHR
//CMPRINT  DD SYSOUT=*
//CMWKF01  DD DSN=MRDBNK.COREBKG.CONTROL.INTRADAY.&DATE,
//             DISP=SHR
//SYSIN    DD *
GLOBALS PROGRAM=CBEOP001,LIBRARY=MRDCBLIB
CBEOP001 PARM=CHECKPRECOND
/*
//*------------------------------------------------------------
//* STEP 02: FREEZE ONLINE — SET EOD FLAG
//*          Sets SYS-EOD-FLAG=Y in FILE 015.
//*          Online programs observe this flag within 30 seconds
//*          (GDA refresh interval). EOD window begins.
//* COND: Only if STEP01 RC = 0000.
//*------------------------------------------------------------
//STEP02   EXEC PGM=NATBAT,REGION=0M,
//             COND=(4,LT,STEP01)
//STEPLIB  DD DSN=NATSYS.LOAD,DISP=SHR
//         DD DSN=MRDBNK.LOAD,DISP=SHR
//NATPARM  DD DSN=MRDBNK.NATPARM.MRDCBLIB,DISP=SHR
//CMPRINT  DD SYSOUT=*
//SYSIN    DD *
GLOBALS PROGRAM=CBEOP001,LIBRARY=MRDCBLIB
CBEOP001 PARM=FREEZE
/*
//*------------------------------------------------------------
//* STEP 03: WAIT FOR ONLINE TRANSACTIONS TO DRAIN
//*          Polls FILE 150 for any transactions posted in last
//*          60 seconds with BB=PE (GL pending) to catch in-flight
//*          postings that started before the freeze flag was seen.
//*          Waits up to 120 seconds, then proceeds.
//* COND: Run if STEP02 successful.
//*------------------------------------------------------------
//STEP03   EXEC PGM=NATBAT,REGION=0M,
//             COND=(4,LT,STEP02)
//STEPLIB  DD DSN=NATSYS.LOAD,DISP=SHR
//         DD DSN=MRDBNK.LOAD,DISP=SHR
//NATPARM  DD DSN=MRDBNK.NATPARM.MRDCBLIB,DISP=SHR
//CMPRINT  DD SYSOUT=*
//SYSIN    DD *
GLOBALS PROGRAM=CBEOP001,LIBRARY=MRDCBLIB
CBEOP001 PARM=DRAIN,WAIT=120
/*
//*------------------------------------------------------------
//* STEP 04: WRITE EOD CONTROL RECORD
//*          Writes timestamp and online transaction count to
//*          EOD control dataset. Used by downstream jobs to
//*          verify they are running in correct sequence.
//* COND: Run if STEP03 successful.
//*------------------------------------------------------------
//STEP04   EXEC PGM=NATBAT,REGION=0M,
//             COND=(4,LT,STEP03)
//STEPLIB  DD DSN=NATSYS.LOAD,DISP=SHR
//         DD DSN=MRDBNK.LOAD,DISP=SHR
//NATPARM  DD DSN=MRDBNK.NATPARM.MRDCBLIB,DISP=SHR
//CMPRINT  DD SYSOUT=*
//CMWKF01  DD DSN=MRDBNK.COREBKG.CONTROL.EOD.LATEST,
//             DISP=(NEW,CATLG,DELETE),
//             DCB=(RECFM=FB,LRECL=200,BLKSIZE=2000),
//             SPACE=(TRK,(1,1))
//SYSIN    DD *
GLOBALS PROGRAM=CBEOP001,LIBRARY=MRDCBLIB
CBEOP001 PARM=WRITECONTROL
/*
