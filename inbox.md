
# TODO


Debug HPC resources
Features 


Assuming ranked dataset compute metrics:
Header:
**JobId** TimeToFirstFailure S10-NAPFD... Inclusiveness-S10 Inclusiveness-S20 ... SelectionExecutionTime-S10 ...

# Evaluation results
Metrics obtained per ranklib dataset, per model trained:
- Time to first failure
Per selection (10%, 20%, ... 90%, 100%)
- Inclusiveness
- Selection execution time
- nAPFD

What visualizations to report?
- Candlestick plot with nAPFD comparing methods (from best results? from several ranklib datasets)
- Candlestick plot with time to first failure comparing methods (from best results? from several ranklib datasets)
- safe methods w/ selection execution time 






# Backlog
- Collect mean time for each task on the test dependencies chain
  - Consider a score related to build time for comparison functions on pairwise algs
- Preselection for ensuring running e.g. new test cases
- q-learning
- Comparison with existing methods


# ..
Argue, why is it needed on the project to have automatic selection, and not relying on dev knowledge