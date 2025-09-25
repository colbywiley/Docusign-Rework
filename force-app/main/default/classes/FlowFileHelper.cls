public with sharing class FlowFileHelper {

    // ===== Inputs from Flow =====
    public class FlowFileRequest {
        @InvocableVariable(required=true)
        public String base64Data;

        @InvocableVariable(required=true)
        public String fileName;

        @InvocableVariable(required=true)
        public Id parentRecordId;

        // Optional: If provided, we update Smartwaiver_Event__c
        @InvocableVariable
        public Id smartwaiverEventId;
    }

    // ===== Outputs back to Flow =====
    public class FlowFileResult {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String  message;
        @InvocableVariable public Id      contentVersionId;
        @InvocableVariable public Id      contentDocumentId;
        @InvocableVariable public Id      smartwaiverEventId;
    }

    @InvocableMethod(label='Save PDF from Base64'
                     description='Decodes base64 and creates a File on the parent record; marks Smartwaiver Event Parsed/Error.')
    public static List<FlowFileResult> savePdfFromBase64(List<FlowFileRequest> requests) {
        List<FlowFileResult> results = new List<FlowFileResult>();
        if (requests == null) return results;

        // Stage ContentVersions (bulk)
        List<ContentVersion> staged = new List<ContentVersion>();
        List<Integer>        stagedToReqIdx = new List<Integer>(); // index mapping

        // Pre-fill results list
        for (Integer i = 0; i < (requests != null ? requests.size() : 0); i++) {
            results.add(new FlowFileResult());
        }

        // 1) Validate & stage CV rows
        for (Integer i = 0; i < requests.size(); i++) {
            FlowFileRequest req = requests[i];
            FlowFileResult  res = results[i];
            res.smartwaiverEventId = (req != null) ? req.smartwaiverEventId : null;

            try {
                if (req == null)                           { fail(res, 'Null request.'); continue; }
                if (String.isBlank(req.base64Data))        { fail(res, 'base64Data is blank.'); continue; }
                if (String.isBlank(req.fileName))          { fail(res, 'fileName is blank.'); continue; }
                if (req.parentRecordId == null)            { fail(res, 'parentRecordId is required.'); continue; }

                Blob pdf;
                try {
                    pdf = EncodingUtil.base64Decode(req.base64Data);
                } catch (Exception decodeEx) {
                    fail(res, 'Invalid base64: ' + decodeEx.getMessage()); continue;
                }
                if (pdf == null || pdf.size() == 0)        { fail(res, 'Decoded PDF is empty.'); continue; }

                ContentVersion cv = new ContentVersion();
                cv.Title        = cropTitleWithoutExtension(req.fileName);
                cv.PathOnClient = ensurePdfExtension(req.fileName);
                cv.VersionData  = pdf;

                // We'll create the ContentDocumentLink ourselves => do NOT set FirstPublishLocationId here.
                staged.add(cv);
                stagedToReqIdx.add(i);

            } catch (Exception e) {
                fail(res, 'Staging error: ' + e.getMessage());
            }
        }

        // For Smartwaiver_Event__c updates
        List<Smartwaiver_Event__c> eventsToUpdate = new List<Smartwaiver_Event__c>();

        // 2) Insert ContentVersion in bulk
        if (!staged.isEmpty()) {
            Database.SaveResult[] cvSRs = Database.insert(staged, /*allOrNone*/ false);

            // Collect CV IDs (successes) to fetch their ContentDocumentId in one query
            List<Id> successfulCvIds = new List<Id>();
            // Map CV Id -> request index
            Map<Id, Integer> cvIdToReqIdx = new Map<Id, Integer>();

            for (Integer s = 0; s < cvSRs.size(); s++) {
                Integer reqIdx = stagedToReqIdx[s];
                FlowFileResult res = results[reqIdx];

                if (!cvSRs[s].isSuccess()) {
                    String err = firstError(cvSRs[s]);
                    fail(res, err);

                    // Mark Smartwaiver Event = Error (if provided)
                    Id sweId = results[reqIdx].smartwaiverEventId;
                    if (sweId != null) {
                        Smartwaiver_Event__c ev = new Smartwaiver_Event__c(
                            Id = sweId,
                            Status__c = 'Error',
                            Error_Reason__c = err
                        );
                        eventsToUpdate.add(ev);
                    }
                    continue;
                }

                Id cvId = (Id) cvSRs[s].getId();
                successfulCvIds.add(cvId);
                cvIdToReqIdx.put(cvId, reqIdx);
            }

            // 3) Query back ContentDocumentId for successes (single SOQL)
            Map<Id, ContentVersion> cvById = new Map<Id, ContentVersion>(
                [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :successfulCvIds]
            );

            // 4) Build & insert ContentDocumentLinks for successes
            List<ContentDocumentLink> links = new List<ContentDocumentLink>();
            // Track link order to request index mapping
            List<Integer> linkToReqIdx = new List<Integer>();

            for (Id cvId : successfulCvIds) {
                ContentVersion cv = cvById.get(cvId);
                Integer reqIdx = cvIdToReqIdx.get(cvId);
                FlowFileRequest req = requests[reqIdx];

                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = cv.ContentDocumentId;
                cdl.LinkedEntityId    = req.parentRecordId;
                cdl.ShareType         = 'V';              // Viewer
                cdl.Visibility        = 'InternalUsers';  // Always internal per your requirement
                links.add(cdl);
                linkToReqIdx.add(reqIdx);
            }

            if (!links.isEmpty()) {
                Database.SaveResult[] linkSRs = Database.insert(links, /*allOrNone*/ false);

                // 5) Finalize results per request and prep Smartwaiver Event updates
                for (Integer k = 0; k < linkSRs.size(); k++) {
                    Integer reqIdx = linkToReqIdx[k];
                    FlowFileResult  res = results[reqIdx];

                    // We know the CV insert succeeded for this reqIdx, so fetch IDs again
                    // Find the cvId mapped to this reqIdx
                    Id cvId = null; Id cdId = null;
                    for (Id keyCvId : cvIdToReqIdx.keySet()) {
                        if (cvIdToReqIdx.get(keyCvId) == reqIdx) {
                            cvId = keyCvId;
                            ContentVersion cv = cvById.get(cvId);
                            if (cv != null) cdId = cv.ContentDocumentId;
                            break;
                        }
                    }

                    if (!linkSRs[k].isSuccess()) {
                        String err = firstError(linkSRs[k]);
                        fail(res, 'File created but link failed: ' + err);
                        res.contentVersionId = cvId;
                        res.contentDocumentId = cdId;

                        // Mark Smartwaiver Event = Error (if provided)
                        Id sweId = results[reqIdx].smartwaiverEventId;
                        if (sweId != null) {
                            Smartwaiver_Event__c ev = new Smartwaiver_Event__c(
                                Id = sweId,
                                Status__c = 'Error',
                                Error_Reason__c = err
                            );
                            eventsToUpdate.add(ev);
                        }
                    } else {
                        res.success = true;
                        res.message = 'File saved and linked.';
                        res.contentVersionId  = cvId;
                        res.contentDocumentId = cdId;

                        // Mark Smartwaiver Event = Parsed (if provided)
                        Id sweId = results[reqIdx].smartwaiverEventId;
                        if (sweId != null) {
                            Smartwaiver_Event__c ev = new Smartwaiver_Event__c(
                                Id = sweId,
                                Status__c = 'Parsed',
                                Error_Reason__c = null
                            );
                            eventsToUpdate.add(ev);
                        }
                    }
                }
            }
        }

        // 6) Update Smartwaiver Events (bulk)
        if (!eventsToUpdate.isEmpty()) {
            try {
                Database.update(eventsToUpdate, /*allOrNone*/ false);
            } catch (Exception e) {
                // Don’t fail the whole action; Flow already has per-item messages.
                System.debug('Smartwaiver_Event__c update error: ' + e.getMessage());
            }
        }

        return results;
    }

    // ===== Helpers =====

    private static void fail(FlowFileResult res, String msg) {
        res.success = false;
        res.message = msg;
    }

    private static String firstError(Database.SaveResult sr) {
        for (Database.Error e : sr.getErrors()) return e.getMessage();
        return 'Unknown error';
    }

    private static String ensurePdfExtension(String name) {
        String n = name == null ? '' : name.trim();
        if (!n.toLowerCase().endsWith('.pdf')) n += '.pdf';
        return n;
    }

    private static String cropTitleWithoutExtension(String name) {
        String n = name == null ? '' : name.trim();
        if (n.toLowerCase().endsWith('.pdf')) n = n.substring(0, n.length() - 4);
        if (n.length() > 255) n = n.substring(0, 255);
        return n;
    }
}
