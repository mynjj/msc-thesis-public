# CI Stats

Visualization tools and scripts for collecting data of the CI pipeline executions.

## Questions
From a given set of CI pipeline jobs:
- How many failed?
- From those that failed, how many were due to an AppTest task?
- What's the distribution between categories of AppTest tasks?
- For each AppTest category what's the distribution of tasks/failures?
- What's the distribution of tasks and dependency chains for each?

**Which set of test tasks should we choose for collecting its data?**
Considerations:
- Changes for `AL Test Runner` Category of AppTest tasks are ready for collection
- Dependency chain for task execution should be shared for increased validity

## Cmdlets provided
`Start-CIStatsCollection`