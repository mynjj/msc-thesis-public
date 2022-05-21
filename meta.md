# Project

## Formal requirements

### Links with information
- Exam Registration: https://itustudent.itu.dk/Study-Administration/Exams/Registration
  Consulted in "My study activities"
- Submission Deadlines: https://itustudent.itu.dk/Study-Administration/Exams/Submission-Deadlines
  They list the following deadlines at 14:00 (they are under Bsc and thesis, are they valid?):
    . Ordinary exam: June 1 2022
    . Re-exam (1st): September 1 2022
    . Re-exam (2nd): December 1 2022
- Register for the Project: https://itustudent.itu.dk/study-administration/project-work/register-for-the-project
  Register in "My Study Activities", fill in the "Project Agreement" in "Project base", complete with supervisors approval and submit.
  Other FAQ on project title and diploma (can be changed until hand in)
  Deadline for agreement: Friday in week 5/35 until 23:59 (that is 04 Feb)
- Submitting Written Work: https://itustudent.itu.dk/Study-Administration/Exams/Submitting-written-work
  Where/when to upload, guidelines on how it must be structured, FAQ

### Reference links
- Project base: https://mit.itu.dk/ucs/pb/index.sml
- My study activities: http://minestudieaktiviteter.itu.dk/

### Project agreement

#### Problem formulation
Industrial software development increasingly relies on regression test suites to ensure that the functionality that customers depend on remain unchanged when introducing new changes. Such practice increases the confidence of developers in the correctness of their changes, allowing a software system to continue evolving.

However, on large codebases, efficiency becomes an important factor when running these test suites, since they can be prohibitively large and expensive to execute. Moreover, many tests may not be relevant to catch potential errors and just increase the burden on the test execution. For this reason, extensive research has been conducted, both to reduce the execution burden and to determine which tests should be a priority to run.

For this project, we will explore test selection algorithms on the application codebase of Microsoft's Business Central (Dynamics NAV). The goal is to reduce the number of tests executed on their CI pipeline while maintaining an acceptable level of confidence. 

#### Method
We will conduct an unstructured literature review on a subset of test selection techniques, to get the information requirements that we need to extract from the codebase for each of these techniques.

Work from the previous research project obtained test coverage information. We plan to use and incorporate it with the technique to explore.

Some techniques from literature require a specific representation of their input information. We will work on acquiring such representation of the collected information.

The research project showed that the representation of differences within each revision of the codebase can produce useful parameters. We plan to expand on this according to the selection method proposed.

Finally, an important enabler of our project is the integration with the existing infrastructure to collect the required information for our algorithm as well as for the evaluation of the method. To achieve this, work on the modifications to the CI pipeline is in scope.

#### What will be handed in
- Report with the description of each stage, evaluation, and analysis of the results.
- Open source code used on the different stages of the project.

## Project workflow
Going forward with supervisions, quick status meetings + weekly plannings of 1 h

Meetings booked on outlook (Room 4F20)

	
## General research project content
As ITU's guidelines:
- I: Identify and delimit an IT problem (Introduction/Background)
- L: Identify means for solving it, literature reviews, etc. (Related work)
- A: Combine selected means and develop further towards the solution (Method)
- E: Evaluate the achieved solution (Evaluation)
- R: Report all of it
- F: Reflect upon approach results and findings (Conclusion)


## Project specific outline
- Test Selection Algorithms (L, A, R)
  - Input representation (transformations)
- Diff representation (A, L, R)
- Infrastructure (I, E, A, R)
  - Pipeline infrastructure
  - Information collection process

### Test Selection Algorithms
What is the target implementation we should be aiming to. This can determine which kind of information we need to collect, changing Infrastructure requirements or 

### Infrastructure
Integrating with the existing infrastructure. To streamline evaluation or for algorithms that require training 

#### Pipeline infrastructure
Integrating into the pipeline 

#### Information collection process
How is information to be collected

### Diff representation
Extracting properties of the changes on the codebase

	
		
		
