# SCOM Administration Add-Ons

Management Pack was created by Uretzky Zvi to make his daily job easier 😊.

Once in awhile disaster happens and when it happens; the first question will be which servers were affected?, Unfortunately, the answer to this question is not accurate, yes, I know there is a monitor “Failed to connect to computer” that raised when the agent stops sending heartbeat for 3 seconds (default) and if it not answer Management Server send a ping to check connectivity. The issue raise when agents have a some kind of problem before the disaster such as service has been down or data was corrupted or even somehow the agent was deleted from the server). The monitor “Failed to connect to computer” will not raise for those agents. I’m sure many of SCOM administrator’s familiar with a problem.

My motivation to create this MP was to solve this problem.

My solution bases on SQL query and ping check.

I created a rule that schedule to run every 5 minutes (you can override it), it execute a query which return only agents that follow those two conditions 1. Agents with status error in heartbeat monitor (network problem, server down, HealthService stopped or HealthService data corrupted). 2. Agent is not in Maintenance Mode.

For each agent that return from the query, I execute a check ping task from agent’s primary management server, the task data publish to Operations Manager DB as event. This workflow make easy to answer on the question which servers were affected. Since we have agent status in real time all the time. Now by using simple SQL query we can get all the affected agents.

While I was working on this rule, I had another idea, and it was to try repair the unhealthy agent.

To repair those agents I created a rule that schedule to run every 12 hours (you can override it), this rule execute SQL query and return last sample for unhealthy agents and for each of them it analyze and execute necessary task to repair it. 
If agent’s ping status is 0 then the problem is within agent, therefore, the rule will execute the task Restart Agent. If agent’s ping status is 14 (bad address) then the problem is within SCOM environment and therefore execute the task Delete Agent from SCOM. 
For bonus :), I create a rule to repair agents that stopped collect performance data. The rule schedule to run every 12 hours, it is executes a SQL query that return healthy agent that didn’t wrote performance data more than 12 hours.For each return agent it execute task flush agent.

In the future, I will add more cool rules and tasks to this MP, So you should be updated 😊 

  If you use this MP and you like it, invite me to a coffee :-)
 
 Bitcoin Address: 1HPXi5M38F9zCtp1nciaGc15JdR48DrgVv
 
 Ethereum Address: 0x6a34dab1c1e655bb1fab6279204c3eb4ea840e48

## License

[License](https://github.com/UretzkyZvi/SCOMAdministration/blob/master/LICENSE)


# Quick Start - Usage
Please always test new management packs in a test environment before importing to production!

## Requirements
* SCOM 2012 R2 (earlier versions are untested)
* Microsoft SQL Management Packs.
* SCOM Admin rights (only Administrators can import management packs)
## Quick Start - Install
1. Download [SCOMAdministrationAddOns.xml](https://github.com/UretzkyZvi/SCOMAdministration/blob/master/SCOMAdministrationAddOns/bin/Debug/SCOMAdministrationAddOns.xml)
2. Import it in your SCOM environment/
3. Enjoy!!

