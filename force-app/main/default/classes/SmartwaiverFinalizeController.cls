// SmartwaiverFinalizeController.cls
public without sharing class SmartwaiverFinalizeController {
    public class FinalizeResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  message;
        @AuraEnabled public Id      contractId;
    }

    /**
     * finalizeByWaiver
     * - Persists waiverId (if provided and not already stored)
     * - Marks the contract signed/complete
     * - DOES NOT call Smartwaiver nor attach PDFs (webhook/Flow now handles that)
     */
    @AuraEnabled(cacheable=false)
    public static FinalizeResult finalizeByWaiver(String waiverId, String autoTagFromQuery) {
        FinalizeResult r = new FinalizeResult();
        try {
            // We now rely on the contract id passed in the URL (autoTagFromQuery)
            if (String.isBlank(autoTagFromQuery)) {
                throw new AuraHandledException('Missing contract Id.');
            }
            if (!isSalesforceId(autoTagFromQuery)) {
                throw new AuraHandledException('Invalid contract Id.');
            }

            Id contractId = (Id) autoTagFromQuery;

            TREX1__Contract_And_Form__c c = [
                SELECT Id,
                       TREX1__Status__c,
                       TREX1__Has_Been_Signed__c,
                       TREX1__Third_Party_Envelope_Id__c
                FROM TREX1__Contract_And_Form__c
                WHERE Id = :contractId
                LIMIT 1
            ];

            // Only set the waiver id if we learned it here and the field is still blank
            TREX1__Contract_And_Form__c upd = new TREX1__Contract_And_Form__c(Id = c.Id);
            if (String.isNotBlank(waiverId) && String.isBlank(c.TREX1__Third_Party_Envelope_Id__c)) {
                upd.TREX1__Third_Party_Envelope_Id__c = waiverId;
            }

            // Mark as signed/complete (idempotent)
            upd.TREX1__Has_Been_Signed__c = true;
            upd.TREX1__Status__c          = 'Complete';
            // If you track signed date, uncomment:
            // upd.TREX1__Date_Signed__c      = Date.today();

            update upd;

            r.success    = true;
            r.contractId = contractId;
            r.message    = 'Recorded signature. PDF will be attached by the webhook/Flow.';
        } catch (Exception e) {
            r.success = false;
            r.message = e.getMessage();
        }
        return r;
    }

    private static Boolean isSalesforceId(String s) {
        if (String.isBlank(s)) return false;
        Integer len = s.length();
        if (len != 15 && len != 18) return false;
        for (Integer i = 0; i < len; i++) {
            String ch = s.substring(i, i+1);
            if (!((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9'))) {
                return false;
            }
        }
        return true;
    }
}
