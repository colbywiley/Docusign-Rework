public with sharing class SW_ContractAndFormToolbarController {
    private static final String CONTRACT_COMPLETE  = 'Complete';
    private static final String PROVIDER_SMART     = 'Smartwaiver';
    private static final String PROVIDER_DOCU      = 'DocuSign';

    /**
     * Idempotent:
     * - If contract not Complete OR already retrieved => no-op
     * - If provider = DocuSign => fetch documents now and mark retrieved
     * - If provider = Smartwaiver => no-op (webhook/Flow handles PDF + file attach)
     */
    @AuraEnabled
    public static void getContract(Id contractId) {
        try {
            TREX1__Contract_And_Form__c contract = [
                SELECT Id,
                       Name,
                       TREX1__Third_Party_Envelope_Id__c,
                       TREX1__Status__c,
                       Signed_Contract_Retrieved__c,
                       TREX1__Template_Id__c
                FROM TREX1__Contract_And_Form__c
                WHERE Id = :contractId
                LIMIT 1
            ];

            if (contract == null) return;

            // Nothing to do if not complete yet OR already retrieved
            if (contract.TREX1__Status__c != CONTRACT_COMPLETE ||
                contract.Signed_Contract_Retrieved__c) {
                return;
            }

            // Determine provider (default to DocuSign for backward compatibility)
            String provider = PROVIDER_DOCU;
            if (contract.TREX1__Template_Id__c != null) {
                TREX1__Contract_Or_Form_Template__c tmpl = [
                    SELECT Id, Waiver_Provider__c
                    FROM TREX1__Contract_Or_Form_Template__c
                    WHERE Id = :contract.TREX1__Template_Id__c
                    LIMIT 1
                ];
                if (tmpl != null && String.isNotBlank(tmpl.Waiver_Provider__c)) {
                    provider = tmpl.Waiver_Provider__c;
                }
            }
            Boolean isSmart = provider.equalsIgnoreCase(PROVIDER_SMART);

            if (!isSmart) {
                // === DocuSign branch (original behavior) ===
                Docusign ds = new Docusign(
                    contract.Id,
                    contract.TREX1__Third_Party_Envelope_Id__c,
                    '',          // action
                    null,        // templateIds
                    null,        // currentContact
                    ''           // return URL (not needed here)
                );
                insert ds.getEnvelopeDocuments();

                contract.Signed_Contract_Retrieved__c = true;
                update contract;

                ds.upsertAccessTokenSetting();
                return;
            }

            // === Smartwaiver branch ===

            return;

        } catch (Exception ex) {
            throw new DocusignContractAndFormToolbarControllerException(ex.getMessage());
        }
    }

    public class DocusignContractAndFormToolbarControllerException extends Exception {}
}
