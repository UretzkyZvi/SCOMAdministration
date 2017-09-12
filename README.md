# SCOM Administration Add-Ons

Management Pack was created by Uretzky Zvi to make daily job of SCOM administrator easier.

At the beginning, I have tried to solve a problem that I’m sure many of SCOM administrator’s familiar with; In every company once in a while disaster happens and the first question to be is which servers were affected from this disaster? Unfortunately, the answer to this question is not accurate, yes, I know there is a monitor “Failed to connect to computer” that raised when the agent stops sending heartbeat for 3 seconds (default) and not answer to a ping from Management Server it is a great monitor, but what about agents that had a problem before the disaster (like service is down or data corrupted or even been deleted from the server), monitor “Failed to connect to computer” won’t raise for those agents and therefore the answer to this simple question is not accurate.
There are several solutions for this problem like checking ping 24X7 for a static list of servers, personally I does not agree with this solution, this why I decided to create a new solution and it based on SQL query and ping check for only those servers that return from SQL result. I will explain, I created a rule that schedule to run every 5 minutes, it is executes a query which return only agents that follow those two conditions; 1. Agent have error in heartbeat monitor (network problem, server down, HealthService stopped or HealthService data corrupted). 2. Agent is not in Maintenance Mode.
For each agent that return from the query, I execute a check ping task from agent primary management server, task data I save in Operations Manager DB as event.
Now, I can write a report that will show the exact affected servers.
After I solved this problem, I had another idea, if I know the unhealthy agent ping status why not to try repair them, so I develop another rule that schedule to run every 12 hours, it is responsible for analyze agent ping status and execute the necessary task to repair the agent. If status is 0, it means the sever answer to ping and the problem is with agent, so I will execute Restart Agent task. If status is 14, it means the ping answer was bad address, so I execute delete agent from SCOM task.
It all fun but about agents that stopped collect performance data from not understandable reason.
I created another rule that schedule to run every 12 hours, it executes a query to get all agents that not in MM and with heartbeat monitor ok, for each return agent I execute Flush agent task.
In the future, I will add more cool rules and tasks to this MP, so be updated 😊 
If you use this and you like it, invite me to a coffee :-)

Bitcoin Address: 1HPXi5M38F9zCtp1nciaGc15JdR48DrgVv

Ethereum Address: 0x6a34dab1c1e655bb1fab6279204c3eb4ea840e48
