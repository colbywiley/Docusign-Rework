global abstract class DocusignBatchable implements Database.Batchable<sObject>, Schedulable {

    private static final Set<String> ACTIVE_STATUSES = new Set<String>{ 'Queued', 'Processing', 'Preparing', 'Holding' };

    protected Boolean isSchedulable = false;
    protected String jobName;
    protected String cronExpression;
    protected String className;
    protected Integer batchSize;
    protected String jobId;

    /**
     * @description Schedules the job to run.
     */
    global void schedule() {
        if (!isSchedulable) {
            throw new DocusignBatchableException('This batch job is not schedulable in the current configuration');
        }

        if (Test.isRunningTest()) { 
            System.schedule(jobName + ' test', cronExpression, this);    
        } else {
            System.schedule(jobName, cronExpression, this);    
        }
    }

    /**
     * Called by the system on a schedule
     */
    public void execute(SchedulableContext sc){
        jobId = sc.getTriggerId();
        run();
    }

    /**
     * @return The active AsyncApexJobs with the same class name
     */
    global List<AsyncApexJob> getActiveJobs() {
        return [
            SELECT Id
            FROM AsyncApexJob
            WHERE JobType = 'ScheduledApex' AND ApexClass.Name = :className AND Status IN :ACTIVE_STATUSES
        ];
    }

    /**
     * @return True if this batch job is currently running
     */
    global Boolean isRunning() {
        return getActiveJobs().size() > 0;
    }

    /**
     * Executes this batch job with the recommended batch size if the job is not currently running
     * @return The ID of new batch job (AsyncApexJob)
     */
    global Id safeRun() {
        return safeRun(batchSize);
    }

    /**
     * Executes this batch job if the job is not currently running
     * @param batchSize Number of records to be passed into the execute method for batch processing
     * @return The ID of new batch job (AsyncApexJob)
     */
    global Id safeRun(Integer batchSize) {
        Id newJobId = null;
        if( !isRunning() ) {
            newJobId = run(batchSize);
        }
        return newJobId;
    }

    /**
     * Executes this batch job with the recommended batch size
     * @return The ID of new batch job (AsyncApexJob)
     */
    global Id run() {
        return run(batchSize);
    }

    /**
     * Executes this batch job
     * @param batchSize Number of records to be passed into the execute method for batch processing
     * @return The ID of new batch job (AsyncApexJob)
     */
    global Id run(Integer batchSize) {
        return Database.executeBatch(this, batchSize);
    }

    /**
     * @return The number of records that satisfy this batch's query (batch size)
     */
    global abstract Integer getQueryCount();

    public virtual Database.QueryLocator start(Database.BatchableContext BC) { return null; }

    public virtual void execute(Database.BatchableContext BC, List<sObject> scope) {}

    public virtual void finish(Database.BatchableContext BC) {}

    public class DocusignBatchableException extends Exception {}
}