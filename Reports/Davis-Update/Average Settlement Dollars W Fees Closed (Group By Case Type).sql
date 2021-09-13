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
DECLARE @rptName varchar(100) = 'Average Settlement Dollars W Fees Closed (Group By Case Type)';
DECLARE @rptDesc varchar(500) = 'Average Settlement Dollars W Fees Closed (Group By Case Type)';
DECLARE @rptId varchar(50) = 'Average Settlement Dollars W Fees Closed';
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
				casenum,
				matcode,
				staff_1,
				party_name,
				Insurance_Actual,
				Date_Settled,
				Case_Costs,
				Attorney_Fees
				)
AS (
SELECT
	cases.casenum,
	matter.matcode,
	(SELECT staff_code FROM case_staff, staff, matter_staff WHERE cases.id = case_staff.casesid AND staff.id = case_staff.staffid 
			AND case_staff.matterstaffid=matter_staff.id AND staffroleid=''00000000-0000-0000-0000-000000000001'') AS staff_1,
	(SELECT TOP 1 fullname_lastfirst FROM party,names WHERE casesid = cases.id AND party.namesid=names.id ORDER BY record_num ASC) AS party_name,
	ISNULL((SELECT SUM(insurance.actual) FROM insurance WHERE cases.id=insurance.casesid AND (@enter_start_date IS NULL OR insurance.date_settled>=@enter_start_date)
			AND (@enter_end_date IS NULL OR insurance.date_settled<@enter_end_date)),0) AS Insurance_Actual,
	(SELECT TOP 1 (insurance.date_settled) FROM insurance WHERE cases.id=insurance.casesid AND (@enter_start_date IS NULL OR insurance.date_settled>=@enter_start_date)
			AND (@enter_end_date IS NULL OR insurance.date_settled<@enter_end_date) ORDER BY insurance.date_settled desc) AS Date_Settled,
	ISNULL((SELECT SUM(TRY_CAST(user_insurance_data.data AS float)) FROM cases c JOIN insurance ON insurance.casesid=c.id JOIN user_insurance_data ON user_insurance_data.insuranceid=insurance.id 
			JOIN user_case_fields ON user_case_fields.id=user_insurance_data.usercasefieldid AND user_case_fields.field_title=''Case Costs'' WHERE c.id=cases.id),0) AS Case_Costs,
	ISNULL((SELECT SUM(TRY_CAST(user_insurance_data.data AS float)) FROM cases c JOIN insurance ON insurance.casesid=c.id JOIN user_insurance_data ON user_insurance_data.insuranceid=insurance.id 
			JOIN user_case_fields ON user_case_fields.id=user_insurance_data.usercasefieldid AND user_case_fields.field_title=''Attorney Fees'' WHERE c.id=cases.id),0) AS Attorney_Fees	
FROM 
	cases
JOIN matter ON matter.id=cases.matterid
WHERE
	cases.close_date IS NOT NULL
	AND cases.id IN (SELECT insurance.casesid FROM insurance WHERE insurance.casesid=cases.id AND (@enter_start_date IS NULL OR insurance.date_settled >= @enter_start_date))
	AND cases.id IN (SELECT insurance.casesid FROM insurance WHERE insurance.casesid=cases.id AND (@enter_end_date IS NULL OR insurance.date_settled < @enter_end_date))
) 

SELECT 
		matcode,
		COUNT(DISTINCT casenum) as tcg,
		FORMAT(SUM(Insurance_Actual),''c2'') as ins_actual,
		FORMAT((SUM(Insurance_Actual)/COUNT(DISTINCT casenum)),''c2'') as avg_settlement,
		FORMAT(SUM(Case_Costs),''c2'') as cse_costs,
		FORMAT(SUM(Case_Costs)/ COUNT(DISTINCT casenum),''c2'') as avg_cse_costs,
		FORMAT(SUM(Attorney_Fees),''c2'') as attorney_fee,
		FORMAT(SUM(Attorney_Fees)/ COUNT(DISTINCT casenum),''c2'') as avg_attorny_fee
FROM 
	cteAllData
GROUP BY
	matcode
ORDER BY
	matcode;',@baseTableId)
-- insert the columns, one row per column in the select
INSERT report_columns_orm (id, binding, reportid, name, col_order) VALUES (newid(), N'matcode', @newReport, N'Case Type', 0)
INSERT report_columns_orm (id, binding, reportid, name, col_order) VALUES (newid(), N'tcg', @newReport, N'Total Cases', 1)
INSERT report_columns_orm (id, binding, reportid, name, col_order) VALUES (newid(), N'ins_actual', @newReport, N'Total Acutal Amount', 2)
INSERT report_columns_orm (id, binding, reportid, name, col_order) VALUES (newid(), N'avg_settlement', @newReport, N'Average $ Settlement/Case', 3)
INSERT report_columns_orm (id, binding, reportid, name, col_order) VALUES (newid(), N'cse_costs', @newReport, N'Total Case Costs', 4)
INSERT report_columns_orm (id, binding, reportid, name, col_order) VALUES (newid(), N'avg_cse_costs', @newReport, N'Case Cost Averages', 5)
INSERT report_columns_orm (id, binding, reportid, name, col_order) VALUES (newid(), N'attorney_fee', @newReport, N'Total Attorney Fee', 6)
INSERT report_columns_orm (id, binding, reportid, name, col_order) VALUES (newid(), N'avg_attorny_fee', @newReport, N'Attorney Fee Averages', 7)

INSERT report_parameters_orm (id, reportid, name, type, multi_value, visible, description, use_string_value, is_sql_parm, is_required, parm_order) 
	VALUES (newid(), @newReport, N'enter_start_date', N'System.Nullable`1[[System.DateTime]]', 
	0, 1, N'Enter Start Date', 0, 1, 0,0)
INSERT report_parameters_orm (id, reportid, name, type, multi_value, visible, description, use_string_value, is_sql_parm, is_required, parm_order) 
	VALUES (newid(), @newReport, N'enter_end_date', N'System.Nullable`1[[System.DateTime]]', 
	0, 1, N'Enter End Date', 0, 1, 0, 1)


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