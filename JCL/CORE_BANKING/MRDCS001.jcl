//*============================================================
//* JOB  : MRDCS001
//* TYPE : Start-of-Day (SOD)
//* CYCLE: Daily SOD — submitted by scheduler at 06:00
//* PURPOSE: Meridian Bank SOD initialisation for Core Banking.
//*          Loads system parameters, validates business date,
//*          and sets SYS-EOD-FLAG=N to open the system for
//*          online transactions.
//* SUCCESSOR JOBS:
//*   MRDCD001 (intraday poster — starts after SOD completes)
//*   Online ETP sessions (start after MRDCS001 RC=0000)
//* DATASETS WRITTEN:
//*   MRDBNK.COREBKG.CONTROL.LATEST    (system parameters)
//*   MRDBNK.COREBKG.ACCT.INBOUND (processed if present from CUSTONB)
//* DATASETS READ:
//*   MRDBNK.SHARED.SYSPARM.MASTER.LATEST  (system parameters)
//*   MRDBNK.CUSTONB.IF.COREBKG.DAILY.LATEST (account open triggers)
//* CONDITION CODES:
//*   0000 = Successful SOD
//*   0004 = Warning (non-fatal, review SYSOUT)
//*   0008 = SOD failed — do not start online sessions
//* CONTACT: MERIDIAN BANK OPERATIONS (OPS@MRDBANK.COM, x4400)
//*============================================================
//MRDCS001 JOB (MRDBNK,CORESOD),
//             'CORE BANKING SOD',
//             CLASS=A,
//             MSGCLASS=X,
//             MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID,
//             REGION=0M
//*------------------------------------------------------------
//* STEP 01: VALIDATE BUSINESS DATE
//*          Program CBEOP005 reads FILE 015 business date,
//*          validates it is a banking day, and populates GDA.
//* COND: Run unconditionally.
//*------------------------------------------------------------
//STEP01   EXEC PGM=NATBAT,REGION=0M
//STEPLIB  DD DSN=NATSYS.LOAD,DISP=SHR
//         DD DSN=MRDBNK.LOAD,DISP=SHR
//NATPARM  DD DSN=MRDBNK.NATPARM.MRDCBLIB,DISP=SHR
//CMPRINT  DD SYSOUT=*
//CMSYSIN  DD DSN=MRDBNK.SHARED.SYSPARM.MASTER.LATEST,DISP=SHR
//CMWKF01  DD DSN=MRDBNK.COREBKG.CONTROL.WORK.&DATE,
//             DISP=(NEW,CATLG,DELETE),
//             DCB=(RECFM=FB,LRECL=200,BLKSIZE=6000),
//             SPACE=(CYL,(1,1))
//SYSIN    DD *
GLOBALS PROGRAM=CBEOP005,LIBRARY=MRDCBLIB,PROGRAM=CBEOP005
CBEOP005
/*
//*------------------------------------------------------------
//* STEP 02: LOAD FX RATE TABLE
//*          Reads FX rates from treasury flat file and loads
//*          to FILE 025. Must complete before any FX transactions.
//* COND: Skip if STEP01 failed (RC > 4).
//*------------------------------------------------------------
//STEP02   EXEC PGM=NATBAT,REGION=0M,
//             COND=(8,LE,STEP01)
//STEPLIB  DD DSN=NATSYS.LOAD,DISP=SHR
//         DD DSN=MRDBNK.LOAD,DISP=SHR
//NATPARM  DD DSN=MRDBNK.NATPARM.MRDCBLIB,DISP=SHR
//CMPRINT  DD SYSOUT=*
//CMWKF01  DD DSN=MRDBNK.SHARED.CCYRATE.INBOUND.DAILY.LATEST,
//             DISP=SHR
//SYSIN    DD *
GLOBALS PROGRAM=CMUTS010,LIBRARY=MRDCMLIB
CMUTS010
/*
//*------------------------------------------------------------
//* STEP 03: PROCESS ACCOUNT OPEN TRIGGERS FROM ONBOARDING
//*          Reads MRDBNK.CUSTONB.IF.COREBKG.DAILY.LATEST
//*          and creates new accounts via CBACP002 batch mode.
//* COND: Skip if STEP02 failed.
//*------------------------------------------------------------
//STEP03   EXEC PGM=NATBAT,REGION=0M,
//             COND=(8,LE,STEP02)
//STEPLIB  DD DSN=NATSYS.LOAD,DISP=SHR
//         DD DSN=MRDBNK.LOAD,DISP=SHR
//NATPARM  DD DSN=MRDBNK.NATPARM.MRDCBLIB,DISP=SHR
//CMPRINT  DD SYSOUT=*
//CMWKF01  DD DSN=MRDBNK.CUSTONB.IF.COREBKG.DAILY.LATEST,
//             DISP=SHR
//CMWKF02  DD DSN=MRDBNK.COREBKG.ACCT.WORK.SOD.REJECTS.&DATE,
//             DISP=(NEW,CATLG,DELETE),
//             DCB=(RECFM=FB,LRECL=200,BLKSIZE=6000),
//             SPACE=(CYL,(1,1))
//SYSIN    DD *
GLOBALS PROGRAM=CBACP002,LIBRARY=MRDCBLIB
CBACP002
/*
//*------------------------------------------------------------
//* STEP 04: VERIFY SOD COMPLETION AND SET ONLINE-OPEN FLAG
//*          Sets SYS-EOD-FLAG=N in FILE 015 to allow online.
//* COND: Only run if all prior steps <= 4 (no hard failures).
//*------------------------------------------------------------
//STEP04   EXEC PGM=NATBAT,REGION=0M,
//             COND=(8,LE,STEP03)
//STEPLIB  DD DSN=NATSYS.LOAD,DISP=SHR
//         DD DSN=MRDBNK.LOAD,DISP=SHR
//NATPARM  DD DSN=MRDBNK.NATPARM.MRDCBLIB,DISP=SHR
//CMPRINT  DD SYSOUT=*
//SYSIN    DD *
GLOBALS PROGRAM=CBEOP003,LIBRARY=MRDCBLIB
CBEOP003 PARM=OPEN
/*
