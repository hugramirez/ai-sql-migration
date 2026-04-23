-- ============================================================================
-- SQL Server Schema Definition
-- ============================================================================
-- Purpose: Create database and schema for pharmacy platform
-- Database: pharmacy_db
-- Schema: dbo
-- ============================================================================

USE master;
GO

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'pharmacy_db')
BEGIN
    CREATE DATABASE pharmacy_db
        COLLATE SQL_Latin1_General_CP1_CI_AS;
END
GO

USE pharmacy_db;
GO

EXEC sp_addextendedproperty
    @name = N'Description',
    @value = N'Pharmacy Comprehensive Platform - dimensional model for pharmacy management',
    @level0type = N'SCHEMA',
    @level0name = N'dbo';
GO

