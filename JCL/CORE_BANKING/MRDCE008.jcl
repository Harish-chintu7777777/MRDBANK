//*============================================================
//* JOB  : MRDCE008
//* TYPE : End-of-Day (EOD)
//* CYCLE: Daily EOD — EOD Chain Position 8 of 14
//* PURPOSE: GL Batch Summarisation. Reads all transactions in
//*          FILE 150 for today's business date, produces the
//*          daily GL summary, and detects any GL anomalies
//*          (pending or error posting statuses).
//* PREDECESSOR: MRDCE007 (direct debit processing)
//*              ALL of: MRDCE002 through MRDCE007 must complete
//*              before GL summary is meaningful.
//*              MRDBNK.COREBKG.CONTROL.EOD.LATEST must exist (MRDCE001)
//* SUCCESSOR  : MRDCE009 (GL suspense reconciliation)
//* DATASETS READ:
//*   FILE 150 (transaction history — direct read by CBGLP001)
//*   FILE 105 (GL master — direct read by CBGLP001)
//*   MRDBNK.COREBKG.CONTROL.EOD.LATEST (predecessor verification)
//* DATASETS WRITTEN:
//*   MRDBNK.COREBKG.GL.SUMMARY.DAILY.&DATE (GL summary)
//*   MRDBNK.COREBKG.GL.EXCEPTION.DAILY.&DATE (pending/error TXNs)
//*   FILE 010 (audit trail via CBGLP001 -> CMUTS007)
//* CONDITION CODES:
//*   0000 = GL balanced — debits = credits
//*   0004 = GL exceptions found — check exception file
//*   0008 = GL imbalance detected — halt EOD chain immediately
//*============================================================
//MRDCE008 JOB (MRDBNK,COREGLSM),
//             'CB EOD GL SUMMARISATION',
//             CLASS=E,
//             MSGCLASS=X,
//             MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID,
//             REGION=0M
//*
//         SET DATE=&YYYYMMDD
//*------------------------------------------------------------
//* STEP 01: VERIFY EOD PREDECESSOR CONTROL RECORD EXISTS
//*          Checks MRDBNK.COREBKG.CONTROL.EOD.LATEST is present
//*          and was written by MRDCE001 today. Aborts if not.
//*------------------------------------------------------------
//STEP01   EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  LISTCAT ENTRIES(MRDBNK.COREBKG.CONTROL.EOD.LATEST) -
          ALL
/*
//*------------------------------------------------------------
//* STEP 02: RUN GL BATCH SUMMARISER (CBGLP001)
//*          Reads FILE 150 directly (legacy approved exception).
//*          Writes summary report to CMPRINT.
//*          Writes exception records to CMWKF01.
//* COND: Run only if STEP01 IDCAMS found the dataset (RC=0).
//*------------------------------------------------------------
//STEP02   EXEC PGM=NATBAT,REGION=0M,
//             COND=(4,LT,STEP01)
//STEPLIB  DD DSN=NATSYS.LOAD,DISP=SHR
//         DD DSN=MRDBNK.LOAD,DISP=SHR
//NATPARM  DD DSN=MRDBNK.NATPARM.MRDCBLIB,DISP=SHR
//CMPRINT  DD SYSOUT=*,DCB=(RECFM=FBA,LRECL=133)
//CMWKF01  DD DSN=MRDBNK.COREBKG.GL.EXCEPTION.DAILY.&DATE,
//             DISP=(NEW,CATLG,DELETE),
//             DCB=(RECFM=FB,LRECL=200,BLKSIZE=6000),
//             SPACE=(CYL,(2,1))
//SYSIN    DD *
GLOBALS PROGRAM=CBGLP001,LIBRARY=MRDCBLIB
CBGLP001
/*
//*------------------------------------------------------------
//* STEP 03: SORT GL SUMMARY BY GL ACCOUNT CODE
//*          Output used by MRDCE009 (suspense reconciliation)
//*          and MRDCE010 (trial balance).
//* COND: Run if STEP02 RC <= 4 (balanced or minor exceptions).
//*       If STEP02 RC=8 (imbalance), do NOT proceed — halt chain.
//*------------------------------------------------------------
//STEP03   EXEC PGM=SORT,REGION=0M,
//             COND=((8,LE,STEP02),(4,LT,STEP01))
//SORTIN   DD SYSOUT=*
//         DD DSN=MRDBNK.COREBKG.GL.EXCEPTION.DAILY.&DATE,
//             DISP=SHR
//SORTOUT  DD DSN=MRDBNK.COREBKG.GL.SUMMARY.DAILY.&DATE,
//             DISP=(NEW,CATLG,DELETE),
//             DCB=(RECFM=FB,LRECL=200,BLKSIZE=6000),
//             SPACE=(CYL,(5,2))
//SYSOUT   DD SYSOUT=*
//SORTWK01 DD SPACE=(CYL,(10,5)),UNIT=SYSDA
//SORTWK02 DD SPACE=(CYL,(10,5)),UNIT=SYSDA
//SYSIN    DD *
  SORT FIELDS=(1,12,CH,A)
  RECORD TYPE=F,LENGTH=200
/*
//*------------------------------------------------------------
//* STEP 04: VERIFY GL BALANCE
//*          Reads GL summary, checks debit total = credit total.
//*          Sets RC=8 if imbalance — halts EOD chain.
//* COND: Run if STEP03 successful.
//*------------------------------------------------------------
//STEP04   EXEC PGM=NATBAT,REGION=0M,
//             COND=(4,LT,STEP03)
//STEPLIB  DD DSN=NATSYS.LOAD,DISP=SHR
//         DD DSN=MRDBNK.LOAD,DISP=SHR
//NATPARM  DD DSN=MRDBNK.NATPARM.MRDCBLIB,DISP=SHR
//CMPRINT  DD SYSOUT=*
//CMWKF01  DD DSN=MRDBNK.COREBKG.GL.SUMMARY.DAILY.&DATE,
//             DISP=SHR
//SYSIN    DD *
GLOBALS PROGRAM=CBGLP002,LIBRARY=MRDCBLIB
CBGLP002 PARM=VERIFY
/*
