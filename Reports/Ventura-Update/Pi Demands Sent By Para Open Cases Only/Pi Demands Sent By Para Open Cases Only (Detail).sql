-- SQL Server Session Handling Parameters
SET NOCOUNT ON;
SET DEADLOCK_PRIORITY LOW;
SET LANGUAGE us_english;
SET LOCK_TIMEOUT 30000;
SET IMPLICIT_TRANSACTIONS OFF;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET NOEXEC OFF;
-- Declare RAISERROR Parameters
DECLARE @ErrorNumber [INT] = 0;
DECLARE @ErrorSeverity [INT] = 10;
DECLARE @ErrorState [INT] = 0;
DECLARE @ErrorProcedure [NVARCHAR] (128) = NULL;
DECLARE @ErrorLine [INT] = 0;
DECLARE @ErrorMessage [NVARCHAR] (4000) = NULL;
DECLARE @RaiseErrorText [NVARCHAR] (4000) = NULL;
-- Declare Local Script Specific Parameters
DECLARE @newReport uniqueidentifier = newid();
DECLARE @baseTableId uniqueidentifier = newid();
DECLARE @rptName varchar(100) = 'Pi Demands Sent By Para Open Cases Only (Detail)';
DECLARE @rptDesc varchar(500) = 'Pi Demands Sent By Para Open Cases Only (Detail)';
DECLARE @rptId varchar(50) = 'Pi Demands Sent By Para Open Cases Only';
DECLARE @rptObject varchar(100) = 'Blank Report Object';
DECLARE @rptCategoryId uniqueidentifier = (select top 1 [id] from [report_category] where [name] = 'User Defined');

-- T-SQL Script
BEGIN
   BEGIN TRY
      BEGIN TRANSACTION @rptName WITH MARK 'Neos Report';
         IF EXISTS
            (
               SELECT
                  TOP 1 [title] 
               FROM
                  [reports_orm] 
               WHERE 
                  [title] = @rptid 
               OR 
                  [title] = @rptName
            )
               BEGIN
                  DELETE FROM 
                     [reports_orm]
                  WHERE 
                     [title] = @rptid
                  OR 
                     [title] = @rptName;
               END;

         IF EXISTS
            (
               SELECT
                  TOP 1 [title]
               FROM
                  [reports] 
               WHERE 
                  [title] = @rptName
            )
               BEGIN
                  DELETE FROM 
                     [reports] 
                  WHERE 
                     [title] = @rptName;
               END;

         -- BEGIN ADDITIONAL T-SQL CODE

INSERT reports (id,title, description,report_object, read_only, reportcategoryid, date_created, 
	staffcreatedid,date_modified,staffmodifiedid, content, datelastrun, stafflastrunid,report_type)

VALUES (@baseTableId ,@rptName, @rptDesc,@rptObject, 0,@rptCategoryId,current_timestamp,
NULL,current_timestamp, NULL, NULL, NULL, NULL, 0)
;
-- insert the report object (title must be unique)
INSERT reports_orm (id, title, description, report_object, read_only, 
reportcategoryid, date_created, staffcreatedid, date_modified, staffmodifiedid, base_entity, 
raw_sql, main_table_id) 
VALUES (@newReport, @rptName, @rptName, @rptObject, 0, @rptCategoryId , 
current_timestamp, NULL, NULL, NULL, N'Needles.ReportDesigner.ReportObjects.UserDefinedReport', '

WITH cteAllData (
	case_date_2,case_date_3,casenum,staff_1,staff_3,staff_6,close_date,matcode,classcode,
	date_of_incident,case_title,party_name
		) 
AS (

SELECT
	(SELECT casedate FROM case_dates, matter_dates WHERE cases.id = case_dates.casesid AND cases.matterid = matter_dates.matterid 
		AND case_dates.datelabelid=matter_dates.datelabelid AND display_order=2) AS case_date_2,
	(SELECT casedate FROM case_dates, matter_dates WHERE cases.id = case_dates.casesid AND cases.matterid = matter_dates.matterid 
		AND case_dates.datelabelid=matter_dates.datelabelid AND display_order=3) AS case_date_3,
	cases.casenum,
	(SELECT staff_code FROM case_staff, staff, matter_staff WHERE cases.id = case_staff.casesid AND staff.id = case_staff.staffid 
		AND case_staff.matterstaffid=matter_staff.id AND staffroleid=''00000000-0000-0000-0000-000000000001'') AS staff_1,
	(SELECT staff_code FROM case_staff, staff, matter_staff WHERE cases.id = case_staff.casesid AND staff.id = case_staff.staffid 
		AND case_staff.matterstaffid=matter_staff.id AND staffroleid=''00000000-0000-0000-0000-000000000003'') AS staff_3,
	(SELECT staff_code FROM case_staff, staff, matter_staff WHERE cases.id = case_staff.casesid AND staff.id = case_staff.staffid 
		AND case_staff.matterstaffid=matter_staff.id AND staffroleid=''00000000-0000-0000-0000-000000000006'') AS staff_6,
	cases.close_date,
	matter.matcode,
	class.classcode,
	cases.date_of_incident,
	cases.case_title,
	(SELECT TOP 1 fullname_lastfirst FROM party,names WHERE casesid = cases.id AND party.namesid=names.id ORDER BY record_num ASC) AS party_name
FROM 
	cases
JOIN matter on matter.id = cases.matterid AND matter.matcode NOT IN (''pro'')
LEFT JOIN class on class.id = cases.classid
WHERE 
	(SELECT casedate FROM case_dates, matter_dates WHERE cases.id = case_dates.casesid AND cases.matterid = matter_dates.matterid 
		AND case_dates.datelabelid=matter_dates.datelabelid AND display_order=2) is not null
	AND cases.close_date IS NULL
	AND (@enter_staff IS NULL OR (SELECT staff.staff_code FROM case_staff, staff, matter_staff WHERE cases.id = case_staff.casesid AND staff.id = case_staff.staffid 
		AND case_staff.matterstaffid=matter_staff.id AND staffroleid=''00000000-0000-0000-0000-000000000001'') = @enter_staff)
	AND (SELECT casedate FROM case_dates, matter_dates WHERE cases.id = case_dates.casesid AND cases.matterid = matter_dates.matterid 
		AND case_dates.datelabelid=matter_dates.datelabelid AND display_order=3) IS NULL
	
 )
 
SELECT 
	party_name
	,FORMAT(try_cast(date_of_incident AS date), ''MM/dd/yyyy'') AS date_of_incident
	,casenum
	,matcode
	,(CASE WHEN (case_date_3 <= case_date_2) THEN staff_3 ELSE staff_1 END) AS staff_1
	,FORMAT(try_cast(case_date_2 AS date), ''MM/dd/yyyy'') AS case_date_2
	,staff_6
 FROM
	cteAllData AS cte
 ORDER BY
	case_date_2;',@baseTableId)

-- insert the columns, one row per column in the select
INSERT report_columns_orm (id, binding, reportid, name, col_order) VALUES (newid(), N'party_name', @newReport, N'Party Name', 0)
INSERT report_columns_orm (id, binding, reportid, name, col_order) VALUES (newid(), N'date_of_incident', @newReport, N'DOL', 1)
INSERT report_columns_orm (id, binding, reportid, name, col_order) VALUES (newid(), N'casenum', @newReport, N'Case #', 2)
INSERT report_columns_orm (id, binding, reportid, name, col_order) VALUES (newid(), N'matcode', @newReport, N'Type', 3)
INSERT report_columns_orm (id, binding, reportid, name, col_order) VALUES (newid(), N'staff_1', @newReport, N'Paralegal', 4)
INSERT report_columns_orm (id, binding, reportid, name, col_order) VALUES (newid(), N'case_date_2', @newReport, N'Demand Sent', 5)
INSERT report_columns_orm (id, binding, reportid, name, col_order) VALUES (newid(), N'staff_6', @newReport, N'Neg Atty', 6)

INSERT report_parameters_orm (id, reportid, name, type, multi_value, visible, description, use_string_value, is_sql_parm, is_required, parm_order) 
	VALUES (newid(), @newReport, N'enter_staff', N'Needles.Core.Entities.Common.StaffPersonBasic', 
	1, 1, N'Staff Name', 0, 1, 0,0)

         -- END ADDITIONAL T-SQL CODE

      -- CHECK FOR TRANSACTION
      IF (XACT_STATE()) <> 0
         BEGIN
            IF
               (XACT_STATE()) = 1 COMMIT TRANSACTION;
            ELSE
               ROLLBACK TRANSACTION;
         END;
   END TRY
   BEGIN CATCH
      IF @ErrorNumber BETWEEN 13000 AND 2147483647 AND @ErrorNumber <> 50000
         BEGIN
            SELECT
                 @ErrorNumber = ERROR_NUMBER()
               , @ErrorSeverity = ERROR_SEVERITY()
               , @ErrorState = ERROR_STATE()
               , @ErrorProcedure = ERROR_PROCEDURE()
               , @ErrorLine = ERROR_LINE()
               , @ErrorMessage = ERROR_MESSAGE();
            RAISERROR
            (
                 @ErrorNumber
               , @ErrorSeverity
               , @ErrorState
               , @ErrorProcedure
               , @ErrorLine
               , @ErrorMessage
            ) WITH NOWAIT, LOG;
            IF (XACT_STATE()) <> 0
               BEGIN
                  IF
                     (XACT_STATE()) = 1 COMMIT TRANSACTION;
                  ELSE
                     ROLLBACK TRANSACTION;
               END;
         END;
      ELSE
         BEGIN
            SELECT
                 @ErrorMessage = ERROR_MESSAGE()
               , @ErrorSeverity = ERROR_SEVERITY()
               , @ErrorState = ERROR_STATE();
            RAISERROR
            (
                 @ErrorMessage
               , @ErrorSeverity
               , @ErrorState
            ) WITH NOWAIT, LOG;
            IF (XACT_STATE()) <> 0
               BEGIN
                  IF
                     (XACT_STATE()) = 1 COMMIT TRANSACTION;
                  ELSE
                     ROLLBACK TRANSACTION;
               END;
         END;
   END CATCH;
END;
GO