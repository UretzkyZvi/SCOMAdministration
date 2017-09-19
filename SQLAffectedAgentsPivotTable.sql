
DECLARE @StartTime DateTime
DECLARE @EndTime DateTime

SET @StartTime =DATEADD(MINUTE, ((DATEPART(MINUTE,  GETUTCDATE()) / 5) * 5)-30, DATEADD(HOUR, DATEDIFF(HOUR, 0, GETUTCDATE()), 0))
SET @EndTime =  DATEADD(MINUTE, ((DATEPART(MINUTE,  GETUTCDATE()) / 5) * 5), DATEADD(HOUR, DATEDIFF(HOUR, 0, GETUTCDATE()), 0))

SELECT
	v.TimeGenerated
	,DATEADD(MINUTE, ((DATEPART(MINUTE, v.TimeGenerated) / 5) * 5), DATEADD(HOUR, DATEDIFF(HOUR, 0, v.TimeGenerated), 0)) AS TimeGeneratedFixed
	,EventParametersXML
	,y.Status
	,y.StatusCode
	,y.ResponseTime
	,y.AgentServerName
	,y.ManagementServerName
INTO #EventAllView
FROM EventAllView v
OUTER APPLY (SELECT
		CAST(v.EventParameters AS XML) AS EventParametersXML) x
OUTER APPLY (SELECT
		x.value('Param[1]', 'VARCHAR(80)') AS Status
		,x.value('Param[2]', 'VARCHAR(80)') AS StatusCode
		,x.value('Param[3]', 'VARCHAR(80)') AS ResponseTime
		,x.value('Param[4]', 'VARCHAR(80)') AS AgentServerName
		,x.value('Param[5]', 'VARCHAR(80)') AS ManagementServerName
	FROM x.EventParametersXML.nodes('/') AS NodeValues (x)) y
WHERE
PublisherName = 'ServerConnectivityCheck'
AND TimeGenerated >= @StartTime
AND DATEADD(MINUTE, DATEDIFF(MINUTE, 0, TimeGenerated), 0) <= @EndTime

;WITH TimesCTE ([Date])
AS 
(
	SELECT
	@StartTime 
	UNION ALL 
	SELECT DATEADD(MINUTE, 5, [Date]) FROM TimesCTE WHERE [Date] < @EndTime
)
SELECT
res.AgentServerName,
res.[Date],
v.TimeGenerated,
v.Status,
v.StatusCode,
v.ResponseTime,
v.ManagementServerName into #tmpPivot
FROM
(
	SELECT
	srv.AgentServerName,
	c.[Date]
	FROM
	(
		SELECT DISTINCT AgentServerName FROM #EventAllView
	) srv
	CROSS APPLY
	(
		SELECT [Date] FROM TimesCTE
	) c	
) res
JOIN
#EventAllView v
	ON DATEADD(MINUTE, ((DATEPART(MINUTE, v.TimeGenerated) / 5) * 5), DATEADD(HOUR, DATEDIFF(HOUR, 0, v.TimeGenerated), 0)) = res.[Date]
	AND v.AgentServerName = res.AgentServerName
ORDER BY
res.AgentServerName,
res.[Date]


DECLARE @CMD VARCHAR(MAX)
SET @CMD = 'SELECT * FROM (SELECT AgentServerName, StatusCode, CONVERT(VARCHAR(80), DATEADD(HOUR, (DATEDIFF(HOUR, GETUTCDATE(), GETDATE())), [Date]), 108) AS [Date] FROM #tmpPivot) AS SourceTable PIVOT (MAX(StatusCode) FOR [Date] IN ('

SET @CMD = @CMD + (
       SELECT
       LEFT(txt.grouped, LEN(txt.grouped) - 1)
       FROM
       (
              SELECT
              '[' + CONVERT(VARCHAR(80), DATEADD(HOUR, (DATEDIFF(HOUR, GETUTCDATE(), GETDATE())), [Date]), 108) + '],' AS [text()]
              FROM
              #tmpPivot
              GROUP BY
              CONVERT(VARCHAR(80), DATEADD(HOUR, (DATEDIFF(HOUR, GETUTCDATE(), GETDATE())), [Date]), 108)
			  ORDER BY
			  CONVERT(VARCHAR(80), DATEADD(HOUR, (DATEDIFF(HOUR, GETUTCDATE(), GETDATE())), [Date]), 108)
              FOR XML PATH('')
       ) txt(grouped))

SET @CMD = @CMD + ')) AS PivotTable ORDER BY AgentServerName'

EXEC (@CMD)


DROP TABLE #EventAllView
DROP TABLE #tmpPivot