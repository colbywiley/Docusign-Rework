public with sharing class DocusignContractAndFormToolbarController {
    private static final String CONTRACT_COMPLETE  = 'Complete';
    private static final String PROVIDER_SMART     = 'Smartwaiver';
    private static final String PROVIDER_DOCU      = 'DocuSign';

    @AuraEnabled
    public static void getContract(Id contractId) {
        try {
            TREX1__Contract_And_Form__c contract = [
                SELECT Id, Name, TREX1__Third_Party_Envelope_Id__c, TREX1__Status__c, Signed_Contract_Retrieved__c, TREX1__Template_Id__c
                FROM TREX1__Contract_And_Form__c
                WHERE Id = :contractId
                LIMIT 1
            ];

            if (contract == null) return;

            if (contract.TREX1__Status__c != CONTRACT_COMPLETE || contract.Signed_Contract_Retrieved__c) {
                // Nothing to do (either not complete yet, or already retrieved)
                return;
            }

            // Determine provider from the template (default to DocuSign if blank)
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
                Docusign ds = new Docusign(contract.Id, contract.TREX1__Third_Party_Envelope_Id__c, '', null, null, '');
                insert ds.getEnvelopeDocuments();

                contract.Signed_Contract_Retrieved__c = true;
                update contract;

                ds.upsertAccessTokenSetting();
                return;
            }

            // === Smartwaiver branch ===
            if (String.isBlank(contract.TREX1__Third_Party_Envelope_Id__c)) {
                // WaiverId not yet stored. Webhook/processor may not have finished.
                throw new DocusignContractAndFormToolbarControllerException(
                    'Waiver is complete but the waiver ID has not been recorded yet. Try again in a moment or verify webhook processing.'
                );
            }

            // GET /waivers/{waiverId}?pdf=true via Named Credential
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint('callout:Smartwaiver_Named_Credential/waivers/' + contract.TREX1__Third_Party_Envelope_Id__c + '?pdf=true');
            HttpResponse resp = new Http().send(req);
            if (resp.getStatusCode() != 200) {
                throw new DocusignContractAndFormToolbarControllerException('Smartwaiver PDF fetch failed: ' + resp.getStatus() + ' - ' + resp.getBody());
            }

            Map<String,Object> root = (Map<String,Object>)JSON.deserializeUntyped(resp.getBody());
            Map<String,Object> waiver = (Map<String,Object>)root.get('waiver');
            if (waiver == null || waiver.get('pdf') == null) {
                throw new DocusignContractAndFormToolbarControllerException('Smartwaiver response missing PDF.');
            }

            String pdfB64 = (String)waiver.get('pdf');
            Blob pdfBlob = EncodingUtil.base64Decode(pdfB64);

            // Save file as ContentVersion on the contract
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Completed Smartwaiver Waiver';
            cv.PathOnClient = 'Completed_Smartwaiver_Waiver.pdf';
            cv.VersionData = pdfBlob;
            cv.FirstPublishLocationId = contract.Id;
            insert cv;

            contract.Signed_Contract_Retrieved__c = true;
            update contract;

        } catch (Exception ex) {
            throw new DocusignContractAndFormToolbarControllerException(ex.getMessage());
        }
    }

    public class DocusignContractAndFormToolbarControllerException extends Exception {}
}