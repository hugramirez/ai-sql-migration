-- ============================================================================
-- Drop Pharmacy Database Script
--
-- This script drops the pharmacy_db database if it exists.
-- Use this to reset and start fresh before running run.sql
--
-- WARNING: This will delete all data in pharmacy_db
-- ============================================================================

USE master;
GO

IF EXISTS (SELECT * FROM sys.databases WHERE name = 'pharmacy_db')
BEGIN
    DROP DATABASE pharmacy_db;
END
GO

PRINT 'pharmacy_db database dropped successfully (if it existed).';
GO
