-- ============================================================================
-- SQL Server Schema Definition
-- ============================================================================
-- Purpose: Create database and schema for localuc platform
-- Database: localuc_db
-- Schema: dbo
-- ============================================================================

USE master;
GO

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'localuc_db')
BEGIN
    CREATE DATABASE localuc_db
        COLLATE SQL_Latin1_General_CP1_CI_AS;
END
GO

USE localuc_db;
GO

EXEC sp_addextendedproperty
    @name = N'Description',
    @value = N'Pharmacy Comprehensive Platform - dimensional model for localuc management',
    @level0type = N'SCHEMA',
    @level0name = N'dbo';
GO

