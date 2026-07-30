//*============================================================
//* JOB  : MRDCD001
//* TYPE : Daily Intraday (runs every 2 hours during business day)
//* CYCLE: Every 2 hours 08:00–18:00 (5 runs per day)
//* PURPOSE: Intraday Batch Transaction Poster. Posts transactions
//*          received from channels (ATM, internet banking, bulk
//*          files) that did not post online during the day.
//*          Reads MRDBNK.COREBKG.TX.WORK.INTRADAY.LATEST.
//* PREDECESSOR: MRDCS001 (SOD must be complete, RC=0000)
//* SUCCESSOR  : MRDFE001 (fraud scoring — runs 15 min after)
//* DATASETS READ:
//*   MRDBNK.COREBKG.TX.WORK.INTRADAY.LATEST  (inbound transactions)
//* DATASETS WRITTEN:
//*   MRDBNK.COREBKG.TX.WORK.INTRADAY.REJECTS.&DATE (rejects)
//*   FILE 100 (balance updates via CBTXS001)
//*   FILE 150 (transaction inserts via CBTXS001)
//*   FILE 105 (GL entries via CBGLS001)
//*   FILE 010 (audit trail via CMUTS007)
//* CONDITION CODES:
//*   0000 = All records posted successfully
//*   0004 = Partial post — some rejects, check CMWKF02
//*   0008 = Fatal error — no records posted
//*============================================================
//MRDCD001 JOB (MRDBNK,COREINTR),
//             'CORE BANKING INTRADAY POSTER',
//             CLASS=B,
//             MSGCLASS=X,
//             MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID,
//             REGION=0M
//*
//JCLLIB   ORDER=MRDBNK.JCL.PROCLIB
//*
//* Pass current date as symbolic
//         SET DATE=&YYYYMMDD
//*------------------------------------------------------------
//* STEP 01: SORT INBOUND TRANSACTION FILE
//*          Sort by account number + value date for efficient
//*          ADABAS sequential read access.
//* SORT KEY: Positions 2-12 (account), 36-43 (value date)
//*------------------------------------------------------------
//STEP01   EXEC PGM=SORT,REGION=0M
//SORTIN   DD DSN=MRDBNK.COREBKG.TX.WORK.INTRADAY.LATEST,
//             DISP=SHR
//SORTOUT  DD DSN=MRDBNK.COREBKG.TX.WORK.SORTED.&DATE,
//             DISP=(NEW,CATLG,DELETE),
//             DCB=(RECFM=FB,LRECL=350,BLKSIZE=35000),
//             SPACE=(CYL,(10,5))
//SYSOUT   DD SYSOUT=*
//SORTWK01 DD SPACE=(CYL,(20,10)),UNIT=SYSDA
//SORTWK02 DD SPACE=(CYL,(20,10)),UNIT=SYSDA
//SORTWK03 DD SPACE=(CYL,(20,10)),UNIT=SYSDA
//SYSIN    DD *
  SORT FIELDS=(2,11,CH,A,36,8,CH,A)
  RECORD TYPE=F,LENGTH=350
/*
//*------------------------------------------------------------
//* STEP 02: POST TRANSACTIONS VIA CBTXP010
//*          Reads sorted file from STEP01.
//*          Calls CBTXVD01 -> CBTXS001 -> CBGLS001 -> CMUTS007
//* COND: Skip if STEP01 failed (SORT RC > 4).
//*------------------------------------------------------------
//STEP02   EXEC PGM=NATBAT,REGION=0M,
//             COND=(8,LE,STEP01)
//STEPLIB  DD DSN=NATSYS.LOAD,DISP=SHR
//         DD DSN=MRDBNK.LOAD,DISP=SHR
//NATPARM  DD DSN=MRDBNK.NATPARM.MRDCBLIB,DISP=SHR
//CMPRINT  DD SYSOUT=*
//CMWKF01  DD DSN=MRDBNK.COREBKG.TX.WORK.SORTED.&DATE,
//             DISP=SHR
//CMWKF02  DD DSN=MRDBNK.COREBKG.TX.WORK.INTRADAY.REJECTS.&DATE,
//             DISP=(NEW,CATLG,DELETE),
//             DCB=(RECFM=FB,LRECL=350,BLKSIZE=35000),
//             SPACE=(CYL,(2,1))
//SYSIN    DD *
GLOBALS PROGRAM=CBTXP010,LIBRARY=MRDCBLIB
CBTXP010
/*
//*------------------------------------------------------------
//* STEP 03: VALIDATE CONTROL TOTALS
//*          Counts posted records and amounts, compares against
//*          header/trailer values. Raises RC=8 if mismatch.
//* COND: Run if STEP02 completed (even with rejects RC=4).
//*------------------------------------------------------------
//STEP03   EXEC PGM=NATBAT,REGION=0M,
//             COND=(8,LE,STEP02)
//STEPLIB  DD DSN=NATSYS.LOAD,DISP=SHR
//         DD DSN=MRDBNK.LOAD,DISP=SHR
//NATPARM  DD DSN=MRDBNK.NATPARM.MRDCBLIB,DISP=SHR
//CMPRINT  DD SYSOUT=*
//CMWKF01  DD DSN=MRDBNK.COREBKG.TX.WORK.INTRADAY.REJECTS.&DATE,
//             DISP=SHR
//SYSIN    DD *
GLOBALS PROGRAM=CBCNBT01,LIBRARY=MRDCBLIB
CBCNBT01 PARM=VALIDATE
/*
//*------------------------------------------------------------
//* STEP 04: ARCHIVE SORTED WORK FILE
//*          Delete sorted work file — rejects retained 30 days.
//* COND: Unconditional cleanup.
//*------------------------------------------------------------
//STEP04   EXEC PGM=IEFBR14
//DELWORK  DD DSN=MRDBNK.COREBKG.TX.WORK.SORTED.&DATE,
//             DISP=(OLD,DELETE,DELETE)
