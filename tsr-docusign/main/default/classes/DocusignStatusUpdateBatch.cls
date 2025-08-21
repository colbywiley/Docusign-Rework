/**
 * DocusignStatusUpdateBatch
 * @description Updates contracts based on results returned from the callout
 * @author Thomas Tran, Traction on Demand
 * @date 02-4-2017
 */
global class DocusignStatusUpdateBatch extends DocusignBatchable implements Database.AllowsCallouts, Database.Stateful  {
	public static final String TAG = DocusignStatusUpdateBatch.class.getName();
	private static final String STATUS_COMPLETE = 'Complete';
	public static final Integer RECOMMENDED_BATCH_SIZE = 50;
	public static final Integer RECOMMENDED_INCREMENT  = 20;
	public static final String JOB_NAME                = 'Docusign Status Update';

    global DocusignStatusUpdateBatch() {
        this.jobName = JOB_NAME;
        this.batchSize = RECOMMENDED_BATCH_SIZE;
        this.isSchedulable = true;
        this.className = 'DocusignStatusUpdateBatch';
    }

    global override Integer getQueryCount() {
        return Database.countQuery('SELECT count() FROM TREX1__Contract_and_Form__c WHERE TREX1__Type__c = \'Docusign Form\' AND TREX1__Status__c = \'Sent\' AND TREX1__Third_Party_Envelope_Id__c != null AND LastModifiedDate = LAST_N_DAYS:30');
    }

    public override Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator('SELECT TREX1__Third_Party_Envelope_Id__c FROM TREX1__Contract_and_Form__c WHERE TREX1__Type__c = \'Docusign Form\' AND TREX1__Status__c = \'Sent\' AND TREX1__Third_Party_Envelope_Id__c != null AND LastModifiedDate = LAST_N_DAYS:30');
    }

    public override void execute(Database.BatchableContext BC, List<SObject> scope) {
    	String envelopeIds = '';
    	Set<String> completedEnvelopeIds = new Set<String>();
    	List<TREX1__Contract_and_Form__c> formsToUpdate = new List<TREX1__Contract_and_Form__c>();

        for(TREX1__Contract_and_Form__c form : (List<TREX1__Contract_and_Form__c>) scope){
            if(String.isNotBlank(envelopeIds)) {
                envelopeIds += ',' + form.TREX1__Third_Party_Envelope_Id__c;
            } else {
                envelopeIds += form.TREX1__Third_Party_Envelope_Id__c;
            }
        }

        if(String.isNotBlank(envelopeIds)){
            Docusign ds = new Docusign();
        	completedEnvelopeIds.addAll(ds.getListOfEnvelopeBasedOnStatus(envelopeIds, 'Completed'));

	        for(TREX1__Contract_and_Form__c form : (List<TREX1__Contract_and_Form__c>) scope){
	        	if(completedEnvelopeIds.contains(form.TREX1__Third_Party_Envelope_Id__c)){
	        		form.TREX1__Status__c = STATUS_COMPLETE;
	        		form.TREX1__Has_Been_Signed__c = true;
                    form.TREX1__Date_Signed__c = Date.today();

	        		formsToUpdate.add(form);
	        	}
	        }

	        if(!formsToUpdate.isEmpty()){
				Database.update(formsToUpdate, false);
			}
            
            ds.upsertAccessTokenSetting();
        }
    }

    public override void finish(Database.BatchableContext BC){
        DocusignStatusUpdateBatch batch = new DocusignStatusUpdateBatch();

        DateTime futureDateTime = (Datetime.now()).addMinutes(RECOMMENDED_INCREMENT);
        String hour = String.valueOf(futureDateTime.hour());
        String minute = String.valueOf(futureDateTime.minute());
        String month = String.valueOf(futureDateTime.month());
        String day = String.valueOf(futureDateTime.day());
        String year = String.valueOf(futureDateTime.year());
        String nextFire = '0 ' + minute + ' ' + hour + ' ' + day + ' ' + month + ' ?' + ' ' + year;
        batch.cronExpression = nextFire;

    	if(!isRunning() && !Test.isRunningTest()){
            if(String.isNotBlank(this.jobId)){
                System.abortJob(this.jobId);
            }
    		batch.schedule();
    	}
    }
}