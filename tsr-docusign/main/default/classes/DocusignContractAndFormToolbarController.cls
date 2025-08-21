public with sharing class DocusignContractAndFormToolbarController {
    private static final String CONTRACT_COMPLETE  = 'Complete';

    @AuraEnabled
    public static void getContract(Id contractId) {
        try{
            TREX1__Contract_And_Form__c contract = [SELECT Id, TREX1__Third_Party_Envelope_Id__c, TREX1__Status__c FROM TREX1__Contract_And_Form__c WHERE Id = :contractId AND Signed_Contract_Retrieved__c = false];

            if(contract != null && contract.TREX1__Status__c.equals(CONTRACT_COMPLETE)) {
                Docusign ds = new Docusign(contract.Id, contract.TREX1__Third_Party_Envelope_Id__c, '', null, null, '');
                insert ds.getEnvelopeDocuments();

                contract.Signed_Contract_Retrieved__c = true;
                update contract;

                ds.upsertAccessTokenSetting();
            }
        } catch(Exception ex) {
            throw new DocusignContractAndFormToolbarControllerException(ex.getMessage());
        }
    }
    
    public class DocusignContractAndFormToolbarControllerException extends Exception {}
}