// SmartwaiverFinalizeController.cls
public without sharing class SmartwaiverFinalizeController {
    public class FinalizeResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  message;
        @AuraEnabled public Id      contractId;
    }

    @AuraEnabled(cacheable=false)
    public static FinalizeResult finalizeByWaiver(String waiverId, String autoTagFromQuery) {
        FinalizeResult r = new FinalizeResult();
        try {
            if (String.isBlank(waiverId)) throw new AuraHandledException('Missing waiverId');

            // Call the existing Flow Action to fetch waiver JSON (+ PDF)
            SW_SmartwaiverFlowAction.InputWrapper iw = new SW_SmartwaiverFlowAction.InputWrapper();
            iw.waiverId = waiverId;
            iw.retrievePdf = true;
            List<SW_SmartwaiverFlowAction.OutputWrapper> outs =
                SW_SmartwaiverFlowAction.fetchWaivers(new List<SW_SmartwaiverFlowAction.InputWrapper>{ iw });
            if (outs.isEmpty()) throw new AuraHandledException('No waiver returned from Smartwaiver.');

            SW_SmartwaiverFlowAction.OutputWrapper ow = outs[0];

            // Determine the Contract Id: prefer the value parsed from waiver (autoTag), fall back to query string
            String tag = String.isNotBlank(ow.autoTagValue) ? ow.autoTagValue : autoTagFromQuery;
            if (!isSalesforceId(tag)) throw new AuraHandledException('Missing/invalid contract Id (autotag).');

            Id contractId = (Id) tag;

            // Fetch the contract (also used to dedupe file writes)
            TREX1__Contract_And_Form__c c = [
                SELECT Id, Name, Signed_Contract_Retrieved__c, TREX1__Status__c
                FROM TREX1__Contract_And_Form__c
                WHERE Id = :contractId
                LIMIT 1
            ];

            // Attach PDF if provided and not already retrieved
            if (!c.Signed_Contract_Retrieved__c && !String.isBlank(ow.pdfValue)) {
                Blob pdfBlob = EncodingUtil.base64Decode(ow.pdfValue);
                ContentVersion cv = new ContentVersion();
                cv.Title = 'Completed Smartwaiver Waiver';
                cv.PathOnClient = 'Completed_Smartwaiver_Waiver.pdf';
                cv.VersionData = pdfBlob;
                cv.FirstPublishLocationId = c.Id;
                insert cv;
            }

            // Mark complete (idempotent)
            TREX1__Contract_And_Form__c upd = new TREX1__Contract_And_Form__c(
                Id = c.Id,
                TREX1__Has_Been_Signed__c     = true,
                TREX1__Status__c              = 'Complete',
                TREX1__Date_Signed__c         = Date.today(),
                TREX1__Third_Party_Envelope_Id__c = waiverId,
                Signed_Contract_Retrieved__c  = true
            );
            update upd;

            r.success = true;
            r.contractId = contractId;
            r.message = 'Finalized';
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