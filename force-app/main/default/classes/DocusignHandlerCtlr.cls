/**
 * DocusignHandlerCtlr
 * Unified controller:
 *  - If template.Waiver_Provider__c = 'DocuSign' (or blank), use original DocuSign behavior
 *  - If template.Waiver_Provider__c = 'Smartwaiver', use Smartwaiver behavior
 *
 * Includes Smartwaiver "finalize" endpoint used by the redirect page (DocusignHandler.app?flowType=Finish&event=signing_complete&waiverId=...)
 * and resilient PDF fetch classification so the UI can poll on NOT_READY / TRANSIENT_RETRY.
 */
public without sharing class DocusignHandlerCtlr {
    // --------------------------
    // Constants
    // --------------------------
    private static final String PL_CAPTURE_STATUS_IN_PERSON = 'In Person';
    private static final String PL_CAPTURE_STATUS_VIA_EMAIL = 'Via Email';
    private static final String EMAIL_DOCUMENT              = 'Email';
    private static final String SIGN_DOCUMENT               = 'Sign';
    private static final String CONTRACT_SENT               = 'Sent';
    private static final String CONTRACT_COMPLETE           = 'Complete';
    private static final String PROVIDER_SMART              = 'Smartwaiver';
    private static final String PROVIDER_DOCU               = 'DocuSign';

    private static final TREX1__App_Config__c APP_CONFIG = TREX1__App_Config__c.getOrgDefaults();

    // --------------------------
    // Retry signaling for Smartwaiver
    // --------------------------
    public class SmartwaiverRetryException extends Exception {}

    // --------------------------
    // Public API (unchanged signatures)
    // --------------------------

    @AuraEnabled
    public static DocusignResult docusignEmail(String contractAndFormId){
        DocusignResult result = new DocusignResult();
        try{
            ContractData cd = getContractData(contractAndFormId);
            if (cd == null) throw new DocusignException('Contract not found.');

            Boolean isSmart = (cd.provider != null && cd.provider.equalsIgnoreCase(PROVIDER_SMART));
            if (!isSmart) {
                // -------- DocuSign branch (original) --------
                TREX1__Contract_And_Form__c c = cd.contractAndForm;
                if (String.isNotBlank(c.TREX1__Capture_Status__c) && String.isNotBlank(c.TREX1__Third_Party_Envelope_Id__c)){
                    // Already sent once; resend
                    result = docusignResend(contractAndFormId);
                    if (result.isSuccess) {
                        result.result = c.TREX1__Third_Party_Envelope_Id__c;
                    }
                    return result;
                }
                if (String.isBlank(cd.template.Third_Party_Template_Id__c)) {
                    throw new DocusignException('Third party template id is blank - check permissions');
                }

                List<String> templateIds = new List<String>{ cd.template.Third_Party_Template_Id__c };
                Docusign ds = new Docusign(
                    contractAndFormId,
                    c.TREX1__Third_Party_Envelope_Id__c,
                    EMAIL_DOCUMENT,
                    templateIds,
                    cd.currentContact,
                    buildReturnUrl((Id)contractAndFormId)
                );

                String envelopeId = ds.createEnvelope();
                ds.upsertAccessTokenSetting();

                if (String.isBlank(c.TREX1__Third_Party_Envelope_Id__c)){
                    updateContractAndFormWithEnvelopeId(contractAndFormId, envelopeId, CONTRACT_SENT, PL_CAPTURE_STATUS_VIA_EMAIL);
                }

                result.isSuccess = true;
                result.result = envelopeId;
                return result;
            }

            // -------- Smartwaiver branch --------
            if (cd.template == null || String.isBlank(cd.template.Third_Party_Template_Id__c)) {
                throw new DocusignException('Smartwaiver Template GUID is blank - check permissions and template config.');
            }
            if (cd.currentContact == null || String.isBlank(cd.currentContact.Email)) {
                throw new DocusignException('Signer email is required.');
            }

            String waiverUrl = buildSmartwaiverUrl(cd, (Id)contractAndFormId, false /*kiosk*/);
            sendWaiverEmail(cd.currentContact, waiverUrl);

            upsert new TREX1__Contract_And_Form__c(
                Id = (Id)contractAndFormId,
                TREX1__Status__c = CONTRACT_SENT,
                TREX1__Capture_Status__c = PL_CAPTURE_STATUS_VIA_EMAIL
            );

            result.isSuccess = true;
            result.result = waiverUrl; // informational
            return result;

        } catch(Exception ex){
            result.isSuccess = false;
            result.errorMessage = ex.getMessage();
            return result;
        }
    }

    // Replaces deprecated URL.getSalesforceBaseUrl()
    // - Internal: returns My Domain (https://<mydomain>.my.salesforce.com)
    // - Experience Cloud: returns the site URL incl. prefix (https://<domain>/<prefix>)
    private static String buildReturnUrl(Id contractAndFormId) {
        ConnectApi.Community community =
            DocusignCommunityService.isCurrentRequestCommunity()
            ? DocusignCommunityService.getCurrentRequestCommunity()
            : null;

        String base;
        if (community != null && !String.isBlank(community.siteUrl)) {
            base = community.siteUrl;
        } else {
            base = URL.getOrgDomainUrl().toExternalForm();
        }
        if (base.endsWith('/')) base = base.left(base.length() - 1);
        return base + '/c/DocusignHandler.app?recordId=' + contractAndFormId + '&flowType=Finish';
    }

    @AuraEnabled
    public static DocusignResult docusignSign(String contractAndFormId){
        DocusignResult result = new DocusignResult();
        try{
            ContractData cd = getContractData(contractAndFormId);
            if (cd == null) throw new DocusignException('Contract not found.');

            Boolean isSmart = (cd.provider != null && cd.provider.equalsIgnoreCase(PROVIDER_SMART));
            if (!isSmart) {
                // -------- DocuSign branch (original) --------
                if (String.isBlank(cd.template.Third_Party_Template_Id__c)) {
                    throw new DocusignException('Third party template id is blank - check permissions');
                }
                List<String> templateIds = new List<String>{ cd.template.Third_Party_Template_Id__c };

                Docusign ds = new Docusign(
                    contractAndFormId,
                    cd.contractAndForm.TREX1__Third_Party_Envelope_Id__c,
                    SIGN_DOCUMENT,
                    templateIds,
                    cd.currentContact,
                    buildReturnUrl((Id)contractAndFormId)
                );

                String docusignURL = ds.getPostRecipientView();
                String envelopeId  = ds.options.envelopeId;

                ds.upsertAccessTokenSetting();
                if (String.isBlank(cd.contractAndForm.TREX1__Third_Party_Envelope_Id__c)){
                    updateContractAndFormWithEnvelopeId(contractAndFormId, envelopeId, CONTRACT_SENT, PL_CAPTURE_STATUS_IN_PERSON);
                }
                result.isSuccess = true;
                result.result = docusignURL;
                return result;
            }

            // -------- Smartwaiver branch --------
            if (cd.template == null || String.isBlank(cd.template.Third_Party_Template_Id__c)) {
                throw new DocusignException('Smartwaiver Template GUID is blank - check permissions and template config.');
            }
            String waiverUrl = buildSmartwaiverUrl(cd, (Id)contractAndFormId, false /*web*/);

            upsert new TREX1__Contract_And_Form__c(
                Id = (Id)contractAndFormId,
                TREX1__Status__c = CONTRACT_SENT,
                TREX1__Capture_Status__c = PL_CAPTURE_STATUS_IN_PERSON
            );

            result.isSuccess = true;
            result.result = waiverUrl;
            return result;

        } catch(Exception ex){
            result.isSuccess = false;
            result.errorMessage = ex.getMessage();
            return result;
        }
    }

    @AuraEnabled
    public static DocusignResult docusignResend(String contractAndFormId){
        DocusignResult result = new DocusignResult();
        try{
            ContractData cd = getContractData(contractAndFormId);
            if (cd == null) throw new DocusignException('Contract not found.');

            Boolean isSmart = (cd.provider != null && cd.provider.equalsIgnoreCase(PROVIDER_SMART));
            if (!isSmart) {
                // -------- DocuSign branch (original) --------
                if (String.isBlank(cd.template.Third_Party_Template_Id__c)) {
                    throw new DocusignException('Third party template id is blank - check permissions');
                }
                List<String> templateIds = new List<String>{ cd.template.Third_Party_Template_Id__c };

                Docusign ds = new Docusign(
                    contractAndFormId,
                    cd.contractAndForm.TREX1__Third_Party_Envelope_Id__c,
                    '',
                    templateIds,
                    cd.currentContact,
                    buildReturnUrl((Id)contractAndFormId)
                );

                ds.resendEnvelope();
                ds.upsertAccessTokenSetting();
                result.isSuccess = true;
                return result;
            }

            // -------- Smartwaiver branch --------
            // For Smartwaiver, "resend" = send the email again with the same Smartwaiver link
            return docusignEmail(contractAndFormId);

        } catch(Exception ex){
            result.isSuccess = false;
            result.errorMessage = ex.getMessage();
            return result;
        }
    }

    @AuraEnabled
    public static DocusignResult docusignPDF(String contractAndFormId){
        DocusignResult result = new DocusignResult();
        try{
            ContractData cd = getContractData(contractAndFormId);
            if (cd == null) throw new DocusignException('Contract not found.');
            Boolean isSmart = (cd.provider != null && cd.provider.equalsIgnoreCase(PROVIDER_SMART));

            if (!isSmart) {
                // -------- DocuSign branch (original) --------
                List<String> templateIds = new List<String>();
                if (cd.template != null && String.isNotBlank(cd.template.Third_Party_Template_Id__c)) {
                    templateIds.add(cd.template.Third_Party_Template_Id__c);
                }
                Docusign ds = new Docusign(
                    contractAndFormId,
                    cd.contractAndForm.TREX1__Third_Party_Envelope_Id__c,
                    '',
                    templateIds,
                    cd.currentContact,
                    buildReturnUrl((Id)contractAndFormId)
                );

                insert ds.getEnvelopeDocuments();
                ds.upsertAccessTokenSetting();
                result.isSuccess = true;
                return result;
            }

            // -------- Smartwaiver branch --------
            TREX1__Contract_And_Form__c c = [
                SELECT Id, Name, TREX1__Third_Party_Envelope_Id__c, TREX1__Status__c, Signed_Contract_Retrieved__c
                FROM TREX1__Contract_And_Form__c
                WHERE Id = :contractAndFormId
                LIMIT 1
            ];
            if (String.isBlank(c.TREX1__Third_Party_Envelope_Id__c)) {
                throw new DocusignException('No Smartwaiver Waiver ID found on the contract. Has the webhook processed this waiver yet?');
            }

            // single attempt (manual fetch); errors bubble
            fetchAndAttachWaiverPdf(c.Id, c.TREX1__Third_Party_Envelope_Id__c);

            result.isSuccess = true;
            return result;

        } catch(Exception ex){
            result.isSuccess = false;
            result.errorMessage = ex.getMessage();
            return result;
        }
    }

    /**
     * Smartwaiver finalize entry (called by redirect page).
     * - Stores waiverId (if provided) onto Third_Party_Envelope_Id__c
     * - If PDF already retrieved, returns success
     * - Attempts one fetch; for 404/429/5xx throws SmartwaiverRetryException (UI will poll)
     */
    @AuraEnabled
    public static DocusignResult smartwaiverFinalize(String contractAndFormId, String waiverId){
        DocusignResult res = new DocusignResult();
        try {
            TREX1__Contract_And_Form__c c = [
                SELECT Id, TREX1__Third_Party_Envelope_Id__c, Signed_Contract_Retrieved__c, TREX1__Template_Id__c
                FROM TREX1__Contract_And_Form__c
                WHERE Id = :contractAndFormId
                LIMIT 1
            ];

            // Confirm Smartwaiver template (defensive; prevents calling this for DocuSign)
            TREX1__Contract_Or_Form_Template__c tmpl = c.TREX1__Template_Id__c == null ? null :
                [SELECT Id, Waiver_Provider__c, Third_Party_Template_Id__c
                 FROM TREX1__Contract_Or_Form_Template__c
                 WHERE Id = :c.TREX1__Template_Id__c
                 LIMIT 1];

            if (tmpl == null || tmpl.Waiver_Provider__c != PROVIDER_SMART) {
                res.isSuccess = false;
                res.errorMessage = 'This contract is not configured for Smartwaiver.';
                return res;
            }

            // Already done?
            if (c.Signed_Contract_Retrieved__c) {
                res.isSuccess = true;
                return res;
            }

            // Choose a waiver id to try (use existing on record, else the one from redirect)
            String candidate = String.isNotBlank(c.TREX1__Third_Party_Envelope_Id__c)
                ? c.TREX1__Third_Party_Envelope_Id__c
                : (String.isNotBlank(waiverId) ? waiverId : null);

            if (String.isBlank(candidate)) {
                // Signal UI to keep polling; Smartwaiver may not have produced an id yet
                res.isSuccess = false;
                res.errorMessage = 'NOT_READY: No Smartwaiver found yet for this contract. Please wait a few seconds.';
                return res;
            }

            // IMPORTANT: Callout FIRST (no prior DML in this method)
            fetchAndAttachWaiverPdf(c.Id, candidate);

            // After successful fetch + attach, persist the waiver id if we learned it from the redirect
            if (String.isBlank(c.TREX1__Third_Party_Envelope_Id__c) && String.isNotBlank(waiverId)) {
                update new TREX1__Contract_And_Form__c(
                    Id = c.Id,
                    TREX1__Third_Party_Envelope_Id__c = waiverId
                );
            }

            res.isSuccess = true;
            return res;

        } catch (SmartwaiverRetryException sre) {
            res.isSuccess = false;
            res.errorMessage = String.valueOf(sre.getMessage()); // contains NOT_READY or TRANSIENT_RETRY
            return res;
        } catch (Exception e) {
            res.isSuccess = false;
            res.errorMessage = e.getMessage();
            return res;
        }
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
    // Helpers
    // --------------------------

    private static String buildSmartwaiverUrl(ContractData cd, Id contractId, Boolean kioskMode){
        String base = 'https://waiver.smartwaiver.com/w/' + cd.template.Third_Party_Template_Id__c + (kioskMode ? '/kiosk/' : '/web/') + '?';

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
            String yyyymmdd =
                String.valueOf(d.year()) +
                (d.month() < 10 ? '0' : '') + String.valueOf(d.month()) +
                (d.day()   < 10 ? '0' : '') + String.valueOf(d.day());
            params.add('wautofill_dobyyyymmdd=' + yyyymmdd);
        }
        // NEW: prefill email if available
        if (!String.isBlank(signer.Email)) {
            params.add('wautofill_email=' + EncodingUtil.urlEncode(signer.Email, 'UTF-8'));
        }

        // Use Salesforce Contract Id as auto tag so webhook/finalizer can map back
        params.add('wautofill_tag=' + EncodingUtil.urlEncode((String)contractId, 'UTF-8'));

        // Build the URL, then append a redirect back to our handler (works in both internal and Communities)
        String url = base + String.join(params, '&');
        url = withSmartwaiverRedirect(url, contractId);
        return url;
    }

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
            // Need template provider + third party template id
            if (!TREX1__Contract_Or_Form_Template__c.Waiver_Provider__c.getDescribe().isAccessible()
                || !TREX1__Contract_Or_Form_Template__c.Third_Party_Template_Id__c.getDescribe().isAccessible()) {
                throw new DocusignException('Cannot read template fields (Waiver_Provider__c / Third_Party_Template_Id__c). Check field-level security.');
            }
            List<TREX1__Contract_Or_Form_Template__c> templates = [
                SELECT Id, Waiver_Provider__c, Third_Party_Template_Id__c
                FROM TREX1__Contract_Or_Form_Template__c
                WHERE Id = :currentContract.TREX1__Template_Id__c
            ];
            if (!templates.isEmpty()) {
                associatedTemplate = templates[0];
            }
        }

        if (currentContract != null){
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

        // Default provider to DocuSign if blank (backward compatible)
        String providerValue = (associatedTemplate != null && !String.isBlank(associatedTemplate.Waiver_Provider__c))
            ? associatedTemplate.Waiver_Provider__c
            : PROVIDER_DOCU;

        return new ContractData(currentContract, associatedTemplate, currentContact, providerValue);
    }

    private static void updateContractAndFormWithEnvelopeId(Id contractAndFormId, String envelopeId, String status, String captureStatus){
        upsert new TREX1__Contract_And_Form__c(
            Id = contractAndFormId,
            TREX1__Third_Party_Envelope_Id__c = envelopeId,
            TREX1__Status__c = status,
            TREX1__Capture_Status__c = captureStatus
        );
    }

    // Fetch once; classify retryable conditions for the UI
    private static void fetchAndAttachWaiverPdf(Id contractId, String waiverId) {
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint('callout:Smartwaiver_Named_Credential/waivers/' +
                        EncodingUtil.urlEncode(waiverId, 'UTF-8') +
                        '?pdf=true');

        HttpResponse resp = new Http().send(req);
        Integer sc = resp.getStatusCode();

        if (sc == 200) {
            Map<String,Object> root   = (Map<String,Object>)JSON.deserializeUntyped(resp.getBody());
            Map<String,Object> waiver = (Map<String,Object>)root.get('waiver');
            if (waiver == null || waiver.get('pdf') == null) {
                throw new DocusignException('Smartwaiver response missing PDF.');
            }
            Blob pdfBlob = EncodingUtil.base64Decode((String)waiver.get('pdf'));

            ContentVersion cv = new ContentVersion();
            cv.Title = 'Completed Smartwaiver Waiver';
            cv.PathOnClient = 'Completed_Smartwaiver_Waiver.pdf';
            cv.VersionData = pdfBlob;
            cv.FirstPublishLocationId = contractId;
            insert cv;

            update new TREX1__Contract_And_Form__c(
                Id = contractId,
                Signed_Contract_Retrieved__c = true
            );
            return;
        }

        String statusLine = resp.getStatus();
        String body       = resp.getBody();

        // 404 = not yet queryable by ID -> retry
        if (sc == 404) {
            throw new SmartwaiverRetryException('NOT_READY: ' + statusLine + ' - ' + body);
        }
        // Transient conditions -> retry
        if (sc == 429 || sc == 500 || sc == 502 || sc == 503 || sc == 504) {
            throw new SmartwaiverRetryException('TRANSIENT_RETRY: ' + statusLine + ' - ' + body);
        }

        // Anything else = hard failure
        throw new DocusignException('Smartwaiver PDF fetch failed: ' + statusLine + ' - ' + body);
    }

    /** Returns https://<current-host>[/sfsites]/c/DocusignHandler.app?... */
    private static String buildFinishUrl(Id contractId) {
        Url req = URL.getCurrentRequestUrl();                   // current request host (org or community)
        String base = req.getProtocol() + '://' + req.getHost();
        // Robust community detection
        Boolean isCommunity = (Network.getNetworkId() != null);
        String lightningPrefix = (isCommunity ? '/sfsites' : '') + '/c';

        String qs = 'flowType=Finish'
                  + '&event=signing_complete'
                  + '&recordId=' + EncodingUtil.urlEncode(String.valueOf(contractId), 'UTF-8');

        return base + lightningPrefix + '/DocusignHandler.app?' + qs;
    }

    /** Adds/overwrites Smartwaiver redirect parameter */
    private static String withSmartwaiverRedirect(String smartwaiverUrl, Id contractId) {
        String finishUrl = buildFinishUrl(contractId);
        String enc = EncodingUtil.urlEncode(finishUrl, 'UTF-8');
        // Remove any existing redirect= to avoid duplicates
        if (smartwaiverUrl.contains('redirect=')) {
            // crude but safe enough for this case
            smartwaiverUrl = smartwaiverUrl.replaceAll('([?&])redirect=[^&]*', '$1');
            // strip trailing & or ? if we ended up with them
            if (smartwaiverUrl.endsWith('&') || smartwaiverUrl.endsWith('?')) {
                smartwaiverUrl = smartwaiverUrl.substring(0, smartwaiverUrl.length()-1);
            }
        }
        String glue = smartwaiverUrl.contains('?') ? '&' : '?';
        return smartwaiverUrl + glue + 'redirect=' + enc;
    }

    // --------------------------
    // Inner classes (unchanged shapes)
    // --------------------------

    public class ContractData{
        public TREX1__Contract_And_Form__c contractAndForm {get; set;}
        public TREX1__Contract_Or_Form_Template__c template {get; set;}
        public Contact currentContact {get; set;}
        public String provider {get; set;}
        public ContractData(TREX1__Contract_And_Form__c contractAndForm,
                            TREX1__Contract_Or_Form_Template__c template,
                            Contact currentContact,
                            String provider){
            this.contractAndForm = contractAndForm;
            this.template = template;
            this.currentContact = currentContact;
            this.provider = provider;
        }
    }

    public class DocusignResult{
        @AuraEnabled public String result {get; set;}
        @AuraEnabled public String errorMessage {get; set;}
        @AuraEnabled public Boolean isSuccess {get; set;}
    }

    public class DocusignException extends Exception {}
}