/**
 * DocusignRetrieveCompletedContractBatch
 * @description Retrieves completed contracts
 * @author Thomas Tran, Traction on Demand
 * @date 02-4-2017
 */
global with sharing class DocusignRetrieveCompletedContractBatch extends DocusignBatchable implements Database.AllowsCallouts, Database.Stateful, Schedulable  {
	public static final String TAG = DocusignRetrieveCompletedContractBatch.class.getName();
	public static final Integer RECOMMENDED_BATCH_SIZE = 1;
	public static final String JOB_NAME                = 'Docusign Retrieve Completed Contract';
    private static final Integer DS_API_CALLOUT_LIMIT = 1000;
    private Boolean hasExceedAPILimits = false;

	global DocusignRetrieveCompletedContractBatch() {
		this.batchSize = RECOMMENDED_BATCH_SIZE;
        this.isSchedulable = true;
        this.className = 'DocusignRetrieveCompletedContract';
	}

	global override Integer getQueryCount() {
        return Database.countQuery('SELECT count() FROM TREX1__Contract_and_Form__c WHERE TREX1__Type__c = \'Docusign Form\' AND  TREX1__Third_Party_Envelope_Id__c != null AND TREX1__Status__c = \'Complete\' AND Signed_Contract_Retrieved__c = false');
    }

    public override Database.QueryLocator start(Database.BatchableContext BC) {
        Integer resultCount = getQueryCount();

        if(resultCount > DS_API_CALLOUT_LIMIT) {
            hasExceedAPILimits = true;
        }

        return Database.getQueryLocator('SELECT TREX1__Third_Party_Envelope_Id__c FROM TREX1__Contract_and_Form__c WHERE TREX1__Type__c = \'Docusign Form\' AND TREX1__Third_Party_Envelope_Id__c != null AND TREX1__Status__c = \'Complete\' AND Signed_Contract_Retrieved__c = false LIMIT 1001');
    }

    public override void execute(Database.BatchableContext BC, List<SObject> scope) {
        for(TREX1__Contract_and_Form__c form : (List<TREX1__Contract_and_Form__c>) scope){
            Docusign ds = new Docusign(form.Id, form.TREX1__Third_Party_Envelope_Id__c, '', null, null, '');
        	Database.insert(ds.getEnvelopeDocuments());
            
            form.Signed_Contract_Retrieved__c = true;
            Database.update(form);
            ds.upsertAccessTokenSetting();
        }
    }

    public override void finish(Database.BatchableContext BC){
        if(hasExceedAPILimits) {
            TREX1__Error__c errorLog = new TREX1__Error__c(
                TREX1__Exception__c = 'HOURLY_APIINVOCATION_LIMIT_EXCEEDED. The maximum number of hourly API invocations has been exceeded. The hourly limit is 1000.',
                TREX1__Message__c = 'Please wait until the start of the next hour to run the Docusign Retrieve Completed Contract Batch Job.',
                TREX1__Type__c = 'Error Log'
            );

            insert errorLog;
        }
    }
}