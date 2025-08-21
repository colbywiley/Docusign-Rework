/**
 * DocusignHandlerCtlr (Smartwaiver Edition)
 * Fully replaces DocuSign behavior with Smartwaiver while keeping method signatures identical.
 * - Email flow: creates a Smartwaiver URL and emails it to the signer; marks record Sent/Via Email.
 * - In-person flow: returns a Smartwaiver URL to open; marks record Sent/In Person.
 * - Manual PDF fetch: pulls waiver PDF by waiverId (stored post-webhook) and attaches as ContentVersion.
 *
 * Requirements:
 * - Named Credential: Smartwaiver_Named_Credential (points to https://api.smartwaiver.com/v4 and sends the API key)
 * - Templates: store Smartwaiver Template GUID in TREX1__Contract_Or_Form_Template__c.Third_Party_Template_Id__c
 * - Webhook: SW_WebhookService + SmartwaiverEventTrigger + SW_WebhookProcessor handle completion -> attach PDF & mark Complete
 */
public without sharing class DocusignHandlerCtlr {
    private static final String PL_CAPTURE_STATUS_IN_PERSON = 'In Person';
    private static final String PL_CAPTURE_STATUS_VIA_EMAIL = 'Via Email';
    private static final String CONTRACT_SENT               = 'Sent';
    private static final String CONTRACT_COMPLETE           = 'Complete';

    private static final TREX1__App_Config__c APP_CONFIG = TREX1__App_Config__c.getOrgDefaults();

    // --------------------------
    // Public API (unchanged)
    // --------------------------

    @AuraEnabled
    public static DocusignResult docusignEmail(String contractAndFormId){
        DocusignResult result = new DocusignResult();
        try {
            ContractData cd = getContractData(contractAndFormId);
            if (cd == null || cd.template == null) {
                throw new DocusignException('Template not found for contract.');
            }
            if (String.isBlank(cd.template.Third_Party_Template_Id__c)) {
                throw new DocusignException('Smartwaiver Template GUID is blank - check permissions and template config.');
            }
            if (cd.currentContact == null || String.isBlank(cd.currentContact.Email)) {
                throw new DocusignException('Signer email is required.');
            }

            String waiverUrl = buildSmartwaiverUrl(cd, (Id)contractAndFormId, false /*kiosk*/);

            // Send the email with the waiver link
            sendWaiverEmail(cd.currentContact, waiverUrl);

            // Mark as Sent (no envelope id yet; webhook will set waiver id later)
            upsert new TREX1__Contract_And_Form__c(
                Id = (Id)contractAndFormId,
                TREX1__Status__c = CONTRACT_SENT,
                TREX1__Capture_Status__c = PL_CAPTURE_STATUS_VIA_EMAIL
            );

            result.isSuccess = true;
            // Return URL for visibility/logging; UI doesn't need it (email was sent)
            result.result = waiverUrl;
        } catch (Exception ex) {
            result.isSuccess = false;
            result.errorMessage = ex.getMessage();
        }
        return result;
    }

    @AuraEnabled
    public static DocusignResult docusignSign(String contractAndFormId){
        DocusignResult result = new DocusignResult();
        try {
            ContractData cd = getContractData(contractAndFormId);
            if (cd == null || cd.template == null) {
                throw new DocusignException('Template not found for contract.');
            }
            if (String.isBlank(cd.template.Third_Party_Template_Id__c)) {
                throw new DocusignException('Smartwaiver Template GUID is blank - check permissions and template config.');
            }

            // Build Smartwaiver URL for immediate (in-person/on-screen) signing
            String waiverUrl = buildSmartwaiverUrl(cd, (Id)contractAndFormId, false /*kiosk or web*/);

            // Mark as Sent (no waiver id yet; webhook will set waiver id + attach PDF)
            upsert new TREX1__Contract_And_Form__c(
                Id = (Id)contractAndFormId,
                TREX1__Status__c = CONTRACT_SENT,
                TREX1__Capture_Status__c = PL_CAPTURE_STATUS_IN_PERSON
            );

            // Return the URL for the UI to open
            result.isSuccess = true;
            result.result = waiverUrl;
        } catch (Exception ex) {
            result.isSuccess = false;
            result.errorMessage = ex.getMessage();
        }
        return result;
    }

    @AuraEnabled
    public static DocusignResult docusignResend(String contractAndFormId){
        // Resend is same as sending the email again with the exact same Smartwaiver URL
        return docusignEmail(contractAndFormId);
    }

    /**
     * Manual on-demand PDF fetch (fallback). Normally the webhook + processor attach the PDF.
     * This pulls the waiver PDF by the waiverId (stored in TREX1__Third_Party_Envelope_Id__c post-webhook)
     * and attaches a ContentVersion to the contract record.
     */
    @AuraEnabled
    public static DocusignResult docusignPDF(String contractAndFormId){
        DocusignResult result = new DocusignResult();
        try {
            TREX1__Contract_And_Form__c c = [
                SELECT Id, Name, TREX1__Third_Party_Envelope_Id__c, TREX1__Status__c, Signed_Contract_Retrieved__c
                FROM TREX1__Contract_And_Form__c
                WHERE Id = :contractAndFormId
                LIMIT 1
            ];
            if (String.isBlank(c.TREX1__Third_Party_Envelope_Id__c)) {
                throw new DocusignException('No Smartwaiver Waiver ID found on the contract. Has the webhook processed this waiver yet?');
            }

            // Call Smartwaiver API: GET /waivers/{waiverId}?pdf=true
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint('callout:Smartwaiver_Named_Credential/waivers/' + c.TREX1__Third_Party_Envelope_Id__c + '?pdf=true');
            HttpResponse resp = new Http().send(req);
            if (resp.getStatusCode() != 200) {
                throw new DocusignException('Smartwaiver PDF fetch failed: ' + resp.getStatus() + ' - ' + resp.getBody());
            }
            Map<String,Object> root = (Map<String,Object>)JSON.deserializeUntyped(resp.getBody());
            Map<String,Object> waiver = (Map<String,Object>)root.get('waiver');
            if (waiver == null || waiver.get('pdf') == null) {
                throw new DocusignException('Smartwaiver response missing PDF.');
            }
            String pdfB64 = (String)waiver.get('pdf');
            Blob pdfBlob = EncodingUtil.base64Decode(pdfB64);

            // Save as ContentVersion (File) on the contract
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Completed Smartwaiver Waiver';
            cv.PathOnClient = 'Completed_Smartwaiver_Waiver.pdf';
            cv.VersionData = pdfBlob;
            cv.FirstPublishLocationId = c.Id;
            insert cv;

            // Mark retrieved if not already
            if (!c.Signed_Contract_Retrieved__c) {
                c.Signed_Contract_Retrieved__c = true;
                update c;
            }

            result.isSuccess = true;
        } catch (Exception ex) {
            result.isSuccess = false;
            result.errorMessage = ex.getMessage();
        }
        return result;
    }

    @AuraEnabled
    public static DocusignResult updateContractToSigned(String contractAndFormId){
        DocusignResult result = new DocusignResult();
        try{
            update new TREX1__Contract_And_Form__c(
                Id = (Id)contractAndFormId,
                TREX1__Has_Been_Signed__c = true,
                TREX1__Status__c = CONTRACT_COMPLETE
            );
            result.isSuccess = true;
        } catch (Exception ex) {
            result.isSuccess = false;
            result.errorMessage = ex.getMessage();
        }
        return result;
    }

    // --------------------------
    // Helpers / Shared logic
    // --------------------------

    /**
     * Builds a Smartwaiver link for the given template, prefilled for the signer (adult) and auto-tagged with the contract Id.
     * Example:
     *   https://waiver.smartwaiver.com/w/<GUID>/web/?wautofill_firstname=...&wautofill_lastname=...&wautofill_dobyyyymmdd=YYYYMMDD&wautofill_tag=<ContractId>
     */
    private static String buildSmartwaiverUrl(ContractData cd, Id contractId, Boolean kioskMode){
        String base = 'https://waiver.smartwaiver.com/w/' + cd.template.Third_Party_Template_Id__c + (kioskMode ? '/kiosk/' : '/web/') + '?';

        // Determine adult/signer contact (already done in getContractData)
        Contact signer = cd.currentContact != null ? cd.currentContact : new Contact();

        List<String> params = new List<String>();
        if (!String.isBlank(signer.FirstName)) {
            params.add('wautofill_firstname=' + EncodingUtil.urlEncode(signer.FirstName, 'UTF-8'));
        }
        if (!String.isBlank(signer.LastName)) {
            params.add('wautofill_lastname=' + EncodingUtil.urlEncode(signer.LastName, 'UTF-8'));
        }
        if (signer.Birthdate != null) {
            Date d = signer.Birthdate;
            String yyyymmdd = String.valueOf(d.year()) +
                (d.month() < 10 ? '0' + String.valueOf(d.month()) : String.valueOf(d.month())) +
                (d.day()   < 10 ? '0' + String.valueOf(d.day())   : String.valueOf(d.day()));
            params.add('wautofill_dobyyyymmdd=' + yyyymmdd);
        }

        // Auto-tag with the Salesforce Contract Id so webhook can link back
        params.add('wautofill_tag=' + EncodingUtil.urlEncode((String)contractId, 'UTF-8'));

        return base + String.join(params, '&');
    }

    /**
     * Sends a plain email containing the Smartwaiver link to the signer.
     * Customize as desired or switch to Lightning templates.
     */
    private static void sendWaiverEmail(Contact toContact, String waiverUrl){
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ toContact.Email });
        mail.setSubject('Waiver Signature Request');
        String body = 'Hello ' + (String.isBlank(toContact.FirstName) ? 'there' : toContact.FirstName) + ',\n\n'
            + 'Please complete your waiver at the link below:\n'
            + waiverUrl + '\n\n'
            + 'Thank you.';
        mail.setPlainTextBody(body);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
    }

    /**
     * Retrieves the necessary data (template, currentContact/signer) from the contract.
     * Logic preserved from the original implementation, minus DocuSign-specific checks.
     */
    private static ContractData getContractData(Id contractAndFormId){
        if (APP_CONFIG.TREX1__Minimum_Contract_Signing_Age__c == null){
            throw new DocusignException('Minimum signing age has not been set on the app config');
        }

        TREX1__Contract_And_Form__c currentContract;
        TREX1__Contract_Or_Form_Template__c associatedTemplate;
        Contact currentContact;

        List<TREX1__Contract_And_Form__c> contractAndForms = [
            SELECT Id, TREX1__Contact__c, TREX1__Contact__r.Name, TREX1__Contact__r.Email, TREX1__Template_Id__c, TREX1__Third_Party_Envelope_Id__c, TREX1__Primary_Contact_Signature__c,
                   TREX1__Transaction__r.TREX1__Account__r.TREX1__Primary_Contact__c, TREX1__Contact__r.TREX1__Age__c, TREX1__Capture_Status__c
            FROM TREX1__Contract_And_Form__c
            WHERE Id = :contractAndFormId
        ];
        if (!contractAndForms.isEmpty()){
            currentContract = contractAndForms[0];
        }

        if (currentContract != null && String.isNotBlank(currentContract.TREX1__Template_Id__c)) {
            if (!TREX1__Contract_Or_Form_Template__c.Third_Party_Template_Id__c.getDescribe().isAccessible()) {
                throw new DocusignException('Cannot read Third_Party_Template_Id__c on TREX1__Contract_Or_Form_Template__c');
            }
            List<TREX1__Contract_Or_Form_Template__c> templates = [
                SELECT Id, Third_Party_Template_Id__c
                FROM TREX1__Contract_Or_Form_Template__c
                WHERE Id = :currentContract.TREX1__Template_Id__c
            ];
            if (!templates.isEmpty()) {
                associatedTemplate = templates[0];
                if (String.isBlank(associatedTemplate.Third_Party_Template_Id__c)) {
                    throw new DocusignException('Template has no Third_Party_Template_Id__c (Smartwaiver GUID). Id: ' + associatedTemplate.Id);
                }
            }
        }

        if (currentContract != null){
            // Mirror original logic: primary contact signs if participant is under minimum age or if flag is set
            Boolean usePrimary = currentContract.TREX1__Primary_Contact_Signature__c
                || (currentContract.TREX1__Contact__r != null
                    && currentContract.TREX1__Contact__r.TREX1__Age__c < APP_CONFIG.TREX1__Minimum_Contract_Signing_Age__c);

            if (usePrimary) {
                if (String.isNotBlank(currentContract.TREX1__Transaction__r.TREX1__Account__r.TREX1__Primary_Contact__c)) {
                    currentContact = [
                        SELECT Id, FirstName, LastName, Name, Email, Birthdate
                        FROM Contact
                        WHERE Id = :currentContract.TREX1__Transaction__r.TREX1__Account__r.TREX1__Primary_Contact__c
                        LIMIT 1
                    ];
                } else {
                    throw new DocusignException('Primary Contact Not Assigned to the Account.');
                }
            } else {
                if (String.isNotBlank(currentContract.TREX1__Contact__c)) {
                    currentContact = [
                        SELECT Id, FirstName, LastName, Name, Email, Birthdate
                        FROM Contact
                        WHERE Id = :currentContract.TREX1__Contact__c
                        LIMIT 1
                    ];
                } else {
                    throw new DocusignException('Contact Not Assigned to the Contract.');
                }
            }
        }

        return new ContractData(currentContract, associatedTemplate, currentContact);
    }

    // --------------------------
    // Inner classes (unchanged signatures)
    // --------------------------

    public class ContractData{
        public TREX1__Contract_And_Form__c contractAndForm {get; set;}
        public TREX1__Contract_Or_Form_Template__c template {get; set;}
        public Contact currentContact {get; set;}
        public ContractData(TREX1__Contract_And_Form__c contractAndForm, TREX1__Contract_Or_Form_Template__c template, Contact currentContact){
            this.contractAndForm = contractAndForm;
            this.template = template;
            this.currentContact = currentContact;
        }
    }

    public class DocusignResult{
        @AuraEnabled public String result {get; set;}
        @AuraEnabled public String errorMessage {get; set;}
        @AuraEnabled public Boolean isSuccess {get; set;}
    }

    public class DocusignException extends Exception {}
}
