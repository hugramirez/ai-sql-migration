-- ============================================================================
-- SQL Server Schema Definition
-- ============================================================================
-- Purpose: Create database and schema for pharmacy platform
-- Database: localdb
-- Schema: dbo
-- ============================================================================

USE master;
GO

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'localdb')
BEGIN
    CREATE DATABASE localdb
        COLLATE SQL_Latin1_General_CP1_CI_AS;
END
GO

USE localdb;
GO

EXEC sp_addextendedproperty
    @name = N'Description',
    @value = N'Pharmacy Comprehensive Platform - dimensional model for pharmacy management',
    @level0type = N'SCHEMA',
    @level0name = N'dbo';
GO

