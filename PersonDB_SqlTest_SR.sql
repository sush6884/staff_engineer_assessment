USE PERSONDATABASE

/*********************
Hello! 
Please use the test data provided in the file 'PersonDatabase' to answer the following
questions. Please also import the dbo.Contracts flat file to a table for use. 
All answers should be written in SQL. 
***********************
QUESTION 1
The table dbo.Person contains basic demographic information. The source system users 
input nicknames as strings inside parenthesis. Write a query or group of queries to 
return the full name and nickname of each person. The nickname should contain only letters 
or be blank if no nickname exists.
**********************/

---The below script removes only ( or ) characters upto 2 occurences

select 
replace(LTRIM(RTRIM(replace(replace(personname,
Case 
when charindex('(',personname)>0 then
substring(PersonName,CHARINDEX('(',PersonName),CHARINDEX(')',PersonName)-charindex('(',personname)+1)
when charindex('(',personname)=0 then
''
end
,''),')',''))),'  ',' ') as FULL_NAME,

Case 
when (charindex('(',personname)>0 OR charindex(')',personname)>0)  then
substring(PersonName,CHARINDEX('(',PersonName)+1,CHARINDEX(')',PersonName)-charindex('(',personname)-1)
--when charindex('(',personname)=0 then
when (charindex('(',personname)=0 OR charindex(')',personname)=0) then
''
end as NICK_NAME 
from dbo.Person; 

/***********************Alternate solution to handle any special characters*************************************/

Use PERSONDATABASE

GO

CREATE FUNCTION dbo.Remove_Specialchar
(
@string VARCHAR(255)
)
RETURNS VARCHAR(255)
AS
BEGIN
DECLARE @IncorrectCharLoc SMALLINT
SET @IncorrectCharLoc = PATINDEX('%[^0-9A-Za-z]%', @string)
WHILE @IncorrectCharLoc > 0
BEGIN
SET @string = STUFF(@string, @IncorrectCharLoc, 1, '')
SET @IncorrectCharLoc = PATINDEX('%[^0-9A-Za-z]%', @string)
END
SET @string = @string
RETURN @string
END
GO

--drop table #person_temp;

select personid,dateofbirth,sex,
replace(LTRIM(RTRIM(replace(replace(personname,
Case 
when charindex('(',personname)>0 then
substring(PersonName,CHARINDEX('(',PersonName),CHARINDEX(')',PersonName)-charindex('(',personname)+1)
when charindex('(',personname)=0 then
''
end
,''),')',''))),'  ',' ') as FULL_NAME,

Case 
when (charindex('(',personname)>0 OR charindex(')',personname)>0)  then
substring(PersonName,CHARINDEX('(',PersonName)+1,CHARINDEX(')',PersonName)-charindex('(',personname)-1)
--when charindex('(',personname)=0 then
when (charindex('(',personname)=0 OR charindex(')',personname)=0) then
''
end as NICK_NAME into #person_temp
from dbo.Person; 
select * from #person_temp;

--drop table  #person_names;

select PersonId,left(full_name, CHARINDEX(' ', full_name)) as firstname,
substring(full_name, CHARINDEX(' ', full_name)+1, len(full_name)-(CHARINDEX(' ', full_name)-1)) as lastname, DateofBirth,Sex,NICK_NAME
into #person_names
from #person_temp ;

select dbo.Remove_Specialchar(FIRSTNAME)+' '+dbo.Remove_Specialchar(LASTNAME) FULL_NAME,dbo.Remove_Specialchar(NICK_NAME) from #person_names;

/**********************
QUESTION 2
The dbo.Risk table contains risk and risk level data for persons over time for various 
payers. Write a query that returns patient name and their current risk level. 
For patients with multiple current risk levels return only one level so that Gold > Silver > Bronze.
**********************/

 
 with Person_Risk	as 
 (

 select Person.PersonName,Risk.RiskLevel,rank() over(partition by PersonName order by risklevel desc) as risk_rank
 from dbo.Person left outer join dbo.Risk
 on Person.[PersonID]=Risk.[PersonID]
 )select PersonName,RiskLevel from Person_Risk where risk_rank=1;

 /***************The above query can be enhanced to pull person firstname, lastname info in separate columns using the query from Question 1*********************************/

/**********************
QUESTION 3
Create a patient matching stored procedure that accepts (first name, last name, dob and sex) as parameters and 
and calculates a match score from the Person table based on the parameters given. If the parameters do not match the existing 
data exactly, create a partial match check using the weights below to assign partial credit for each. Return PatientIDs and the
 calculated match score. Feel free to modify or create any objects necessary in PersonDatabase.  
FirstName 
	Full Credit = 1
	Partial Credit = .5
LastName 
	Full Credit = .8
	Partial Credit = .4
Dob 
	Full Credit = .75
	Partial Credit = .3
Sex 
	Full Credit = .6
	Partial Credit = .25
**********************/

/****The below queries create a temporary #person_names table to insert firstname,lastname,patientid, dob and gender into it******************/
--drop table #person_temp;

select personid,dateofbirth,sex,
replace(LTRIM(RTRIM(replace(replace(personname,
Case 
when charindex('(',personname)>0 then
substring(PersonName,CHARINDEX('(',PersonName),CHARINDEX(')',PersonName)-charindex('(',personname)+1)
when charindex('(',personname)=0 then
''
end
,''),')',''))),'  ',' ') as FULL_NAME,

Case 
when (charindex('(',personname)>0 OR charindex(')',personname)>0)  then
substring(PersonName,CHARINDEX('(',PersonName)+1,CHARINDEX(')',PersonName)-charindex('(',personname)-1)
--when charindex('(',personname)=0 then
when (charindex('(',personname)=0 OR charindex(')',personname)=0) then
''
end as NICK_NAME into #person_temp
from dbo.Person; 
select * from #person_temp;

--drop table  #person_names;

select PersonId,left(full_name, CHARINDEX(' ', full_name)) as firstname,
substring(full_name, CHARINDEX(' ', full_name)+1, len(full_name)-(CHARINDEX(' ', full_name)-1)) as lastname,  DateofBirth,Sex, row_number() over ( order by personid) as rownum
into #person_names
from #person_temp ;

select * from #person_names;


create table #pat_match
(personid varchar(10),
firstname varchar(50),
lastname varchar(50),
dob datetime,
sex varchar(6),
match_score decimal(5,3))

--Drop procedure sp_patient_match;

Use dwstage
GO
create procedure sp_patient_match(
 @firstname varchar(50),
 @lastname varchar(50), 
@dob varchar(10), 
 @sex varchar(6))
AS 
Begin

declare @pat_firstname varchar(50)
declare @pat_lastname varchar(50)
declare @pat_dob varchar(10)
declare @pat_sex varchar(6)
declare @patient_id varchar(10)
declare  @Match_Score Decimal(3,2)


declare @cnt int

set @cnt=(select count(*) from #person_names)

while @cnt>0
BEGIN

/********Match firstname***************/
set @Patient_Id =(select personid from #person_names where rownum=@cnt)

set @pat_firstname = (select FirstName FROM #person_names where rownum=@cnt)



set @Match_Score= 
(
case 
when @pat_firstname=@firstname then 1
when @pat_firstname like @firstname+'%' then 0.5 
else 0
end)



/************Match Lastname***************/
set @pat_lastname = (select lastname FROM #person_names where  rownum=@cnt)


set @Match_Score= @Match_Score +
(
case 
when @pat_lastname=@lastname then 0.8
when @pat_lastname like @lastname+'%' then 0.4
else 0
end)


print @Match_Score

/***************Match Gender*******************/
set @pat_sex = (select sex FROM #person_names where  rownum=@cnt)

set @Match_Score= @Match_Score +
(
case 
when @pat_sex=@sex then 0.6
when @pat_sex like @sex+'%' then 0.25
else 0
end)




/***************Match DOB*******************/
set @pat_dob = (select convert(varchar(10),DateofBirth,20) FROM #person_names where  rownum=@cnt)

set @Match_Score= @Match_Score +
(
case 
when @pat_dob=@dob then 0.75
when @pat_dob like @dob+'%' then 0.3
else 0
end)


insert into #pat_match values (@patient_id,@pat_firstname,@pat_lastname,@pat_dob,@pat_sex,@Match_Score)

set @cnt=@cnt-1;

end

Return;
End

/******Execute the patient matching proc by using the script below********************/

 truncate table #pat_match  ;

 insert into #pat_match  
execute sp_patient_match 'Romeo','St','1949-06-02','M';

 select * from #pat_match order by match_score desc;

/**********************
QUESTION 4
A. Looking at the script 'PersonDatabase', what change(s) to the tables could be made to improve the database structure?  
B. What method(s) could we use to standardize the data allowed in dbo.Person (Sex) to only allow 'Male' or 'Female'?
C. Assuming these tables will grow very large, what other database tools/objects could we use to ensure they remain
efficient when queried?
**********************/
/*
A. Recommendations to improve PersonDatabase structure are - 

  1.  Standardize Datatypes - Datatypes across different tables for the same column have to be consistent. PersonId is defined as integer in Person table and 
      as varchar in the risk table. Datatype for PersonID can be defined as bigint to save space and increase efficiency in joins. 
	  AttributedPayer field size can be defined as varchar(50) or varchar(75) after analyzing all expected attributed payers in the market.  
  2.  Primary Key & Constraints- PersonID should be made primary key in the person table as it is unique per person and should be defined as not null. 
      This prevents duplicates from being inserted into the table at personid level, increases query time while joining to other tables as index is automatically 
	  created on a primary key. Also this primary key can be referenced in other tables as a foreign key and be included in referential constraints in order to
	  ensure referential integrity.
  3.  Normalization - a. Split address to Address1, Address2, City, State, Zip and Country. Add lookup tables for city, state and zip code and add foreign keys 
      for these columns from the Person table to these lookup tables. This will ensure consistent spellings and easy slice and dice for end users/reporting teams.
	  b. If the plan is to store historical or multiple addresses for a person in future, have a separate address table that contains personid and all fields of 
	  Address like Address1, Address2, City, State and Zip and Active flag, Address obsolete date etc... in order to track all historical address changes for a Person.
	  c. Split person name into first name, last name, nick name in order to improve sort or searching by different parts of the names. It is always easy to concatenate
	  fields to get a full name for end user vs. splitting a full name.
	  d. Attributed Payer can be maintained in a separate look up table having referential integrity to a attribute payer Id in the Risk table.
  4.  Traceability - Add create date, update date and update user name in every table for ease of tracking as to when a record was created/updated and by whom.
  5.  Data Hash keys - Since the tables are expected to grow in size in future, having indexed datahashkeys in tables that get frequent updates will improve
      update time to the database.
  6.  Documentation - As best practice, always draw a database schema to define relationships among the tables.
  7.  Dates - Since contracts table has dates, adding date dim keys for contract begin and end dates will help end users to slice and dice contracts by different
      attributes for dates i.e. month, day, quarter etc..
 
B. In order to standardize incoming values into the Person.Sex field, check constraint should be added to the table to ensure only values Male or Female
   get inserted. Example after executing the following alter table script - */

   ALTER TABLE dbo.Person WITH NOCHECK  
	  ADD  CONSTRAINT CK_Person_Sex
	  CHECK  (Sex in ( 'Male' , 'Female') )

	 /* The below insert statement will throw an error as sex contains invalid values */

	  INSERT INTO DBO.PERSON (PersonID, PersonName, Sex, DateofBirth, Address, IsActive)
      VALUES (8, 'Margot Steed ())', 'Fmale','1962-03-12', '62 South Peg Shop Street Terre Haute, IN 47802', 1)
/*

   Another way is to create a look up table for Sex that contains standard values. During ETL process, this look up table will be referenced before loading any
   data into Sex column of the Person table.

C. Following are the suggestions to increase query efficiency-
   1. Add indices on tables using best practices (primary keys, frequently used fields in where, aggregate or group by clauses).
   2. Store temporary or backend tables that are used during ETL process in a separate database.
   3. Partition tables like the contracts table that will grow very large over time. 
   4. Educate end users to use optimized queries based on best practices (using indices, where clause fields, nolock etc..).
   5. If data is not updated to these tables in real time, database inserts/updates can be done overnight during less query intensive hours.
   6. Add more CPU/RAM to the backend databases.
   7. Implement new technologies that can support large databases like Big Data and Cloud.
   8. In order for operations to go smoothly, strict QA checks should be implemented before inserting/updating data into the data warehouse. This will ensure less
      downtime and data integrity.
   */
   
/**********************
QUESTION 5
Write a query to return risk data for all patients, all contracts and a moving average of risk for that patient and contract 
in dbo.Risk. 
**********************/

WITH Riskdates AS
(SELECT *, LEAD(riskdatetime) OVER (PARTITION BY personid ORDER BY riskdatetime) AS NextContractStartDate
 FROM dbo.risk
)
SELECT t.personid, d.Datevalue as Riskdatetime, t.riskscore,t.RiskLevel,t.AttributedPayer into Missing_Contracts
FROM dbo.dates d
JOIN Riskdates t
    ON d.Datevalue BETWEEN t.riskdatetime AND ISNULL(DATEADD(day,-1,t.NextContractStartDate),t.NextContractStartDate)

--select * from Missing_Contracts
--drop table missing_contracts
--drop table All_Contracts

select x.* into All_Contracts from

(select * from Missing_Contracts

UNION ALL

select personid,riskdatetime, riskscore, RiskLevel,AttributedPayer
from dbo.risk )x


--select * from All_Contracts;

select p.PersonID,p.PersonName, t.RiskDateTime, t.Riskscore, t.RiskLevel, t.AttributedPayer,avg(t.riskscore) over (partition by p.personid order by t.riskdatetime) as Moving_Avg_Risk
from dbo.person p left outer join All_Contracts t 
on p.personid=t.personid;


/**********************
QUESTION 6
Write script to load the dbo.Dates table with all applicable data elements for dates 
between 1/1/2010 and 500 days past the current date.
**********************/

--drop table dates;

Declare @begin_dt Date ='2010-01-01'
Declare @EndDaysfromCurrentDate int=500
while @begin_dt<=Getdate()+@EndDaysfromCurrentDate

Begin

	Insert into dbo.[Dates] ([DateValue]
      ,[DateDayofMonth]
      ,[DateDayofYear]
      ,[DateQuarter]
      ,[DateWeekdayName]
      ,[DateMonthName]
      ,[DateYearMonth])

	  values (@begin_dt, -- datevalue
	  Day(@begin_dt), --dayofmonth
	  Datepart(dy,@begin_dt), --dayofyear
	  Datepart(qq,@begin_dt),--datequarter
	  Datename(dw,@begin_dt), --weekdayname
	  Datename(mm,@begin_dt), --monthname
	  Convert(varchar(6),@begin_dt,112))

	  SET @begin_dt=Dateadd(dd,1,@begin_dt)

	  END

	  
/**********************
QUESTION 7
Please import the data from the flat file dbo.Contracts.txt to a table to complete this question. 
Using the data in dbo.Contracts, create a query that returns 
	(PersonID, AttributionStartDate, AttributionEndDate) 
The data should be structured so that rows with contiguous ranges are merged into a single row. Rows that contain a 
break in time of 1 day or more should be entered as a new record in the output. Restarting a row for a new 
month or year is not necessary.
Use the dbo.Dates table if helpful.
**********************/


 SELECT s1.PersonID,s1.ContractStartDate as AttributionStartDate, 
       MIN(t1.ContractEndDate) AS AttributionEndDate 
FROM [dbo].Contracts s1 
INNER JOIN [dbo].Contracts t1 ON s1.PersonID=t1.PersonID and s1.ContractStartDate <= t1.ContractEndDate
  AND NOT EXISTS(SELECT * FROM [dbo].Contracts t2 
                 WHERE t1.PersonID=t2.PersonID and t1.ContractEndDate >= t2.ContractStartDate AND t1.ContractEndDate < t2.ContractEndDate) 
WHERE NOT EXISTS(SELECT * FROM [dbo].Contracts s2 
                 WHERE s1.personid=s2.personid and s1.ContractStartDate > s2.ContractStartDate AND s1.ContractStartDate <= s2.ContractEndDate) 
GROUP BY s1.personid,s1.ContractStartDate 
ORDER BY s1.personid,s1.ContractStartDate 