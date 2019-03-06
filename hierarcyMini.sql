--1.
--update fnGetFullDisplayPath function to fit [HumanResources].[Employee] table.
--replace null with 0x and check by isnull([OrganizationNode],0x)
--join with person.person to get names


-- Create a UDF to return the full display path of a node
create FUNCTION dbo.fnGetFullDisplayPath(@EmployeeNodeId hierarchyid) RETURNS varchar(max) 
 AS 
BEGIN
    -- Start with the specified node
	DECLARE @Depth smallint
	DECLARE @DisplayPath varchar(max)
	--check if null, if so replace with 0
	--@depth = level of hierarchy
	--@DisplayPath = name of person 
	--@EmployeeNodeId = hierarchyid of employee
	--@ParentEmployeeName = manager name
	set @EmployeeNodeId = isnull(@EmployeeNodeId,0x)
	SELECT @Depth = isnull(emp.[OrganizationNode].GetLevel(),0), @DisplayPath = pp.FirstName
	 FROM [HumanResources].[Employee] emp inner join [Person].[Person] pp
	 ON emp.[BusinessEntityID] = pp.[BusinessEntityID]
	 WHERE isnull([OrganizationNode],0x) = @EmployeeNodeId

    -- Loop through all its ancestors
	DECLARE @LevelCounter smallint = 0
	WHILE @LevelCounter < @Depth BEGIN
		SET @LevelCounter += 1

		-- Get parent node ID
		DECLARE @ParentEmployeeNodeId hierarchyid =
		 isnull((SELECT distinct [OrganizationNode].GetAncestor(@LevelCounter) FROM [HumanResources].[Employee] WHERE [OrganizationNode] = @EmployeeNodeId),0x)

		-- Get parent name
		DECLARE @ParentEmployeeName varchar(max) =
		 (SELECT pp.FirstName
		 FROM [HumanResources].[Employee] emp inner join [Person].[Person] pp
		 ON emp.[BusinessEntityID] = pp.[BusinessEntityID]
		 WHERE isnull([OrganizationNode],0x) = @ParentEmployeeNodeId)

		-- Prepend to display path
		SET @DisplayPath = @ParentEmployeeName + ' > ' + @DisplayPath
	END
 
	RETURN(@DisplayPath)
END 
GO

SELECT
	*,
	[OrganizationNode].ToString() AS NodeIdPath,
	dbo.fnGetFullDisplayPath([OrganizationNode]) AS NodeIdDisplayPath
 FROM
	[HumanResources].[Employee]
 ORDER BY
	NodeIdDisplayPath
GO

--2. create script to:
--a. show one level below employee 'Terri Duffy'
DECLARE @TerriOrganizationNode hierarchyid = (SELECT OrganizationNode 
											  FROM [HumanResources].[Employee] emp
												inner join
												[Person].[Person] pp
												ON emp.[BusinessEntityID] = pp.[BusinessEntityID]
											 where pp.FirstName = 'Terri'
											 and pp.LastName = 'Duffy')

SELECT *, OrganizationNode.ToString() AS NodeIdPath, dbo.fnGetFullDisplayPath(OrganizationNode) AS NodeIdDisplayPath
 FROM [HumanResources].[Employee]
 WHERE OrganizationNode.GetAncestor(1)=@TerriOrganizationNode
 ORDER BY NodeIdDisplayPath

--b. names of workers in lowest hierarcy

SELECT *, OrganizationNode.ToString() AS NodeIdPath, dbo.fnGetFullDisplayPath(OrganizationNode) AS NodeIdDisplayPath
 FROM [HumanResources].[Employee]
 WHERE OrganizationLevel = (select max(OrganizationLevel) from [HumanResources].[Employee])
 ORDER BY NodeIdDisplayPath
 
--c. names of managers in level 1
SELECT
	*,
	emp.[OrganizationNode].ToString() AS NodeIdPath,
	dbo.fnGetRequestedDisplayPath(emp.[OrganizationNode], 1, 1) AS NodeIdDisplayPath
 FROM
	[HumanResources].[Employee] emp
	where emp.OrganizationLevel = (select min(OrganizationLevel) from [HumanResources].[Employee])
 ORDER BY
	NodeIdDisplayPath
GO


--d. show sub tree of all emloyees under 'brian welcker'

DECLARE @BrianOrganizationNode hierarchyid = (SELECT OrganizationNode 
											  FROM [HumanResources].[Employee] emp
												inner join
												[Person].[Person] pp
												ON emp.[BusinessEntityID] = pp.[BusinessEntityID]
											 where pp.FirstName = 'Brian'
											 and pp.LastName = 'Welcker')

SELECT *, OrganizationNode.ToString() AS NodeIdPath, dbo.fnGetFullDisplayPath(OrganizationNode) AS NodeIdDisplayPath
 FROM [HumanResources].[Employee]
 WHERE OrganizationNode.IsDescendantOf(@BrianOrganizationNode) = 1
 ORDER BY NodeIdDisplayPath

--e. employee names under 'peter krebs'

DECLARE @PeterOrganizationNode hierarchyid = (SELECT OrganizationNode 
											  FROM [HumanResources].[Employee] emp
												inner join
												[Person].[Person] pp
												ON emp.[BusinessEntityID] = pp.[BusinessEntityID]
											 where pp.FirstName = 'Peter'
											 and pp.LastName = 'Krebs')

SELECT *, OrganizationNode.ToString() AS NodeIdPath, dbo.fnGetFullDisplayPath(OrganizationNode) AS NodeIdDisplayPath
 FROM [HumanResources].[Employee]
 WHERE OrganizationNode.IsDescendantOf(@PeterOrganizationNode) = 1
 ORDER BY NodeIdDisplayPath

--f. what is the name of the manager for employee 5 (Gail)
declare @GailEmployeeId hierarchyid = (SELECT OrganizationNode 
											  FROM [HumanResources].[Employee] emp
												inner join
												[Person].[Person] pp
												ON emp.[BusinessEntityID] = pp.[BusinessEntityID]
											 where pp.FirstName = 'Gail'
											 and pp.BusinessEntityID = '5')

declare @GailAncestor hierarchyid = (select @GailEmployeeId.GetAncestor(1))
SELECT pp.FirstName, pp.LastName,
	[OrganizationNode].ToString() AS NodeIdPath,
	dbo.fnGetFullDisplayPath([OrganizationNode]) AS NodeIdDisplayPath
FROM [HumanResources].[Employee] emp
inner join
[Person].[Person] pp
ON emp.[BusinessEntityID] = pp.[BusinessEntityID]
WHERE OrganizationNode= @GailAncestor
ORDER BY NodeIdDisplayPath

--g. how many levels of heirarcy are in the company?
--4 levels

--3 write a script that shows:
-- employee names - first and lastnames
-- how many employees under each employee (subordinates)

Declare @OrganizationNode hierarchyid, @fname varchar(20), @lname varchar(20)
declare @counter int = 0
declare @total int = ((select count(OrganizationLevel) from [HumanResources].[Employee]) - 1)
declare @levels int = (select max(OrganizationLevel) from [HumanResources].[Employee])
Declare MycursorOuter cursor
for SELECT  emp.OrganizationNode,  pp.FirstName, pp.LastName
	FROM [HumanResources].[Employee] emp
	inner join
	[Person].[Person] pp
	ON emp.[BusinessEntityID] = pp.[BusinessEntityID]
open MycursorOuter
Fetch next from MycursorOuter into @OrganizationNode, @fname , @lname
while @@FETCH_STATUS=0
begin
		SELECT @counter = count(*)
		FROM [HumanResources].[Employee]
		WHERE OrganizationNode.IsDescendantOf(@OrganizationNode)=1

		if @fname = 'Ken' and @lname = 'Sánchez'
			 Print '#subordinates for '+@fname+' '+@lname+ ' are: '+cast(@total as char(10))
		else
			Print '#subordinates for '+@fname+' '+@lname+ ' are: '+cast(@counter as char(10))

Fetch next from MycursorOuter into @OrganizationNode, @fname , @lname
end 
close MycursorOuter
Deallocate MycursorOuter


--4. add 4 new columns to employees table to show the following:
--a. rank of employee

alter TABLE [dbo].[Employee]
add	[rank] AS (nodeid.GetLevel())
--b. fnGetFullDisplayPath
alter TABLE [dbo].[Employee]
add	[FullDisplayPath] AS (dbo.fnGetFullDisplayPath(nodeid))
--c. manager name
alter TABLE [dbo].[Employee]
add	[DirectManager] AS (nodeid.GetAncestor(1))
--e. manager of manager name
alter TABLE [dbo].[Employee]
add	[ParentDirectManager] AS (nodeid.GetAncestor(2))

--5 create publish file from answers from question 4
--EmployeeComputedcolumns.publish


--6. updates
--a. Peter Krebs no longer works in the company. 
--   need to move all of employees under him to David Lui.
--********should work but dosn't*******************
-- Move the entire subtree beneath Peter to a new location beneath David 0x7AC0
DECLARE @OldParentNodeId hierarchyid = (SELECT OrganizationNode 
										FROM [HumanResources].[Employee] emp
												inner join
												[Person].[Person] pp
												ON emp.[BusinessEntityID] = pp.[BusinessEntityID]
										where pp.FirstName = 'Peter'
										and pp.LastName = 'Krebs') 
-- Move Peter's tree to under David 0x85A0
DECLARE @NewParentNodeId hierarchyid = (SELECT OrganizationNode 
										FROM [HumanResources].[Employee] emp
												inner join
												[Person].[Person] pp
												ON emp.[BusinessEntityID] = pp.[BusinessEntityID]
										where pp.FirstName = 'David'
										and pp.LastName = 'Liu')
UPDATE [HumanResources].[Employee]
 SET   OrganizationNode = OrganizationNode.GetReparentedValue(@OldParentNodeId, @NewParentNodeId)
 WHERE OrganizationNode.IsDescendantOf(@OldParentNodeId) = 1 
 AND OrganizationNode <> @OldParentNodeId -- Excludes Peter himself

 --*****************gives error because Guy (0x85AB58) has 2 managers Jo and Deborah
SELECT *, OrganizationNode.ToString() AS NodeIdPath, 
      dbo.fnGetFullDisplayPath(OrganizationNode) AS NodeIdDisplayPath
 FROM [HumanResources].[Employee]
 where [OrganizationNode] = 0x85AB58
 ORDER BY NodeIdDisplayPath

DECLARE @ParentEmployeeNodeId hierarchyid =(SELECT [OrganizationNode].GetAncestor(1) 
FROM [HumanResources].[Employee] WHERE [OrganizationNode] = 0x85AB58)
SELECT pp.FirstName
		 FROM [HumanResources].[Employee] emp inner join [Person].[Person] pp
		 ON emp.[BusinessEntityID] = pp.[BusinessEntityID]
		 WHERE isnull([OrganizationNode],0x) = @ParentEmployeeNodeId

 --b. create proc that receives details and adds new employee to the company
 --   need to update tables for FK
   
 exec dbo.insertNewEmployee 5, '992457891','Designer', '1959-03-11', 'M', 'F', 1, 88, 60, 1,'Sari', 'Gross'

 SELECT *, OrganizationNode.ToString() AS NodeIdPath, 
      dbo.fnGetFullDisplayPath(OrganizationNode) AS NodeIdDisplayPath
 FROM [HumanResources].[Employee]
 where [OrganizationNode] = 0x5ADAB0
 ORDER BY NodeIdDisplayPath

go
alter Procedure dbo.insertNewEmployee(@ParentEmployeeId int, @NationalIDNumber nvarchar(15),
										@JobTitle nvarchar(50), @BirthDate date, 
										@MaritalStatus nchar(1), @Gender nchar(1),
										@SalariedFlag bit, @VacationHours smallint,
										@SickLeaveHours smallint, @CurrentFlag bit,
										@EmployeeFirstName nvarchar(50), @EmployeeLastName nvarchar(50))
 AS  
BEGIN

		declare @BusinessEntityID int, @LoginID nvarchar(256), @EmployeeNodeId hierarchyid, 
		        @newGUID uniqueidentifier, @ParentEmployeeNodeId hierarchyid, @LastChildNodeId hierarchyid
		set @LoginID = 'adventure-works\'+@EmployeeFirstName+'0'
		-- Get the hierarchyid of the parent employee
		set @ParentEmployeeNodeId = (SELECT OrganizationNode 
									 FROM [HumanResources].[Employee] 
									 WHERE BusinessEntityID = @ParentEmployeeId)

		-- Get the hierarchyid of the last existing child beneath the parent
		set @LastChildNodeId = (SELECT MAX(OrganizationNode) 
							FROM [HumanResources].[Employee] 
							WHERE OrganizationNode.GetAncestor(1) = @ParentEmployeeNodeId)

		-- Construct a new hierarchyid positioned at the end of any existing children
		set @EmployeeNodeId = @ParentEmployeeNodeId.GetDescendant(@LastChildNodeId, NULL)
		set @newGUID    = NewID()

		--insert @newGUID into FK table for new employee
		INSERT INTO [Person].[BusinessEntity]
				   ([rowguid],[ModifiedDate])
			 VALUES
				   (@newGUID, getdate());
		set @BusinessEntityID = (select BusinessEntityID 
								 from [Person].[BusinessEntity]
								 where rowguid = @newGUID)

		--insert into [Person].[Person]
		INSERT INTO [Person].[Person]
           ([BusinessEntityID],[PersonType],[NameStyle],[Title] ,[FirstName] ,[MiddleName]
           ,[LastName],[Suffix],[EmailPromotion],[AdditionalContactInfo],[Demographics]
           ,[rowguid],[ModifiedDate])
        VALUES
           (@BusinessEntityID, 'EM', 0, '', @EmployeeFirstName, '', @EmployeeLastName, '',0,
           '', '',NewID(),getdate())

		--insert new employee
		INSERT INTO [HumanResources].[Employee]
				   ([BusinessEntityID], [NationalIDNumber],[LoginID],[OrganizationNode],[JobTitle]
				   ,[BirthDate],[MaritalStatus],[Gender],[HireDate],[SalariedFlag],[VacationHours]
				   ,[SickLeaveHours],[CurrentFlag],[rowguid],[ModifiedDate])
			 VALUES
				   (@BusinessEntityID, @NationalIDNumber, @LoginID, @EmployeeNodeId, @JobTitle, 
					@BirthDate, @MaritalStatus, @Gender, getDate(), @SalariedFlag, @VacationHours, 
					@SickLeaveHours, @CurrentFlag,  NewID(), getDate());

END 
GO




create FUNCTION dbo.fnGetRequestedDisplayPath(@ParentEmployeeNodeId hierarchyid, @Depth smallint, @LevelCounter smallint) RETURNS varchar(max) 
 AS 
BEGIN
    -- Start with the specified node
	DECLARE @DisplayPath varchar(max)
	--check if null, if so replace with 0
	--@depth = level of hierarchy
	--@DisplayPath = name of person 
	--@EmployeeNodeId = hierarchyid of employee
	--@ParentEmployeeName = manager name
	set @ParentEmployeeNodeId = isnull(@ParentEmployeeNodeId,0x)
	SELECT @DisplayPath = pp.FirstName
	 FROM [HumanResources].[Employee] emp inner join [Person].[Person] pp
	 ON emp.[BusinessEntityID] = pp.[BusinessEntityID]
	 WHERE isnull([OrganizationNode],0x) = @ParentEmployeeNodeId

    -- Loop through all its ancestors
	set @LevelCounter = isnull(@LevelCounter,0)
	WHILE @LevelCounter < @Depth BEGIN
		SET @LevelCounter += 1

		-- Get employee node ID
		DECLARE @EmployeeNodeId hierarchyid = (select @ParentEmployeeNodeId.GetDescendant(null, NULL))

		-- Get employee name
		DECLARE @EmployeeName varchar(max) =
		 (SELECT pp.FirstName
		 FROM [HumanResources].[Employee] emp inner join [Person].[Person] pp
		 ON emp.[BusinessEntityID] = pp.[BusinessEntityID]
		 WHERE isnull([OrganizationNode],0x) = @EmployeeNodeId)

		-- Prepend to display path
		SET @DisplayPath =   @DisplayPath+ ' > '+@EmployeeName
	END
 
	RETURN(@DisplayPath)
END 
GO


declare @ParentEmployeeNodeId hierarchyid = (SELECT emp.[OrganizationNode] fROM [HumanResources].[Employee] emp
												inner join
												[Person].[Person] pp
												ON emp.[BusinessEntityID] = pp.[BusinessEntityID]
											 where pp.FirstName = 'Brian'
											 and pp.LastName = 'Welcker')
SELECT *
	 FROM [HumanResources].[Employee] emp inner join [Person].[Person] pp
	 ON emp.[BusinessEntityID] = pp.[BusinessEntityID]
	 WHERE isnull([OrganizationNode],0x) = (SELECT emp.[OrganizationNode]
							 				 FROM
												[HumanResources].[Employee] emp
												inner join
												[Person].[Person] pp
												ON emp.[BusinessEntityID] = pp.[BusinessEntityID]
											 where pp.FirstName = 'Brian'
											 and pp.LastName = 'Welcker')

DECLARE @EmployeeNodeId hierarchyid = (select @ParentEmployeeNodeId.GetDescendant(null, NULL))